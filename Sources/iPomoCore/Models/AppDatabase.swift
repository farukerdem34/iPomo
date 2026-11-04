import Foundation

public struct AppDatabase: Codable, Sendable {
    public static let currentSchemaVersion = 1
    private static let maximumRecordedSeconds = 7 * 24 * 60 * 60
    private static let maximumPomodoros = 999.0
    private static let maximumSortOrder = 1_000_000
    private static let maximumFocusRounds = 1_000_000

    public var schemaVersion: Int
    public var createdAt: Date
    public var updatedAt: Date
    public var projects: [Project]
    public var tasks: [PlanTask]
    public var sessions: [FocusSession]
    public var settings: AppSettings
    public var timer: TimerSnapshot

    public init(
        schemaVersion: Int = AppDatabase.currentSchemaVersion,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        projects: [Project] = [],
        tasks: [PlanTask] = [],
        sessions: [FocusSession] = [],
        settings: AppSettings = AppSettings(),
        timer: TimerSnapshot = TimerSnapshot()
    ) {
        self.schemaVersion = schemaVersion
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.projects = projects
        self.tasks = tasks
        self.sessions = sessions
        self.settings = settings
        self.timer = timer
    }

    private enum CodingKeys: String, CodingKey {
        case schemaVersion, createdAt, updatedAt, projects, tasks, sessions, settings, timer
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        schemaVersion = try c.decodeIfPresent(Int.self, forKey: .schemaVersion) ?? 1
        createdAt = try c.decodeIfPresent(Date.self, forKey: .createdAt) ?? Date()
        updatedAt = try c.decodeIfPresent(Date.self, forKey: .updatedAt) ?? Date()
        projects = try c.decodeIfPresent([Project].self, forKey: .projects) ?? []
        tasks = try c.decodeIfPresent([PlanTask].self, forKey: .tasks) ?? []
        sessions = try c.decodeIfPresent([FocusSession].self, forKey: .sessions) ?? []
        settings = try c.decodeIfPresent(AppSettings.self, forKey: .settings) ?? AppSettings()
        timer = try c.decodeIfPresent(TimerSnapshot.self, forKey: .timer) ?? TimerSnapshot()
        normalize()
    }

    // MARK: - Lookups

    public var projectByID: [UUID: Project] {
        Dictionary(uniqueKeysWithValues: projects.map { ($0.id, $0) })
    }

    public func project(id: UUID?) -> Project? {
        guard let id else { return nil }
        return projects.first { $0.id == id }
    }

    public func task(id: UUID?) -> PlanTask? {
        guard let id else { return nil }
        return tasks.first { $0.id == id }
    }

    public var activeProjects: [Project] {
        projects.filter { $0.status == .active || $0.status == .onHold }
            .sorted { $0.sortOrder < $1.sortOrder }
    }

    public var activeTasks: [PlanTask] {
        tasks.filter { !$0.isCompleted }
    }

    public var focusTodayTasks: [PlanTask] {
        activeTasks.filter(\.isFocusToday)
    }

    public func tasks(in projectID: UUID?) -> [PlanTask] {
        tasks.filter { $0.projectID == projectID }
    }

    // MARK: - Normalization

    public mutating func normalize() {
        schemaVersion = max(schemaVersion, 1)
        var seenProjectIDs = Set<UUID>()
        for index in projects.indices {
            if seenProjectIDs.contains(projects[index].id) {
                projects[index].id = UUID()
            }
            seenProjectIDs.insert(projects[index].id)
            projects[index].sortOrder = index
            if let target = projects[index].targetPomodoros {
                projects[index].targetPomodoros = min(Self.maximumPomodoros, max(0.1, target))
            }
        }
        var seenTaskIDs = Set<UUID>()
        for index in tasks.indices {
            if seenTaskIDs.contains(tasks[index].id) {
                tasks[index].id = UUID()
            }
            seenTaskIDs.insert(tasks[index].id)
            if let projectID = tasks[index].projectID, !seenProjectIDs.contains(projectID) {
                tasks[index].projectID = nil
            }
            tasks[index].estimatedPomodoros = min(Self.maximumPomodoros, max(0.1, tasks[index].estimatedPomodoros))
            tasks[index].completedPomodoros = min(Self.maximumPomodoros, max(0, tasks[index].completedPomodoros))
            tasks[index].sortOrder = min(Self.maximumSortOrder, max(0, tasks[index].sortOrder))
        }
        var seenSessionIDs = Set<UUID>()
        for index in sessions.indices {
            if seenSessionIDs.contains(sessions[index].id) {
                sessions[index].id = UUID()
            }
            seenSessionIDs.insert(sessions[index].id)
            sessions[index].plannedSeconds = min(Self.maximumRecordedSeconds, max(0, sessions[index].plannedSeconds))
            sessions[index].actualSeconds = min(Self.maximumRecordedSeconds, max(0, sessions[index].actualSeconds))
        }
        timer.focusRoundCount = min(Self.maximumFocusRounds, max(0, timer.focusRoundCount))
        timer.accumulatedSeconds = min(Double(Self.maximumRecordedSeconds), max(0, timer.accumulatedSeconds))
    }

    public var totalFocusSeconds: Int {
        sessions.filter(\.isFocus).reduce(0) { $0 + max(0, $1.actualSeconds) }
    }

    public var totalSessions: Int {
        sessions.filter(\.isFocus).count
    }
}
