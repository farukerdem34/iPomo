import Foundation
import Testing
@testable import iPomoCore

@Suite struct TimerMathTests {
    private let settings = TimerSettings()

    @Test func stageDurations() {
        #expect(TimerMath.durationSeconds(stage: .focus, settings: settings, task: nil) == 1500)
        #expect(TimerMath.durationSeconds(stage: .shortBreak, settings: settings, task: nil) == 300)
        #expect(TimerMath.durationSeconds(stage: .longBreak, settings: settings, task: nil) == 900)
    }

    @Test func fractionalEstimateScalesFocusDuration() {
        let task = TestSupport.task("Tiny task", estimate: 0.5)
        #expect(TimerMath.durationSeconds(stage: .focus, settings: settings, task: task) == 750)
    }

    @Test func consumedSecondsWithRunningSegment() {
        let now = TestSupport.date(2026, 11, 4)
        let snapshot = TimerSnapshot(
            stage: .focus,
            isRunning: true,
            accumulatedSeconds: 100,
            startedAt: now.addingTimeInterval(-50)
        )
        #expect(abs(TimerMath.consumedSeconds(snapshot: snapshot, now: now) - 150) < 0.01)
    }

    @Test func remainingNeverNegative() {
        let now = TestSupport.date(2026, 11, 4)
        let snapshot = TimerSnapshot(
            stage: .focus,
            isRunning: true,
            accumulatedSeconds: 1400,
            startedAt: now.addingTimeInterval(-200)
        )
        let progress = TimerMath.progress(snapshot: snapshot, settings: settings, task: nil, now: now)
        #expect(progress.remainingSeconds == 0)
        #expect(progress.fraction == 1)
    }

    @Test func longBreakAfterInterval() {
        #expect(TimerMath.nextStage(after: .focus, completedFocusRounds: 0, longBreakInterval: 4) == .shortBreak)
        #expect(TimerMath.nextStage(after: .focus, completedFocusRounds: 3, longBreakInterval: 4) == .longBreak)
        #expect(TimerMath.nextStage(after: .focus, completedFocusRounds: 7, longBreakInterval: 4) == .longBreak)
        #expect(TimerMath.nextStage(after: .shortBreak, completedFocusRounds: 4, longBreakInterval: 4) == .focus)
        #expect(TimerMath.nextStage(after: .longBreak, completedFocusRounds: 4, longBreakInterval: 4) == .focus)
    }

    @Test func autoStartRules() {
        var settings = TimerSettings()
        settings.autoStartBreaks = true
        settings.autoStartFocus = false
        #expect(TimerMath.shouldAutoStart(nextStage: .shortBreak, settings: settings))
        #expect(!TimerMath.shouldAutoStart(nextStage: .focus, settings: settings))
    }

    @Test func countdownFormatting() {
        #expect(TimerMath.formatCountdown(1500) == "25:00")
        #expect(TimerMath.formatCountdown(65) == "01:05")
        #expect(TimerMath.formatCountdown(3661) == "1:01:01")
        #expect(TimerMath.formatCountdown(-1) == "00:00")
    }
}
