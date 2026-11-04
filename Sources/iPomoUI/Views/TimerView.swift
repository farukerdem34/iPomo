import iPomoCore
import SwiftUI

struct TimerView: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.editorialAccent) private var accent

    private var stageColor: Color {
        StagePalette.color(for: model.stage, accent: accent)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DesignTokens.s5) {
                header
                HStack(alignment: .top, spacing: DesignTokens.s6) {
                    timerStage
                        .frame(maxWidth: .infinity, alignment: .top)
                    sideColumn
                        .frame(width: 320)
                }
            }
            .editorialPagePadding()
        }
        .editorialBackground()
        .navigationTitle("Timer")
    }

    private var header: some View {
        HStack(alignment: .top, spacing: DesignTokens.s4) {
            PageTitle(
                eyebrow: "Focus session",
                title: "Timer",
                detail: "\(model.roundLabel) · \(model.longBreakIntervalLabel.lowercased())"
            )
            Spacer()
            Button("Reset cycle") { model.resetCycle() }
                .buttonStyle(EditorialQuietButtonStyle())
        }
    }

    private var timerStage: some View {
        VStack(spacing: DesignTokens.s4) {
            EditorialTabs(
                items: Stage.allCases,
                title: { $0.title },
                selection: Binding(
                    get: { model.stage },
                    set: { model.selectStage($0) }
                ),
                spacing: DesignTokens.s4
            )

            activeTaskMenu
                .frame(maxWidth: 420)

            timerRing
                .padding(.vertical, DesignTokens.s2)

            HStack(spacing: DesignTokens.s3) {
                Button {
                    model.toggleTimer()
                } label: {
                    Label(
                        model.isTimerRunning ? "Pause" : "Start",
                        systemImage: model.isTimerRunning ? "pause.fill" : "play.fill"
                    )
                    .frame(minWidth: 92)
                }
                .buttonStyle(EditorialFilledButtonStyle(
                    background: stageColor,
                    foreground: DesignTokens.onAccent,
                    horizontalPadding: DesignTokens.s4,
                    verticalPadding: 10
                ))

                Button {
                    model.skipStage()
                } label: {
                    Label("Skip", systemImage: "forward.end.fill")
                }
                .buttonStyle(EditorialSecondaryButtonStyle())
                .help("Skip and count this stage as completed")

                Button {
                    model.resetTimer()
                } label: {
                    Label("Reset", systemImage: "arrow.counterclockwise")
                }
                .buttonStyle(EditorialQuietButtonStyle())
            }

            HStack(spacing: DesignTokens.s3) {
                Text("Space")
                    .font(Typography.overline(9))
                    .tracking(0.6)
                    .foregroundStyle(DesignTokens.inkTertiary)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 2)
                    .overlay(
                        RoundedRectangle(cornerRadius: 4)
                            .strokeBorder(DesignTokens.hairline, lineWidth: 1)
                    )
                Text(model.isTimerRunning ? "Pause" : "Start")
                    .font(Typography.caption(11))
                    .foregroundStyle(DesignTokens.inkTertiary)
                if let finish = model.finishClockText {
                    Text("·")
                        .foregroundStyle(DesignTokens.inkTertiary)
                    Text(model.isTimerRunning ? "ends \(finish)" : "would end \(finish)")
                        .font(Typography.caption(11))
                        .foregroundStyle(DesignTokens.inkTertiary)
                }
            }
        }
        .frame(maxWidth: .infinity)
    }

    private var activeTaskMenu: some View {
        Menu {
            Button("No task") { model.requestTaskSelection(nil) }
            Divider()
            ForEach(model.activeTasks) { task in
                Button {
                    model.requestTaskSelection(task.id)
                } label: {
                    if task.id == model.activeTask?.id {
                        Label(task.title, systemImage: "checkmark")
                    } else {
                        Text(task.title)
                    }
                }
            }
        } label: {
            VStack(alignment: .leading, spacing: 5) {
                Overline(model.activeTask == nil ? "Attach task" : "Now focusing")
                HStack(spacing: DesignTokens.s2) {
                    if let task = model.activeTask {
                        if let project = model.project(id: task.projectID) {
                            ProjectDot(hex: project.colorHex, size: 8)
                        }
                        Text(task.title)
                            .font(Typography.bodyMedium(15))
                            .foregroundStyle(DesignTokens.ink)
                            .lineLimit(1)
                        Text(task.displayProgress)
                            .font(Typography.caption(11))
                            .monospacedDigit()
                            .foregroundStyle(DesignTokens.inkTertiary)
                    } else {
                        Text("Choose a task")
                            .font(Typography.bodyMedium(15))
                            .foregroundStyle(DesignTokens.inkSecondary)
                    }
                    Spacer(minLength: DesignTokens.s2)
                    Image(systemName: "chevron.down")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(DesignTokens.inkTertiary)
                }
                Hairline()
            }
            .frame(width: 390, alignment: .leading)
            .contentShape(Rectangle())
        }
        .menuStyle(.button)
        .buttonStyle(.plain)
        .menuIndicator(.hidden)
    }

    private var timerRing: some View {
        let fraction = min(1, max(0, model.timerProgress.fraction))
        let size: CGFloat = 330

        return ZStack {
            Circle()
                .fill(stageColor.opacity(0.045))
                .frame(width: size + 36, height: size + 36)

            TickRing()
                .frame(width: size + 60, height: size + 60)

            Circle()
                .stroke(DesignTokens.hairline, lineWidth: 7)
                .frame(width: size, height: size)

            Circle()
                .trim(from: 0, to: fraction)
                .stroke(
                    stageColor,
                    style: StrokeStyle(lineWidth: 7, lineCap: .round)
                )
                .frame(width: size, height: size)
                .rotationEffect(.degrees(-90))
                .animation(.easeInOut(duration: 0.25), value: fraction)

            VStack(spacing: DesignTokens.s1) {
                Overline(model.stage.title, color: stageColor)
                Text(model.countdownText)
                    .font(Typography.number(88))
                    .monospacedDigit()
                    .foregroundStyle(DesignTokens.ink)
                    .contentTransition(.numericText())
                Text(model.roundLabel)
                    .font(Typography.caption(11))
                    .foregroundStyle(DesignTokens.inkTertiary)
            }
        }
        .frame(width: size + 60, height: size + 60)
    }

    private var sideColumn: some View {
        VStack(alignment: .leading, spacing: DesignTokens.s4) {
            activeTaskPanel
            todayPanel
            upNextPanel
        }
    }

    private var activeTaskPanel: some View {
        VStack(alignment: .leading, spacing: DesignTokens.s2) {
            Overline("Active task")
            if let task = model.activeTask {
                Text(task.title)
                    .font(Typography.section(22))
                    .foregroundStyle(DesignTokens.ink)
                    .fixedSize(horizontal: false, vertical: true)
                HStack(spacing: DesignTokens.s2) {
                    if let project = model.project(id: task.projectID) {
                        ProjectDot(hex: project.colorHex)
                        Text(project.name)
                            .font(Typography.caption(11))
                            .foregroundStyle(DesignTokens.inkSecondary)
                    }
                    if let due = task.dueDate {
                        Text(AppFormat.dueLabel(due, now: model.now, calendar: model.calendar))
                            .font(Typography.caption(11))
                            .foregroundStyle(DesignTokens.inkTertiary)
                    }
                }
                ProgressView(value: task.progress)
                    .progressViewStyle(EditorialProgressViewStyle(
                        fill: accent,
                        height: 3
                    ))
                HStack {
                    Text("\(task.displayProgress) pomodoros")
                        .font(Typography.caption(11))
                        .foregroundStyle(DesignTokens.inkTertiary)
                    Spacer()
                    Button("Edit") { model.presentEditTask(task) }
                        .buttonStyle(EditorialQuietButtonStyle())
                    Button(task.isFocusToday ? "Unstar" : "Star") {
                        model.setFocusToday(id: task.id, value: !task.isFocusToday)
                    }
                    .buttonStyle(EditorialQuietButtonStyle())
                }
                if !task.notes.isEmpty {
                    Hairline()
                    Text(task.notes)
                        .font(Typography.body(12))
                        .foregroundStyle(DesignTokens.inkSecondary)
                        .lineLimit(4)
                        .padding(.top, 2)
                }
            } else {
                Text("No task selected. Choose one above to attach the session to a task.")
                    .font(Typography.body(13))
                    .foregroundStyle(DesignTokens.inkSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var todayPanel: some View {
        VStack(alignment: .leading, spacing: DesignTokens.s2) {
            Overline("Today")
            sideMetric("Focus", AppFormat.duration(seconds: model.todayFocusSeconds))
            Hairline()
            sideMetric("Rounds", "\(model.database.timer.focusRoundCount)")
            Hairline()
            sideMetric("Tasks done", "\(model.database.tasks.filter { $0.isCompleted && ($0.completedAt.map { model.calendar.isDate($0, inSameDayAs: model.now) } ?? false) }.count)")
        }
    }

    private var upNextPanel: some View {
        VStack(alignment: .leading, spacing: DesignTokens.s2) {
            Overline("Up next")
            let upcoming = model.activeTasks.filter { $0.id != model.activeTask?.id }.prefix(3)
            if upcoming.isEmpty {
                Text("No other open tasks.")
                    .font(Typography.body(12))
                    .foregroundStyle(DesignTokens.inkTertiary)
            } else {
                ForEach(Array(upcoming)) { task in
                    Button {
                        model.requestTaskSelection(task.id)
                    } label: {
                        HStack(spacing: DesignTokens.s2) {
                            Image(systemName: "play")
                                .font(.system(size: 9, weight: .semibold))
                                .foregroundStyle(accent)
                                .frame(width: 20, height: 20)
                                .background(Circle().fill(accent.opacity(0.1)))
                            Text(task.title)
                                .font(Typography.body(12))
                                .foregroundStyle(DesignTokens.ink)
                                .lineLimit(1)
                            Spacer(minLength: DesignTokens.s1)
                            Text(task.displayProgress)
                                .font(Typography.caption(10))
                                .monospacedDigit()
                                .foregroundStyle(DesignTokens.inkTertiary)
                        }
                        .padding(.vertical, 3)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func sideMetric(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label)
                .font(Typography.body(12))
                .foregroundStyle(DesignTokens.inkSecondary)
            Spacer()
            Text(value)
                .font(Typography.bodyMedium(13))
                .monospacedDigit()
                .foregroundStyle(DesignTokens.ink)
        }
        .padding(.vertical, 5)
    }
}

private struct TickRing: View {
    var body: some View {
        Canvas { context, size in
            let center = CGPoint(x: size.width / 2, y: size.height / 2)
            let radius = min(size.width, size.height) / 2 - 4
            for index in 0..<12 {
                let angle = Double(index) * .pi / 6 - .pi / 2
                let inner = CGPoint(
                    x: center.x + cos(angle) * (radius - (index % 3 == 0 ? 11 : 8)),
                    y: center.y + sin(angle) * (radius - (index % 3 == 0 ? 11 : 8))
                )
                let outer = CGPoint(
                    x: center.x + cos(angle) * radius,
                    y: center.y + sin(angle) * radius
                )
                var path = Path()
                path.move(to: inner)
                path.addLine(to: outer)
                context.stroke(
                    path,
                    with: .color(
                        index % 3 == 0
                            ? DesignTokens.inkTertiary.opacity(0.55)
                            : DesignTokens.hairline
                    ),
                    lineWidth: index % 3 == 0 ? 1.5 : 1
                )
            }
        }
    }
}
