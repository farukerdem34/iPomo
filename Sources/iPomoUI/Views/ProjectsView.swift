import iPomoCore
import SwiftUI

struct ProjectsView: View {
    @EnvironmentObject private var model: AppModel
    @State private var statusFilter: ProjectStatusFilter = .active
    @State private var projectToDelete: Project?

    private var visibleProjects: [Project] {
        model.projects.filter { statusFilter.matches($0.status) }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DesignTokens.s4) {
                header
                EditorialTabs(
                    items: ProjectStatusFilter.allCases,
                    title: { $0.title },
                    selection: $statusFilter,
                    spacing: DesignTokens.s4
                )
                Hairline()

                if visibleProjects.isEmpty {
                    EditorialEmptyState(
                        overline: "Nothing here",
                        title: "No projects yet",
                        message: "Create a project to group tasks, set a target date, and see its focus time.",
                        actionTitle: "New project",
                        action: { model.presentNewProject() }
                    )
                } else {
                    VStack(spacing: 0) {
                        ForEach(visibleProjects) { project in
                            ProjectLedgerRow(project: project) {
                                projectToDelete = project
                            }
                        }
                    }
                }
            }
            .editorialPagePadding()
        }
        .editorialBackground()
        .navigationTitle("Projects")
        .confirmationDialog(
            "Delete “\(projectToDelete?.name ?? "project")”?",
            isPresented: Binding(
                get: { projectToDelete != nil },
                set: { if !$0 { projectToDelete = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button("Delete and keep tasks") {
                if let project = projectToDelete {
                    model.deleteProject(id: project.id, deleteTasks: false)
                }
                projectToDelete = nil
            }
            Button("Delete project and its tasks", role: .destructive) {
                if let project = projectToDelete {
                    model.deleteProject(id: project.id, deleteTasks: true)
                }
                projectToDelete = nil
            }
            Button("Cancel", role: .cancel) { projectToDelete = nil }
        } message: {
            Text("“Keep tasks” moves them to No Project. Deleting tasks cannot be undone; focus history is kept.")
        }
    }

    private var header: some View {
        HStack(alignment: .top, spacing: DesignTokens.s4) {
            PageTitle(
                eyebrow: "Plan",
                title: "Projects",
                detail: "\(model.projects.count) total · \(model.activeProjects.count) active"
            )
            Spacer()
            Button {
                model.presentNewProject()
            } label: {
                Label("New Project", systemImage: "plus")
            }
            .buttonStyle(EditorialPrimaryButtonStyle())
        }
    }
}

private enum ProjectStatusFilter: String, CaseIterable, Identifiable, Hashable {
    case active
    case all
    case completed
    case archived

    var id: String { rawValue }

    var title: String {
        switch self {
        case .active: return "Active"
        case .all: return "All"
        case .completed: return "Completed"
        case .archived: return "Archived"
        }
    }

    func matches(_ status: ProjectStatus) -> Bool {
        switch self {
        case .active: return status == .active || status == .onHold
        case .all: return true
        case .completed: return status == .completed
        case .archived: return status == .archived
        }
    }
}

private struct ProjectLedgerRow: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.editorialAccent) private var accent
    let project: Project
    let onDelete: () -> Void
    @State private var hovering = false

    private var progress: ProjectProgress { model.projectProgress(project.id) }
    private var tasks: [PlanTask] { model.projectTasks(project.id) }
    private var openCount: Int { tasks.filter { !$0.isCompleted }.count }
    private var projectColor: Color { Color(hex: project.colorHex) }

    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .top, spacing: DesignTokens.s3) {
                ProjectDot(hex: project.colorHex, size: 10)
                    .padding(.top, 8)

                VStack(alignment: .leading, spacing: DesignTokens.s2) {
                    HStack(alignment: .firstTextBaseline, spacing: DesignTokens.s2) {
                        Text(project.name)
                            .font(Typography.section(22))
                            .foregroundStyle(DesignTokens.ink)
                            .lineLimit(1)
                        EditorialTag(text: project.status.title, color: projectColor)
                        if let due = project.dueDate {
                            Text("due \(AppFormat.dueLabel(due, now: model.now, calendar: model.calendar))")
                                .font(Typography.caption(11))
                                .foregroundStyle(
                                    due < model.calendar.startOfDay(for: model.now) && project.status == .active
                                        ? DesignTokens.danger
                                        : DesignTokens.inkTertiary
                                )
                        }
                        Spacer(minLength: DesignTokens.s2)
                    }

                    if !project.details.isEmpty {
                        Text(project.details)
                            .font(Typography.body(13))
                            .foregroundStyle(DesignTokens.inkSecondary)
                            .lineLimit(2)
                    }

                    HStack(spacing: DesignTokens.s3) {
                        Text("\(openCount) open")
                        Text("\(progress.completedTaskCount)/\(progress.taskCount) tasks done")
                        Text("\(PlanTask.numberString(progress.completedPomodoros))/\(PlanTask.numberString(progress.estimatedPomodoros)) pomodoros")
                        Text(AppFormat.duration(seconds: model.projectFocusSeconds(project.id)))
                        if let target = project.targetPomodoros {
                            Text("target \(PlanTask.numberString(target))")
                        }
                    }
                    .font(Typography.caption(11))
                    .foregroundStyle(DesignTokens.inkTertiary)

                    HStack(spacing: DesignTokens.s3) {
                        ProgressView(value: progress.fraction)
                            .progressViewStyle(EditorialProgressViewStyle(
                                fill: projectColor,
                                height: 4
                            ))
                        Text("\(Int((progress.fraction * 100).rounded()))%")
                            .font(Typography.caption(11))
                            .monospacedDigit()
                            .foregroundStyle(DesignTokens.inkSecondary)
                            .frame(width: 34, alignment: .trailing)
                    }
                    .padding(.top, 2)
                }

                HStack(alignment: .firstTextBaseline, spacing: DesignTokens.s1) {
                    Button("Open tasks") {
                        model.selectedSidebar = .tasks
                        model.taskProjectFilter = project.id
                        model.taskScope = .active
                    }
                    .buttonStyle(EditorialQuietButtonStyle())

                    Menu {
                        Button("Edit…") { model.presentEditProject(project) }
                        Divider()
                        Button("Delete…", role: .destructive, action: onDelete)
                    } label: {
                        Image(systemName: "ellipsis")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(DesignTokens.inkTertiary)
                            .frame(width: 28, height: 24)
                    }
                    .menuStyle(.button)
                    .buttonStyle(.plain)
                    .menuIndicator(.hidden)
                    .fixedSize()
                    .help("More project actions")
                }
            }
            .padding(.vertical, DesignTokens.s3)
            .background(hovering ? DesignTokens.surfaceMuted.opacity(0.28) : Color.clear)
            .contentShape(Rectangle())
            .onHover { hovering = $0 }
            .onTapGesture(count: 2) {
                model.selectedSidebar = .tasks
                model.taskProjectFilter = project.id
                model.taskScope = .active
            }

            Hairline()
        }
    }
}
