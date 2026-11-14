import AppKit
import iPomoCore
import SwiftUI

// MARK: - Palette

extension NSColor {
    convenience init(hex: UInt32) {
        self.init(
            srgbRed: CGFloat((hex >> 16) & 0xFF) / 255,
            green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255,
            alpha: 1
        )
    }
}


extension NSColor {
    convenience init(hexString: String) {
        let cleaned = hexString.trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "#", with: "")
        var value: UInt64 = 0
        Scanner(string: cleaned).scanHexInt64(&value)
        self.init(hex: UInt32(value))
    }
}

extension Color {
    static func dynamic(light: UInt32, dark: UInt32) -> Color {
        Color(nsColor: NSColor(name: nil) { appearance in
            let isDark = appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            return NSColor(hex: isDark ? dark : light)
        })
    }

    static func dynamic(lightHex: String, darkHex: String) -> Color {
        Color(nsColor: NSColor(name: nil) { appearance in
            let isDark = appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            let hex = isDark ? darkHex : lightHex
            let cleaned = hex.replacingOccurrences(of: "#", with: "")
            var value: UInt64 = 0
            Scanner(string: cleaned).scanHexInt64(&value)
            return NSColor(hex: UInt32(value))
        })
    }
}

enum DesignTokens {
    // Surfaces and inks are resolved from the active theme palette. Colors are
    // dynamic so they follow system dark/light changes at draw time.
    static var canvas: Color { Self.dynamicColor { $0.canvas } }
    static var sidebar: Color { Self.dynamicColor { $0.sidebar } }
    static var surface: Color { Self.dynamicColor { $0.surface } }
    static var surfaceMuted: Color { Self.dynamicColor { $0.surfaceMuted } }
    static var ink: Color { Self.dynamicColor { $0.ink } }
    static var inkSecondary: Color { Self.dynamicColor { $0.inkSecondary } }
    static var inkTertiary: Color { Self.dynamicColor { $0.inkTertiary } }
    static var hairline: Color { Self.dynamicColor { $0.hairline } }

    static var accent: Color { Self.dynamicColor { $0.accent } }
    static var onAccent: Color { Self.dynamicColor { $0.onAccent } }
    static var switchKnob: Color { Self.dynamicColor { $0.switchKnob } }
    static var sage: Color { Self.dynamicColor { $0.sage } }
    static var slate: Color { Self.dynamicColor { $0.slate } }
    static var success: Color { Self.dynamicColor { $0.success } }
    static var warning: Color { Self.dynamicColor { $0.warning } }
    static var danger: Color { Self.dynamicColor { $0.danger } }

    private static func dynamicColor(_ key: @escaping (ThemePalette) -> String) -> Color {
        Color(nsColor: NSColor(name: nil) { appearance in
            NSColor(hexString: key(ThemeManager.shared.palette(for: appearance)))
        })
    }

    // 8pt grid
    static let s1: CGFloat = 4
    static let s2: CGFloat = 8
    static let s3: CGFloat = 16
    static let s4: CGFloat = 24
    static let s5: CGFloat = 32
    static let s6: CGFloat = 48

    static let r1: CGFloat = 6
    static let r2: CGFloat = 8
    static let r3: CGFloat = 12

    static let sidebarWidth: CGFloat = 232
    static let contentMaxWidth: CGFloat = 1_120
}

private struct EditorialAccentKey: EnvironmentKey {
    static let defaultValue = DesignTokens.accent
}

extension EnvironmentValues {
    var editorialAccent: Color {
        get { self[EditorialAccentKey.self] }
        set { self[EditorialAccentKey.self] = newValue }
    }
}

enum StagePalette {
    static func color(for stage: Stage, accent: Color) -> Color {
        switch stage {
        case .focus: return accent
        case .shortBreak: return DesignTokens.sage
        case .longBreak: return DesignTokens.slate
        }
    }
}

enum Motion {
    /// Calm, quick UI motion; returns nil when Reduce Motion is enabled.
    static func calm(_ reduceMotion: Bool, duration: Double = 0.2) -> Animation? {
        reduceMotion ? nil : .smooth(duration: duration)
    }
}

// MARK: - Typography

enum Typography {
    static func display(_ size: CGFloat = 40) -> Font {
        .system(size: size, weight: .semibold, design: .serif)
    }

