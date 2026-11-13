import iPomoCore
import SwiftUI

struct ManualSessionSheet: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.dismiss) private var dismiss

    @State private var taskTitle = ""
    @State private var notes = ""
    @State private var notesPreview = false
    @State private var projectID: UUID?
    @State private var date = Date()
    @State private var minutes = 25

    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    Overline("Report")
                    Text("Add focus entry")
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

            Hairline()

            ScrollView {
                VStack(alignment: .leading, spacing: DesignTokens.s4) {
                    VStack(alignment: .leading, spacing: DesignTokens.s2) {
                        Overline("Task or description")
                        TextField("Reading, writing, review…", text: $taskTitle)
                            .textFieldStyle(EditorialTextFieldStyle(font: Typography.body(15)))
                    }

                    VStack(alignment: .leading, spacing: DesignTokens.s2) {
                        HStack(spacing: DesignTokens.s2) {
                            Overline("Notes")
                            Spacer()
                            if !notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                Button(notesPreview ? "Write" : "Preview") {
                                    notesPreview.toggle()
                                }
                                .buttonStyle(EditorialQuietButtonStyle())
                                .help(notesPreview ? "Edit the Markdown source" : "Preview the formatted note")
                            }
                        }
                        if notesPreview {
                            MarkdownText(text: notes, color: DesignTokens.inkSecondary, fontSize: 13)
                                .padding(10)
                                .frame(maxWidth: .infinity, minHeight: 90, alignment: .topLeading)
                                .background(
                                    RoundedRectangle(cornerRadius: DesignTokens.r2, style: .continuous)
                                        .fill(DesignTokens.surface)
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: DesignTokens.r2, style: .continuous)
                                        .strokeBorder(DesignTokens.hairline, lineWidth: 1)
                                )
                        } else {
                            PaperTextEditor(text: $notes, minHeight: 90)
                        }
                    }

                    VStack(alignment: .leading, spacing: DesignTokens.s2) {
                        Overline("Project")
                        projectMenu
                    }

                    VStack(alignment: .leading, spacing: DesignTokens.s2) {
                        Overline("Date & time")
                        EditorialDateField(
                            date: $date,
                            components: [.date, .hourAndMinute],
                            hourFormat: model.database.settings.appearance.hourFormat
                        )
                    }

                    VStack(alignment: .leading, spacing: DesignTokens.s2) {
                        Overline("Minutes")
                        HStack(spacing: DesignTokens.s2) {
                            EditorialIntStepper(
                                value: $minutes,
                                range: 1...1_440,
                                step: 5,
                                textWidth: 64,
                                label: "Minutes"
                            )
                            Text("minutes")
                                .font(Typography.caption(10))
                                .foregroundStyle(DesignTokens.inkTertiary)
                        }
                    }

                    Text("Manual entries appear in reports and CSV exports. They don't change task pomodoro counts.")
                        .font(Typography.caption(10))
                        .foregroundStyle(DesignTokens.inkTertiary)
                }
                .padding(DesignTokens.s4)
            }

            Hairline()

            HStack(spacing: DesignTokens.s2) {
                Spacer()
                Button("Cancel") { dismiss() }
                    .buttonStyle(EditorialSecondaryButtonStyle())
                    .keyboardShortcut(.cancelAction)
                Button("Add entry") {
                    model.addManualSession(
                        taskTitle: taskTitle,
                        notes: notes,
                        projectID: projectID,
                        date: date,
                        minutes: minutes
                    )
                    dismiss()
                }
                .buttonStyle(EditorialPrimaryButtonStyle())
                .keyboardShortcut(.defaultAction)
                .disabled(minutes <= 0)
            }
            .padding(DesignTokens.s4)
        }
        .frame(width: 480, height: 560)
        .background(DesignTokens.canvas)
    }

    private var projectMenu: some View {
        Menu {
            Button("No Project") { projectID = nil }
            Divider()
            ForEach(model.projects) { project in
                Button(project.name) { projectID = project.id }
            }
        } label: {
            HStack(spacing: DesignTokens.s2) {
                if let project = model.project(id: projectID) {
                    ProjectDot(hex: project.colorHex)
                    Text(project.name)
                } else {
                    ProjectDot(hex: "#6B6258")
                    Text("No Project")
                }
                Spacer(minLength: DesignTokens.s2)
                Image(systemName: "chevron.down")
                    .font(.system(size: 8, weight: .semibold))
                    .foregroundStyle(DesignTokens.inkTertiary)
            }
            .font(Typography.body(13))
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
        .menuStyle(.button)
        .buttonStyle(.plain)
        .menuIndicator(.hidden)
    }
}
