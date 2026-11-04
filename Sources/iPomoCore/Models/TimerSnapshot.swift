import Foundation

public struct TimerSnapshot: Codable, Sendable, Equatable {
    public var stage: Stage
    public var isRunning: Bool
    /// Seconds already consumed in the current stage before `startedAt`.
    public var accumulatedSeconds: Double
    /// When the current running segment began. Nil while paused.
    public var startedAt: Date?
    /// Number of completed focus rounds. Used for the long-break interval.
    public var focusRoundCount: Int
    public var activeTaskID: UUID?
    public var lastFinishedAt: Date?

    public init(
        stage: Stage = .focus,
        isRunning: Bool = false,
        accumulatedSeconds: Double = 0,
        startedAt: Date? = nil,
        focusRoundCount: Int = 0,
        activeTaskID: UUID? = nil,
        lastFinishedAt: Date? = nil
    ) {
        self.stage = stage
        self.isRunning = isRunning
        self.accumulatedSeconds = accumulatedSeconds
        self.startedAt = startedAt
        self.focusRoundCount = focusRoundCount
        self.activeTaskID = activeTaskID
        self.lastFinishedAt = lastFinishedAt
    }

    private enum CodingKeys: String, CodingKey {
        case stage, isRunning, accumulatedSeconds, startedAt
        case focusRoundCount, activeTaskID, lastFinishedAt
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        stage = try c.decodeIfPresent(Stage.self, forKey: .stage) ?? .focus
        isRunning = try c.decodeIfPresent(Bool.self, forKey: .isRunning) ?? false
        accumulatedSeconds = try c.decodeIfPresent(Double.self, forKey: .accumulatedSeconds) ?? 0
        startedAt = try c.decodeIfPresent(Date.self, forKey: .startedAt)
        focusRoundCount = try c.decodeIfPresent(Int.self, forKey: .focusRoundCount) ?? 0
        activeTaskID = try c.decodeIfPresent(UUID.self, forKey: .activeTaskID)
        lastFinishedAt = try c.decodeIfPresent(Date.self, forKey: .lastFinishedAt)
        accumulatedSeconds = max(0, accumulatedSeconds)
        focusRoundCount = max(0, focusRoundCount)
        if !isRunning { startedAt = nil }
    }
}
