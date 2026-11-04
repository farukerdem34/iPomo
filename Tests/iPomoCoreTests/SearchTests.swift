import Foundation
import Testing
@testable import iPomoCore

@Suite struct SearchTests {
    private let work = Project(name: "Work")
    private var projects: [UUID: Project] { [work.id: work] }

    private var tasks: [PlanTask] {
        [
            TestSupport.task("Write quarterly report", notes: "Numbers for Q3", projectID: work.id),
            TestSupport.task("Report review", notes: "Team feedback"),
            TestSupport.task("Cafe meeting", notes: "Catch up", projectID: work.id),
            TestSupport.task("Grocery list"),
            TestSupport.task("Finished task", isCompleted: true),
        ]
    }

    @Test func caseInsensitiveAndMultiTermAnd() {
        let results = TaskSearch.search(tasks, query: "REPORT write", projects: projects, scope: .active)
        #expect(results.first?.title == "Write quarterly report")
        #expect(results.contains { $0.title == "Report review" } == false)
    }

    @Test func searchesNotesAndProject() {
        #expect(TaskSearch.search(tasks, query: "numbers", projects: projects, scope: .active)
            .contains { $0.title == "Write quarterly report" })
        #expect(TaskSearch.search(tasks, query: "work", projects: projects, scope: .active)
            .contains { $0.title == "Cafe meeting" })
    }

    @Test func diacriticAndWhitespaceFolding() {
        let results = TaskSearch.search(tasks, query: "café   MEETING", projects: projects, scope: .active)
        #expect(results.first?.title == "Cafe meeting")
    }

    @Test func noLiteralUndefinedForMissingFields() {
        // Missing optional fields must stay empty, not become "undefined"/"null".
        #expect(TaskSearch.search(tasks, query: "undefined", projects: projects, scope: .active).isEmpty)
        #expect(TaskSearch.search(tasks, query: "null", projects: projects, scope: .active).isEmpty)
    }

    @Test func titleMatchesRankAboveNotes() {
        let tasks = [
            TestSupport.task("Unrelated", notes: "report report report"),
            TestSupport.task("Report"),
        ]
        let results = TaskSearch.search(tasks, query: "report", projects: [:], scope: .active)
        #expect(results.first?.title == "Report")
    }

    @Test func scopeFiltersStatus() {
        let active = TaskSearch.search(tasks, query: "", projects: projects, scope: .active)
        #expect(active.count == tasks.count)
        #expect(active.contains { $0.isCompleted })
        #expect(TaskSearch.search(tasks, query: "finished", projects: projects, scope: .completed)
            .contains { $0.title == "Finished task" })
        #expect(TaskSearch.search(tasks, query: "", projects: projects, scope: .completed)
            .allSatisfy { $0.isCompleted })
    }

    @Test func emptyQueryKeepsCompletedTasksVisibleAtTheBottom() {
        let results = TaskSearch.search(tasks, query: "   ", projects: projects, scope: .active)
        #expect(results.count == 5)
        #expect(results.last?.title == "Finished task")
    }
}
