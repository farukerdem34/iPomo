import Foundation

// MARK: - Timer

public struct TimerSettings: Codable, Sendable, Equatable {
    public var focusMinutes: Double
    public var shortBreakMinutes: Double
    public var longBreakMinutes: Double
    public var longBreakInterval: Int
    public var autoStartBreaks: Bool
    public var autoStartFocus: Bool

    public init(
        focusMinutes: Double = 25,
        shortBreakMinutes: Double = 5,
        longBreakMinutes: Double = 15,
        longBreakInterval: Int = 4,
        autoStartBreaks: Bool = false,
        autoStartFocus: Bool = false
    ) {
        self.focusMinutes = focusMinutes
        self.shortBreakMinutes = shortBreakMinutes
        self.longBreakMinutes = longBreakMinutes
        self.longBreakInterval = longBreakInterval
        self.autoStartBreaks = autoStartBreaks
        self.autoStartFocus = autoStartFocus
    }

    private enum CodingKeys: String, CodingKey {
        case focusMinutes, shortBreakMinutes, longBreakMinutes
        case longBreakInterval, autoStartBreaks, autoStartFocus
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        focusMinutes = try c.decodeIfPresent(Double.self, forKey: .focusMinutes) ?? 25
        shortBreakMinutes = try c.decodeIfPresent(Double.self, forKey: .shortBreakMinutes) ?? 5
        longBreakMinutes = try c.decodeIfPresent(Double.self, forKey: .longBreakMinutes) ?? 15
        longBreakInterval = try c.decodeIfPresent(Int.self, forKey: .longBreakInterval) ?? 4
        autoStartBreaks = try c.decodeIfPresent(Bool.self, forKey: .autoStartBreaks) ?? false
        autoStartFocus = try c.decodeIfPresent(Bool.self, forKey: .autoStartFocus) ?? false
        clamp()
    }

    public mutating func clamp() {
        focusMinutes = min(999, max(0.1, focusMinutes))
        shortBreakMinutes = min(999, max(0, shortBreakMinutes))
        longBreakMinutes = min(999, max(0, longBreakMinutes))
        longBreakInterval = min(99, max(1, longBreakInterval))
    }
}

// MARK: - Behavior

public struct BehaviorSettings: Codable, Sendable, Equatable {
    public var autoCheckTasks: Bool
    public var moveCompletedToBottom: Bool
    public var confirmTaskSwitch: Bool
    public var recordPartialSessions: Bool

    public init(
        autoCheckTasks: Bool = false,
        moveCompletedToBottom: Bool = true,
        confirmTaskSwitch: Bool = true,
        recordPartialSessions: Bool = true
    ) {
        self.autoCheckTasks = autoCheckTasks
        self.moveCompletedToBottom = moveCompletedToBottom
        self.confirmTaskSwitch = confirmTaskSwitch
        self.recordPartialSessions = recordPartialSessions
    }

    private enum CodingKeys: String, CodingKey {
        case autoCheckTasks, moveCompletedToBottom, confirmTaskSwitch, recordPartialSessions
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        autoCheckTasks = try c.decodeIfPresent(Bool.self, forKey: .autoCheckTasks) ?? false
        moveCompletedToBottom = try c.decodeIfPresent(Bool.self, forKey: .moveCompletedToBottom) ?? true
        confirmTaskSwitch = try c.decodeIfPresent(Bool.self, forKey: .confirmTaskSwitch) ?? true
        recordPartialSessions = try c.decodeIfPresent(Bool.self, forKey: .recordPartialSessions) ?? true
    }
}

// MARK: - Sound

public struct SoundSettings: Codable, Sendable, Equatable {
    public var soundsEnabled: Bool
    public var alarmSound: AlarmSound
    public var alarmVolume: Double
    public var alarmRepeatCount: Int
    public var tickingSound: TickingSound
    public var tickingVolume: Double

    public init(
        soundsEnabled: Bool = true,
        alarmSound: AlarmSound = .glass,
        alarmVolume: Double = 0.7,
        alarmRepeatCount: Int = 2,
        tickingSound: TickingSound = .none,
        tickingVolume: Double = 0.25
    ) {
        self.soundsEnabled = soundsEnabled
        self.alarmSound = alarmSound
        self.alarmVolume = alarmVolume
        self.alarmRepeatCount = alarmRepeatCount
        self.tickingSound = tickingSound
        self.tickingVolume = tickingVolume
    }

