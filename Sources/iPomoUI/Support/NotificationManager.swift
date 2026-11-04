import Foundation
import UserNotifications

@MainActor
final class NotificationManager {
    private static let reminderPrefix = "ipomo.reminder."
    private var requesting = false
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
            }
        }
    }

    func notify(title: String, body: String, identifier: String = UUID().uuidString) {
        guard authorized, let center else { return }
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

    /// Schedules local reminders at the given offsets from now. All reminders share
    /// a prefix so they can be removed when the timer pauses or advances.
    func scheduleReminders(offsets: [TimeInterval], title: String, body: String) {
        guard authorized, let center else { return }
        removeReminders()
        for (index, offset) in offsets.enumerated() {
            guard offset > 1 else { continue }
            let content = UNMutableNotificationContent()
            content.title = title
            content.body = body
            content.sound = .default
            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: offset, repeats: false)
            let request = UNNotificationRequest(
                identifier: "\(Self.reminderPrefix)\(index)",
                content: content,
                trigger: trigger
            )
            center.add(request) { _ in }
        }
    }

    func removeReminders() {
        guard let center else { return }
        center.getPendingNotificationRequests { requests in
            let identifiers = requests
                .map(\.identifier)
                .filter { $0.hasPrefix(Self.reminderPrefix) }
            guard !identifiers.isEmpty else { return }
            center.removePendingNotificationRequests(withIdentifiers: identifiers)
        }
    }

    func removeAllPending() {
        center?.removeAllPendingNotificationRequests()
    }
}
