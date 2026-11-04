import Foundation
import Testing
@testable import iPomoCore

@Suite struct ReportTests {
    private let now = TestSupport.date(2026, 11, 4, hour: 12)
    private let projectA = Project(name: "Alpha", colorHex: "#111111")
    private let projectB = Project(name: "Beta", colorHex: "#222222")

    private func makeDatabase() -> AppDatabase {
        let sessions = [
            TestSupport.session(task: "Old week", projectID: projectA.id, project: "Alpha", start: TestSupport.date(2026, 10, 28, hour: 9)),
            TestSupport.session(task: "Sunday", projectID: projectA.id, project: "Alpha", start: TestSupport.date(2026, 11, 1, hour: 9)),
            TestSupport.session(task: "Monday", projectID: projectA.id, project: "Alpha", start: TestSupport.date(2026, 11, 2, hour: 9)),
            TestSupport.session(task: "Tuesday", projectID: projectA.id, project: "Alpha", start: TestSupport.date(2026, 11, 3, hour: 9)),
            TestSupport.session(task: "Wednesday", projectID: projectA.id, project: "Alpha", start: TestSupport.date(2026, 11, 4, hour: 9)),
            TestSupport.session(task: "Manual", projectID: projectB.id, project: "Beta", start: TestSupport.date(2026, 11, 4, hour: 10), seconds: 600, manual: true),
            TestSupport.session(task: "Break", projectID: projectA.id, project: "Alpha", stage: .shortBreak, start: TestSupport.date(2026, 11, 4, hour: 11), seconds: 300),
        ]
        var completed = TestSupport.task("Done this week", projectID: projectA.id)
        completed.isCompleted = true
        completed.completedAt = TestSupport.date(2026, 11, 3, hour: 17)
        var outside = TestSupport.task("Done last week", projectID: projectA.id)
        outside.isCompleted = true
        outside.completedAt = TestSupport.date(2026, 10, 29, hour: 17)
        return AppDatabase(
            projects: [projectA, projectB],
            tasks: [completed, outside],
            sessions: sessions
        )
    }

    @Test func weekTotalsExcludeBreaksAndCountCompletedTasks() {
        let summary = ReportAggregator.summary(
            database: makeDatabase(),
            range: .week,
            now: now,
            calendar: TestSupport.calendar
        )
        #expect(summary.totalFocusSeconds == 5100)
        #expect(summary.focusSessionCount == 4)
        #expect(summary.daysAccessed == 3)
        #expect(summary.completedTaskCount == 1)
        #expect(summary.buckets.count == 7)
        #expect(summary.buckets.reduce(0) { $0 + $1.seconds } == 5100)
        #expect(summary.totalFocusMinutes == 85)
    }

    @Test func monthAndYearTotals() {
        let month = ReportAggregator.summary(
            database: makeDatabase(),
            range: .month,
            now: now,
            calendar: TestSupport.calendar
        )
        #expect(month.totalFocusSeconds == 6600)
        #expect(month.daysAccessed == 4)

        let year = ReportAggregator.summary(
            database: makeDatabase(),
            range: .year,
            now: now,
            calendar: TestSupport.calendar
        )
        #expect(year.totalFocusSeconds == 8100)
        #expect(year.buckets.count == 12)
    }

    @Test func projectTotalsAndShares() {
        let summary = ReportAggregator.summary(
            database: makeDatabase(),
            range: .week,
            now: now,
            calendar: TestSupport.calendar
        )
        #expect(summary.projectTotals.count == 2)
        #expect(summary.projectTotals.first?.name == "Alpha")
        #expect(summary.projectTotals.first?.seconds == 4500)
        #expect(abs((summary.projectTotals.first?.share ?? 0) - 4500.0 / 5100.0) < 0.0001)
        #expect(summary.projectTotals.last?.name == "Beta")
    }

    @Test func projectFilter() {
        let summary = ReportAggregator.summary(
            database: makeDatabase(),
            range: .week,
            projectFilter: projectB.id,
            now: now,
            calendar: TestSupport.calendar
        )
        #expect(summary.totalFocusSeconds == 600)
        #expect(summary.focusSessionCount == 1)
        #expect(summary.completedTaskCount == 0)
    }

    @Test func currentAndLongestStreak() {
        let summary = ReportAggregator.summary(
            database: makeDatabase(),
            range: .week,
            now: now,
            calendar: TestSupport.calendar
        )
        #expect(summary.currentStreak == 4)
        #expect(summary.longestStreak == 4)

        let nextDay = TestSupport.date(2026, 11, 5, hour: 8)
        let nextDaySummary = ReportAggregator.summary(
            database: makeDatabase(),
            range: .week,
            now: nextDay,
            calendar: TestSupport.calendar
        )
        #expect(nextDaySummary.currentStreak == 4)
    }

    @Test func csvFormulaPrefixesAreEscaped() {
        let session = TestSupport.session(
            task: "=1+1",
            project: "@SUM(A1)",
            start: TestSupport.date(2026, 11, 4, hour: 9)
        )
        let csv = ReportCSV.makeCSV(sessions: [session], calendar: TestSupport.calendar)
        let row = csv.split(separator: "\n")[1]
        #expect(row.contains("'=1+1"))
        #expect(row.contains("'@SUM(A1)"))
    }

    @Test func csvEscaping() {
        let session = TestSupport.session(
            task: "Task, with \"quotes\"",
            project: "Alpha",
            start: TestSupport.date(2026, 11, 4, hour: 9)
        )
        let csv = ReportCSV.makeCSV(sessions: [session], calendar: TestSupport.calendar)
        let lines = csv.split(separator: "\n")
        #expect(lines.count == 2)
        #expect(lines[1].contains("\"Task, with \"\"quotes\"\"\""))
        #expect(lines[0].hasPrefix("Date,Start,End,Task,Project"))
    }
}
