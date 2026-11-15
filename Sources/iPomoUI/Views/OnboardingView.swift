import iPomoCore
import SwiftUI

struct OnboardingView: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.editorialAccent) private var accent
    @State private var step = 0

    private let stepCount = 5

    var body: some View {
        ZStack {
            DesignTokens.canvas.ignoresSafeArea()
            VStack(spacing: DesignTokens.s5) {
                progress
                content
                    .frame(maxWidth: 560)
                controls
            }
            .padding(DesignTokens.s6)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var progress: some View {
        HStack(spacing: DesignTokens.s2) {
            ForEach(0..<stepCount, id: \.self) { index in
                Capsule()
                    .fill(index <= step ? accent : DesignTokens.hairline)
                    .frame(height: 4)
            }
        }
        .frame(maxWidth: 320)
    }

    @ViewBuilder
    private var content: some View {
        switch step {
        case 0:
            welcome
        case 1:
            timerStep
        case 2:
            appearanceStep
        case 3:
            notificationsStep
        default:
            finishStep
        }
    }

    private var welcome: some View {
        VStack(spacing: DesignTokens.s3) {
            Text("Welcome to iPomo")
                .font(Typography.display(34))
                .foregroundStyle(DesignTokens.ink)
            Text("A calm, local-first focus timer and planner. Let's set a few things up before you begin.")
                .font(Typography.body(16))
                .foregroundStyle(DesignTokens.inkSecondary)
                .multilineTextAlignment(.center)
            VStack(alignment: .leading, spacing: DesignTokens.s2) {
                feature("timer", "Focus, short break, and long break stages with a menu-bar countdown.")
                feature("checklist", "Tasks, projects, and a Today plan that estimates your day.")
                feature("chart.bar.xaxis", "Reports and streaks, all stored on your Mac.")
            }
            .padding(.top, DesignTokens.s3)
        }
    }

    private func feature(_ icon: String, _ text: String) -> some View {
        HStack(spacing: DesignTokens.s2) {
            Image(systemName: icon)
                .foregroundStyle(accent)
                .frame(width: 20)
            Text(text)
                .font(Typography.body(14))
                .foregroundStyle(DesignTokens.inkSecondary)
        }
    }

    private var timerStep: some View {
        VStack(spacing: DesignTokens.s4) {
            Text("Timer durations")
                .font(Typography.title(24))
                .foregroundStyle(DesignTokens.ink)
            Text("Adjust the lengths of each stage. You can change these later in Settings.")
                .font(Typography.body(14))
                .foregroundStyle(DesignTokens.inkSecondary)
                .multilineTextAlignment(.center)

            VStack(spacing: DesignTokens.s3) {
                durationRow("Focus", binding: model.binding(\.timer.focusMinutes), range: 1...90)
                durationRow("Short break", binding: model.binding(\.timer.shortBreakMinutes), range: 0...30)
                durationRow("Long break", binding: model.binding(\.timer.longBreakMinutes), range: 0...60)
                HStack {
                    Text("Long break every")
                        .font(Typography.body(14))
                        .foregroundStyle(DesignTokens.ink)
                    Spacer()
                    Stepper(value: model.binding(\.timer.longBreakInterval), in: 1...12) {
                        Text("\(model.database.settings.timer.longBreakInterval) focus rounds")
                            .font(Typography.body(14))
                            .foregroundStyle(DesignTokens.inkSecondary)
                    }
                }
            }
            .padding(DesignTokens.s4)
            .background(DesignTokens.surface)
            .clipShape(RoundedRectangle(cornerRadius: DesignTokens.r2, style: .continuous))
        }
    }

    private func durationRow(_ label: String, binding: Binding<Double>, range: ClosedRange<Double>) -> some View {
        HStack {
            Text(label)
                .font(Typography.body(14))
                .foregroundStyle(DesignTokens.ink)
            Spacer()
            Text("\(Int(binding.wrappedValue)) min")
                .font(Typography.bodyMedium(14))
                .foregroundStyle(DesignTokens.inkSecondary)
                .frame(width: 64, alignment: .trailing)
            Slider(value: binding, in: range, step: 1)
                .frame(width: 160)
        }
    }

    private var appearanceStep: some View {
        VStack(spacing: DesignTokens.s4) {
            Text("Appearance")
                .font(Typography.title(24))
                .foregroundStyle(DesignTokens.ink)
            Text("Pick an accent color and how your week starts.")
                .font(Typography.body(14))
                .foregroundStyle(DesignTokens.inkSecondary)
                .multilineTextAlignment(.center)

            VStack(spacing: DesignTokens.s3) {
                Text("Accent")
                    .font(Typography.bodyMedium(14))
                    .foregroundStyle(DesignTokens.ink)
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: DesignTokens.s2), count: 4), spacing: DesignTokens.s2) {
                    ForEach(AppTheme.allCases.filter { $0 != .custom }) { theme in
                        Button {
                            model.updateSettings { $0.appearance.theme = theme }
                        } label: {
                            HStack {
                                Circle()
                                    .fill(ThemeColors.accent(theme))
                                    .frame(width: 14, height: 14)
                                Text(theme.title)
                                    .font(Typography.caption(12))
                                    .foregroundStyle(DesignTokens.ink)
                            }
                            .padding(.horizontal, DesignTokens.s2)
                            .padding(.vertical, 6)
                            .background(
                                RoundedRectangle(cornerRadius: DesignTokens.r1, style: .continuous)
                                    .fill(model.database.settings.appearance.theme == theme ? accent.opacity(0.12) : DesignTokens.surfaceMuted)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }

                Picker("Week starts", selection: model.binding(\.appearance.weekStart)) {
                    ForEach(WeekStart.allCases, id: \.self) { start in
                        Text(start.title).tag(start)
                    }
                }
                .pickerStyle(.segmented)
            }
            .padding(DesignTokens.s4)
            .background(DesignTokens.surface)
            .clipShape(RoundedRectangle(cornerRadius: DesignTokens.r2, style: .continuous))
        }
    }

    private var notificationsStep: some View {
        VStack(spacing: DesignTokens.s4) {
            Text("Notifications")
                .font(Typography.title(24))
                .foregroundStyle(DesignTokens.ink)
            Text("Get a banner and sound when a round ends. You can enable this later.")
                .font(Typography.body(14))
                .foregroundStyle(DesignTokens.inkSecondary)
                .multilineTextAlignment(.center)

            VStack(spacing: DesignTokens.s3) {
                Toggle("Enable notifications", isOn: model.binding(\.notifications.notificationsEnabled))
                    .toggleStyle(.switch)
                if model.database.settings.notifications.notificationsEnabled {
                    Button("Request permission") {
                        model.notifications.requestAuthorization()
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(accent)
                }
            }
            .padding(DesignTokens.s4)
            .background(DesignTokens.surface)
            .clipShape(RoundedRectangle(cornerRadius: DesignTokens.r2, style: .continuous))
        }
    }

    private var finishStep: some View {
        VStack(spacing: DesignTokens.s3) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 48))
                .foregroundStyle(accent)
            Text("You're ready")
                .font(Typography.title(24))
                .foregroundStyle(DesignTokens.ink)
            Text("Add your first task from Today, start a focus round, and let iPomo keep the count.")
                .font(Typography.body(14))
                .foregroundStyle(DesignTokens.inkSecondary)
                .multilineTextAlignment(.center)
        }
    }

    private var controls: some View {
        HStack {
            Button("Skip") {
                model.skipOnboarding()
            }
            .buttonStyle(.plain)
            .foregroundStyle(DesignTokens.inkTertiary)

            Spacer()

            if step > 0 {
                Button("Back") {
                    step -= 1
                }
                .buttonStyle(.bordered)
            }

            Button(step == stepCount - 1 ? "Get started" : "Next") {
                if step == stepCount - 1 {
                    model.completeOnboarding()
                } else {
                    step += 1
                }
            }
            .buttonStyle(.borderedProminent)
            .tint(accent)
        }
        .frame(maxWidth: 560)
    }
}
