import iPomoCore
import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.editorialAccent) private var accent
    var embedded: Bool = false
    @State private var showResetConfirm = false

    private var importPresented: Binding<Bool> {
        Binding(
            get: { model.pendingImportedDatabase != nil },
            set: { if !$0 { model.pendingImportedDatabase = nil } }
        )
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DesignTokens.s4) {
                PageTitle(
                    eyebrow: "App",
                    title: "Settings",
                    detail: "Changes are saved as you make them."
                )
                timerGroup
                tasksGroup
                soundGroup
                appearanceGroup
                notificationGroup
                reportsGroup
                planningGroup
                dataGroup
                aboutGroup
            }
            .frame(maxWidth: 780, alignment: .leading)
            .editorialPagePadding()
        }
        .editorialBackground()
        .navigationTitle("Settings")
        .frame(
            width: embedded ? nil : 720,
            height: embedded ? nil : 760
        )
        .alert("Replace all data?", isPresented: importPresented) {
            Button("Import Backup", role: .destructive) {
                model.applyImportedDatabase()
            }
            Button("Cancel", role: .cancel) {
                model.pendingImportedDatabase = nil
            }
        } message: {
            Text("Your current tasks, projects, settings, and focus history will be replaced by the backup.")
        }
        .alert("Reset all data?", isPresented: $showResetConfirm) {
            Button("Reset Everything", role: .destructive) {
                model.resetAllData()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This deletes all tasks, projects, sessions, and settings. Export a backup first if you want to keep them.")
        }
    }

    // MARK: - Timer

    private var timerGroup: some View {
        SettingsGroup(title: "Timer") {
            SettingsFieldRow(title: "Pomodoro", detail: "Focus round length") {
                numberField(model.binding(\.timer.focusMinutes), width: 76)
                unitLabel("min")
            }
            SettingsFieldRow(title: "Short break") {
                numberField(model.binding(\.timer.shortBreakMinutes), width: 76)
                unitLabel("min")
            }
            SettingsFieldRow(title: "Long break") {
                numberField(model.binding(\.timer.longBreakMinutes), width: 76)
                unitLabel("min")
            }
            SettingsFieldRow(title: "Long break interval", detail: "Focus rounds between long breaks") {
                stepperValue(model.binding(\.timer.longBreakInterval), range: 1...12, textWidth: 56, label: "Long break interval")
            }
            EditorialToggleRow(title: "Auto-start breaks", isOn: model.binding(\.timer.autoStartBreaks))
            EditorialToggleRow(title: "Auto-start focus rounds", isOn: model.binding(\.timer.autoStartFocus))
        }
    }

    // MARK: - Tasks

    private var tasksGroup: some View {
        SettingsGroup(title: "Tasks") {
            EditorialToggleRow(
                title: "Auto-check completed estimates",
                detail: "Check a task when its completed pomodoros reach the estimate.",
                isOn: model.binding(\.behavior.autoCheckTasks)
            )
            EditorialToggleRow(
                title: "Move completed to a Completed section",
                detail: "Keep checked tasks visible but collected at the bottom.",
                isOn: model.binding(\.behavior.moveCompletedToBottom)
            )
            EditorialToggleRow(
                title: "Confirm task switches",
                detail: "Ask before resetting a running round for a different task.",
                isOn: model.binding(\.behavior.confirmTaskSwitch)
            )
            EditorialToggleRow(
                title: "Record partial focus time",
                detail: "On reset, stage switch, or task switch. Skip always counts as completion.",
                isOn: model.binding(\.behavior.recordPartialSessions)
            )
        }
    }

    // MARK: - Sound

    private var soundGroup: some View {
        SettingsGroup(title: "Sound") {
            EditorialToggleRow(title: "Enable sounds", isOn: model.binding(\.sound.soundsEnabled))
            SettingsFieldRow(title: "Alarm") {
                picker(model.binding(\.sound.alarmSound), options: AlarmSound.allCases, title: { $0.title }, width: 150)
            }
            SettingsSliderRow(
                title: "Alarm volume",
                value: model.binding(\.sound.alarmVolume),
                display: "\(Int(model.database.settings.sound.alarmVolume * 100))%"
            )
            SettingsFieldRow(title: "Repeat alarm") {
                stepperValue(model.binding(\.sound.alarmRepeatCount), range: 1...10, textWidth: 56, label: "Repeat alarm")
                unitLabel("×")
            }
            HStack {
                Spacer()
                Button("Preview alarm") {
                    model.soundPlayer.previewAlarm(settings: model.database.settings.sound)
                }
                .buttonStyle(EditorialQuietButtonStyle())
            }
            SettingsFieldRow(title: "Focus sound") {
                picker(model.binding(\.sound.tickingSound), options: TickingSound.allCases, title: { $0.title }, width: 150)
            }
            SettingsSliderRow(
                title: "Focus sound volume",
                value: model.binding(\.sound.tickingVolume),
                display: "\(Int(model.database.settings.sound.tickingVolume * 100))%"
            )
            HStack {
                Spacer()
                Button("Preview focus sound") {
                    model.soundPlayer.startTicking(settings: model.database.settings.sound)
                    Task { @MainActor in
                        try? await Task.sleep(nanoseconds: 3_000_000_000)
                        if !model.isTimerRunning {
                            model.soundPlayer.stopTicking()
                        }
                    }
                }
                .buttonStyle(EditorialQuietButtonStyle())
                .disabled(model.isTimerRunning)
            }
        }
    }

    // MARK: - Appearance

    private var appearanceGroup: some View {
        SettingsGroup(title: "Appearance") {
            HStack(alignment: .center) {
                Text("Theme color")
                    .font(Typography.bodyMedium(13))
                    .foregroundStyle(DesignTokens.ink)
                Spacer()
                HStack(spacing: 8) {
                    ForEach(AppTheme.allCases) { theme in
                        Button {
                            model.updateSettings { $0.appearance.theme = theme }
                        } label: {
                            Circle()
                                .fill(ThemeColors.accent(theme))
                                .frame(width: 22, height: 22)
                                .overlay(
                                    Circle()
                                        .strokeBorder(
                                            DesignTokens.ink.opacity(
                                                model.database.settings.appearance.theme == theme ? 0.65 : 0.1
                                            ),
                                            lineWidth: model.database.settings.appearance.theme == theme ? 2 : 1
                                        )
                                )
                        }
                        .buttonStyle(.plain)
                        .help(theme.title)
                    }
                }
            }
            .padding(.vertical, 7)
            EditorialToggleRow(title: "Dark mode while running", isOn: model.binding(\.appearance.darkModeWhenRunning))
            SettingsFieldRow(title: "Hour format") {
                picker(model.binding(\.appearance.hourFormat), options: HourFormat.allCases, title: { $0.title }, width: 120)
            }
            SettingsFieldRow(title: "Start of week") {
                picker(model.binding(\.appearance.weekStart), options: WeekStart.allCases, title: { $0.title }, width: 120)
            }
            EditorialToggleRow(title: "Show timer in the menu bar", isOn: model.binding(\.appearance.showTimerInMenuBar))
        }
    }

    // MARK: - Notifications

    private var notificationGroup: some View {
        SettingsGroup(title: "Notifications") {
            EditorialToggleRow(title: "Enable notifications", isOn: model.binding(\.notifications.notificationsEnabled))
            EditorialToggleRow(title: "Notify when a round ends", isOn: model.binding(\.notifications.notifyOnRoundEnd))
                .disabled(!model.database.settings.notifications.notificationsEnabled)
            EditorialToggleRow(title: "In-round reminders", isOn: model.binding(\.notifications.remindersEnabled))
                .disabled(!model.database.settings.notifications.notificationsEnabled)
            SettingsFieldRow(title: "Reminder mode") {
                picker(model.binding(\.notifications.reminderMode), options: ReminderMode.allCases, title: { $0.title }, width: 100)
            }
            .disabled(!model.database.settings.notifications.notificationsEnabled
                || !model.database.settings.notifications.remindersEnabled)
            SettingsFieldRow(title: "Reminder minutes") {
                stepperValue(model.binding(\.notifications.reminderMinutes), range: 1...120, textWidth: 56, label: "Reminder minutes")
                unitLabel("min")
            }
            .disabled(!model.database.settings.notifications.notificationsEnabled
                || !model.database.settings.notifications.remindersEnabled)
            HStack(spacing: DesignTokens.s2) {
                Text(model.notifications.authorized ? "Permission granted" : "Permission not granted")
                    .font(Typography.caption(11))
                    .foregroundStyle(model.notifications.authorized ? DesignTokens.success : DesignTokens.inkTertiary)
                Spacer()
                Button("Request Permission") { model.notifications.requestAuthorization() }
                    .buttonStyle(EditorialQuietButtonStyle())
                Button("Test") {
                    model.notifications.notify(title: "iPomo", body: "Notifications are working.")
                    model.showBanner(
                        model.notifications.authorized
                            ? "Test notification sent."
                            : "macOS has not granted notification permission; in-app banners still work.",
                        kind: .info
                    )
                }
                .buttonStyle(EditorialQuietButtonStyle())
            }
            .padding(.vertical, 6)
            if let error = model.notifications.permissionError {
                Text(error)
                    .font(Typography.caption(10))
                    .foregroundStyle(DesignTokens.warning)
            }
        }
    }

    // MARK: - Reports

    private var reportsGroup: some View {
        SettingsGroup(title: "Reports") {
            SettingsFieldRow(title: "Default range") {
                picker(model.binding(\.reports.defaultRange), options: ReportRange.allCases, title: { $0.title }, width: 110)
            }
            .onChange(of: model.database.settings.reports.defaultRange) { _, newValue in
                model.reportRange = newValue
            }
        }
    }

    // MARK: - Planning

    private var planningGroup: some View {
        SettingsGroup(title: "Planning") {
            SettingsFieldRow(title: "Daily focus goal") {
                stepperValue(model.binding(\.planning.dailyGoalMinutes), range: 0...1_440, step: 15, label: "Daily focus goal")
                unitLabel("min")
            }
            SettingsFieldRow(title: "Default task estimate") {
                EstimateStepper(value: model.binding(\.planning.defaultEstimatedPomodoros))
                unitLabel("pomos")
            }
            SettingsFieldRow(
                title: "Plan horizon",
                detail: "Tasks due within this many days fill the Next bucket."
            ) {
                stepperValue(model.binding(\.planning.planHorizonDays), range: 1...30, label: "Plan horizon")
                unitLabel("days")
            }
        }
    }

    // MARK: - Data

    private var dataGroup: some View {
        SettingsGroup(title: "Data") {
            VStack(alignment: .leading, spacing: 4) {
                Overline("Database file")
                Text(model.store.storagePath)
                    .font(Typography.caption(10))
                    .foregroundStyle(DesignTokens.inkSecondary)
                    .textSelection(.enabled)
                    .lineLimit(2)
                if let readOnlyMessage = model.dataReadOnlyMessage {
                    Text(readOnlyMessage)
                        .font(Typography.caption(10))
                        .foregroundStyle(DesignTokens.warning)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.top, 4)
                }
            }
            .padding(.vertical, 6)
            SettingsActionRow {
                Button("Reveal in Finder") { model.revealDataFolder() }
                    .buttonStyle(EditorialSecondaryButtonStyle())
                Button("Export Backup") { model.exportBackup() }
                    .buttonStyle(EditorialSecondaryButtonStyle())
                Button("Import Backup") { model.chooseImportBackup() }
                    .buttonStyle(EditorialSecondaryButtonStyle())
                Spacer()
                Button("Reset All Data…") { showResetConfirm = true }
                    .buttonStyle(EditorialDangerButtonStyle())
            }
            Text("Your data never leaves this Mac. The optional update check in About is the only network request.")
                .font(Typography.caption(10))
                .foregroundStyle(DesignTokens.inkTertiary)
                .padding(.top, 4)
        }
    }

    private var aboutGroup: some View {
        SettingsGroup(title: "About") {
            HStack {
                Text("Version")
                    .font(Typography.bodyMedium(13))
                    .foregroundStyle(DesignTokens.ink)
                Spacer()
                Text(model.appVersion ?? "Development build")
                    .font(Typography.caption(11))
                    .foregroundStyle(DesignTokens.inkSecondary)
                    .textSelection(.enabled)
            }
            .padding(.vertical, 6)
            EditorialToggleRow(
                title: "Check for updates automatically",
                detail: "Asks GitHub at most once a day whether a newer release exists.",
                isOn: model.binding(\.updates.automaticallyChecksForUpdates)
            )
            SettingsActionRow {
                Button("Check Now") {
                    Task { await model.checkForUpdates() }
                }
                .buttonStyle(EditorialSecondaryButtonStyle())
                .disabled(model.isCheckingForUpdates || model.appVersion == nil)
                if model.availableUpdate != nil {
                    Button("Download Update") { model.openAvailableUpdate() }
                        .buttonStyle(EditorialSecondaryButtonStyle())
                }
                Spacer()
                if !model.updateStatusText.isEmpty {
                    Text(model.updateStatusText)
                        .font(Typography.caption(10))
                        .foregroundStyle(DesignTokens.inkTertiary)
                        .lineLimit(2)
                }
            }
            HStack {
                Text("Privacy")
                    .font(Typography.bodyMedium(13))
                    .foregroundStyle(DesignTokens.ink)
                Spacer()
                Text("No accounts, analytics, or telemetry")
                    .font(Typography.caption(11))
                    .foregroundStyle(DesignTokens.inkSecondary)
            }
            .padding(.vertical, 6)
            Text("iPomo is a local-first focus timer and planner. Your data stays on this Mac; the optional update check only asks GitHub for the latest published version.")
                .font(Typography.caption(10))
                .foregroundStyle(DesignTokens.inkTertiary)
        }
    }

    // MARK: - Helpers

    private func numberField(_ binding: Binding<Double>, width: CGFloat) -> some View {
        TextField("", value: binding, format: .number.precision(.fractionLength(0...2)))
            .textFieldStyle(EditorialTextFieldStyle())
            .frame(width: width)
            .multilineTextAlignment(.trailing)
    }

    private func unitLabel(_ text: String) -> some View {
        Text(text)
            .font(Typography.caption(10))
            .foregroundStyle(DesignTokens.inkTertiary)
            .frame(width: 34, alignment: .leading)
    }

    /// Steppers in one group share the same text width so their minus/plus
    /// buttons line up in a column across rows.
    private func stepperValue(
        _ binding: Binding<Int>,
        range: ClosedRange<Int>,
        step: Int = 1,
        textWidth: CGFloat = 66,
        label: String
    ) -> some View {
        EditorialIntStepper(
            value: binding,
            range: range,
            step: step,
            textWidth: textWidth,
            label: label
        )
    }

    private func picker<T: Hashable & Identifiable>(
        _ selection: Binding<T>,
        options: [T],
        title: @escaping (T) -> String,
        width: CGFloat
    ) -> some View {
        Picker("", selection: selection) {
            ForEach(options) { option in
                Text(title(option)).tag(option)
            }
        }
        .labelsHidden()
        .pickerStyle(.menu)
        .frame(width: width)
        .tint(accent)
    }
}

