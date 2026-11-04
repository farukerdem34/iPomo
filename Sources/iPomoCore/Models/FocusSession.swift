import Foundation

public struct FocusSession: Identifiable, Codable, Hashable, Sendable {
    public var id: UUID
    public var taskID: UUID?
    public var taskTitle: String
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
