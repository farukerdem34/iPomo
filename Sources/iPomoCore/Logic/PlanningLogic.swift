import Foundation

// MARK: - Project progress

public struct ProjectProgress: Sendable, Equatable {
    public let taskCount: Int
    public let completedTaskCount: Int
    public let estimatedPomodoros: Double
    public let completedPomodoros: Double

    public var fraction: Double {
        guard estimatedPomodoros > 0 else {
            return taskCount > 0 && completedTaskCount == taskCount ? 1 : 0
        }
        return min(1, max(0, completedPomodoros / estimatedPomodoros))
    }

    public var remainingPomodoros: Double {
        max(0, estimatedPomodoros - completedPomodoros)
    }
}

// MARK: - Finish estimate

public struct FinishEstimate: Sendable, Equatable {
    public let remainingPomodoros: Double
    public let focusSeconds: Double
    public let breakSeconds: Double
    public let totalSeconds: Double
    public let finishDate: Date
    public let focusRounds: Int

    public var hours: Double { totalSeconds / 3600.0 }
    public var remainingMinutes: Int { Int((remainingPomodoros * 1).rounded()) }
}

public enum PlanningLogic {
    public static func projectProgress(tasks: [PlanTask]) -> ProjectProgress {
        let estimated = tasks.reduce(0) { $0 + max(0, $1.estimatedPomodoros) }
        let completed = tasks.reduce(0) { $0 + max(0, $1.completedPomodoros) }
        return ProjectProgress(
            taskCount: tasks.count,
            completedTaskCount: tasks.filter(\.isCompleted).count,
            estimatedPomodoros: estimated,
            completedPomodoros: completed
        )
    }

    public static func completedPomodoroUnit(for task: PlanTask) -> Double {
        task.pomodoroUnit
    }

    public static func shouldAutoComplete(task: PlanTask, settings: BehaviorSettings) -> Bool {
        guard settings.autoCheckTasks, !task.isCompleted else { return false }
        return task.completedPomodoros + 0.0001 >= task.estimatedPomodoros
    }

    /// Tasks that belong in the Today plan: explicitly flagged, due today, or overdue.
    public static func todayTasks(
        in database: AppDatabase,
        now: Date = Date(),
        calendar: Calendar
    ) -> [PlanTask] {
        database.activeTasks.filter { task in
            if task.isFocusToday { return true }
            guard let dueDate = task.dueDate else { return false }
            return calendar.startOfDay(for: dueDate) <= calendar.startOfDay(for: now)
        }
        .sorted(by: planSort)
    }

    public static func planSort(_ lhs: PlanTask, _ rhs: PlanTask) -> Bool {
        if lhs.isCompleted != rhs.isCompleted { return !lhs.isCompleted }
        if lhs.priority != rhs.priority { return lhs.priority > rhs.priority }
        if lhs.dueDate != rhs.dueDate {
            switch (lhs.dueDate, rhs.dueDate) {
            case let (l?, r?): return l < r
            case (nil, _?): return false
            case (_?, nil): return true
            case (nil, nil): break
            }
        }
        if lhs.sortOrder != rhs.sortOrder { return lhs.sortOrder < rhs.sortOrder }
        return lhs.createdAt < rhs.createdAt
    }

    public static func sortedForTasksView(_ tasks: [PlanTask], now: Date, calendar: Calendar) -> [PlanTask] {
        tasks.sorted { lhs, rhs in
            if lhs.isCompleted != rhs.isCompleted { return !lhs.isCompleted }
            if lhs.priority != rhs.priority { return lhs.priority > rhs.priority }
            let lhsOverdue = lhs.isOverdue(now: now, calendar: calendar)
            let rhsOverdue = rhs.isOverdue(now: now, calendar: calendar)
            if lhsOverdue != rhsOverdue { return lhsOverdue }
            switch (lhs.dueDate, rhs.dueDate) {
            case let (l?, r?):
                if !calendar.isDate(l, inSameDayAs: r) { return l < r }
            case (nil, _?): return false
            case (_?, nil): return true
            case (nil, nil): break
            }
            if lhs.sortOrder != rhs.sortOrder { return lhs.sortOrder < rhs.sortOrder }
            return lhs.createdAt < rhs.createdAt
        }
    }
}

// MARK: - Finish time

public enum FinishTimeCalculator {
    public static func estimate(
        tasks: [PlanTask],
        settings: TimerSettings,
        now: Date = Date(),
        calendar: Calendar
    ) -> FinishEstimate {
        let liveTasks = tasks.filter { !$0.isCompleted }
        let focusSeconds = max(1, settings.focusMinutes * 60)
        var remaining = 0.0
        var rounds = 0

        for task in liveTasks {
            let left = max(0, task.estimatedPomodoros - task.completedPomodoros)
            guard left > 0 else { continue }
            if task.estimatedPomodoros > 0 && task.estimatedPomodoros < 1 {
                remaining += task.estimatedPomodoros
                rounds += 1
            } else {
                remaining += left
                rounds += Int(ceil(left))
            }
        }

        let focusTotal = remaining * focusSeconds
        var breaks = 0.0
        if rounds > 1 {
            for round in 1..<rounds {
                if round % max(1, settings.longBreakInterval) == 0 {
                    breaks += settings.longBreakMinutes * 60
                } else {
                    breaks += settings.shortBreakMinutes * 60
                }
            }
        }

        let total = focusTotal + breaks
        return FinishEstimate(
            remainingPomodoros: remaining,
            focusSeconds: focusTotal,
            breakSeconds: breaks,
            totalSeconds: total,
            finishDate: now.addingTimeInterval(total),
            focusRounds: rounds
        )
    }
}
