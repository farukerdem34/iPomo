import Foundation

public struct Project: Identifiable, Codable, Hashable, Sendable {
    public var id: UUID
    public var name: String
    public var details: String
    public var colorHex: String
    public var status: ProjectStatus
    public var dueDate: Date?
    public var targetPomodoros: Double?
    public var sortOrder: Int
    public var createdAt: Date
    public var updatedAt: Date

    public init(
        id: UUID = UUID(),
        name: String,
        details: String = "",
        colorHex: String = ProjectPalette.colors[0],
        status: ProjectStatus = .active,
        dueDate: Date? = nil,
        targetPomodoros: Double? = nil,
        sortOrder: Int = 0,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.details = details
        self.colorHex = colorHex
        self.status = status
        self.dueDate = dueDate
        self.targetPomodoros = targetPomodoros
        self.sortOrder = sortOrder
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}
