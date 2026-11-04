import iPomoCore
import SwiftUI

struct EstimateStepper: View {
    @Binding var value: Double
    var range: ClosedRange<Double> = 0.1...99

    var body: some View {
        HStack(spacing: 6) {
            Button {
                let step = value > 1 ? 1.0 : 0.1
                value = max(range.lowerBound, rounded(value - step))
            } label: {
                Image(systemName: "minus")
                    .font(.system(size: 10, weight: .semibold))
            }
            .buttonStyle(StepperIconButtonStyle())
            .help("Decrease estimate")

            TextField(
                "",
                value: $value,
                format: .number.precision(.fractionLength(0...1))
            )
            .textFieldStyle(EditorialTextFieldStyle(font: Typography.number(16)))
            .frame(width: 64)
            .multilineTextAlignment(.center)
            .accessibilityLabel("Estimated pomodoros")
            .onChange(of: value) { _, newValue in
                value = min(range.upperBound, max(range.lowerBound, rounded(newValue)))
            }

            Button {
                let step = value >= 1 ? 1.0 : 0.1
                value = min(range.upperBound, rounded(value + step))
            } label: {
                Image(systemName: "plus")
                    .font(.system(size: 10, weight: .semibold))
            }
            .buttonStyle(StepperIconButtonStyle())
            .help("Increase estimate")
        }
    }

    private func rounded(_ value: Double) -> Double {
        (value * 10).rounded() / 10
    }
}

struct EditorialIntStepper: View {
    @Binding var value: Int
    var range: ClosedRange<Int>
    var step: Int = 1
    var textWidth: CGFloat = 64
    var label: String = "Value"

    var body: some View {
        HStack(spacing: 6) {
            Button {
                value = max(range.lowerBound, value - step)
            } label: {
                Image(systemName: "minus")
                    .font(.system(size: 10, weight: .semibold))
            }
            .buttonStyle(StepperIconButtonStyle())
            .help("Decrease \(label.lowercased())")

            TextField("", value: $value, format: .number)
                .textFieldStyle(EditorialTextFieldStyle(font: Typography.number(16)))
                .frame(width: textWidth)
                .multilineTextAlignment(.center)
                .accessibilityLabel(label)
                .onChange(of: value) { _, newValue in
                    value = min(range.upperBound, max(range.lowerBound, newValue))
                }

            Button {
                value = min(range.upperBound, value + step)
            } label: {
                Image(systemName: "plus")
                    .font(.system(size: 10, weight: .semibold))
            }
            .buttonStyle(StepperIconButtonStyle())
            .help("Increase \(label.lowercased())")
        }
    }
}

struct StepperIconButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(DesignTokens.inkSecondary)
            .frame(width: 28, height: 28)
            .background(
                Circle().fill(configuration.isPressed ? DesignTokens.surfaceMuted : Color.clear)
            )
            .overlay(
                Circle().strokeBorder(DesignTokens.hairline, lineWidth: 1)
            )
            .contentShape(Circle())
    }
}