// MARK: - Settings components

private struct SettingsGroup<Content: View>: View {
    let title: String
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.s2) {
            Overline(title)
            Hairline()
            content()
        }
        .padding(.top, DesignTokens.s3)
    }
}

private struct SettingsFieldRow<Content: View>: View {
    let title: String
    var detail: String?
    @ViewBuilder let content: () -> Content

    init(
        title: String,
        detail: String? = nil,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.title = title
        self.detail = detail
        self.content = content
    }

    var body: some View {
        HStack(alignment: .center, spacing: DesignTokens.s3) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(Typography.bodyMedium(13))
                    .foregroundStyle(DesignTokens.ink)
                if let detail {
                    Text(detail)
                        .font(Typography.caption(10))
                        .foregroundStyle(DesignTokens.inkTertiary)
                }
            }
            Spacer(minLength: DesignTokens.s3)
            HStack(spacing: DesignTokens.s2) {
                content()
            }
        }
        .padding(.vertical, 6)
    }
}

private struct SettingsSliderRow: View {
    @Environment(\.editorialAccent) private var accent
    let title: String
    @Binding var value: Double
    let display: String

    var body: some View {
        HStack(spacing: DesignTokens.s3) {
            Text(title)
                .font(Typography.bodyMedium(13))
                .foregroundStyle(DesignTokens.ink)
            Spacer()
            Slider(value: $value, in: 0...1)
                .tint(accent)
                .frame(width: 160)
            Text(display)
                .font(Typography.caption(10))
                .monospacedDigit()
                .foregroundStyle(DesignTokens.inkTertiary)
                .frame(width: 38, alignment: .trailing)
        }
        .padding(.vertical, 6)
    }
}

private struct SettingsActionRow<Content: View>: View {
    @ViewBuilder let content: () -> Content

    var body: some View {
        HStack(spacing: DesignTokens.s2) {
            content()
        }
        .padding(.vertical, 8)
    }
}
