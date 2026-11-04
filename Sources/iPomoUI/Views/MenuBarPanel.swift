import AppKit
import iPomoCore
import SwiftUI

struct MenuBarPanel: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.openWindow) private var openWindow
    @Environment(\.editorialAccent) private var accent
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var stageColor: Color {
        StagePalette.color(for: model.stage, accent: accent)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.s3) {
            HStack {
                Overline(model.stage.title, color: stageColor)
                Spacer()
                Text(model.roundLabel)
                    .font(Typography.overline(9))
                    .foregroundStyle(DesignTokens.inkTertiary)
            }

            Text(model.countdownText)
                .font(Typography.number(42))
                .monospacedDigit()
                .foregroundStyle(DesignTokens.ink)
                .contentTransition(.numericText())
                .animation(Motion.calm(reduceMotion, duration: 0.25), value: model.countdownText)

            ProgressView(value: model.timerProgress.fraction)
                .progressViewStyle(EditorialProgressViewStyle(
                    fill: stageColor,
                    height: 3
                ))

            HStack(spacing: 6) {
                Image(systemName: "scope")
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(DesignTokens.inkTertiary)
                Text(model.activeTask?.title ?? "No active task")
                    .font(Typography.body(12))
                    .foregroundStyle(model.activeTask == nil ? DesignTokens.inkTertiary : DesignTokens.ink)
                    .lineLimit(1)
            }

            HStack(spacing: DesignTokens.s2) {
                Button {
                    model.toggleTimer()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: model.isTimerRunning ? "pause.fill" : "play.fill")
                            .contentTransition(.symbolEffect(.replace))
                            .symbolEffectsRemoved(reduceMotion)
                        Text(model.isTimerRunning ? "Pause" : "Start")
                    }
                    .frame(maxWidth: .infinity)
                    .animation(Motion.calm(reduceMotion), value: model.isTimerRunning)
                }
                .buttonStyle(EditorialFilledButtonStyle(
                    background: stageColor,
                    foreground: DesignTokens.onAccent,
                    verticalPadding: 8
                ))

                Button {
                    model.skipStage()
                } label: {
                    Image(systemName: "forward.end.fill")
                }
                .buttonStyle(MenuIconButtonStyle())
                .help("Skip and count this stage as completed")

                Button {
                    model.resetTimer()
                } label: {
                    Image(systemName: "arrow.counterclockwise")
                }
                .buttonStyle(MenuIconButtonStyle())
            }

            Hairline()

            HStack {
                Label("\(AppFormat.duration(seconds: model.todayFocusSeconds)) today", systemImage: "timer")
                Spacer()
                Label("\(model.activeTasks.count) open", systemImage: "checklist")
            }
            .font(Typography.caption(10))
            .foregroundStyle(DesignTokens.inkTertiary)

            HStack {
                Button("Open iPomo") {
                    openWindow(id: "main")
                    NSApp.activate(ignoringOtherApps: true)
                }
                .buttonStyle(EditorialQuietButtonStyle())
                Spacer()
                Button("Quit") {
                    NSApplication.shared.terminate(nil)
                }
                .buttonStyle(EditorialQuietButtonStyle())
            }
        }
        .padding(DesignTokens.s3)
        .frame(width: 306)
        .background(DesignTokens.canvas)
    }
}

private struct MenuIconButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(DesignTokens.inkSecondary)
            .frame(width: 32, height: 32)
            .background(
                Circle()
                    .fill(configuration.isPressed ? DesignTokens.surfaceMuted : Color.clear)
            )
            .overlay(
                Circle().strokeBorder(DesignTokens.hairline, lineWidth: 1)
            )
            .contentShape(Circle())
    }
}
