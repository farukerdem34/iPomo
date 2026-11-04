import iPomoCore
import SwiftUI

struct DashboardView: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.editorialAccent) private var accent
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var quickTaskTitle = ""

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DesignTokens.s5) {
                header
                MetricLedger(metrics: metrics)
                HStack(alignment: .top, spacing: DesignTokens.s5) {
                    planColumn
                        .frame(maxWidth: .infinity, alignment: .topLeading)
                    rightColumn
                        .frame(width: 304)
                }
            }
            .editorialPagePadding()
        }
        .editorialBackground()
        .navigationTitle("Today")
    }

    private var header: some View {
        HStack(alignment: .top, spacing: DesignTokens.s4) {
            PageTitle(
                eyebrow: AppFormat.longDate(model.now, calendar: model.calendar),
                title: "Today",
                detail: headerDetail
            )
            Spacer(minLength: DesignTokens.s3)
            Button {
                model.presentNewTask()
            } label: {
                Label("Add task", systemImage: "plus")
            }
            .buttonStyle(EditorialPrimaryButtonStyle())
        }
    }

    private var headerDetail: String {
        let focus = AppFormat.duration(seconds: model.todayFocusSeconds)
        if model.todayPlanTasks.isEmpty {
            return "\(focus) focused today · nothing planned yet"
        }
        let finish = AppFormat.clock(
            model.todayPlanFinishEstimate.finishDate,
            hourFormat: model.database.settings.appearance.hourFormat,
            calendar: model.calendar
        )
        return "\(model.todayPlanTasks.count) planned · \(focus) focused · projected finish \(finish)"
    }

    private var metrics: [LedgerMetric] {
        let goal = model.database.settings.planning.dailyGoalMinutes
        let percent = goal > 0 ? min(100, Int((Double(model.todayFocusMinutes) / Double(goal) * 100).rounded())) : 0
        let remaining = max(0, goal - model.todayFocusMinutes)
        return [
            LedgerMetric(
                label: "Focus today",
                value: AppFormat.duration(seconds: model.todayFocusSeconds),
                detail: "\(model.todayFocusMinutes) of \(goal) goal min"
            ),
            LedgerMetric(
                label: "Streak",
                value: "\(model.overallStreak.current) days",
                detail: "Longest \(model.overallStreak.longest)"
            ),
            LedgerMetric(
                label: "Open tasks",
                value: "\(model.activeTasks.count)",
                detail: "\(model.todayPlanTasks.count) in today's plan"
            ),
            LedgerMetric(
                label: "Daily goal",
                value: goal > 0 ? "\(percent)%" : "—",
                detail: goal > 0 ? (remaining == 0 ? "Goal reached" : "\(remaining) min left") : "Set a goal in Settings"
            ),
        ]
    }

    private var planColumn: some View {
        VStack(alignment: .leading, spacing: DesignTokens.s3) {
            HStack(alignment: .firstTextBaseline) {
                SectionHeading(
                    overline: "Plan",
                    title: "Today's plan",
                    detail: model.todayPlanTasks.isEmpty ? nil : "Projected from \(AppFormat.clock(model.now, hourFormat: model.database.settings.appearance.hourFormat, calendar: model.calendar))"
                )
                Spacer()
                Button("Open Tasks") {
                    model.selectedSidebar = .tasks
                    model.taskProjectFilter = nil
                }
                .buttonStyle(EditorialQuietButtonStyle())
            }

            Hairline()

            if model.todayPlanTasks.isEmpty {
                EditorialEmptyState(
                    overline: "Nothing planned",
                    title: "Make room for deep work",
                    message: "Star a task, set a due date for today, or add something small to begin.",
                    actionTitle: "Add a task",
                    action: { model.presentNewTask() }
                )
                quickAddRow
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(projectedRows.enumerated()), id: \.element.task.id) { index, row in
                        DashboardTaskRow(
                            task: row.task,
                            projectedStart: row.start,
                            isLast: index == projectedRows.count - 1
                        )
                    }
                }
                .animation(Motion.calm(reduceMotion, duration: 0.2), value: model.todayPlanTasks.map(\.id))
                quickAddRow
            }
        }
    }

    private var rightColumn: some View {
        VStack(alignment: .leading, spacing: DesignTokens.s5) {
            focusPanel
            projectsPanel
        }
    }

    private var focusPanel: some View {
        let stageColor = StagePalette.color(for: model.stage, accent: accent)
        return VStack(alignment: .leading, spacing: DesignTokens.s3) {
            HStack {
                Overline("Timer", color: DesignTokens.onAccent.opacity(0.7))
                Spacer()
                Text(model.roundLabel)
                    .font(Typography.overline(9))
                    .foregroundStyle(DesignTokens.onAccent.opacity(0.7))
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(model.countdownText)
                    .font(Typography.number(48))
                    .monospacedDigit()
                    .foregroundStyle(DesignTokens.onAccent)
                    .contentTransition(.numericText())
                    .animation(Motion.calm(reduceMotion, duration: 0.25), value: model.countdownText)
                Text(model.stage.title)
                    .font(Typography.caption(12))
                    .foregroundStyle(DesignTokens.onAccent.opacity(0.72))
            }
            ProgressView(value: model.timerProgress.fraction)
                .progressViewStyle(EditorialProgressViewStyle(
                    track: DesignTokens.onAccent.opacity(0.2),
                    fill: DesignTokens.onAccent,
                    height: 3
                ))
            Text(model.activeTask?.title ?? "No task selected")
                .font(Typography.bodyMedium(13))
                .foregroundStyle(DesignTokens.onAccent.opacity(model.activeTask == nil ? 0.65 : 0.95))
                .lineLimit(1)
            HStack(spacing: DesignTokens.s2) {
                Button {
                    model.toggleTimer()
                } label: {
                    Label(model.isTimerRunning ? "Pause" : "Start", systemImage: model.isTimerRunning ? "pause.fill" : "play.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(PanelPrimaryButtonStyle(background: DesignTokens.onAccent, foreground: stageColor))

                Button {
                    model.skipStage()
                } label: {
                    Image(systemName: "forward.end.fill")
                }
                .buttonStyle(PanelIconButtonStyle(foreground: DesignTokens.onAccent))
                .help("Skip and count this stage as completed")
            }
            Button("Open timer") { model.selectedSidebar = .timer }
                .buttonStyle(PanelQuietButtonStyle(foreground: DesignTokens.onAccent))
        }
        .padding(DesignTokens.s4)
        .background(
            RoundedRectangle(cornerRadius: DesignTokens.r3, style: .continuous)
                .fill(stageColor)
        )
        .animation(Motion.calm(reduceMotion, duration: 0.3), value: model.stage)
    }

    private var projectsPanel: some View {
        VStack(alignment: .leading, spacing: DesignTokens.s2) {
            HStack(alignment: .firstTextBaseline) {
                SectionHeading(overline: "Projects", title: "In motion")
                Spacer()
                Button("Manage") { model.selectedSidebar = .projects }
                    .buttonStyle(EditorialQuietButtonStyle())
            }
            Hairline()
            if model.activeProjects.isEmpty {
                Text("No active projects yet.")
                    .font(Typography.body(13))
                    .foregroundStyle(DesignTokens.inkSecondary)
                    .padding(.vertical, DesignTokens.s2)
                Button("Create a project") { model.presentNewProject() }
                    .buttonStyle(EditorialQuietButtonStyle())
            } else {
                ForEach(Array(model.activeProjects.prefix(4).enumerated()), id: \.element.id) { index, project in
                    projectRow(project)
                    if index < min(4, model.activeProjects.count) - 1 {
                        Hairline()
                    }
                }
            }
        }
    }

    private func projectRow(_ project: Project) -> some View {
        let progress = model.projectProgress(project.id)
        return Button {
            model.selectedSidebar = .tasks
            model.taskProjectFilter = project.id
            model.taskScope = .active
        } label: {
            HStack(spacing: DesignTokens.s2) {
                ProjectDot(hex: project.colorHex, size: 8)
                VStack(alignment: .leading, spacing: 4) {
                    Text(project.name)
                        .font(Typography.bodyMedium(13))
                        .foregroundStyle(DesignTokens.ink)
                        .lineLimit(1)
                    ProgressView(value: progress.fraction)
                        .progressViewStyle(EditorialProgressViewStyle(
                            fill: Color(hex: project.colorHex),
                            height: 3
                        ))
                }
                Spacer(minLength: DesignTokens.s2)
                Text("\(Int((progress.fraction * 100).rounded()))%")
                    .font(Typography.caption(11))
                    .monospacedDigit()
                    .foregroundStyle(DesignTokens.inkTertiary)
            }
            .padding(.vertical, 7)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var quickAddRow: some View {
        HStack(spacing: DesignTokens.s2) {
            Image(systemName: "plus")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(accent)
            TextField("Add a task for today…", text: $quickTaskTitle)
                .textFieldStyle(.plain)
                .font(Typography.body(14))
                .foregroundStyle(DesignTokens.ink)
                .onSubmit(addQuickTask)
            Text("↵")
                .font(Typography.overline(10))
                .foregroundStyle(DesignTokens.inkTertiary)
        }
        .padding(.vertical, 9)
        .overlay(alignment: .bottom) {
            Hairline()
        }
        .padding(.top, DesignTokens.s1)
    }

    private struct ProjectedRow {
        let task: PlanTask
        let start: Date
    }

    private var projectedRows: [ProjectedRow] {
        let estimate = model.todayPlanFinishEstimate
        return model.todayPlanTasks.map { task in
            ProjectedRow(task: task, start: estimate.taskStarts[task.id] ?? model.now)
        }
    }

    private func addQuickTask() {
        let title = quickTaskTitle
        guard !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        model.createTaskQuick(title: title)
        quickTaskTitle = ""
    }
}

// MARK: - Timeline row

private struct DashboardTaskRow: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.editorialAccent) private var accent
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let task: PlanTask
    let projectedStart: Date
    let isLast: Bool
    @State private var hovering = false

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            Text(projectedTime)
                .font(Typography.caption(11))
                .monospacedDigit()
                .foregroundStyle(DesignTokens.inkTertiary)
                .frame(width: 46, alignment: .trailing)
                .padding(.top, 7)

            VStack(spacing: 0) {
                Circle()
                    .fill(accent)
                    .frame(width: 6, height: 6)
                    .padding(.top, 10)
                if !isLast {
                    Rectangle()
                        .fill(DesignTokens.hairline)
                        .frame(width: 1, height: 24)
                }
            }
            .frame(width: 20)

            HStack(alignment: .top, spacing: DesignTokens.s2) {
                Button {
                    withAnimation(Motion.calm(reduceMotion, duration: 0.2)) {
                        model.toggleTaskCompletion(id: task.id)
                    }
                } label: {
                    EditorialCheckbox(isOn: task.isCompleted)
                }
                .buttonStyle(.plain)

                VStack(alignment: .leading, spacing: 4) {
                    Text(task.title)
                        .font(Typography.bodyMedium(15))
                        .foregroundStyle(task.isCompleted ? DesignTokens.inkTertiary : DesignTokens.ink)
                        .strikethrough(task.isCompleted)
                        .lineLimit(2)
                    HStack(spacing: DesignTokens.s2) {
                        if let project = model.project(id: task.projectID) {
                            HStack(spacing: 5) {
                                ProjectDot(hex: project.colorHex)
                                Text(project.name)
                            }
                            .font(Typography.caption(11))
                            .foregroundStyle(DesignTokens.inkSecondary)
                        }
                        if let due = task.dueDate {
                            Text(AppFormat.dueLabel(due, now: model.now, calendar: model.calendar))
                                .font(Typography.caption(11))
                                .foregroundStyle(
                                    task.isOverdue(now: model.now, calendar: model.calendar)
                                        ? DesignTokens.danger
                                        : DesignTokens.inkTertiary
                                )
                        }
                        if task.priority == .high {
                            Image(systemName: "exclamationmark")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundStyle(DesignTokens.warning)
                        }
                    }
                }

                Spacer(minLength: DesignTokens.s2)

                Text(task.displayProgress)
                    .font(Typography.caption(11))
                    .monospacedDigit()
                    .foregroundStyle(DesignTokens.inkTertiary)
                    .padding(.top, 3)

                Button {
                    withAnimation(Motion.calm(reduceMotion, duration: 0.2)) {
                        model.setFocusToday(id: task.id, value: !task.isFocusToday)
                    }
                } label: {
                    Image(systemName: task.isFocusToday ? "star.fill" : "star")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(task.isFocusToday ? accent : DesignTokens.inkTertiary)
                        .frame(width: 26, height: 26)
                }
                .buttonStyle(.plain)
                .help(task.isFocusToday ? "Remove from today's plan" : "Add to today's plan")

                Button {
                    model.presentEditTask(task)
                } label: {
                    Image(systemName: "pencil")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(DesignTokens.inkTertiary)
                        .frame(width: 26, height: 26)
                }
                .buttonStyle(.plain)
                .opacity(hovering ? 1 : 0)
                .help("Edit task")
            }
            .padding(.leading, DesignTokens.s2)
            .padding(.vertical, 6)
            .padding(.bottom, isLast ? 4 : 10)
        }
        .background(
            Rectangle().fill(hovering ? DesignTokens.surfaceMuted.opacity(0.4) : Color.clear)
        )
        .contentShape(Rectangle())
        .onHover { hovering = $0 }
        .animation(Motion.calm(reduceMotion, duration: 0.12), value: hovering)
    }

    private var projectedTime: String {
        AppFormat.clock(
            projectedStart,
            hourFormat: model.database.settings.appearance.hourFormat,
            calendar: model.calendar
        )
    }
}

// MARK: - Panel button styles

private struct PanelPrimaryButtonStyle: ButtonStyle {
    let background: Color
    let foreground: Color

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(Typography.bodyMedium(13))
            .foregroundStyle(foreground)
            .padding(.horizontal, DesignTokens.s3)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: DesignTokens.r1, style: .continuous)
                    .fill(background.opacity(configuration.isPressed ? 0.8 : 1))
            )
    }
}

private struct PanelIconButtonStyle: ButtonStyle {
    let foreground: Color

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(foreground.opacity(configuration.isPressed ? 0.6 : 0.9))
            .frame(width: 32, height: 32)
            .background(Circle().fill(foreground.opacity(0.12)))
    }
}

private struct PanelQuietButtonStyle: ButtonStyle {
    let foreground: Color

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(Typography.bodyMedium(12))
            .foregroundStyle(foreground.opacity(configuration.isPressed ? 0.6 : 0.8))
            .padding(.vertical, 2)
    }
}
