import Foundation

// MARK: - Timer stage

public enum Stage: String, Codable, CaseIterable, Identifiable, Sendable {
    case focus
    case shortBreak
    case longBreak

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .focus: return "Focus"
        case .shortBreak: return "Short Break"
        case .longBreak: return "Long Break"
        }
    }

    public var isFocus: Bool { self == .focus }
}

// MARK: - Project

public enum ProjectStatus: String, Codable, CaseIterable, Identifiable, Sendable {
    case active
    case onHold
    case completed
    case archived

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .active: return "Active"
        case .onHold: return "On Hold"
        case .completed: return "Completed"
        case .archived: return "Archived"
        }
    }

}

// MARK: - Task

public enum TaskPriority: Int, Codable, CaseIterable, Identifiable, Sendable, Comparable {
    case low = 0
    case medium = 1
    case high = 2

    public var id: Int { rawValue }

    public var title: String {
        switch self {
        case .low: return "Low"
        case .medium: return "Medium"
        case .high: return "High"
        }
    }

    public static func < (lhs: TaskPriority, rhs: TaskPriority) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

public enum TaskScope: String, CaseIterable, Identifiable, Sendable {
    case active
    case completed

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .active: return "Active"
        case .completed: return "Completed"
        }
    }
}

// MARK: - Sound

public enum AlarmSound: String, Codable, CaseIterable, Identifiable, Sendable {
    case glass
    case ping
    case pop
    case purr
    case submarine
    case funk
    case tink
    case hero

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .glass: return "Bell (Glass)"
        case .ping: return "Ping"
        case .pop: return "Pop"
        case .purr: return "Purr"
        case .submarine: return "Submarine"
        case .funk: return "Funk"
        case .tink: return "Tink"
        case .hero: return "Hero"
        }
    }

    /// Name of the built-in macOS system sound. No audio assets are shipped.
    public var systemSoundName: String {
        switch self {
        case .glass: return "Glass"
        case .ping: return "Ping"
        case .pop: return "Pop"
        case .purr: return "Purr"
        case .submarine: return "Submarine"
        case .funk: return "Funk"
        case .tink: return "Tink"
        case .hero: return "Hero"
        }
    }
}

public enum TickingSound: String, Codable, CaseIterable, Identifiable, Sendable {
    case none
    case fast
    case slow

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .none: return "None"
        case .fast: return "Tick Fast"
        case .slow: return "Tick Slow"
        }
    }

    /// Seconds between ticks; nil means disabled.
    public var interval: TimeInterval? {
        switch self {
        case .none: return nil
        case .fast: return 1
        case .slow: return 2
        }
    }
}

// MARK: - Formatting

public enum HourFormat: String, Codable, CaseIterable, Identifiable, Sendable {
    case twelve
    case twentyFour

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .twelve: return "12-hour"
        case .twentyFour: return "24-hour"
        }
    }
}

public enum WeekStart: String, Codable, CaseIterable, Identifiable, Sendable {
    case monday
    case sunday
    case saturday

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .monday: return "Monday"
        case .sunday: return "Sunday"
        case .saturday: return "Saturday"
        }
    }

    public var calendarWeekday: Int {
        // Calendar uses 1 = Sunday ... 7 = Saturday.
        switch self {
        case .monday: return 2
        case .sunday: return 1
        case .saturday: return 7
        }
    }
}

public enum ReminderMode: String, Codable, CaseIterable, Identifiable, Sendable {
    case last
    case every

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .last: return "Last"
        case .every: return "Every"
        }
    }
}

// MARK: - Appearance

public enum AppTheme: String, Codable, CaseIterable, Identifiable, Sendable {
    case tomato
    case emerald
    case ocean
    case violet
    case amber
    case teal
    case rose
    case indigo

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .tomato: return "Tomato"
        case .emerald: return "Emerald"
        case .ocean: return "Ocean"
        case .violet: return "Violet"
        case .amber: return "Amber"
        case .teal: return "Teal"
        case .rose: return "Rose"
        case .indigo: return "Indigo"
        }
    }

    public var lightHex: String {
        switch self {
        case .tomato: return "#B85C43"
        case .emerald: return "#5F7355"
        case .ocean: return "#4A6572"
        case .violet: return "#765D7A"
        case .amber: return "#A9762F"
        case .teal: return "#3F6F6A"
        case .rose: return "#9E5A63"
        case .indigo: return "#4B5670"
        }
    }

    public var darkHex: String {
        switch self {
        case .tomato: return "#E08C72"
        case .emerald: return "#9CB18A"
        case .ocean: return "#8FA9B7"
        case .violet: return "#B79BB9"
        case .amber: return "#D8AA63"
        case .teal: return "#86B8B2"
        case .rose: return "#D49AA2"
        case .indigo: return "#94A2C4"
        }
    }
}

public enum ProjectPalette {
    public static let colors: [String] = [
        "#B85C43", "#A9762F", "#8A7A45", "#5F7355",
        "#3F6F6A", "#4A6572", "#4B5670", "#765D7A",
        "#9E5A63", "#6B6258", "#8A7A66", "#3D6B63",
    ]

}
