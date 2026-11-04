import iPomoCore
import SwiftUI

struct TaskEditorView: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.dismiss) private var dismiss
    let request: TaskEditorRequest

    @State private var title: String
    @State private var notes: String
    @State private var projectID: UUID?
    @State private var estimatedPomodoros: Double
    @State private var priority: TaskPriority
    @State private var dueEnabled: Bool
    @State private var dueDate: Date
    @State private var focusToday: Bool
    @State private var isCompleted: Bool
    @State private var showDeleteConfirm = false

    init(request: TaskEditorRequest) {
        self.request = request
        _title = State(initialValue: request.task?.title ?? "")
        _notes = State(initialValue: request.task?.notes ?? "")
        _projectID = State(initialValue: request.task?.projectID ?? request.projectID)
        _estimatedPomodoros = State(initialValue: request.task?.estimatedPomodoros ?? 1)
        _priority = State(initialValue: request.task?.priority ?? .medium)
        _dueEnabled = State(initialValue: request.task?.dueDate != nil)
        _dueDate = State(initialValue: request.task?.dueDate ?? Date())
        _focusToday = State(initialValue: request.task?.isFocusToday ?? true)
        _isCompleted = State(initialValue: request.task?.isCompleted ?? false)
    }

    private var isEditing: Bool { request.task != nil }

    var body: some View {
        VStack(spacing: 0) {
            header
            Hairline()
            ScrollView {
                VStack(alignment: .leading, spacing: DesignTokens.s4) {
                    TextField("What are you working on?", text: $title)
                        .textFieldStyle(EditorialTextFieldStyle(font: Typography.title(22)))
                        .padding(.top, DesignTokens.s2)

                    VStack(alignment: .leading, spacing: DesignTokens.s2) {
                        Overline("Notes")
                        PaperTextEditor(text: $notes, minHeight: 110)
                    }

                    HStack(alignment: .top, spacing: DesignTokens.s4) {
                        VStack(alignment: .leading, spacing: DesignTokens.s2) {
                            Overline("Project")
                            projectMenu
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)

                        VStack(alignment: .leading, spacing: DesignTokens.s2) {
                            Overline("Estimate")
                            HStack {
                                EstimateStepper(value: $estimatedPomodoros)
                                Text("pomodoros")
                                    .font(Typography.caption(10))
                                    .foregroundStyle(DesignTokens.inkTertiary)
                            }
                        }
                        .fixedSize()
                    }

                    VStack(alignment: .leading, spacing: DesignTokens.s2) {
                        Overline("Priority")
                        HStack(spacing: DesignTokens.s2) {
                            ForEach(TaskPriority.allCases) { value in
                                PriorityChip(
                                    title: value.title,
                                    isSelected: priority == value,
                                    action: { priority = value }
                                )
                            }
                        }
                    }

                    VStack(alignment: .leading, spacing: DesignTokens.s2) {
                        Hairline()
                        EditorialToggleRow(
                            title: "Due date",
                            detail: dueEnabled ? nil : "Give this task a day to land.",
                            isOn: $dueEnabled.animation()
                        )
                        if dueEnabled {
                            EditorialDateField(date: $dueDate)
                                .accessibilityLabel("Due date")
                                .padding(.leading, 2)
                        }
                        EditorialToggleRow(
                            title: "Add to today's plan",
                            isOn: $focusToday
                        )
                        if isEditing {
                            EditorialToggleRow(title: "Completed", isOn: $isCompleted)
                        }
                    }

                    if isEditing, let task = request.task {
                        VStack(alignment: .leading, spacing: DesignTokens.s2) {
                            Hairline()
                            Overline("History")
                            HStack(spacing: DesignTokens.s5) {
                                historyItem("Completed", PlanTask.numberString(task.completedPomodoros))
                                historyItem("Created", AppFormat.shortDate(task.createdAt, calendar: model.calendar))
                                historyItem("Updated", AppFormat.shortDate(task.updatedAt, calendar: model.calendar))
                            }
                            .padding(.top, DesignTokens.s1)
                        }
                    }
                }
                .padding(DesignTokens.s4)
            }
            Hairline()
            footer
        }
        .frame(width: 600, height: 700)
        .background(DesignTokens.canvas)
        .onAppear {
            if !isEditing {
                estimatedPomodoros = model.database.settings.planning.defaultEstimatedPomodoros
            }
        }
        .alert("Delete this task?", isPresented: $showDeleteConfirm) {
            Button("Delete", role: .destructive) {
                if let task = request.task {
                    model.deleteTask(id: task.id)
                }
                dismiss()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("The task will be removed. Focus history is kept.")
        }
    }

    private var header: some View {
        HStack(alignment: .top, spacing: DesignTokens.s3) {
            VStack(alignment: .leading, spacing: 6) {
                Overline("Task")
                Text(isEditing ? "Edit task" : "New task")
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

    private var footer: some View {
        HStack(spacing: DesignTokens.s2) {
            if isEditing {
                Button("Delete") { showDeleteConfirm = true }
                    .buttonStyle(EditorialDangerButtonStyle())
            }
            Spacer()
            Button("Cancel") { dismiss() }
                .buttonStyle(EditorialSecondaryButtonStyle())
                .keyboardShortcut(.cancelAction)
            Button(isEditing ? "Save" : "Add task") { save() }
                .buttonStyle(EditorialPrimaryButtonStyle())
                .keyboardShortcut(.defaultAction)
                .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
        .padding(DesignTokens.s4)
    }

    private func historyItem(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(value)
                .font(Typography.bodyMedium(13))
                .foregroundStyle(DesignTokens.ink)
            Overline(label)
        }
    }

    private func save() {
        let now = Date()
        var task = request.task ?? PlanTask(title: title)
        task.title = title
        task.notes = notes
        task.projectID = projectID
        task.estimatedPomodoros = estimatedPomodoros
        task.priority = priority
        task.isFocusToday = focusToday
        task.dueDate = dueEnabled ? dueDate : nil
        if isCompleted != task.isCompleted {
            task.isCompleted = isCompleted
            task.completedAt = isCompleted ? now : nil
        }
        task.updatedAt = now
        model.saveTask(task)
        dismiss()
    }
}

private struct PriorityChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    @Environment(\.editorialAccent) private var accent

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(Typography.bodyMedium(12))
                .foregroundStyle(isSelected ? DesignTokens.onAccent : DesignTokens.inkSecondary)
                .padding(.horizontal, 12)
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