    static func title(_ size: CGFloat = 26) -> Font {
        .system(size: size, weight: .semibold, design: .serif)
    }

    static func section(_ size: CGFloat = 21) -> Font {
        .system(size: size, weight: .semibold, design: .serif)
    }

    static func number(_ size: CGFloat) -> Font {
        .system(size: size, weight: .medium, design: .serif)
    }

    static func heading(_ size: CGFloat = 16) -> Font {
        .system(size: size, weight: .semibold)
    }

    static func body(_ size: CGFloat = 14) -> Font {
        .system(size: size, weight: .regular)
    }

    static func bodyMedium(_ size: CGFloat = 14) -> Font {
        .system(size: size, weight: .medium)
    }

    static func caption(_ size: CGFloat = 12) -> Font {
        .system(size: size, weight: .regular)
    }

    static func overline(_ size: CGFloat = 10) -> Font {
        .system(size: size, weight: .semibold)
    }
}

// MARK: - Small components

struct Overline: View {
    let text: String
    var color: Color = DesignTokens.inkTertiary

    init(_ text: String, color: Color = DesignTokens.inkTertiary) {
        self.text = text
        self.color = color
    }

    var body: some View {
        Text(text.uppercased())
            .font(Typography.overline())
            .tracking(1.1)
            .foregroundStyle(color)
    }
}

struct Hairline: View {
    var color: Color = DesignTokens.hairline

    var body: some View {
        Rectangle()
            .fill(color)
            .frame(height: 1)
    }
}

struct PomoMark: View {
    var size: CGFloat = 22
    @Environment(\.editorialAccent) private var accent

    var body: some View {
        ZStack {
            Circle()
                .stroke(accent.opacity(0.25), lineWidth: 1.4)
            Circle()
                .trim(from: 0.08, to: 0.78)
                .stroke(accent, style: StrokeStyle(lineWidth: 2, lineCap: .round))
                .rotationEffect(.degrees(-90))
            Circle()
                .fill(accent)
                .frame(width: size * 0.12, height: size * 0.12)
                .offset(y: -size * 0.29)
        }
        .frame(width: size, height: size)
    }
}

struct ProjectDot: View {
    let hex: String
    var size: CGFloat = 7

    var body: some View {
        Circle()
            .fill(Color(hex: hex))
            .frame(width: size, height: size)
    }
}

struct EditorialTag: View {
    let text: String
    var color: Color = DesignTokens.inkTertiary

    var body: some View {
        Text(text.uppercased())
            .font(Typography.overline(9))
            .tracking(0.7)
            .foregroundStyle(color)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .fill(color.opacity(0.1))
            )
    }
}

