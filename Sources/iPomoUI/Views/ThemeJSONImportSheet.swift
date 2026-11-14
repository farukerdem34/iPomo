import AppKit
import iPomoCore
import SwiftUI

struct ThemeJSONImportSheet: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.dismiss) private var dismiss

    @State private var jsonText: String = ""
    @State private var statusMessage: String?
    @State private var statusIsError: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.s3) {
            PageTitle(
                eyebrow: "Appearance",
                title: "Import theme from JSON",
                detail: "Paste a theme definition, or generate one with an AI assistant."
            )

            TextEditor(text: $jsonText)
                .font(.system(.body, design: .monospaced))
                .frame(minHeight: 220)
                .padding(DesignTokens.s2)
                .background(
                    RoundedRectangle(cornerRadius: DesignTokens.r2, style: .continuous)
                        .fill(DesignTokens.surface)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: DesignTokens.r2, style: .continuous)
                        .strokeBorder(DesignTokens.hairline, lineWidth: 1)
                )

            if let statusMessage {
                Text(statusMessage)
                    .font(Typography.caption(11))
                    .foregroundStyle(statusIsError ? DesignTokens.danger : DesignTokens.success)
                    .fixedSize(horizontal: false, vertical: true)
            }

            HStack(spacing: DesignTokens.s2) {
                Button {
                    pasteFromClipboard()
                } label: {
                    Label("Paste", systemImage: "doc.on.clipboard")
                }
                .buttonStyle(EditorialSecondaryButtonStyle())

                Button {
                    copySampleJSON()
                } label: {
                    Label("Copy sample JSON", systemImage: "doc.on.doc")
                }
                .buttonStyle(EditorialSecondaryButtonStyle())

                Button {
                    copyAIPrompt()
                } label: {
                    Label("Need help?", systemImage: "sparkles")
                }
                .buttonStyle(EditorialSecondaryButtonStyle())

                Spacer()
            }

            HStack {
                Spacer()
                Button("Cancel") { dismiss() }
                    .buttonStyle(EditorialSecondaryButtonStyle())
                Button("Apply") { apply() }
                    .buttonStyle(EditorialPrimaryButtonStyle())
                    .disabled(jsonText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding(DesignTokens.s4)
        .frame(width: 620, height: 520)
        .editorialBackground()
    }

    private func pasteFromClipboard() {
        if let value = NSPasteboard.general.string(forType: .string) {
            jsonText = value
            statusMessage = "Pasted from clipboard."
            statusIsError = false
        } else {
            statusMessage = "Clipboard does not contain text."
            statusIsError = true
        }
    }

    private func copySampleJSON() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(CustomTheme.sampleJSON, forType: .string)
        statusMessage = "Sample theme JSON copied to clipboard."
        statusIsError = false
    }

    private func copyAIPrompt() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(Self.aiPrompt, forType: .string)
        statusMessage = "AI prompt copied to clipboard. Paste it into ChatGPT, Claude, DeepSeek, etc."
        statusIsError = false
    }

    private func apply() {
        let trimmed = jsonText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            statusMessage = "Paste or type a JSON theme first."
            statusIsError = true
            return
        }
        guard let data = trimmed.data(using: .utf8) else {
            statusMessage = "Could not read the text as UTF-8."
            statusIsError = true
            return
        }
        do {
            let theme = try JSONDecoder().decode(CustomTheme.self, from: data)
            model.updateSettings { settings in
                settings.appearance.customThemes.append(theme)
                settings.appearance.theme = .custom
                settings.appearance.selectedCustomThemeID = theme.id
            }
            model.showBanner("Theme “\(theme.name)” applied.", kind: .success)
            dismiss()
        } catch {
            statusMessage = "Invalid JSON: \(error.localizedDescription)"
            statusIsError = true
        }
    }

    static let aiPrompt: String = """
    You are an expert UI color designer. Create one complete theme for iPomo, a macOS Pomodoro timer app with a calm, paper-like interface. Return ONLY a valid JSON object. Do not include markdown fences, comments, analysis, or any text outside the JSON.

    OUTPUT SCHEMA (all fields required):
    {
      "name": "Short, human-readable theme name",
      "light": {
        "canvas": "#RRGGBB",
        "sidebar": "#RRGGBB",
        "surface": "#RRGGBB",
        "surfaceMuted": "#RRGGBB",
        "ink": "#RRGGBB",
        "inkSecondary": "#RRGGBB",
        "inkTertiary": "#RRGGBB",
        "hairline": "#RRGGBB",
        "accent": "#RRGGBB",
        "onAccent": "#RRGGBB",
        "switchKnob": "#RRGGBB",
        "sage": "#RRGGBB",
        "slate": "#RRGGBB",
        "success": "#RRGGBB",
        "warning": "#RRGGBB",
        "danger": "#RRGGBB"
      },
      "dark": { "canvas": "#RRGGBB", "sidebar": "#RRGGBB", "surface": "#RRGGBB", "surfaceMuted": "#RRGGBB", "ink": "#RRGGBB", "inkSecondary": "#RRGGBB", "inkTertiary": "#RRGGBB", "hairline": "#RRGGBB", "accent": "#RRGGBB", "onAccent": "#RRGGBB", "switchKnob": "#RRGGBB", "sage": "#RRGGBB", "slate": "#RRGGBB", "success": "#RRGGBB", "warning": "#RRGGBB", "danger": "#RRGGBB" }
    }

    FIELD MEANING:
    - canvas: main page background.
    - sidebar: navigation sidebar background.
    - surface: raised inputs, cards, and popovers.
    - surfaceMuted: hover states, quiet fills, code blocks.
    - ink: primary text.
    - inkSecondary: body secondary text.
    - inkTertiary: metadata, overlines, placeholders.
    - hairline: 1px rules, borders, dividers.
    - accent: primary brand color used for focus, selection, primary buttons, links, and the timer ring.
    - onAccent: text/icon color drawn on top of accent fills.
    - switchKnob: knob color on an OFF switch.
    - sage: short-break stage color.
    - slate: long-break stage color.
    - success: positive/confirmation color.
    - warning: caution color.
    - danger: destructive/error color.

    DESIGN RULES:
    1. Every color must be exactly a 7-character hex string: # followed by 6 uppercase or lowercase hex digits.
    2. The light variant must use light backgrounds and dark text; the dark variant must use dark backgrounds and light text.
    3. Backgrounds should be low-saturation and calm. Avoid pure black (#000000) and pure white (#FFFFFF) unless the aesthetic truly requires them.
    4. ink on canvas and ink on surface must have at least WCAG AA contrast (4.5:1 for normal text).
    5. accent on canvas and accent on surface must be clearly visible (at least 3:1).
    6. onAccent must contrast strongly with accent (at least 4.5:1).
    7. hairline must be subtle but visible against canvas and surface.
    8. sage, slate, success, warning, and danger must each be distinguishable from one another and from accent.
    9. The dark variant should not be a simple inversion; adapt saturation and lightness so it feels native in dark mode.
    10. Keep the overall palette cohesive and restrained, matching a named aesthetic such as Catppuccin, Tokyo Night, Rose Pine, Nord, Dracula, Gruvbox, or Solarized, or an original aesthetic with a clear mood.

    ACCESSIBILITY CHECKLIST BEFORE FINALIZING:
    - Text contrast passes.
    - Accent is identifiable without relying on color alone where possible.
    - Warning and danger are clearly distinct.
    - No two adjacent surfaces are identical.

    Return only the JSON object. No prose.

    Example:
    \(CustomTheme.sampleJSON)
    """
}