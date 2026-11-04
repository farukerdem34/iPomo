import Foundation
import iPomoCore

extension AppModel {
    // MARK: - Derived timer state

    var stage: Stage { database.timer.stage }
    var isTimerRunning: Bool { database.timer.isRunning }

    var timerProgress: TimerProgress {
        TimerMath.progress(
            snapshot: database.timer,
            settings: database.settings.timer,
            task: activeTask,
            now: now
        )
    }

    var remainingSeconds: Double { timerProgress.remainingSeconds }

    var countdownText: String {
        TimerMath.formatCountdown(remainingSeconds)
    }

    var roundLabel: String {
        "#\(database.timer.focusRoundCount + 1)"
    }

    var longBreakIntervalLabel: String {
        "Long break every \(database.settings.timer.longBreakInterval) focus rounds"
    }

    var finishClockText: String? {
        guard let end = TimerMath.projectedEndDate(
            snapshot: database.timer,
            settings: database.settings.timer,
            task: activeTask,
            now: now
        ) else { return nil }
        return TimerMath.formatClock(
            end,
            hourFormat: database.settings.appearance.hourFormat,
            calendar: calendar
        )
    }

    var menuBarTitle: String {
        guard database.settings.appearance.showTimerInMenuBar else { return "iPomo" }
        if database.timer.isRunning || database.timer.accumulatedSeconds > 0 {
            return TimerMath.formatCountdown(remainingSeconds)
        }
        return "iPomo"
    }

    // MARK: - Controls

    func toggleTimer() {
        if database.timer.isRunning {
            pauseTimer()
        } else {
            startTimer()
        }
    }

    func startTimer() {
        cancelAutoStart()
        let progress = timerProgress
        guard progress.remainingSeconds > 0.05 else {
            finishCurrentRound(now: now, allowAlarm: true)
            return
        }
        mutate { database in
            database.timer.isRunning = true
            database.timer.startedAt = Date()
        }
        now = Date()
        if database.timer.stage == .focus {
            soundPlayer.startTicking(settings: database.settings.sound)
        }
        scheduleRemindersIfNeeded(remaining: progress.remainingSeconds)
        notifications.requestAuthorization()
    }

    func pauseTimer() {
        cancelAutoStart()
        stopTickingAudio()
        notifications.removeReminders()
        mutate { database in
            guard database.timer.isRunning else { return }
            let consumed = TimerMath.consumedSeconds(snapshot: database.timer, now: Date())
            database.timer.accumulatedSeconds = consumed
            database.timer.isRunning = false
            database.timer.startedAt = nil
        }
        now = Date()
    }

    func resetTimer() {
        cancelAutoStart()
        recordCurrentPartialIfNeeded()
        stopTickingAudio()
        notifications.removeReminders()
        mutate { database in
            database.timer.accumulatedSeconds = 0
            database.timer.isRunning = false
            database.timer.startedAt = nil
        }
        now = Date()
    }

    func resetCycle() {
        cancelAutoStart()
        recordCurrentPartialIfNeeded()
        stopTickingAudio()
        notifications.removeReminders()
        mutate { database in
            database.timer.stage = .focus
            database.timer.accumulatedSeconds = 0
            database.timer.isRunning = false
            database.timer.startedAt = nil
            database.timer.focusRoundCount = 0
        }
        now = Date()
        showBanner("Cycle reset. Next focus round is #1.", kind: .info)
    }

    func skipStage() {
        cancelAutoStart()
        // Skipping is a completion shortcut: credit the focus round (or finish
        // the break), advance the long-break cycle, and record the stage as
        // completed, exactly like a natural finish.
        finishCurrentRound(now: Date(), allowAlarm: false)
        let next = database.timer.stage
        if TimerMath.shouldAutoStart(nextStage: next, settings: database.settings.timer) {
            scheduleAutoStart(nextStage: next)
        }
    }

    func selectStage(_ newStage: Stage) {
        guard newStage != database.timer.stage || database.timer.accumulatedSeconds > 0 || database.timer.isRunning else {
            return
        }
        cancelAutoStart()
        recordCurrentPartialIfNeeded()
        stopTickingAudio()
        notifications.removeReminders()
        mutate { database in
            database.timer.stage = newStage
            database.timer.accumulatedSeconds = 0
            database.timer.isRunning = false
            database.timer.startedAt = nil
        }
        now = Date()
    }

    // MARK: - Task selection

    func requestTaskSelection(_ id: UUID?) {
        let title = id.flatMap { database.task(id: $0)?.title } ?? "No task"
        if database.timer.isRunning,
           database.settings.behavior.confirmTaskSwitch,
           id != database.timer.activeTaskID {
            pendingSwitch = PendingTaskSwitch(taskID: id, taskTitle: title)
            return
        }
        applyTaskSelection(id)
    }

