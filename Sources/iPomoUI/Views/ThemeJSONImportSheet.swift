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
        model.showBanner("Sample theme JSON copied to clipboard.", kind: .success)
    }

    private func copyAIPrompt() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(Self.aiPrompt, forType: .string)
        model.showBanner("AI prompt copied to clipboard. Paste it into ChatGPT, Claude, DeepSeek, etc.", kind: .info)
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
    You are helping me create a theme JSON file for iPomo, a macOS Pomodoro timer app. \
    Return ONLY a valid JSON object. Do not include markdown fences, comments, or any explanation.

    The JSON must match this schema:
    {
      "name": "Theme name",
      "light": {
        "canvas": "#RRGGBB", "sidebar": "#RRGGBB", "surface": "#RRGGBB", "surfaceMuted": "#RRGGBB",
        "ink": "#RRGGBB", "inkSecondary": "#RRGGBB", "inkTertiary": "#RRGGBB", "hairline": "#RRGGBB",
        "accent": "#RRGGBB", "onAccent": "#RRGGBB", "switchKnob": "#RRGGBB", "sage": "#RRGGBB",
        "slate": "#RRGGBB", "success": "#RRGGBB", "warning": "#RRGGBB", "danger": "#RRGGBB"
      },
      "dark": { ...same 16 fields... }
    }

    Guidelines:
    - Every color must be a 6-digit hex string starting with #.
    - Light theme: light backgrounds with dark text; dark theme: dark backgrounds with light text.
    - Accent must be clearly visible on canvas and surface in both variants.
    - Keep contrast accessible (WCAG AA where practical).
    - Choose a cohesive aesthetic (for example Catppuccin, Tokyo Night, Rose Pine, Nord, Dracula, Gruvbox, Solarized).

    Example:
    \(CustomTheme.sampleJSON)
    """
}