struct PageTitle: View {
    let eyebrow: String
    let title: String
    var detail: String?

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.s2) {
            Overline(eyebrow)
            Text(title)
                .font(Typography.display(38))
                .foregroundStyle(DesignTokens.ink)
                .fixedSize(horizontal: false, vertical: true)
            if let detail {
                Text(detail)
                    .font(Typography.body(14))
                    .foregroundStyle(DesignTokens.inkSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

struct LedgerMetric: Identifiable {
    let id = UUID()
    let label: String
    let value: String
    var detail: String = ""
}

struct MetricLedger: View {
    let metrics: [LedgerMetric]
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            ForEach(Array(metrics.enumerated()), id: \.element.id) { index, metric in
                VStack(alignment: .leading, spacing: 6) {
                    Text(metric.value)
                        .font(Typography.number(28))
                        .monospacedDigit()
                        .foregroundStyle(DesignTokens.ink)
                        .contentTransition(.numericText())
                    Overline(metric.label)
                    if !metric.detail.isEmpty {
                        Text(metric.detail)
                            .font(Typography.caption(11))
                            .foregroundStyle(DesignTokens.inkTertiary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .animation(Motion.calm(reduceMotion, duration: 0.3), value: metric.value)

                if index < metrics.count - 1 {
                    Rectangle()
                        .fill(DesignTokens.hairline)
                        .frame(width: 1, height: 42)
                        .padding(.horizontal, DesignTokens.s4)
                }
            }
        }
        .padding(.vertical, DesignTokens.s2)
    }
}

struct SectionHeading: View {
    let overline: String
    let title: String
    var detail: String?

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.s1) {
            Overline(overline)
            Text(title)
                .font(Typography.section(22))
                .foregroundStyle(DesignTokens.ink)
            if let detail {
                Text(detail)
                    .font(Typography.caption(12))
                    .foregroundStyle(DesignTokens.inkTertiary)
                    .padding(.bottom, DesignTokens.s2)
            }
        }
    }
}

struct EditorialEmptyState: View {
    let overline: String
    let title: String
    let message: String
    var actionTitle: String?
    var action: (() -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.s2) {
            Overline(overline)
            Text(title)
                .font(Typography.section(24))
                .foregroundStyle(DesignTokens.ink)
            Text(message)
                .font(Typography.body(14))
                .foregroundStyle(DesignTokens.inkSecondary)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: 440, alignment: .leading)
            if let actionTitle, let action {
                Button(actionTitle, action: action)
                    .buttonStyle(EditorialPrimaryButtonStyle())
                    .padding(.top, DesignTokens.s1)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, DesignTokens.s5)
    }
}

struct EditorialCheckbox: View {
    let isOn: Bool
    /// Hit-area side; the 20pt mark stays centered inside it. Dense list rows
    /// use a smaller target than the default 40pt.
    var hitSize: CGFloat = 40
    @Environment(\.editorialAccent) private var accent
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            Circle()
                .fill(accent)
                .opacity(isOn ? 1 : 0)
            Circle()
                .strokeBorder(DesignTokens.inkTertiary.opacity(0.55), lineWidth: 1.5)
                .opacity(isOn ? 0 : 1)
            Image(systemName: "checkmark")
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(DesignTokens.onAccent)
                .scaleEffect(isOn ? 1 : 0.5)
                .opacity(isOn ? 1 : 0)
        }
        .frame(width: 20, height: 20)
        .frame(width: hitSize, height: hitSize)
        .contentShape(Rectangle())
        .animation(Motion.calm(reduceMotion, duration: 0.15), value: isOn)
    }
}

struct EditorialTabs<Item: Hashable & Identifiable>: View {
    let items: [Item]
    let title: (Item) -> String
    @Binding var selection: Item
    var spacing: CGFloat = DesignTokens.s4

    @Environment(\.editorialAccent) private var accent
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Namespace private var underline

    var body: some View {
        HStack(alignment: .bottom, spacing: spacing) {
            ForEach(items) { item in
                Button {
                    selection = item
                } label: {
                    Text(title(item))
                        .font(Typography.bodyMedium(13))
                        .foregroundStyle(selection == item ? DesignTokens.ink : DesignTokens.inkSecondary)
                        .padding(.bottom, 8)
                        .overlay(alignment: .bottom) {
                            if selection == item {
                                Rectangle()
                                    .fill(accent)
                                    .frame(height: 2)
                                    .matchedGeometryEffect(id: "underline", in: underline)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .frame(maxWidth: .infinity)
            }
        }
        .animation(Motion.calm(reduceMotion), value: selection)
    }
}

struct EditorialProgressViewStyle: ProgressViewStyle {
    var track: Color = DesignTokens.hairline
    var fill: Color = DesignTokens.accent
    var height: CGFloat = 3

    func makeBody(configuration: Configuration) -> some View {
        EditorialProgressBar(
            fraction: min(1, max(0, configuration.fractionCompleted ?? 0)),
            track: track,
            fill: fill,
            height: height
        )
    }
}

private struct EditorialProgressBar: View {
    let fraction: Double
    let track: Color
    let fill: Color
    let height: CGFloat
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule(style: .continuous)
                    .fill(track)
                Capsule(style: .continuous)
                    .fill(fill)
                    .frame(width: proxy.size.width * fraction)
            }
            .animation(Motion.calm(reduceMotion, duration: 0.4), value: fraction)
        }
        .frame(height: height)
    }
}

// MARK: - Buttons

