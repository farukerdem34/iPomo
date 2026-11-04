import Foundation
import Testing
import iPomoCore
@testable import iPomoUI

@Suite @MainActor
struct AppModelTests {
    private func makeModel() throws -> (model: AppModel, directory: URL) {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("iPomoAppTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let model = AppModel(store: DatabaseStore(directoryURL: directory))
        model.updateSettings { settings in
            settings.sound.soundsEnabled = false
            settings.notifications.notificationsEnabled = false
            settings.timer.autoStartBreaks = false
            settings.timer.autoStartFocus = false
        }
        return (model, directory)
    }

    @Test func taskPersistsAcrossModels() throws {
        let (model, directory) = try makeModel()
        defer { try? FileManager.default.removeItem(at: directory) }
        model.saveTask(PlanTask(title: "Write report", estimatedPomodoros: 2))
        #expect(model.database.tasks.count == 1)
        model.persistNow()

        let reloaded = AppModel(store: DatabaseStore(directoryURL: directory))
        #expect(reloaded.database.tasks.count == 1)
        #expect(reloaded.database.tasks.first?.title == "Write report")
        #expect(reloaded.database.tasks.first?.estimatedPomodoros == 2)
    }

    @Test func finishingFocusCreditsTaskAndAdvancesStage() throws {
        let (model, directory) = try makeModel()
        defer { try? FileManager.default.removeItem(at: directory) }
        let task = PlanTask(title: "Deep work", estimatedPomodoros: 1)
        model.saveTask(task)
        model.requestTaskSelection(task.id)
        #expect(model.database.timer.activeTaskID == task.id)

        model.finishCurrentRound(now: Date(), allowAlarm: false)

        #expect(model.database.sessions.count == 1)
        #expect(model.database.sessions.first?.stage == .focus)
        #expect(model.database.sessions.first?.actualSeconds == 1500)
        #expect(model.database.sessions.first?.completed == true)
        #expect(model.database.tasks.first?.completedPomodoros == 1)
        #expect(model.database.timer.focusRoundCount == 1)
        #expect(model.database.timer.stage == .shortBreak)
        #expect(model.database.timer.isRunning == false)
    }

    @Test func fourthFocusRoundSchedulesLongBreak() throws {
        let (model, directory) = try makeModel()
        defer { try? FileManager.default.removeItem(at: directory) }
        model.mutate { database in
            database.timer.focusRoundCount = 3
        }
        model.finishCurrentRound(now: Date(), allowAlarm: false)
        #expect(model.database.timer.focusRoundCount == 4)
        #expect(model.database.timer.stage == .longBreak)
    }

    @Test func autoCheckCompletesTaskAndClearsActiveTask() throws {
        let (model, directory) = try makeModel()
        defer { try? FileManager.default.removeItem(at: directory) }
        model.updateSettings { settings in
            settings.behavior.autoCheckTasks = true
            settings.behavior.moveCompletedToBottom = true
        }
        let task = PlanTask(title: "One round", estimatedPomodoros: 1)
        model.saveTask(task)
        model.requestTaskSelection(task.id)

        model.finishCurrentRound(now: Date(), allowAlarm: false)

        #expect(model.database.tasks.first?.isCompleted == true)
        #expect(model.database.tasks.first?.completedAt != nil)
        #expect(model.database.timer.activeTaskID == nil)
    }

    @Test func fractionalEstimateCreditsFraction() throws {
        let (model, directory) = try makeModel()
        defer { try? FileManager.default.removeItem(at: directory) }
        let task = PlanTask(title: "Tiny task", estimatedPomodoros: 0.5)
        model.saveTask(task)
        model.requestTaskSelection(task.id)

        model.finishCurrentRound(now: Date(), allowAlarm: false)

        #expect(model.database.sessions.first?.actualSeconds == 750)
        #expect(model.database.tasks.first?.completedPomodoros == 0.5)
    }

    @Test func skippingFocusActsLikeCompletion() throws {
        let (model, directory) = try makeModel()
        defer { try? FileManager.default.removeItem(at: directory) }
        let task = PlanTask(title: "Skip me", estimatedPomodoros: 1)
        model.saveTask(task)
        model.requestTaskSelection(task.id)
        model.mutate { database in
            database.timer.accumulatedSeconds = 300
        }

        model.skipStage()

        #expect(model.database.sessions.count == 1)
        #expect(model.database.sessions.first?.stage == .focus)
        #expect(model.database.sessions.first?.completed == true)
        #expect(model.database.sessions.first?.actualSeconds == 1500)
        #expect(model.database.tasks.first?.completedPomodoros == 1)
        #expect(model.database.timer.focusRoundCount == 1)
        #expect(model.database.timer.stage == .shortBreak)
    }

    @Test func skippingBreakActsLikeCompletedBreak() throws {
        let (model, directory) = try makeModel()
        defer { try? FileManager.default.removeItem(at: directory) }
        model.mutate { database in
            database.timer.stage = .shortBreak
            database.timer.accumulatedSeconds = 30
        }

        model.skipStage()

        #expect(model.database.sessions.count == 1)
        #expect(model.database.sessions.first?.stage == .shortBreak)
        #expect(model.database.sessions.first?.completed == true)
        #expect(model.database.sessions.first?.actualSeconds == 300)
        #expect(model.database.timer.focusRoundCount == 0)
        #expect(model.database.timer.stage == .focus)
        #expect(model.database.tasks.isEmpty)
    }

    @Test func resetRecordsPartialFocusWithoutCreditingRound() throws {
        let (model, directory) = try makeModel()
        defer { try? FileManager.default.removeItem(at: directory) }
        model.mutate { database in
            database.timer.stage = .focus
            database.timer.accumulatedSeconds = 300
            database.timer.isRunning = false
            database.timer.startedAt = nil
        }

        model.resetTimer()

        #expect(model.database.sessions.count == 1)
        #expect(model.database.sessions.first?.actualSeconds == 300)
        #expect(model.database.sessions.first?.completed == false)
        #expect(model.database.timer.accumulatedSeconds == 0)
        #expect(model.database.timer.focusRoundCount == 0)
    }

    @Test func manualSessionAppearsInTodayReport() throws {
        let (model, directory) = try makeModel()
        defer { try? FileManager.default.removeItem(at: directory) }
        let calendar = model.calendar
        let noon = calendar.date(
            bySettingHour: 12,
            minute: 0,
            second: 0,
            of: Date()
        ) ?? Date()

        model.addManualSession(
            taskTitle: "Reading",
            projectID: nil,
            date: noon,
            minutes: 30
        )

        let summary = model.reportSummary(range: .today)
        #expect(summary.totalFocusSeconds == 1800)
        #expect(summary.focusSessionCount == 1)
        #expect(summary.sessions.first?.isManual == true)
    }

    @Test func deletingProjectCanKeepTasks() throws {
        let (model, directory) = try makeModel()
        defer { try? FileManager.default.removeItem(at: directory) }
        let project = Project(name: "Keep me")
        model.saveProject(project)
        let task = PlanTask(title: "Task", projectID: project.id)
        model.saveTask(task)

        model.deleteProject(id: project.id, deleteTasks: false)

        #expect(model.database.projects.isEmpty)
        #expect(model.database.tasks.count == 1)
        #expect(model.database.tasks.first?.projectID == nil)
    }

    @Test func deletingProjectCanDeleteTasks() throws {
        let (model, directory) = try makeModel()
        defer { try? FileManager.default.removeItem(at: directory) }
        let project = Project(name: "Delete me")
        model.saveProject(project)
        model.saveTask(PlanTask(title: "Task", projectID: project.id))

        model.deleteProject(id: project.id, deleteTasks: true)

        #expect(model.database.projects.isEmpty)
        #expect(model.database.tasks.isEmpty)
    }
}
