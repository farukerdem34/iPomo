import Foundation

// MARK: - Theme palette

/// A full color palette for one appearance (light or dark) of a theme.
/// Stored as hex strings so themes are Codable, Sendable, and portable.
public struct ThemePalette: Codable, Sendable, Equatable, Hashable {
    public var canvas: String
    public var sidebar: String
    public var surface: String
    public var surfaceMuted: String
    public var ink: String
    public var inkSecondary: String
    public var inkTertiary: String
    public var hairline: String
    public var accent: String
    public var onAccent: String
    public var switchKnob: String
    public var sage: String
    public var slate: String
    public var success: String
    public var warning: String
    public var danger: String

    public init(
        canvas: String = "#F5F0E7",
        sidebar: String = "#EFE8DC",
        surface: String = "#FBF7F0",
        surfaceMuted: String = "#ECE4D7",
        ink: String = "#211C17",
        inkSecondary: String = "#6D6458",
        inkTertiary: String = "#9B8F7F",
        hairline: String = "#DCD2C3",
        accent: String = "#B85C43",
        onAccent: String = "#FFF9F2",
        switchKnob: String = "#FFFDF8",
        sage: String = "#6E7F5E",
        slate: String = "#596A78",
        success: String = "#5F7A50",
        warning: String = "#A9762F",
        danger: String = "#A8433A"
    ) {
        self.canvas = canvas
        self.sidebar = sidebar
        self.surface = surface
        self.surfaceMuted = surfaceMuted
        self.ink = ink
        self.inkSecondary = inkSecondary
        self.inkTertiary = inkTertiary
        self.hairline = hairline
        self.accent = accent
        self.onAccent = onAccent
        self.switchKnob = switchKnob
        self.sage = sage
        self.slate = slate
        self.success = success
        self.warning = warning
        self.danger = danger
    }

    // MARK: Built-in palettes

    public static let warmEditorialLight = ThemePalette(
        canvas: "#F5F0E7", sidebar: "#EFE8DC", surface: "#FBF7F0", surfaceMuted: "#ECE4D7",
        ink: "#211C17", inkSecondary: "#6D6458", inkTertiary: "#9B8F7F", hairline: "#DCD2C3",
        accent: "#B85C43", onAccent: "#FFF9F2", switchKnob: "#FFFDF8",
        sage: "#6E7F5E", slate: "#596A78", success: "#5F7A50", warning: "#A9762F", danger: "#A8433A"
    )

    public static let warmEditorialDark = ThemePalette(
        canvas: "#171411", sidebar: "#1D1915", surface: "#221E19", surfaceMuted: "#2B2620",
        ink: "#F1E9DD", inkSecondary: "#B7AB9B", inkTertiary: "#8A7E6E", hairline: "#3B342C",
        accent: "#E08C72", onAccent: "#241A15", switchKnob: "#F1E9DD",
        sage: "#9CB18A", slate: "#8FA9B7", success: "#9CB18A", warning: "#D8AA63", danger: "#E28B82"
    )

    // Catppuccin (Latte / Mocha)
    public static let catppuccinLight = ThemePalette(
        canvas: "#EFF1F5", sidebar: "#E6E9EF", surface: "#FFFFFF", surfaceMuted: "#CCD0DA",
        ink: "#4C4F69", inkSecondary: "#5C5F77", inkTertiary: "#6C6F85", hairline: "#CCD0DA",
        accent: "#8839EF", onAccent: "#EFF1F5", switchKnob: "#EFF1F5",
        sage: "#40A02B", slate: "#1E66F5", success: "#40A02B", warning: "#DF8E1D", danger: "#D20F39"
    )
    public static let catppuccinDark = ThemePalette(
        canvas: "#1E1E2E", sidebar: "#181825", surface: "#313244", surfaceMuted: "#45475A",
        ink: "#CDD6F4", inkSecondary: "#BAC2DE", inkTertiary: "#A6ADC8", hairline: "#45475A",
        accent: "#CBA6F7", onAccent: "#1E1E2E", switchKnob: "#CDD6F4",
        sage: "#A6E3A1", slate: "#89B4FA", success: "#A6E3A1", warning: "#F9E2AF", danger: "#F38BA8"
    )

    // Tokyo Night
    public static let tokyoNightLight = ThemePalette(
        canvas: "#D5D6DB", sidebar: "#CBCCD1", surface: "#E9E9EC", surfaceMuted: "#C4C8D0",
        ink: "#343B58", inkSecondary: "#4C5064", inkTertiary: "#565F89", hairline: "#C4C8D0",
        accent: "#34548A", onAccent: "#D5D6DB", switchKnob: "#D5D6DB",
        sage: "#485E30", slate: "#34548A", success: "#485E30", warning: "#8F5E15", danger: "#8C4351"
    )
    public static let tokyoNightDark = ThemePalette(
        canvas: "#1A1B26", sidebar: "#16161E", surface: "#24283B", surfaceMuted: "#414868",
        ink: "#C0CAF5", inkSecondary: "#A9B1D6", inkTertiary: "#565F89", hairline: "#414868",
        accent: "#7AA2F7", onAccent: "#1A1B26", switchKnob: "#C0CAF5",
        sage: "#9ECE6A", slate: "#7AA2F7", success: "#9ECE6A", warning: "#E0AF68", danger: "#F7768E"
    )