    private enum CodingKeys: String, CodingKey {
        case soundsEnabled, alarmSound, alarmVolume, alarmRepeatCount, tickingSound, tickingVolume
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        soundsEnabled = try c.decodeIfPresent(Bool.self, forKey: .soundsEnabled) ?? true
        alarmSound = try c.decodeIfPresent(AlarmSound.self, forKey: .alarmSound) ?? .glass
        alarmVolume = try c.decodeIfPresent(Double.self, forKey: .alarmVolume) ?? 0.7
        alarmRepeatCount = try c.decodeIfPresent(Int.self, forKey: .alarmRepeatCount) ?? 2
        tickingSound = try c.decodeIfPresent(TickingSound.self, forKey: .tickingSound) ?? .none
        tickingVolume = try c.decodeIfPresent(Double.self, forKey: .tickingVolume) ?? 0.25
        clamp()
    }

    public mutating func clamp() {
        alarmVolume = min(1, max(0, alarmVolume))
        tickingVolume = min(1, max(0, tickingVolume))
        alarmRepeatCount = min(10, max(1, alarmRepeatCount))
    }
}

// MARK: - Appearance

public struct AppearanceSettings: Codable, Sendable, Equatable {
    public var theme: AppTheme
    public var darkModeWhenRunning: Bool
    public var hourFormat: HourFormat
    public var weekStart: WeekStart
    public var showTimerInMenuBar: Bool

    public init(
        theme: AppTheme = .tomato,
        darkModeWhenRunning: Bool = false,
        hourFormat: HourFormat = .twelve,
        weekStart: WeekStart = .monday,
        showTimerInMenuBar: Bool = true
    ) {
        self.theme = theme
        self.darkModeWhenRunning = darkModeWhenRunning
        self.hourFormat = hourFormat
        self.weekStart = weekStart
        self.showTimerInMenuBar = showTimerInMenuBar
    }

    private enum CodingKeys: String, CodingKey {
        case theme, darkModeWhenRunning, hourFormat, weekStart, showTimerInMenuBar
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        theme = try c.decodeIfPresent(AppTheme.self, forKey: .theme) ?? .tomato
        darkModeWhenRunning = try c.decodeIfPresent(Bool.self, forKey: .darkModeWhenRunning) ?? false
        hourFormat = try c.decodeIfPresent(HourFormat.self, forKey: .hourFormat) ?? .twelve
        weekStart = try c.decodeIfPresent(WeekStart.self, forKey: .weekStart) ?? .monday
        showTimerInMenuBar = try c.decodeIfPresent(Bool.self, forKey: .showTimerInMenuBar) ?? true
    }
}

// MARK: - Notifications

public struct NotificationSettings: Codable, Sendable, Equatable {
    public var notificationsEnabled: Bool
    public var notifyOnRoundEnd: Bool
    public var remindersEnabled: Bool
    public var reminderMode: ReminderMode
    public var reminderMinutes: Int

    public init(
        notificationsEnabled: Bool = true,
        notifyOnRoundEnd: Bool = true,
        remindersEnabled: Bool = false,
        reminderMode: ReminderMode = .last,
        reminderMinutes: Int = 5
    ) {
        self.notificationsEnabled = notificationsEnabled
        self.notifyOnRoundEnd = notifyOnRoundEnd
        self.remindersEnabled = remindersEnabled
        self.reminderMode = reminderMode
        self.reminderMinutes = reminderMinutes
    }

    private enum CodingKeys: String, CodingKey {
        case notificationsEnabled, notifyOnRoundEnd, remindersEnabled, reminderMode, reminderMinutes
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        notificationsEnabled = try c.decodeIfPresent(Bool.self, forKey: .notificationsEnabled) ?? true
        notifyOnRoundEnd = try c.decodeIfPresent(Bool.self, forKey: .notifyOnRoundEnd) ?? true
        remindersEnabled = try c.decodeIfPresent(Bool.self, forKey: .remindersEnabled) ?? false
        reminderMode = try c.decodeIfPresent(ReminderMode.self, forKey: .reminderMode) ?? .last
        reminderMinutes = try c.decodeIfPresent(Int.self, forKey: .reminderMinutes) ?? 5
        reminderMinutes = min(120, max(1, reminderMinutes))
    }
}

// MARK: - Reports

