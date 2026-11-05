import Foundation
import Testing
@testable import iPomoCore

@Suite struct PersistenceTests {
    private func makeDirectory() throws -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("iPomoTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }

    @Test func saveAndLoadRoundTrip() throws {
        let directory = try makeDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = DatabaseStore(directoryURL: directory)
        let fixed = TestSupport.date(2026, 11, 4, hour: 9)
        let project = Project(name: "Round trip", createdAt: fixed, updatedAt: fixed)
        let task = PlanTask(
            title: "Task",
            projectID: project.id,
            estimatedPomodoros: 2,
            completedPomodoros: 1,
            createdAt: fixed,
            updatedAt: fixed
        )
        let session = TestSupport.session(task: "Task", projectID: project.id, project: project.name, start: fixed)
        let database = AppDatabase(projects: [project], tasks: [task], sessions: [session])
        try store.save(database)

        let outcome = store.load()
        guard case .loaded(let loaded) = outcome else {
            Issue.record("Expected loaded database")
            return
        }
        #expect(loaded.projects.count == 1)
        #expect(loaded.tasks.count == 1)
        #expect(loaded.tasks.first?.estimatedPomodoros == 2)
        #expect(loaded.tasks.first?.completedPomodoros == 1)
        #expect(loaded.sessions.count == 1)
        #expect(loaded.totalFocusSeconds == 1500)
    }

    @Test func legacyArchiveFlagDoesNotDropTask() throws {
        let task = PlanTask(title: "Previously archived")
        let encoded = try JSONEncoder().encode(task)
        guard var object = try JSONSerialization.jsonObject(with: encoded) as? [String: Any] else {
            Issue.record("Expected a task object")
            return
        }
        object["isArchived"] = true
        let legacy = try JSONSerialization.data(withJSONObject: object)
        let decoded = try JSONDecoder().decode(PlanTask.self, from: legacy)
        #expect(decoded.title == "Previously archived")
    }

    @Test func corruptFileIsMovedAside() throws {
        let directory = try makeDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = DatabaseStore(directoryURL: directory)
        try Data("not json".utf8).write(to: store.fileURL)
        let outcome = store.load()
        guard case .recovered(_, let message) = outcome else {
            Issue.record("Expected recovered outcome")
            return
        }
        #expect(message.contains("could not be decoded"))
        let backups = try FileManager.default.contentsOfDirectory(atPath: store.backupsURL.path)
        #expect(backups.contains { $0.hasPrefix("corrupt-") })
    }

    @Test func normalizationLimitsImportedNumbers() throws {
        let directory = try makeDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = DatabaseStore(directoryURL: directory)
        let now = TestSupport.date(2026, 11, 4)
        let sessionID = UUID()
        var database = AppDatabase()
        database.tasks = [
            PlanTask(title: "Huge", estimatedPomodoros: 1e12, completedPomodoros: 1e12, sortOrder: Int.max)
        ]
        database.sessions = [
            FocusSession(
                id: sessionID,
                taskTitle: "A",
                projectName: "",
                startedAt: now,
                endedAt: now,
                plannedSeconds: Int.max,
                actualSeconds: Int.max,
                completed: true
            ),
            FocusSession(
                id: sessionID,
                taskTitle: "B",
                projectName: "",
                startedAt: now,
                endedAt: now,
                plannedSeconds: -5,
                actualSeconds: -5,
                completed: true
            ),
        ]
        database.timer.focusRoundCount = Int.max
        database.timer.accumulatedSeconds = 1e300

        let decoded = try store.decode(store.encode(database))

        #expect(decoded.sessions.count == 2)
        #expect(Set(decoded.sessions.map(\.id)).count == 2)
        #expect(decoded.sessions.allSatisfy { $0.actualSeconds <= 7 * 86_400 })
        #expect(decoded.sessions.allSatisfy { $0.plannedSeconds >= 0 })
        #expect(decoded.tasks.first?.estimatedPomodoros == 999)
        #expect(decoded.tasks.first?.sortOrder == 1_000_000)
        #expect(decoded.timer.focusRoundCount == 1_000_000)
        #expect(decoded.timer.accumulatedSeconds <= 604_800)
    }

    @Test func tolerantSettingsDecoding() throws {
        let directory = try makeDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let json = """
        {
          "schemaVersion": 1,
          "settings": { "timer": { "focusMinutes": 50 } },
          "timer": { "stage": "focus" }
        }
        """
        let database = try DatabaseStore(directoryURL: directory).decode(Data(json.utf8))
        #expect(database.settings.timer.focusMinutes == 50)
        #expect(database.settings.timer.shortBreakMinutes == 5)
        #expect(database.settings.timer.longBreakInterval == 4)
        #expect(database.settings.appearance.theme == .tomato)
        #expect(database.settings.updates.automaticallyChecksForUpdates)
    }

    @Test func unsupportedSchemaIsRejected() throws {
        let directory = try makeDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let json = #"{"schemaVersion": 99}"#
        let store = DatabaseStore(directoryURL: directory)
        do {
            _ = try store.decode(Data(json.utf8))
            Issue.record("Expected unsupported schema error")
        } catch let error as DatabaseStoreError {
            guard case .unsupportedSchema(99) = error else {
                Issue.record("Unexpected error: \(error)")
                return
            }
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }

    @Test func newerSchemaFileIsKeptInPlace() throws {
        let directory = try makeDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = DatabaseStore(directoryURL: directory)
        try Data(#"{"schemaVersion": 99}"#.utf8).write(to: store.fileURL)

        let outcome = store.load()

        guard case .unsupported(let version) = outcome else {
            Issue.record("Expected unsupported outcome")
            return
        }
        #expect(version == 99)
        #expect(FileManager.default.fileExists(atPath: store.fileURL.path))
        let backups = (try? FileManager.default.contentsOfDirectory(atPath: store.backupsURL.path)) ?? []
        #expect(!backups.contains { $0.hasPrefix("corrupt-") })
    }

    @Test func backupIsCreated() throws {
        let directory = try makeDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = DatabaseStore(directoryURL: directory)
        try store.save(AppDatabase())
        store.backupIfNeeded(force: true)
        let backups = try FileManager.default.contentsOfDirectory(atPath: store.backupsURL.path)
        #expect(backups.contains { $0.hasPrefix("data-") && $0.hasSuffix(".json") })
    }

    @Test func exportImportRoundTrip() throws {
        let directory = try makeDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = DatabaseStore(directoryURL: directory)
        var database = AppDatabase()
        database.settings.appearance.theme = .ocean
        database.settings.timer.focusMinutes = 40
        let data = try store.encode(database)
        let decoded = try store.decode(data)
        #expect(decoded.settings.appearance.theme == .ocean)
        #expect(decoded.settings.timer.focusMinutes == 40)
    }
}
