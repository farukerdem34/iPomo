import iPomoCore
import SwiftUI

struct ThemeEditorSheet: View {
    let onSave: (CustomTheme) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var name: String = "My Theme"
    @State private var light: ThemePalette = .warmEditorialLight
    @State private var dark: ThemePalette = .warmEditorialDark
    @State private var editingDark: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.s3) {
            PageTitle(eyebrow: "Appearance", title: "Custom theme", detail: "Pick colors for light and dark.")
            TextField("Name", text: $name)
                .textFieldStyle(EditorialTextFieldStyle())
            Picker("Variant", selection: $editingDark) {
                Text("Light").tag(false)
                Text("Dark").tag(true)
            }
            .pickerStyle(.segmented)

            ScrollView {
                VStack(alignment: .leading, spacing: DesignTokens.s2) {
                    colorRow("Canvas", binding: colorBinding(\.canvas, dark: editingDark))
                    colorRow("Sidebar", binding: colorBinding(\.sidebar, dark: editingDark))
                    colorRow("Surface", binding: colorBinding(\.surface, dark: editingDark))
                    colorRow("Surface muted", binding: colorBinding(\.surfaceMuted, dark: editingDark))
                    colorRow("Ink", binding: colorBinding(\.ink, dark: editingDark))
                    colorRow("Ink secondary", binding: colorBinding(\.inkSecondary, dark: editingDark))
                    colorRow("Ink tertiary", binding: colorBinding(\.inkTertiary, dark: editingDark))
                    colorRow("Hairline", binding: colorBinding(\.hairline, dark: editingDark))
                    colorRow("Accent", binding: colorBinding(\.accent, dark: editingDark))
                    colorRow("On accent", binding: colorBinding(\.onAccent, dark: editingDark))
                    colorRow("Switch knob", binding: colorBinding(\.switchKnob, dark: editingDark))
                    colorRow("Sage", binding: colorBinding(\.sage, dark: editingDark))
                    colorRow("Slate", binding: colorBinding(\.slate, dark: editingDark))
                    colorRow("Success", binding: colorBinding(\.success, dark: editingDark))
                    colorRow("Warning", binding: colorBinding(\.warning, dark: editingDark))
                    colorRow("Danger", binding: colorBinding(\.danger, dark: editingDark))
                }
            }

            HStack {
                Spacer()
                Button("Cancel") { dismiss() }
                    .buttonStyle(EditorialSecondaryButtonStyle())
                Button("Save") {
                    let theme = CustomTheme(name: name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "My Theme" : name, light: light, dark: dark)
                    onSave(theme)
                    dismiss()
                }
                .buttonStyle(EditorialPrimaryButtonStyle())
            }
        }
        .padding(DesignTokens.s4)
        .frame(width: 520, height: 640)
        .editorialBackground()
    }

    private func colorRow(_ title: String, binding: Binding<Color>) -> some View {
        HStack {
            Text(title)
                .font(Typography.body(13))
                .foregroundStyle(DesignTokens.ink)
            Spacer()
            ColorPicker("", selection: binding, supportsOpacity: false)
                .labelsHidden()
        }
    }

    private func colorBinding(_ keyPath: WritableKeyPath<ThemePalette, String>, dark: Bool) -> Binding<Color> {
        Binding<Color>(
            get: {
                let palette = dark ? self.dark : self.light
                return Color(hex: palette[keyPath: keyPath])
            },
            set: { newColor in
                let hex = newColor.hexString
                if dark {
                    self.dark[keyPath: keyPath] = hex
                } else {
                    self.light[keyPath: keyPath] = hex
                }
            }
        )
    }
}