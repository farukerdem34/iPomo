import Foundation

public struct TimerProgress: Sendable, Equatable {
    public let durationSeconds: Double
    public let consumedSeconds: Double
    public let remainingSeconds: Double

    public var fraction: Double {
        guard durationSeconds > 0 else { return 0 }
        return min(1, max(0, consumedSeconds / durationSeconds))
    }
}

public enum TimerMath {
    public static func durationSeconds(
        stage: Stage,
        settings: TimerSettings,
        task: PlanTask?
    ) -> Double {
        switch stage {
        case .focus:
            let base = max(1, settings.focusMinutes * 60)
            if let task,
               task.estimatedPomodoros > 0,
               task.estimatedPomodoros < 1 {
                return max(1, base * task.estimatedPomodoros)
            }
            return base
        case .shortBreak:
            return max(0, settings.shortBreakMinutes * 60)
        case .longBreak:
            return max(0, settings.longBreakMinutes * 60)
        }
    }

    public static func consumedSeconds(snapshot: TimerSnapshot, now: Date) -> Double {
        var consumed = max(0, snapshot.accumulatedSeconds)
        if snapshot.isRunning, let startedAt = snapshot.startedAt {
            consumed += max(0, now.timeIntervalSince(startedAt))
        }
        return consumed
    }

    public static func progress(
        snapshot: TimerSnapshot,
        settings: TimerSettings,
        task: PlanTask?,
        now: Date
    ) -> TimerProgress {
        let duration = durationSeconds(stage: snapshot.stage, settings: settings, task: task)
        let consumed = consumedSeconds(snapshot: snapshot, now: now)
        return TimerProgress(
            durationSeconds: duration,
            consumedSeconds: consumed,
            remainingSeconds: max(0, duration - consumed)
        )
    }

    /// The stage that follows `stage` when the current stage finishes.
    /// `completedFocusRounds` is the count before this round is credited.
    public static func nextStage(
        after stage: Stage,
        completedFocusRounds: Int,
        longBreakInterval: Int
    ) -> Stage {
        switch stage {
        case .focus:
            let upcomingRound = completedFocusRounds + 1
            let interval = max(1, longBreakInterval)
            return upcomingRound % interval == 0 ? .longBreak : .shortBreak
        case .shortBreak, .longBreak:
            return .focus
        }
    }

    public static func shouldAutoStart(nextStage: Stage, settings: TimerSettings) -> Bool {
        nextStage.isFocus ? settings.autoStartFocus : settings.autoStartBreaks
    }

    public static func formatCountdown(_ seconds: Double) -> String {
        let total = max(0, Int(ceil(seconds)))
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        let secs = total % 60
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, secs)
        }
        return String(format: "%02d:%02d", minutes, secs)
    }

    public static func formatClock(
        _ date: Date,
        hourFormat: HourFormat,
        calendar: Calendar
    ) -> String {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.locale = .current
        formatter.timeZone = calendar.timeZone
        formatter.dateFormat = hourFormat == .twelve ? "h:mm a" : "HH:mm"
        return formatter.string(from: date)
    }

    /// When the current stage would finish if it kept running from `now`.
    public static func projectedEndDate(
        snapshot: TimerSnapshot,
        settings: TimerSettings,
        task: PlanTask?,
        now: Date
    ) -> Date? {
        let progress = progress(snapshot: snapshot, settings: settings, task: task, now: now)
        guard progress.remainingSeconds > 0 else { return nil }
        return now.addingTimeInterval(progress.remainingSeconds)
    }
}