    // Rose Pine (Dawn / Moon)
    public static let rosePineLight = ThemePalette(
        canvas: "#FAF4ED", sidebar: "#F2E9E1", surface: "#FFFAF3", surfaceMuted: "#DFDAD9",
        ink: "#575279", inkSecondary: "#797593", inkTertiary: "#9893A5", hairline: "#DFDAD9",
        accent: "#907AA9", onAccent: "#FAF4ED", switchKnob: "#FAF4ED",
        sage: "#286983", slate: "#56949F", success: "#286983", warning: "#EA9D34", danger: "#B4637A"
    )
    public static let rosePineDark = ThemePalette(
        canvas: "#232136", sidebar: "#1F1D2E", surface: "#2A273F", surfaceMuted: "#393552",
        ink: "#E0DEF4", inkSecondary: "#908CAA", inkTertiary: "#6E6A86", hairline: "#393552",
        accent: "#C4A7E7", onAccent: "#232136", switchKnob: "#E0DEF4",
        sage: "#9CCFD8", slate: "#908CAA", success: "#9CCFD8", warning: "#F6C177", danger: "#EB6F92"
    )

    // Nord
    public static let nordLight = ThemePalette(
        canvas: "#ECEFF4", sidebar: "#E5E9F0", surface: "#FFFFFF", surfaceMuted: "#D8DEE9",
        ink: "#2E3440", inkSecondary: "#3B4252", inkTertiary: "#4C566A", hairline: "#D8DEE9",
        accent: "#5E81AC", onAccent: "#ECEFF4", switchKnob: "#ECEFF4",
        sage: "#8FBCBB", slate: "#81A1C1", success: "#8FBCBB", warning: "#EBCB8B", danger: "#BF616A"
    )
    public static let nordDark = ThemePalette(
        canvas: "#2E3440", sidebar: "#242933", surface: "#3B4252", surfaceMuted: "#434C5E",
        ink: "#ECEFF4", inkSecondary: "#D8DEE9", inkTertiary: "#81A1C1", hairline: "#434C5E",
        accent: "#88C0D0", onAccent: "#2E3440", switchKnob: "#ECEFF4",
        sage: "#A3BE8C", slate: "#81A1C1", success: "#A3BE8C", warning: "#EBCB8B", danger: "#BF616A"
    )

    // Dracula
    public static let draculaLight = ThemePalette(
        canvas: "#F8F8F2", sidebar: "#F0F0EA", surface: "#FFFFFF", surfaceMuted: "#E8E8E2",
        ink: "#282A36", inkSecondary: "#44475A", inkTertiary: "#6272A4", hairline: "#E8E8E2",
        accent: "#BD93F9", onAccent: "#F8F8F2", switchKnob: "#F8F8F2",
        sage: "#50FA7B", slate: "#8BE9FD", success: "#50FA7B", warning: "#F1FA8C", danger: "#FF5555"
    )
    public static let draculaDark = ThemePalette(
        canvas: "#282A36", sidebar: "#21222C", surface: "#343746", surfaceMuted: "#44475A",
        ink: "#F8F8F2", inkSecondary: "#E8E8E2", inkTertiary: "#6272A4", hairline: "#44475A",
        accent: "#BD93F9", onAccent: "#282A36", switchKnob: "#F8F8F2",
        sage: "#50FA7B", slate: "#8BE9FD", success: "#50FA7B", warning: "#F1FA8C", danger: "#FF5555"
    )

    // Gruvbox
    public static let gruvboxLight = ThemePalette(
        canvas: "#FBF1C7", sidebar: "#F2E5BC", surface: "#F9F5D7", surfaceMuted: "#EBDBB2",
        ink: "#3C3836", inkSecondary: "#504945", inkTertiary: "#7C6F64", hairline: "#EBDBB2",
        accent: "#9D0006", onAccent: "#FBF1C7", switchKnob: "#FBF1C7",
        sage: "#79740E", slate: "#427B58", success: "#79740E", warning: "#B57614", danger: "#9D0006"
    )
    public static let gruvboxDark = ThemePalette(
        canvas: "#282828", sidebar: "#1D2021", surface: "#3C3836", surfaceMuted: "#504945",
        ink: "#EBDBB2", inkSecondary: "#D5C4A1", inkTertiary: "#A89984", hairline: "#504945",
        accent: "#FE8019", onAccent: "#282828", switchKnob: "#EBDBB2",
        sage: "#B8BB26", slate: "#83A598", success: "#B8BB26", warning: "#FABD2F", danger: "#FB4934"
    )

    // Solarized
    public static let solarizedLight = ThemePalette(
        canvas: "#FDF6E3", sidebar: "#EEE8D5", surface: "#FFFBF0", surfaceMuted: "#E6DFCC",
        ink: "#586E75", inkSecondary: "#657B83", inkTertiary: "#839496", hairline: "#E6DFCC",
        accent: "#268BD2", onAccent: "#FDF6E3", switchKnob: "#FDF6E3",
        sage: "#859900", slate: "#2AA198", success: "#859900", warning: "#B58900", danger: "#DC322F"
    )
    public static let solarizedDark = ThemePalette(
        canvas: "#002B36", sidebar: "#073642", surface: "#073642", surfaceMuted: "#0A3F4C",
        ink: "#839496", inkSecondary: "#93A1A1", inkTertiary: "#586E75", hairline: "#0A3F4C",
        accent: "#268BD2", onAccent: "#002B36", switchKnob: "#839496",
        sage: "#859900", slate: "#2AA198", success: "#859900", warning: "#B58900", danger: "#DC322F"
    )
}

// MARK: - Custom theme

public struct CustomTheme: Codable, Sendable, Equatable, Identifiable {
    public var id: UUID
    public var name: String
    public var light: ThemePalette
    public var dark: ThemePalette

    public init(id: UUID = UUID(), name: String, light: ThemePalette, dark: ThemePalette) {
        self.id = id
        self.name = name
        self.light = light
        self.dark = dark
    }
}
