import Foundation
@testable import iPomoCore

enum TestSupport {
    static var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        calendar.locale = Locale(identifier: "en_US_POSIX")
        calendar.firstWeekday = 2
        return calendar
    }

    static func date(_ year: Int, _ month: Int, _ day: Int, hour: Int = 12, minute: Int = 0) -> Date {
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = day
        components.hour = hour
        components.minute = minute
        components.timeZone = TimeZone(secondsFromGMT: 0)
        return calendar.date(from: components)!
    }

    static func task(
        _ title: String,
        notes: String = "",
        projectID: UUID? = nil,
        estimate: Double = 1,
        completed: Double = 0,
        due: Date? = nil,
        priority: TaskPriority = .medium,
        isCompleted: Bool = false,
        focusToday: Bool = false,
        order: Int = 0
    ) -> PlanTask {
        PlanTask(
            title: title,
            notes: notes,
            projectID: projectID,
            estimatedPomodoros: estimate,
            completedPomodoros: completed,
            dueDate: due,
            priority: priority,
            isCompleted: isCompleted,
            isFocusToday: focusToday,
            sortOrder: order
        )
    }

    static func session(
        task: String,
        projectID: UUID? = nil,
        project: String = "",
        stage: Stage = .focus,
        start: Date,
        seconds: Int = 1500,
        completed: Bool = true,
        manual: Bool = false
    ) -> FocusSession {
        FocusSession(
            taskTitle: task,
            projectID: projectID,
            projectName: project,
            stage: stage,
            startedAt: start,
            endedAt: start.addingTimeInterval(TimeInterval(seconds)),
            plannedSeconds: seconds,
            actualSeconds: seconds,
            completed: completed,
            isManual: manual
        )
    }
}
