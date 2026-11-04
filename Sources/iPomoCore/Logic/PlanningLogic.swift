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
    public let taskStarts: [UUID: Date]

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
        timer: TimerSnapshot = TimerSnapshot(),
        now: Date = Date(),
        calendar: Calendar
    ) -> FinishEstimate {
        let liveTasks = tasks.filter { !$0.isCompleted }
        let baseFocus = max(1, settings.focusMinutes * 60)
        let interval = max(1, settings.longBreakInterval)

        func plannedRoundCount(_ task: PlanTask) -> Int {
            let left = max(0, task.estimatedPomodoros - task.completedPomodoros)
            guard left > 0 else { return 0 }
            if task.estimatedPomodoros > 0, task.estimatedPomodoros < 1 {
                return 1
            }
            return Int(ceil(left))
        }

        let hasProgress = timer.isRunning || timer.accumulatedSeconds > 0.05
        let activeTask = liveTasks.first { $0.id == timer.activeTaskID }
        let currentRemaining = hasProgress
            ? TimerMath.progress(snapshot: timer, settings: settings, task: activeTask, now: now).remainingSeconds
            : 0
        let hasCurrentRound = hasProgress && currentRemaining > 0.05
        let firstTask = liveTasks.first
        let currentRoundIsFirst = hasCurrentRound
            && timer.stage == .focus
            && timer.activeTaskID != nil
            && timer.activeTaskID == firstTask?.id
            && firstTask.map(plannedRoundCount) ?? 0 > 0

        var preBreakSeconds = 0.0
        var preFocusSeconds = 0.0
        if hasCurrentRound {
            if timer.stage == .focus {
                if !currentRoundIsFirst {
                    preFocusSeconds = currentRemaining
                }
            } else {
                preBreakSeconds = currentRemaining
            }
        }

        var rounds: [(task: PlanTask, duration: Double, count: Int)] = []
        var totalRounds = preFocusSeconds > 0 ? 1 : 0
        for task in liveTasks {
            let count = plannedRoundCount(task)
            guard count > 0 else { continue }
            var effectiveCount = count
            if preFocusSeconds > 0, task.id == timer.activeTaskID {
                effectiveCount -= 1
            }
            guard effectiveCount > 0 else { continue }
            let fractional = task.estimatedPomodoros > 0 && task.estimatedPomodoros < 1
            let duration = fractional ? baseFocus * task.estimatedPomodoros : baseFocus
            rounds.append((task, duration, effectiveCount))
            totalRounds += effectiveCount
        }

        var remaining = 0.0
        for task in liveTasks {
            let left = max(0, task.estimatedPomodoros - task.completedPomodoros)
            guard left > 0 else { continue }
            if task.estimatedPomodoros > 0, task.estimatedPomodoros < 1 {
                remaining += task.estimatedPomodoros
            } else {
                remaining += left
            }
        }

        var cursor = now
        var focusTotal = 0.0
        var breaks = 0.0
        var roundsCompleted = max(0, timer.focusRoundCount)
        var roundsScheduled = 0
        var taskStarts: [UUID: Date] = [:]

        func scheduleBreak() {
            let duration = (roundsCompleted % interval == 0
                ? settings.longBreakMinutes
                : settings.shortBreakMinutes) * 60
            cursor = cursor.addingTimeInterval(duration)
            breaks += duration
        }

        func scheduleRound(taskID: UUID?, duration: Double) {
            if let taskID, taskStarts[taskID] == nil {
                taskStarts[taskID] = cursor
            }
            cursor = cursor.addingTimeInterval(duration)
            focusTotal += duration
            roundsCompleted += 1
            roundsScheduled += 1
            if roundsScheduled < totalRounds {
                scheduleBreak()
            }
        }

        if preBreakSeconds > 0 {
            cursor = cursor.addingTimeInterval(preBreakSeconds)
            breaks += preBreakSeconds
        }
        if preFocusSeconds > 0 {
            scheduleRound(taskID: nil, duration: preFocusSeconds)
        }
        for entry in rounds {
            for index in 0..<entry.count {
                let duration = currentRoundIsFirst && entry.task.id == firstTask?.id && index == 0
                    ? currentRemaining
                    : entry.duration
                scheduleRound(taskID: entry.task.id, duration: duration)
            }
        }

        let total = focusTotal + breaks
        return FinishEstimate(
            remainingPomodoros: remaining,
            focusSeconds: focusTotal,
            breakSeconds: breaks,
            totalSeconds: total,
            finishDate: now.addingTimeInterval(total),
            focusRounds: totalRounds,
            taskStarts: taskStarts
        )
    }
}