struct EditorialPrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        EditorialPrimaryButtonBody(configuration: configuration)
    }

    private struct EditorialPrimaryButtonBody: View {
        @Environment(\.editorialAccent) private var accent
        @Environment(\.isEnabled) private var isEnabled
        let configuration: ButtonStyle.Configuration

        var body: some View {
            configuration.label
                .font(Typography.bodyMedium(14))
                .foregroundStyle(DesignTokens.onAccent)
                .padding(.horizontal, DesignTokens.s3)
                .padding(.vertical, 9)
                .background(
                    RoundedRectangle(cornerRadius: DesignTokens.r2, style: .continuous)
                        .fill(accent.opacity(configuration.isPressed ? 0.82 : 1))
                )
                .contentShape(Rectangle())
                .opacity(isEnabled ? 1 : 0.4)
        }
    }
}

struct EditorialFilledButtonStyle: ButtonStyle {
    let background: Color
    let foreground: Color
    var horizontalPadding: CGFloat = DesignTokens.s3
    var verticalPadding: CGFloat = 9

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(Typography.bodyMedium(14))
            .foregroundStyle(foreground)
            .padding(.horizontal, horizontalPadding)
            .padding(.vertical, verticalPadding)
            .background(
                RoundedRectangle(cornerRadius: DesignTokens.r2, style: .continuous)
                    .fill(background.opacity(configuration.isPressed ? 0.82 : 1))
            )
            .contentShape(Rectangle())
    }
}

struct EditorialSecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(Typography.bodyMedium(14))
            .foregroundStyle(DesignTokens.ink)
            .padding(.horizontal, DesignTokens.s3)
            .padding(.vertical, 9)
            .background(
                RoundedRectangle(cornerRadius: DesignTokens.r2, style: .continuous)
                    .fill(configuration.isPressed ? DesignTokens.surfaceMuted : Color.clear)
            )
            .overlay(
                RoundedRectangle(cornerRadius: DesignTokens.r2, style: .continuous)
                    .strokeBorder(DesignTokens.hairline, lineWidth: 1)
            )
            .contentShape(Rectangle())
    }
}

struct EditorialDangerButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(Typography.bodyMedium(14))
            .foregroundStyle(DesignTokens.danger)
            .padding(.horizontal, DesignTokens.s3)
            .padding(.vertical, 9)
            .background(
                RoundedRectangle(cornerRadius: DesignTokens.r2, style: .continuous)
                    .fill(configuration.isPressed ? DesignTokens.danger.opacity(0.08) : Color.clear)
            )
            .overlay(
                RoundedRectangle(cornerRadius: DesignTokens.r2, style: .continuous)
                    .strokeBorder(DesignTokens.danger.opacity(0.35), lineWidth: 1)
            )
            .contentShape(Rectangle())
    }
}

struct EditorialQuietButtonStyle: ButtonStyle {
    @Environment(\.editorialAccent) private var accent

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(Typography.bodyMedium(13))
            .foregroundStyle(accent.opacity(configuration.isPressed ? 0.6 : 1))
            .padding(.horizontal, DesignTokens.s2)
            .padding(.vertical, 6)
            .contentShape(Rectangle())
    }
}

struct EditorialIconButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(configuration.isPressed ? DesignTokens.ink : DesignTokens.inkSecondary)
            .frame(width: 28, height: 28)
            .background(
                Circle().fill(configuration.isPressed ? DesignTokens.surfaceMuted : Color.clear)
            )
            .contentShape(Circle())
    }
}

// MARK: - Fields

struct EditorialTextFieldStyle: TextFieldStyle {
    var font: Font = Typography.body(14)

    func _body(configuration: TextField<Self._Label>) -> some View {
        configuration
            .textFieldStyle(.plain)
            .font(font)
            .foregroundStyle(DesignTokens.ink)
            .padding(.horizontal, 12)
            .padding(.vertical, 9)
            .background(
                RoundedRectangle(cornerRadius: DesignTokens.r2, style: .continuous)
                    .fill(DesignTokens.surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: DesignTokens.r2, style: .continuous)
                    .strokeBorder(DesignTokens.hairline, lineWidth: 1)
            )
    }
}

struct EditorialDateField: View {
    @Binding var date: Date
    var components: DatePickerComponents = [.date]
    var hourFormat: HourFormat = .twelve
    var width: CGFloat = 0

    @State private var isShowingPicker = false
    @Environment(\.editorialAccent) private var accent

