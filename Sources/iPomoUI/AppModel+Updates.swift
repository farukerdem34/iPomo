import AppKit
import Foundation
import iPomoCore

enum UpdateCheckState: Equatable {
    case idle
    case checking
    case upToDate
    case available(AvailableUpdate)
    case failed(String)
}

extension AppModel {
    private static let lastCheckKey = "com.ipomo.app.lastUpdateCheck"
    private static let checkInterval: TimeInterval = 24 * 60 * 60

    var appVersion: String? { UpdateChecker.currentVersion }

    var availableUpdate: AvailableUpdate? {
        guard case .available(let update) = updateState else { return nil }
        return update
    }

    var isCheckingForUpdates: Bool { updateState == .checking }

    var updateStatusText: String {
        switch updateState {
        case .idle: return ""
        case .checking: return "Checking for updates…"
        case .upToDate: return "iPomo is up to date."
        case .available(let update): return "Version \(update.version) is available."
        case .failed(let message): return message
        }
    }

    func checkForUpdatesIfNeeded() async {
        guard database.settings.updates.automaticallyChecksForUpdates,
              appVersion != nil,
              updateState != .checking else { return }
        let lastCheck = UserDefaults.standard.double(forKey: Self.lastCheckKey)
        guard lastCheck == 0 || Date().timeIntervalSince1970 - lastCheck >= Self.checkInterval else { return }
        await checkForUpdates(isManual: false)
    }

    func checkForUpdates() async {
        guard appVersion != nil else {
            showBanner("Update checks are only available in the packaged app.", kind: .info)
            return
        }
        await checkForUpdates(isManual: true)
    }

    func openAvailableUpdate() {
        guard let update = availableUpdate else { return }
        NSWorkspace.shared.open(update.downloadURL ?? update.releaseURL)
    }

    func openUpdateReleasePage() {
        guard let update = availableUpdate else { return }
        NSWorkspace.shared.open(update.releaseURL)
    }

    private func checkForUpdates(isManual: Bool) async {
        guard updateState != .checking, let currentVersion = appVersion else { return }
        // Set before the request so failures do not retry on every activation.
        UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: Self.lastCheckKey)
        updateState = .checking
        do {
            let update = try await UpdateChecker().latestRelease()
            if UpdateVersion.isNewer(update.version, than: currentVersion) {
                updateState = .available(update)
                isUpdateNoticePresented = true
            } else {
                updateState = .upToDate
                if isManual {
                    showBanner("iPomo \(currentVersion) is up to date.", kind: .success)
                }
            }
        } catch {
            updateState = .failed(error.localizedDescription)
            if isManual {
                showBanner("Update check failed: \(error.localizedDescription)", kind: .warning)
            }
        }
    }
}
