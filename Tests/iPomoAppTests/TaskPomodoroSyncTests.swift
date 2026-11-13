import Foundation
import Testing
import iPomoCore
@testable import iPomoUI

@Suite @MainActor
struct TaskPomodoroSyncTests {
    private func makeModel() throws -> (model: AppModel, directory: URL) {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("iPomoSyncTests-\(UUID().uuidString)", isDirectory: true)
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

    @Test func raisingCompletedCountAddsSession() throws {
        let (model, directory) = try makeModel()
        defer { try? FileManager.default.removeItem(at: directory) }
        let task = PlanTask(title: "Deep work", estimatedPomodoros: 2)
        model.saveTask(task)
        let before = model.database.sessions.count
        var edited = model.task(id: task.id)!
        edited.completedPomodoros = 2
        model.saveTask(edited)
        #expect(model.database.sessions.count == before + 1)
        #expect(model.database.sessions.last?.taskID == task.id)
        #expect(model.database.sessions.last?.creditedPomodoros == 2)
    }

    @Test func loweringCompletedCountRemovesSession() throws {
        let (model, directory) = try makeModel()
        defer { try? FileManager.default.removeItem(at: directory) }
        let task = PlanTask(title: "Deep work", estimatedPomodoros: 2)
        model.saveTask(task)
        var edited = model.task(id: task.id)!
        edited.completedPomodoros = 2
        model.saveTask(edited)
        var editedAgain = model.task(id: task.id)!
        editedAgain.completedPomodoros = 0
        model.saveTask(editedAgain)
        #expect(model.database.sessions.filter { $0.taskID == task.id }.isEmpty)
        #expect(model.database.tasks.first?.completedPomodoros == 0)
    }
}