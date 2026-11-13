import Foundation

public struct FocusSession: Identifiable, Hashable, Sendable {
    public var id: UUID
    public var taskID: UUID?
    public var taskTitle: String
    public var notes: String
    public var projectID: UUID?
    public var projectName: String
    public var stage: Stage
    public var startedAt: Date
    public var endedAt: Date
    public var plannedSeconds: Int
    public var actualSeconds: Int
    public var completed: Bool
    public var isManual: Bool

    public init(
        id: UUID = UUID(),
        taskID: UUID? = nil,
        taskTitle: String,
        notes: String = "",
        projectID: UUID? = nil,
        projectName: String,
        stage: Stage = .focus,
        startedAt: Date,
        endedAt: Date,
        plannedSeconds: Int,
        actualSeconds: Int,
        completed: Bool,
        isManual: Bool = false
    ) {
        self.id = id
        self.taskID = taskID
        self.taskTitle = taskTitle
        self.notes = notes
        self.projectID = projectID
        self.projectName = projectName
        self.stage = stage
        self.startedAt = startedAt
        self.endedAt = endedAt
        self.plannedSeconds = plannedSeconds
        self.actualSeconds = actualSeconds
        self.completed = completed
        self.isManual = isManual
    }

    public var isFocus: Bool { stage == .focus }

    public var minutes: Int {
        Int((Double(actualSeconds) / 60.0).rounded())
    }
}

extension FocusSession: Codable {
    private enum CodingKeys: String, CodingKey {
        case id, taskID, taskTitle, notes, projectID, projectName, stage, startedAt, endedAt, plannedSeconds, actualSeconds, completed, isManual
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        taskID = try container.decodeIfPresent(UUID.self, forKey: .taskID)
        taskTitle = try container.decode(String.self, forKey: .taskTitle)
        notes = try container.decodeIfPresent(String.self, forKey: .notes) ?? ""
        projectID = try container.decodeIfPresent(UUID.self, forKey: .projectID)
        projectName = try container.decode(String.self, forKey: .projectName)
        stage = try container.decode(Stage.self, forKey: .stage)
        startedAt = try container.decode(Date.self, forKey: .startedAt)
        endedAt = try container.decode(Date.self, forKey: .endedAt)
        plannedSeconds = try container.decode(Int.self, forKey: .plannedSeconds)
        actualSeconds = try container.decode(Int.self, forKey: .actualSeconds)
        completed = try container.decode(Bool.self, forKey: .completed)
        isManual = try container.decodeIfPresent(Bool.self, forKey: .isManual) ?? false
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encodeIfPresent(taskID, forKey: .taskID)
        try container.encode(taskTitle, forKey: .taskTitle)
        try container.encode(notes, forKey: .notes)
        try container.encodeIfPresent(projectID, forKey: .projectID)
        try container.encode(projectName, forKey: .projectName)
        try container.encode(stage, forKey: .stage)
        try container.encode(startedAt, forKey: .startedAt)
        try container.encode(endedAt, forKey: .endedAt)
        try container.encode(plannedSeconds, forKey: .plannedSeconds)
        try container.encode(actualSeconds, forKey: .actualSeconds)
        try container.encode(completed, forKey: .completed)
        try container.encode(isManual, forKey: .isManual)
    }
}
