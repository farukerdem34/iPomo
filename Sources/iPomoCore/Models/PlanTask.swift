import Foundation

public struct PlanTask: Identifiable, Codable, Hashable, Sendable {
    public static let inboxName = "No Project"

    public var id: UUID
    public var title: String
    public var notes: String
    public var projectID: UUID?
    public var estimatedPomodoros: Double
    public var completedPomodoros: Double
    public var dueDate: Date?
    public var priority: TaskPriority
    public var isCompleted: Bool
    public var completedAt: Date?
    public var isFocusToday: Bool
    public var sortOrder: Int
    public var createdAt: Date
    public var updatedAt: Date

    public init(
        id: UUID = UUID(),
        title: String,
        notes: String = "",
        projectID: UUID? = nil,
        estimatedPomodoros: Double = 1,
        completedPomodoros: Double = 0,
        dueDate: Date? = nil,
        priority: TaskPriority = .medium,
        isCompleted: Bool = false,
        completedAt: Date? = nil,
        isFocusToday: Bool = false,
        sortOrder: Int = 0,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.title = title
        self.notes = notes
        self.projectID = projectID
        self.estimatedPomodoros = estimatedPomodoros
        self.completedPomodoros = completedPomodoros
        self.dueDate = dueDate
        self.priority = priority
        self.isCompleted = isCompleted
        self.completedAt = completedAt
        self.isFocusToday = isFocusToday
        self.sortOrder = sortOrder
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    /// Fractional estimates: a task estimated below one pomodoro
    /// consumes only that fraction of the focus interval and credits that fraction.
    public var pomodoroUnit: Double {
        if estimatedPomodoros > 0 && estimatedPomodoros < 1 {
            return estimatedPomodoros
        }
        return 1
    }

    public var remainingPomodoros: Double {
        max(0, estimatedPomodoros - completedPomodoros)
    }

    public var progress: Double {
        guard estimatedPomodoros > 0 else { return isCompleted ? 1 : 0 }
        return min(1, max(0, completedPomodoros / estimatedPomodoros))
    }

    public var displayProgress: String {
        let done = Self.numberString(completedPomodoros)
        let total = Self.numberString(estimatedPomodoros)
        return "\(done)/\(total)"
    }

    public func isOverdue(now: Date = Date(), calendar: Calendar = .current) -> Bool {
        guard let dueDate, !isCompleted else { return false }
        return dueDate < calendar.startOfDay(for: now)
    }

    public static func numberString(_ value: Double) -> String {
        if value.rounded() == value {
            return String(Int(value))
        }
        return String(format: "%.1f", value)
    }
}
