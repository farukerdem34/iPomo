import Foundation

public struct AppDatabase: Codable, Sendable {
    public static let currentSchemaVersion = 1

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
        }
    }

    public var totalFocusSeconds: Int {
        sessions.filter(\.isFocus).reduce(0) { $0 + max(0, $1.actualSeconds) }
    }

    public var totalSessions: Int {
        sessions.filter(\.isFocus).count
    }
}