    func confirmTaskSwitch(_ request: PendingTaskSwitch) {
        pendingSwitch = nil
        applyTaskSelection(request.taskID)
    }

    func cancelTaskSwitch() {
        pendingSwitch = nil
    }

    private func applyTaskSelection(_ id: UUID?) {
        guard id != database.timer.activeTaskID else { return }
        cancelAutoStart()
        recordCurrentPartialIfNeeded()
        stopTickingAudio()
        notifications.removeReminders()
        mutate { database in
            database.timer.activeTaskID = id
            database.timer.accumulatedSeconds = 0
            database.timer.isRunning = false
            database.timer.startedAt = nil
        }
        now = Date()
        let title = id.flatMap { database.task(id: $0)?.title } ?? "No task"
        showBanner("Active task: \(title)", kind: .info)
    }

    // MARK: - Completion

    func checkTimerCompletion() {
        guard database.timer.isRunning else { return }
        if remainingSeconds <= 0.05 {
            finishCurrentRound(now: now, allowAlarm: true)
        }
    }

    func finishCurrentRound(now: Date, allowAlarm: Bool) {
        let snapshot = database.timer
        let task = activeTask
        let duration = TimerMath.durationSeconds(
            stage: snapshot.stage,
            settings: database.settings.timer,
            task: task
        )
        let next = TimerMath.nextStage(
            after: snapshot.stage,
            completedFocusRounds: snapshot.focusRoundCount,
            longBreakInterval: database.settings.timer.longBreakInterval
        )

        let endedAt: Date
        if snapshot.isRunning, let startedAt = snapshot.startedAt {
            let expected = startedAt.addingTimeInterval(max(0, duration - snapshot.accumulatedSeconds))
            endedAt = min(now, expected)
        } else {
            endedAt = now
        }
        let startedAt = endedAt.addingTimeInterval(-duration)

        let session = makeSession(
            task: task,
            stage: snapshot.stage,
            startedAt: startedAt,
            endedAt: endedAt,
            plannedSeconds: Int(duration.rounded()),
            actualSeconds: Int(duration.rounded()),
            completed: true,
            isManual: false
        )

        mutate { database in
            database.sessions.append(session)
            if snapshot.stage == .focus {
                database.timer.focusRoundCount += 1
                if let taskID = snapshot.activeTaskID,
                   let index = database.tasks.firstIndex(where: { $0.id == taskID }) {
                    let unit = database.tasks[index].pomodoroUnit
                    database.tasks[index].completedPomodoros += unit
                    database.tasks[index].updatedAt = endedAt
                    if database.settings.behavior.autoCheckTasks,
                       database.tasks[index].completedPomodoros + 0.0001 >= database.tasks[index].estimatedPomodoros {
                        database.tasks[index].isCompleted = true
                        database.tasks[index].completedAt = endedAt
                        if database.settings.behavior.moveCompletedToBottom {
                            database.tasks[index].sortOrder = (database.tasks.map(\.sortOrder).max() ?? 0) + 1
                        }
                        if database.timer.activeTaskID == taskID {
                            database.timer.activeTaskID = nil
                        }
                    }
                }
            }
            database.timer.stage = next
            database.timer.accumulatedSeconds = 0
            database.timer.isRunning = false
            database.timer.startedAt = nil
            database.timer.lastFinishedAt = endedAt
        }

        stopTickingAudio()
        notifications.removeReminders()

        let bannerText = completionMessage(to: next, task: task)
        showBanner(bannerText, kind: .success)
        if allowAlarm {
            let notificationSettings = database.settings.notifications
            if notificationSettings.notificationsEnabled, notificationSettings.notifyOnRoundEnd {
                notifications.notify(title: "iPomo", body: bannerText)
            }
            soundPlayer.playAlarm(settings: database.settings.sound)
            if TimerMath.shouldAutoStart(nextStage: next, settings: database.settings.timer) {
                scheduleAutoStart(nextStage: next)
            }
        }
        self.now = Date()
        persistNow()
    }

    private func completionMessage(to: Stage, task: PlanTask?) -> String {
        let taskSuffix = task.map { " — \($0.title)" } ?? ""
        switch to {
        case .shortBreak:
            return "Focus round complete\(taskSuffix). Time for a short break."
        case .longBreak:
            return "Focus round complete\(taskSuffix). Time for a long break."
        case .focus:
            return "Break complete. Time to focus."
        }
    }

    // MARK: - Restore and teardown