public struct ReportSettings: Codable, Sendable, Equatable {
    public var defaultRange: ReportRange

    public init(defaultRange: ReportRange = .week) {
        self.defaultRange = defaultRange
    }

    private enum CodingKeys: String, CodingKey { case defaultRange }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        defaultRange = try c.decodeIfPresent(ReportRange.self, forKey: .defaultRange) ?? .week
    }
}

// MARK: - Planning

public struct PlanningSettings: Codable, Sendable, Equatable {
    public var dailyGoalMinutes: Int
    public var defaultEstimatedPomodoros: Double
    public var planHorizonDays: Int

    public init(
        dailyGoalMinutes: Int = 120,
        defaultEstimatedPomodoros: Double = 1,
        planHorizonDays: Int = 7
    ) {
        self.dailyGoalMinutes = dailyGoalMinutes
        self.defaultEstimatedPomodoros = defaultEstimatedPomodoros
        self.planHorizonDays = planHorizonDays
    }

    private enum CodingKeys: String, CodingKey {
        case dailyGoalMinutes, defaultEstimatedPomodoros, planHorizonDays
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        dailyGoalMinutes = try c.decodeIfPresent(Int.self, forKey: .dailyGoalMinutes) ?? 120
        defaultEstimatedPomodoros = try c.decodeIfPresent(Double.self, forKey: .defaultEstimatedPomodoros) ?? 1
        planHorizonDays = try c.decodeIfPresent(Int.self, forKey: .planHorizonDays) ?? 7
        dailyGoalMinutes = min(1440, max(0, dailyGoalMinutes))
        defaultEstimatedPomodoros = min(99, max(0.1, defaultEstimatedPomodoros))
        planHorizonDays = min(30, max(1, planHorizonDays))
    }
}

// MARK: - Updates

public struct UpdateSettings: Codable, Sendable, Equatable {
    public var automaticallyChecksForUpdates: Bool

    public init(automaticallyChecksForUpdates: Bool = true) {
        self.automaticallyChecksForUpdates = automaticallyChecksForUpdates
    }

    private enum CodingKeys: String, CodingKey {
        case automaticallyChecksForUpdates
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        automaticallyChecksForUpdates = try c.decodeIfPresent(Bool.self, forKey: .automaticallyChecksForUpdates) ?? true
    }
}

// MARK: - Root settings

public struct AppSettings: Codable, Sendable, Equatable {
    public var timer: TimerSettings
    public var behavior: BehaviorSettings
    public var sound: SoundSettings
    public var appearance: AppearanceSettings
    public var notifications: NotificationSettings
    public var reports: ReportSettings
    public var planning: PlanningSettings
    public var updates: UpdateSettings

    public init(
        timer: TimerSettings = TimerSettings(),
        behavior: BehaviorSettings = BehaviorSettings(),
        sound: SoundSettings = SoundSettings(),
        appearance: AppearanceSettings = AppearanceSettings(),
        notifications: NotificationSettings = NotificationSettings(),
        reports: ReportSettings = ReportSettings(),
        planning: PlanningSettings = PlanningSettings(),
        updates: UpdateSettings = UpdateSettings()
    ) {
        self.timer = timer
        self.behavior = behavior
        self.sound = sound
        self.appearance = appearance
        self.notifications = notifications
        self.reports = reports
        self.planning = planning
        self.updates = updates
    }

    private enum CodingKeys: String, CodingKey {
        case timer, behavior, sound, appearance, notifications, reports, planning, updates
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        timer = try c.decodeIfPresent(TimerSettings.self, forKey: .timer) ?? TimerSettings()
        behavior = try c.decodeIfPresent(BehaviorSettings.self, forKey: .behavior) ?? BehaviorSettings()
        sound = try c.decodeIfPresent(SoundSettings.self, forKey: .sound) ?? SoundSettings()
        appearance = try c.decodeIfPresent(AppearanceSettings.self, forKey: .appearance) ?? AppearanceSettings()
        notifications = try c.decodeIfPresent(NotificationSettings.self, forKey: .notifications) ?? NotificationSettings()
        reports = try c.decodeIfPresent(ReportSettings.self, forKey: .reports) ?? ReportSettings()
        planning = try c.decodeIfPresent(PlanningSettings.self, forKey: .planning) ?? PlanningSettings()
        updates = try c.decodeIfPresent(UpdateSettings.self, forKey: .updates) ?? UpdateSettings()
    }
}
