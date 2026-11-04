import Foundation
import Testing
@testable import iPomoCore

@Suite struct PlanningTests {
    @Test func projectProgress() {
        let projectID = UUID()
        let tasks = [
            TestSupport.task("A", projectID: projectID, estimate: 2, completed: 1),
            TestSupport.task("B", projectID: projectID, estimate: 2, completed: 2, isCompleted: true),
            TestSupport.task("C", projectID: projectID, estimate: 4, completed: 0),
        ]
        let progress = PlanningLogic.projectProgress(tasks: tasks)
        #expect(progress.estimatedPomodoros == 8)
        #expect(progress.completedPomodoros == 3)
        #expect(abs(progress.fraction - 3.0 / 8.0) < 0.0001)
        #expect(progress.completedTaskCount == 1)
    }

    @Test func todayTasksIncludesFocusOverdueAndToday() {
        let now = TestSupport.date(2026, 11, 4)
        let yesterday = TestSupport.date(2026, 11, 3)
        let tomorrow = TestSupport.date(2026, 11, 5)
        let project = Project(name: "P")
        let tasks = [
            TestSupport.task("Focus", projectID: project.id, focusToday: true),
            TestSupport.task("Overdue", projectID: project.id, due: yesterday),
            TestSupport.task("Today", projectID: project.id, due: now),
            TestSupport.task("Tomorrow", projectID: project.id, due: tomorrow),
            TestSupport.task("Done", projectID: project.id, due: now, isCompleted: true),
        ]
        let database = AppDatabase(projects: [project], tasks: tasks)
        let today = PlanningLogic.todayTasks(in: database, now: now, calendar: TestSupport.calendar)
        #expect(Set(today.map(\.title)) == ["Focus", "Overdue", "Today"])
    }

    @Test func autoCompleteHonorsSettingAndEstimate() {
        var behavior = BehaviorSettings()
        behavior.autoCheckTasks = false
        let task = TestSupport.task("A", estimate: 1, completed: 1)
        #expect(!PlanningLogic.shouldAutoComplete(task: task, settings: behavior))
        behavior.autoCheckTasks = true
        #expect(PlanningLogic.shouldAutoComplete(task: task, settings: behavior))
        let unfinished = TestSupport.task("B", estimate: 2, completed: 1)
        #expect(!PlanningLogic.shouldAutoComplete(task: unfinished, settings: behavior))
    }

    @Test func finishEstimateIncludesBreaksAndLongBreaks() {
        let now = TestSupport.date(2026, 11, 4, hour: 9)
        let tasks = [
            TestSupport.task("A", estimate: 1),
            TestSupport.task("B", estimate: 2),
        ]
        let estimate = FinishTimeCalculator.estimate(
            tasks: tasks,
            settings: TimerSettings(),
            now: now,
            calendar: TestSupport.calendar
        )
        // 3 focus rounds: 3 * 1500 = 4500s, two short breaks = 600s.
        #expect(abs(estimate.remainingPomodoros - 3) < 0.0001)
        #expect(abs(estimate.focusSeconds - 4500) < 0.0001)
        #expect(abs(estimate.breakSeconds - 600) < 0.0001)
        #expect(abs(estimate.totalSeconds - 5100) < 0.0001)
        #expect(estimate.finishDate == now.addingTimeInterval(5100))
    }

    @Test func finishEstimateUsesLongBreakAtInterval() {
        let now = TestSupport.date(2026, 11, 4, hour: 9)
        let task = TestSupport.task("Big", estimate: 5)
        let estimate = FinishTimeCalculator.estimate(
            tasks: [task],
            settings: TimerSettings(),
            now: now,
            calendar: TestSupport.calendar
        )
        // Rounds 1..4 between rounds: short, short, short, long => 300*3 + 900 = 1800.
        #expect(abs(estimate.breakSeconds - 1800) < 0.0001)
    }
}