    private var includesTime: Bool { components.contains(.hourAndMinute) }
    private var resolvedWidth: CGFloat { width > 0 ? width : (includesTime ? 250 : 190) }

    private var formattedDate: String {
        let formatter = DateFormatter()
        formatter.locale = .current
        let template: String
        if includesTime {
            template = hourFormat == .twentyFour ? "yMMMd HH:mm" : "yMMMd h:mm a"
        } else {
            template = "yMMMd"
        }
        formatter.setLocalizedDateFormatFromTemplate(template)
        return formatter.string(from: date)
    }

    var body: some View {
        Button {
            isShowingPicker.toggle()
        } label: {
            HStack(spacing: DesignTokens.s2) {
                Text(formattedDate)
                    .font(Typography.body(14))
                    .foregroundStyle(DesignTokens.ink)
                    .lineLimit(1)
                Spacer(minLength: 0)
                Image(systemName: "calendar")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(DesignTokens.inkTertiary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 9)
            .frame(width: resolvedWidth)
            .background(
                RoundedRectangle(cornerRadius: DesignTokens.r2, style: .continuous)
                    .fill(DesignTokens.surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: DesignTokens.r2, style: .continuous)
                    .strokeBorder(DesignTokens.hairline, lineWidth: 1)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(includesTime ? "Date and time" : "Date")
        .popover(isPresented: $isShowingPicker) {
            VStack(alignment: .leading, spacing: DesignTokens.s3) {
                DatePicker("", selection: $date, displayedComponents: [.date])
                    .datePickerStyle(.graphical)
                    .labelsHidden()
                    .tint(accent)

                if includesTime {
                    Hairline()
                    DatePicker("Time", selection: $date, displayedComponents: [.hourAndMinute])
                        .datePickerStyle(.stepperField)
                        .font(Typography.body(12))
                        .tint(accent)
                }

                HStack {
                    Spacer()
                    Button("Done") { isShowingPicker = false }
                        .buttonStyle(EditorialPrimaryButtonStyle())
                }
            }
            .padding(DesignTokens.s3)
            .frame(width: 320)
            .background(DesignTokens.canvas)
        }
    }
}

struct EditorialToggleStyle: ToggleStyle {
    @Environment(\.editorialAccent) private var accent
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        Button {
            withAnimation(Motion.calm(reduceMotion, duration: 0.15)) {
                configuration.isOn.toggle()
            }
        } label: {
            Capsule(style: .continuous)
                .fill(configuration.isOn ? accent : DesignTokens.surfaceMuted)
                .frame(width: 40, height: 22)
                .overlay(alignment: configuration.isOn ? .trailing : .leading) {
                    Circle()
                        .fill(configuration.isOn ? DesignTokens.onAccent : DesignTokens.switchKnob)
                        .frame(width: 18, height: 18)
                        .padding(2)
                        .shadow(color: .black.opacity(0.12), radius: 1, y: 0.5)
                }
                .overlay(
                    Capsule(style: .continuous)
                        .strokeBorder(
                            configuration.isOn ? Color.clear : DesignTokens.hairline,
                            lineWidth: 1
                        )
                )
        }
        .buttonStyle(.plain)
    }
}

struct EditorialToggleRow: View {
    let title: String
    var detail: String?
    @Binding var isOn: Bool

    var body: some View {
        HStack(alignment: .top, spacing: DesignTokens.s3) {
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(Typography.bodyMedium(14))
                    .foregroundStyle(DesignTokens.ink)
                if let detail {
                    Text(detail)
                        .font(Typography.caption(11))
                        .foregroundStyle(DesignTokens.inkSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            Spacer(minLength: DesignTokens.s3)
            Toggle("", isOn: $isOn)
                .labelsHidden()
                .toggleStyle(EditorialToggleStyle())
                .accessibilityLabel(title)
        }
        .padding(.vertical, DesignTokens.s2)
    }
}

// MARK: - Page helpers

extension View {
    func editorialPagePadding() -> some View {
        padding(.horizontal, DesignTokens.s5)
            .padding(.vertical, DesignTokens.s4)
            .frame(maxWidth: DesignTokens.contentMaxWidth, alignment: .leading)
    }

    func editorialBackground() -> some View {
        background(DesignTokens.canvas.ignoresSafeArea())
    }
}
