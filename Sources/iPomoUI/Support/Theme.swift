import AppKit
import Combine
import iPomoCore
import SwiftUI

extension Color {
    init(hex: String) {
        let cleaned = hex.trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "#", with: "")
        var value: UInt64 = 0
        Scanner(string: cleaned).scanHexInt64(&value)
        let red, green, blue: Double
        if cleaned.count == 6 {
            red = Double((value >> 16) & 0xFF) / 255.0
            green = Double((value >> 8) & 0xFF) / 255.0
            blue = Double(value & 0xFF) / 255.0
        } else {
            red = 0.45
            green = 0.47
            blue = 0.52
        }
        self.init(red: red, green: green, blue: blue)
    }

    var hexString: String {
        let nsColor = NSColor(self).usingColorSpace(.sRGB) ?? NSColor(self)
        let r = Int(round(nsColor.redComponent * 255))
        let g = Int(round(nsColor.greenComponent * 255))
        let b = Int(round(nsColor.blueComponent * 255))
        return String(format: "#%02X%02X%02X", r, g, b)
    }
}

enum ThemeColors {
    static func accent(_ theme: AppTheme) -> Color {
        Color.dynamic(lightHex: theme.lightHex, darkHex: theme.darkHex)
    }

    static func accent(custom: CustomTheme, isDark: Bool) -> Color {
        Color(hex: isDark ? custom.dark.accent : custom.light.accent)
    }
}

// MARK: - Theme manager

final class ThemeManager: ObservableObject, @unchecked Sendable {
    static let shared = ThemeManager()

    @Published private(set) var revision: Int = 0

    nonisolated(unsafe) private var theme: AppTheme = .tomato
    nonisolated(unsafe) private var customThemes: [CustomTheme] = []
    nonisolated(unsafe) private var selectedCustomThemeID: UUID?

    private init() {}

    @MainActor
    func configure(theme: AppTheme, customThemes: [CustomTheme], selectedCustomThemeID: UUID?) {
        let changed = theme != self.theme
            || customThemes != self.customThemes
            || selectedCustomThemeID != self.selectedCustomThemeID
        self.theme = theme
        self.customThemes = customThemes
        self.selectedCustomThemeID = selectedCustomThemeID
        if changed { revision &+= 1 }
    }

    private nonisolated var useCustom: Bool { theme == .custom }

    private nonisolated var activePalette: (light: ThemePalette, dark: ThemePalette) {
        if useCustom, let id = selectedCustomThemeID,
           let custom = customThemes.first(where: { $0.id == id }) {
            return (custom.light, custom.dark)
        }
        return (theme.lightPalette, theme.darkPalette)
    }

    nonisolated func palette(for appearance: NSAppearance?) -> ThemePalette {
        let isDark = appearance?.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
        return isDark ? activePalette.dark : activePalette.light
    }

    nonisolated func currentPalette() -> ThemePalette {
        palette(for: NSApp?.effectiveAppearance)
    }

    @MainActor
    func bump() { revision &+= 1 }
}

enum AppFormat {
    static func duration(seconds: Int) -> String {
        let total = max(0, seconds)
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        }
        if minutes > 0 {
            return "\(minutes)m"
        }
        return "\(total)s"
    }

    static func clock(
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

    static func shortDate(_ date: Date, calendar: Calendar) -> String {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.locale = .current
        formatter.timeZone = calendar.timeZone
        formatter.dateFormat = "MMM d"
        return formatter.string(from: date)
    }

    static func longDate(_ date: Date, calendar: Calendar) -> String {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.locale = .current
        formatter.timeZone = calendar.timeZone
        formatter.dateFormat = "EEEE, MMMM d"
        return formatter.string(from: date)
    }

    static func dueLabel(
        _ date: Date,
        now: Date = Date(),
        calendar: Calendar
    ) -> String {
        if calendar.isDate(date, inSameDayAs: now) { return "Today" }
        if let tomorrow = calendar.date(byAdding: .day, value: 1, to: now),
           calendar.isDate(date, inSameDayAs: tomorrow) {
            return "Tomorrow"
        }
        if let yesterday = calendar.date(byAdding: .day, value: -1, to: now),
           calendar.isDate(date, inSameDayAs: yesterday) {
            return "Yesterday"
        }
        return shortDate(date, calendar: calendar)
    }
}
