import Foundation
import UserNotifications

@MainActor
final class NotificationManager {
    private static let reminderPrefix = "ipomo.reminder."
    private static let reminderIdentifiers = (0..<24).map { "\(reminderPrefix)\($0)" }
    private var requesting = false
    private var pendingReminders: (reminders: [(offset: TimeInterval, body: String)], title: String)?
    private(set) var authorized = false
    private(set) var permissionError: String?

    private var center: UNUserNotificationCenter? {
        guard Bundle.main.bundleIdentifier != nil else { return nil }
        return UNUserNotificationCenter.current()
    }

    func requestAuthorization() {
        guard !requesting else { return }
        requesting = true
        guard let center else {
            requesting = false
            return
        }
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

    func notify(title: String, body: String, identifier: String = UUID().uuidString) {
        guard let center else { return }
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        let request = UNNotificationRequest(
            identifier: identifier,
            content: content,
            trigger: nil
        )
        center.add(request) { _ in }
    }

    /// Schedules local reminders at the given offsets from now. Permission is
    /// requested if needed, and the reminders are installed once it is granted.
    func scheduleReminders(_ reminders: [(offset: TimeInterval, body: String)], title: String) {
        pendingReminders = (reminders, title)
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
            content.sound = .default
            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: reminder.offset, repeats: false)
            let request = UNNotificationRequest(
                identifier: Self.reminderIdentifiers[index],
                content: content,
                trigger: trigger
            )
            center.add(request) { _ in }
        }
    }
}