    func restoreTimerIfNeeded() {
        if let activeID = database.timer.activeTaskID, database.task(id: activeID) == nil {
            mutate { database in
                database.timer.activeTaskID = nil
            }
        }
        guard database.timer.isRunning else { return }
        let progress = timerProgress
        if progress.remainingSeconds <= 0.05 {
            finishCurrentRound(now: now, allowAlarm: false)
            showBanner("A round finished while iPomo was closed. The next stage is ready.", kind: .info)
        } else {
            if database.timer.stage == .focus {
                soundPlayer.startTicking(settings: database.settings.sound)
            }
            scheduleRemindersIfNeeded(remaining: progress.remainingSeconds)
            showBanner("Timer resumed with \(TimerMath.formatCountdown(progress.remainingSeconds)) remaining.", kind: .info)
        }
    }

    func stopTimerForDataChange() {
        cancelAutoStart()
        soundPlayer.stopAll()
        notifications.removeReminders()
        mutate { database in
            database.timer = TimerSnapshot()
        }
        now = Date()
    }

    // MARK: - Helpers

    private func stopTickingAudio() {
        soundPlayer.stopTicking()
    }

    private func cancelAutoStart() {
        autoStartWorkItem?.cancel()
        autoStartWorkItem = nil
    }

    private func scheduleAutoStart(nextStage: Stage) {
        cancelAutoStart()
        let item = DispatchWorkItem { [weak self] in
            Task { @MainActor in
                guard let self else { return }
                guard !self.database.timer.isRunning,
                      self.database.timer.stage == nextStage else { return }
                self.startTimer()
            }
        }
        autoStartWorkItem = item
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2, execute: item)
    }

    private func scheduleRemindersIfNeeded(remaining: Double) {
        let settings = database.settings.notifications
        guard settings.notificationsEnabled, settings.remindersEnabled else {
            notifications.removeReminders()
            return
        }
        let interval = TimeInterval(max(1, settings.reminderMinutes) * 60)
        let stage = database.timer.stage.title.lowercased()
        var reminders: [(offset: TimeInterval, body: String)] = []
        switch settings.reminderMode {
        case .last:
            let offset = remaining - interval
            if offset > 1 {
                reminders = [(offset, Self.reminderText(minutes: settings.reminderMinutes, stage: stage))]
            }
        case .every:
            var offset = interval
            while offset < remaining, reminders.count < 24 {
                let minutes = max(1, Int(((remaining - offset) / 60).rounded()))
                reminders.append((offset, Self.reminderText(minutes: minutes, stage: stage)))
                offset += interval
            }
        }
        notifications.scheduleReminders(reminders, title: "iPomo reminder")
    }

    private static func reminderText(minutes: Int, stage: String) -> String {
        "\(minutes) minute\(minutes == 1 ? "" : "s") remain\(minutes == 1 ? "s" : "") in this \(stage)."
    }

    /// Records the uncommitted portion of the current focus round, if any.
    /// Called when the user deliberately abandons the round (reset, stage
    /// switch, task switch) so tracked focus time is not lost. Skipping is a
    /// completion shortcut and goes through `finishCurrentRound` instead.
    private func recordCurrentPartialIfNeeded() {
        guard database.settings.behavior.recordPartialSessions else { return }
        guard database.timer.stage == .focus else { return }
        let consumed = TimerMath.consumedSeconds(snapshot: database.timer, now: Date())
        guard consumed >= 1 else { return }
        let duration = TimerMath.durationSeconds(
            stage: .focus,
            settings: database.settings.timer,
            task: activeTask
        )
        let endedAt = Date()
        let session = makeSession(
            task: activeTask,
            stage: .focus,
            startedAt: endedAt.addingTimeInterval(-consumed),
            endedAt: endedAt,
            plannedSeconds: Int(duration.rounded()),
            actualSeconds: Int(consumed.rounded()),
            completed: false,
            isManual: false
        )
        mutate { database in
            database.sessions.append(session)
        }
    }

    private func makeSession(
        task: PlanTask?,
        stage: Stage,
        startedAt: Date,
        endedAt: Date,
        plannedSeconds: Int,
        actualSeconds: Int,
        completed: Bool,
        isManual: Bool
    ) -> FocusSession {
        let project = database.project(id: task?.projectID)
        let projectName: String
        if let project {
            projectName = project.name
        } else if task?.projectID == nil {
            projectName = "No Project"
        } else {
            projectName = "Deleted Project"
        }
        return FocusSession(
            taskID: task?.id,
            taskTitle: task?.title ?? "No task",
            projectID: task?.projectID,
            projectName: projectName,
            stage: stage,
            startedAt: startedAt,
            endedAt: endedAt,
            plannedSeconds: plannedSeconds,
            actualSeconds: actualSeconds,
            completed: completed,
            isManual: isManual
        )
    }
}
