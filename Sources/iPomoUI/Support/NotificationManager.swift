import AVFoundation
import Foundation
import UserNotifications

import iPomoCore

@MainActor
final class NotificationManager: NSObject, UNUserNotificationCenterDelegate {
    private static let reminderPrefix = "ipomo.reminder."
    private static let reminderIdentifiers = (0..<24).map { "\(reminderPrefix)\($0)" }
    private var requesting = false
    private var pendingReminders: (reminders: [(offset: TimeInterval, body: String)], title: String, sound: UNNotificationSound)?
    private(set) var authorized = false
    private(set) var permissionError: String?

    private var center: UNUserNotificationCenter? {
        guard Bundle.main.bundleIdentifier != nil else { return nil }
        return UNUserNotificationCenter.current()
    }

    override init() {
        super.init()
        installDelegateIfNeeded()
    }

    func requestAuthorization() {
        guard !requesting else { return }
        requesting = true
        guard let center else {
            requesting = false
            return
        }
        installDelegateIfNeeded()
        center.requestAuthorization(options: [.alert, .sound]) { [weak self] granted, error in
            Task { @MainActor in
                self?.authorized = granted
                self?.permissionError = error?.localizedDescription
                self?.requesting = false
                if granted {
                    self?.installPendingReminders()
                } else {
                    self?.pendingReminders = nil
                }
            }
        }
    }

    func notify(
        title: String,
        body: String,
        identifier: String = UUID().uuidString,
        sound: UNNotificationSound = .default
    ) {
        guard let center else { return }
        installDelegateIfNeeded()
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = sound
        if #available(macOS 12.0, *) {
            content.interruptionLevel = .timeSensitive
        }
        let request = UNNotificationRequest(
            identifier: identifier,
            content: content,
            trigger: nil
        )
        center.add(request) { _ in }
    }

    func notify(
        title: String,
        body: String,
        identifier: String = UUID().uuidString,
        settings: NotificationSettings
    ) {
        notify(title: title, body: body, identifier: identifier, sound: notificationSound(for: settings))
    }

    /// Schedules local reminders at the given offsets from now. Permission is
    /// requested if needed, and the reminders are installed once it is granted.
    func scheduleReminders(
        _ reminders: [(offset: TimeInterval, body: String)],
        title: String,
        sound: UNNotificationSound = .default
    ) {
        pendingReminders = (reminders, title, sound)
        if authorized {
            installPendingReminders()
        } else {
            requestAuthorization()
        }
    }

    /// Removes every reminder by its fixed identifier, so a late system reply
    /// cannot delete reminders that were just scheduled.
    func removeReminders() {
        pendingReminders = nil
        guard let center else { return }
        center.removePendingNotificationRequests(withIdentifiers: Self.reminderIdentifiers)
    }

    private func installPendingReminders() {
        guard let pending = pendingReminders, let center else { return }
        pendingReminders = nil
        removeReminders()
        for (index, reminder) in pending.reminders.prefix(Self.reminderIdentifiers.count).enumerated() {
            guard reminder.offset > 1 else { continue }
            let content = UNMutableNotificationContent()
            content.title = pending.title
            content.body = reminder.body
            content.sound = pending.sound
            if #available(macOS 12.0, *) {
                content.interruptionLevel = .timeSensitive
            }
            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: reminder.offset, repeats: false)
            let request = UNNotificationRequest(
                identifier: Self.reminderIdentifiers[index],
                content: content,
                trigger: trigger
            )
            center.add(request) { _ in }
        }
    }

    private func installDelegateIfNeeded() {
        guard let center else { return }
        if center.delegate !== self {
            center.delegate = self
        }
    }

    // MARK: - Sound resolution

    func notificationSound(for settings: NotificationSettings) -> UNNotificationSound {
        switch settings.notificationSound {
        case .default:
            return .default
        case .custom:
            if let fileName = settings.customNotificationSoundFileName,
               fileExists(fileName) {
                return UNNotificationSound(named: UNNotificationSoundName(fileName))
            }
            return .default
        default:
            guard let systemName = settings.notificationSound.systemSoundName else {
                return .default
            }
            let stagedName = "iPomo-\(systemName).aiff"
            stageSystemSound(named: systemName, as: stagedName)
            if fileExists(stagedName) {
                return UNNotificationSound(named: UNNotificationSoundName(stagedName))
            }
            return .default
        }
    }

    // MARK: - Custom sound import

    /// Validates and stages a user-selected audio file. Returns the staged file
    /// name on success, or `nil` when the file cannot be used.
    func importCustomSound(from url: URL) -> String? {
        let ext = url.pathExtension.lowercased()
        guard ["aiff", "aif", "wav", "caf", "mp3", "m4a"].contains(ext) else { return nil }
        guard let audioFile = try? AVAudioFile(forReading: url) else { return nil }
        let duration = Double(audioFile.length) / audioFile.processingFormat.sampleRate
        guard duration > 0, duration <= 30 else { return nil }

        let directory = soundsDirectoryURL
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        } catch {
            return nil
        }
        let fileName = "iPomo-Custom.\(ext)"
        let destination = directory.appendingPathComponent(fileName)
        if FileManager.default.fileExists(atPath: destination.path) {
            try? FileManager.default.removeItem(at: destination)
        }
        do {
            try FileManager.default.copyItem(at: url, to: destination)
            return fileName
        } catch {
            return nil
        }
    }

    // MARK: - Helpers

    private var soundsDirectoryURL: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Sounds", isDirectory: true)
    }

    private func stageSystemSound(named: String, as fileName: String) {
        let directory = soundsDirectoryURL
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        } catch {
            return
        }
        let destination = directory.appendingPathComponent(fileName)
        guard !FileManager.default.fileExists(atPath: destination.path) else { return }
        let source = URL(fileURLWithPath: "/System/Library/Sounds/\(named).aiff")
        guard FileManager.default.fileExists(atPath: source.path) else { return }
        try? FileManager.default.copyItem(at: source, to: destination)
    }

    private func fileExists(_ fileName: String) -> Bool {
        FileManager.default.fileExists(atPath: soundsDirectoryURL.appendingPathComponent(fileName).path)
    }

    // MARK: - UNUserNotificationCenterDelegate

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        if #available(macOS 11.0, *) {
            completionHandler([.banner, .sound, .list])
        } else {
            completionHandler([.alert, .sound])
        }
    }
}