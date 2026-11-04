import iPomoCore
import SwiftUI

struct TasksView: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.editorialAccent) private var accent
    @FocusState private var searchFocused: Bool

    private var filteredTasks: [PlanTask] {
        var results = TaskSearch.search(
            model.tasks,
            query: model.taskSearchText,
            projects: model.projectsByID,
            scope: model.taskScope,
            now: model.now,
            calendar: model.calendar
        )
        if let projectID = model.taskProjectFilter {
            results = results.filter { $0.projectID == projectID }
        }
        return results
    }

    private func sections(_ tasks: [PlanTask]) -> [TaskSection] {
        if isSearching {
            return [TaskSection(title: "Results", tasks: tasks)]
        }
        if model.taskScope != .active {
            return [TaskSection(title: model.taskScope.title, tasks: manualOrder(tasks))]
        }
        let now = model.now
        let calendar = model.calendar
        let separateCompleted = model.database.settings.behavior.moveCompletedToBottom
        let grouped = separateCompleted ? tasks.filter { !$0.isCompleted } : tasks
        let completed = separateCompleted ? tasks.filter(\.isCompleted) : []
        let horizonDays = model.database.settings.planning.planHorizonDays
        let nextBucket = "Next \(horizonDays) Day\(horizonDays == 1 ? "" : "s")"
        let horizonEnd = calendar.date(
            byAdding: .day,
            value: horizonDays + 1,
            to: calendar.startOfDay(for: now)
        )

        var buckets: [String: [PlanTask]] = [
            "Overdue": [], "Today": [], nextBucket: [], "Later": [], "No Date": [],
        ]
        for task in grouped {
            if task.isOverdue(now: now, calendar: calendar) {
                buckets["Overdue", default: []].append(task)
            } else if let due = task.dueDate {
                if calendar.isDate(due, inSameDayAs: now) {
                    buckets["Today", default: []].append(task)
                } else if let horizonEnd, calendar.startOfDay(for: due) < horizonEnd {
                    buckets[nextBucket, default: []].append(task)
                } else {
                    buckets["Later", default: []].append(task)
                }
            } else {
                buckets["No Date", default: []].append(task)
            }
        }

        let order = ["Overdue", "Today", nextBucket, "Later", "No Date"]
        var result = order.compactMap { title -> TaskSection? in
            guard let tasks = buckets[title], !tasks.isEmpty else { return nil }
            return TaskSection(title: title, tasks: manualOrder(tasks))
        }
        if !completed.isEmpty {
            result.append(TaskSection(title: "Completed", tasks: manualOrder(completed)))
        }
        return result
    }

    /// Manual order is the source of truth inside a due-date section, so a
    /// drag is not overridden by a later priority or due-date comparison.
    private func manualOrder(_ tasks: [PlanTask]) -> [PlanTask] {
        tasks.sorted { lhs, rhs in
            if lhs.sortOrder != rhs.sortOrder { return lhs.sortOrder < rhs.sortOrder }
            if lhs.createdAt != rhs.createdAt { return lhs.createdAt < rhs.createdAt }
            return lhs.id.uuidString < rhs.id.uuidString
        }
    }

    private var isSearching: Bool {
        !model.taskSearchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var hasTasks: Bool {
        !model.tasks.isEmpty
    }

    private var emptyStateTitle: String {
        if isSearching { return "Try a different search" }
        return hasTasks ? "No tasks match" : "The page is clear"
    }

    private var emptyStateMessage: String {
        if isSearching {
            return "Search covers titles, notes, and project names. Try a shorter or broader term."
        }
        return hasTasks
            ? "Tasks exist, but the current scope or project filter is hiding them."
            : "Create a task to get started."
    }

    private var emptyStateActionTitle: String? {
        if isSearching { return nil }
        return hasTasks ? "Show all tasks" : "New task"
    }

    private func handleEmptyStateAction() {
        guard hasTasks else {
            model.presentNewTask()
            return
        }
        model.taskSearchText = ""
        model.taskScope = .active
        model.taskProjectFilter = nil
    }

    var body: some View {
        let tasks = filteredTasks
        VStack(alignment: .leading, spacing: 0) {
            header(tasks)
                .padding(.horizontal, DesignTokens.s5)
                .padding(.top, DesignTokens.s4)
            searchRow
                .padding(.horizontal, DesignTokens.s5)
                .padding(.top, DesignTokens.s4)
            filterRow
                .padding(.horizontal, DesignTokens.s5)
                .padding(.top, DesignTokens.s3)
                .padding(.bottom, DesignTokens.s3)
            Hairline()

            if tasks.isEmpty {
                // A List must stay in the detail column: without one the split
                // view resizes to the content's height and breaks the window layout.
                List {
                    EditorialEmptyState(
                        overline: isSearching || hasTasks ? "No matches" : "Nothing here",
                        title: emptyStateTitle,
                        message: emptyStateMessage,
                        actionTitle: emptyStateActionTitle,
                        action: emptyStateActionTitle == nil ? nil : handleEmptyStateAction
                    )
                    .padding(.horizontal, DesignTokens.s5)
                    .listRowSeparator(.hidden)
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
            } else {
                taskList(tasks)
            }
        }
        .editorialBackground()
        .navigationTitle("Tasks")
        .onChange(of: model.searchFocusRequest) { _, _ in
            searchFocused = true
        }
    }

    private func header(_ tasks: [PlanTask]) -> some View {
        HStack(alignment: .top, spacing: DesignTokens.s4) {
            PageTitle(
                eyebrow: "Work",
                title: "Tasks",
                detail: "\(tasks.count) shown · \(model.activeTasks.count) open"
            )
            Spacer()
            Menu {
                Button("Delete completed", role: .destructive) { model.deleteCompletedTasks() }
            } label: {
                Label("Clean up", systemImage: "ellipsis.circle")
            }
            .menuStyle(.button)
            .buttonStyle(.plain)
            .menuIndicator(.hidden)
            .fixedSize()
            Button {
                model.presentNewTask()
            } label: {
                Label("Add Task", systemImage: "plus")
            }
            .buttonStyle(EditorialPrimaryButtonStyle())
        }
    }

    private var searchRow: some View {
        HStack(spacing: DesignTokens.s2) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(DesignTokens.inkTertiary)
            TextField("Search titles, notes, and projects…", text: $model.taskSearchText)
                .textFieldStyle(.plain)
                .font(Typography.body(14))
                .foregroundStyle(DesignTokens.ink)
                .focused($searchFocused)
            if !model.taskSearchText.isEmpty {
                Button {
                    model.taskSearchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(DesignTokens.inkTertiary)
                }
                .buttonStyle(.plain)
            } else {
                Text("⌘F")
                    .font(Typography.overline(9))
                    .foregroundStyle(DesignTokens.inkTertiary)
            }
        }
        .padding(.vertical, 9)
        .overlay(alignment: .bottom) { Hairline() }
    }

    private var filterRow: some View {
        HStack(alignment: .center, spacing: DesignTokens.s4) {
            EditorialTabs(
                items: TaskScope.allCases,
                title: { $0.title },
                selection: $model.taskScope,
                spacing: DesignTokens.s3
            )
            Spacer()
            Menu {
                Button("All Projects") { model.taskProjectFilter = nil }
                Divider()
                ForEach(model.projects) { project in
                    Button(project.name) { model.taskProjectFilter = project.id }
                }
            } label: {
                HStack(spacing: 6) {
                    if let id = model.taskProjectFilter, let project = model.project(id: id) {
                        ProjectDot(hex: project.colorHex)
                        Text(project.name)
                    } else {
                        Text("All Projects")
                    }
                    Image(systemName: "chevron.down")
                        .font(.system(size: 8, weight: .semibold))
                }
                .font(Typography.bodyMedium(12))
                .foregroundStyle(DesignTokens.inkSecondary)
            }
            .menuStyle(.button)
            .buttonStyle(.plain)
            .menuIndicator(.hidden)
            .fixedSize()
        }
    }

    private func taskList(_ tasks: [PlanTask]) -> some View {
        List {
            ForEach(sections(tasks)) { section in
                TaskSectionView(section: section, canMove: !isSearching)
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .environment(\.defaultMinListRowHeight, 44)
    }
}

private struct TaskSection: Identifiable {
    let title: String
    let tasks: [PlanTask]
    var id: String { title }
}

private struct TaskSectionView: View {
    @EnvironmentObject private var model: AppModel
    let section: TaskSection
    let canMove: Bool

    var body: some View {
        Section {
            ForEach(section.tasks) { task in
                TaskLedgerRow(task: task)
                    .listRowSeparator(.hidden)
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
            }
            .onMove(perform: canMove ? { source, destination in
                model.reorderTasks(
                    visibleIDs: section.tasks.map(\.id),
                    from: source,
                    to: destination
                )
            } : nil)
        } header: {
            HStack(spacing: DesignTokens.s2) {
                Overline(section.title)
                Text("\(section.tasks.count)")
                    .font(Typography.overline(9))
                    .foregroundStyle(DesignTokens.inkTertiary)
                Spacer()
            }
            .padding(.horizontal, DesignTokens.s5)
            .padding(.top, DesignTokens.s3)
            .padding(.bottom, DesignTokens.s2)
            .background(DesignTokens.canvas)
        }
    }
}

private struct TaskLedgerRow: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.editorialAccent) private var accent
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let task: PlanTask
    @State private var hovering = false
    @State private var showDeleteConfirm = false

    var body: some View {
        HStack(alignment: .center, spacing: DesignTokens.s2) {
            Button {
                model.toggleTaskCompletion(id: task.id)
            } label: {
                EditorialCheckbox(isOn: task.isCompleted)
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(task.title)
                        .font(Typography.bodyMedium(15))
                        .strikethrough(task.isCompleted)
                        .foregroundStyle(task.isCompleted ? DesignTokens.inkTertiary : DesignTokens.ink)
                        .lineLimit(2)
                        .animation(Motion.calm(reduceMotion), value: task.isCompleted)
                    if task.priority == .high {
                        Image(systemName: "exclamationmark")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(DesignTokens.warning)
                    }
                }
                HStack(spacing: DesignTokens.s2) {
                    if let project = model.project(id: task.projectID) {
                        HStack(spacing: 5) {
                            ProjectDot(hex: project.colorHex)
                            Text(project.name)
                        }
                        .font(Typography.caption(11))
                        .foregroundStyle(DesignTokens.inkSecondary)
                    } else {
                        Text("No Project")
                            .font(Typography.caption(11))
                            .foregroundStyle(DesignTokens.inkTertiary)
                    }
                    if let due = task.dueDate {
                        Text(AppFormat.dueLabel(due, now: model.now, calendar: model.calendar))
                            .font(Typography.caption(11))
                            .foregroundStyle(
                                task.isOverdue(now: model.now, calendar: model.calendar)
                                    ? DesignTokens.danger
                                    : DesignTokens.inkTertiary
                            )
                    }
                    if !task.notes.isEmpty {
                        Image(systemName: "note.text")
                            .font(.system(size: 9))
                            .foregroundStyle(DesignTokens.inkTertiary)
                    }
                }
            }
            .contentShape(Rectangle())
            .onTapGesture(count: 2) {
                model.presentEditTask(task)
            }

            Spacer(minLength: DesignTokens.s2)

            Text(task.displayProgress)
                .font(Typography.caption(11))
                .monospacedDigit()
                .foregroundStyle(DesignTokens.inkTertiary)
                .frame(width: 36, alignment: .trailing)

            Button {
                model.requestTaskSelection(task.id)
                model.selectedSidebar = .timer
            } label: {
                Image(systemName: "play")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(hovering ? accent : DesignTokens.inkTertiary)
                    .frame(width: 28, height: 28)
            }
            .buttonStyle(.plain)
            .help("Focus on this task")

            Button {
                model.setFocusToday(id: task.id, value: !task.isFocusToday)
            } label: {
                Image(systemName: task.isFocusToday ? "star.fill" : "star")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(task.isFocusToday ? accent : DesignTokens.inkTertiary)
                    .frame(width: 28, height: 28)
            }
            .buttonStyle(.plain)
            .help(task.isFocusToday ? "Remove from today's plan" : "Add to today's plan")

            Button {
                model.presentEditTask(task)
            } label: {
                Image(systemName: "pencil")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(DesignTokens.inkTertiary)
                    .frame(width: 28, height: 28)
            }
            .buttonStyle(.plain)
            .opacity(hovering ? 1 : 0)
            .help("Edit task")
        }
        .padding(.horizontal, DesignTokens.s5)
        .padding(.vertical, 9)
        .background(hovering ? DesignTokens.surfaceMuted.opacity(0.35) : Color.clear)
        .overlay(alignment: .bottom) {
            Hairline()
                .padding(.horizontal, DesignTokens.s5)
        }
        .contentShape(Rectangle())
        .onHover { hovering = $0 }
        .animation(Motion.calm(reduceMotion, duration: 0.12), value: hovering)
        .contextMenu {
            Button("Edit…") { model.presentEditTask(task) }
            Button("Focus on this task") {
                model.requestTaskSelection(task.id)
                model.selectedSidebar = .timer
            }
            Button("Duplicate") { model.duplicateTask(id: task.id) }
            Button(task.isFocusToday ? "Remove from Today" : "Add to Today") {
                model.setFocusToday(id: task.id, value: !task.isFocusToday)
            }
            Button(task.isCompleted ? "Mark as Active" : "Mark as Completed") {
                model.toggleTaskCompletion(id: task.id)
            }
            Divider()
            Button("Delete Task", role: .destructive) { showDeleteConfirm = true }
        }
        .alert("Delete “\(task.title)”?", isPresented: $showDeleteConfirm) {
            Button("Delete", role: .destructive) { model.deleteTask(id: task.id) }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("The task will be removed. Focus history is kept.")
        }
    }
}
