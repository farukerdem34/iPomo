import iPomoCore
import SwiftUI

struct ProjectEditorView: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.dismiss) private var dismiss
    let request: ProjectEditorRequest

    @State private var name: String
    @State private var details: String
    @State private var colorHex: String
    @State private var status: ProjectStatus
    @State private var dueEnabled: Bool
    @State private var dueDate: Date
    @State private var targetEnabled: Bool
    @State private var targetPomodoros: Double

    init(request: ProjectEditorRequest) {
        self.request = request
        _name = State(initialValue: request.project?.name ?? "")
        _details = State(initialValue: request.project?.details ?? "")
        _colorHex = State(initialValue: request.project?.colorHex ?? ProjectPalette.colors[0])
        _status = State(initialValue: request.project?.status ?? .active)
        _dueEnabled = State(initialValue: request.project?.dueDate != nil)
        _dueDate = State(initialValue: request.project?.dueDate ?? Date())
        _targetEnabled = State(initialValue: request.project?.targetPomodoros != nil)
        _targetPomodoros = State(initialValue: request.project?.targetPomodoros ?? 20)
    }

    private var isEditing: Bool { request.project != nil }

    var body: some View {
        VStack(spacing: 0) {
            header
            Hairline()
            ScrollView {
                VStack(alignment: .leading, spacing: DesignTokens.s4) {
                    TextField("Project name", text: $name)
                        .textFieldStyle(EditorialTextFieldStyle(font: Typography.title(22)))
                        .padding(.top, DesignTokens.s2)

                    VStack(alignment: .leading, spacing: DesignTokens.s2) {
                        Overline("Details")
                        PaperTextEditor(text: $details, minHeight: 100)
                    }

                    VStack(alignment: .leading, spacing: DesignTokens.s2) {
                        Overline("Color")
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 28), spacing: 8)], alignment: .leading, spacing: 8) {
                            ForEach(ProjectPalette.colors, id: \.self) { hex in
                                Button {
                                    colorHex = hex
                                } label: {
                                    Circle()
                                        .fill(Color(hex: hex))
                                        .frame(width: 24, height: 24)
                                        .overlay(
                                            Circle()
                                                .strokeBorder(
                                                    DesignTokens.ink.opacity(colorHex == hex ? 0.6 : 0.08),
                                                    lineWidth: colorHex == hex ? 2 : 1
                                                )
                                        )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }

                    VStack(alignment: .leading, spacing: DesignTokens.s2) {
                        Overline("Status")
                        HStack(spacing: DesignTokens.s2) {
                            ForEach(ProjectStatus.allCases) { value in
                                StatusChip(
                                    title: value.title,
                                    isSelected: status == value,
                                    action: { status = value }
                                )
                            }
                        }
                    }

                    VStack(alignment: .leading, spacing: DesignTokens.s2) {
                        Hairline()
                        EditorialToggleRow(
                            title: "Target date",
                            detail: dueEnabled ? nil : "Optional deadline for the project.",
                            isOn: $dueEnabled
                        )
                        if dueEnabled {
                            EditorialDateField(date: $dueDate)
                                .accessibilityLabel("Target date")
                                .padding(.leading, 2)
                        }
                        EditorialToggleRow(
                            title: "Pomodoro target",
                            detail: targetEnabled ? nil : "Optional planning target.",
                            isOn: $targetEnabled
                        )
                        if targetEnabled {
                            HStack {
                                Text("Target pomodoros")
                                    .font(Typography.body(13))
                                    .foregroundStyle(DesignTokens.inkSecondary)
                                Spacer()
                                EstimateStepper(value: $targetPomodoros, range: 0.1...999)
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }
                .padding(DesignTokens.s4)
            }
            Hairline()
            footer
        }
        .frame(width: 580, height: 680)
        .background(DesignTokens.canvas)
    }

    private var header: some View {
        HStack(alignment: .top, spacing: DesignTokens.s3) {
            VStack(alignment: .leading, spacing: 6) {
                Overline("Project")
                Text(isEditing ? "Edit project" : "New project")
                    .font(Typography.title(26))
                    .foregroundStyle(DesignTokens.ink)
            }
            Spacer()
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
            }
            .buttonStyle(EditorialIconButtonStyle())
        }
        .padding(DesignTokens.s4)
    }

    private var footer: some View {
        HStack(spacing: DesignTokens.s2) {
            Spacer()
            Button("Cancel") { dismiss() }
                .buttonStyle(EditorialSecondaryButtonStyle())
                .keyboardShortcut(.cancelAction)
            Button(isEditing ? "Save" : "Create") { save() }
                .buttonStyle(EditorialPrimaryButtonStyle())
                .keyboardShortcut(.defaultAction)
                .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
        .padding(DesignTokens.s4)
    }

    private func save() {
        var project = request.project ?? Project(name: name)
        project.name = name
        project.details = details
        project.colorHex = colorHex
        project.status = status
        project.dueDate = dueEnabled ? dueDate : nil
        project.targetPomodoros = targetEnabled ? targetPomodoros : nil
        project.updatedAt = Date()
        model.saveProject(project)
        dismiss()
    }
}

private struct StatusChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    @Environment(\.editorialAccent) private var accent

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(Typography.bodyMedium(12))
                .foregroundStyle(isSelected ? DesignTokens.onAccent : DesignTokens.inkSecondary)
                .padding(.horizontal, 11)
                .padding(.vertical, 6)
                .background(
                    RoundedRectangle(cornerRadius: DesignTokens.r1, style: .continuous)
                        .fill(isSelected ? accent : Color.clear)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: DesignTokens.r1, style: .continuous)
                        .strokeBorder(isSelected ? Color.clear : DesignTokens.hairline, lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }
}
