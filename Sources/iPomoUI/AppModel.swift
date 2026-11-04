import AppKit
import Combine
import Foundation
import iPomoCore
import SwiftUI
import UniformTypeIdentifiers

// MARK: - Navigation and presentation types

enum SidebarItem: String, CaseIterable, Identifiable {
    case today
    case timer
    case tasks
    case projects
    case reports
    case settings

    var id: String { rawValue }

    var title: String {
        switch self {
        case .today: return "Today"
        case .timer: return "Timer"
        case .tasks: return "Tasks"
        case .projects: return "Projects"
        case .reports: return "Reports"
        case .settings: return "Settings"
        }
    }

    var systemImage: String {
        switch self {
        case .today: return "sun.max"
        case .timer: return "timer"
        case .tasks: return "checklist"
        case .projects: return "square.stack.3d.up"
        case .reports: return "chart.bar.xaxis"
        case .settings: return "gearshape"
        }
    }
}

struct Banner: Identifiable, Equatable {
    enum Kind {
        case info
        case success
        case warning
    }

    let id = UUID()
    let text: String
    let kind: Kind
}

struct TaskEditorRequest: Identifiable {
    let id = UUID()
    let task: PlanTask?
    let projectID: UUID?
}

struct ProjectEditorRequest: Identifiable {
    let id = UUID()
    let project: Project?
}

struct PendingTaskSwitch: Identifiable {
    let id = UUID()
    let taskID: UUID?
    let taskTitle: String
}

// MARK: - App model

@MainActor
final class AppModel: ObservableObject {
    @Published private(set) var database: AppDatabase
    @Published var selectedSidebar: SidebarItem? = .today
    @Published var taskSearchText = ""
    @Published var taskScope: TaskScope = .active
    @Published var taskProjectFilter: UUID?
    @Published var now = Date()
    @Published var banner: Banner?
    @Published var pendingTaskEditor: TaskEditorRequest?
    @Published var pendingProjectEditor: ProjectEditorRequest?
    @Published var pendingSwitch: PendingTaskSwitch?
    @Published var pendingImportedDatabase: AppDatabase?
    @Published var reportRange: ReportRange
    @Published var reportProjectFilter: UUID?
    @Published var searchFocusRequest = 0

    let store: DatabaseStore
    let soundPlayer = SoundPlayer()
    let notifications = NotificationManager()

    private var ticker: DispatchSourceTimer?
    private var saveWorkItem: DispatchWorkItem?
    var autoStartWorkItem: DispatchWorkItem?
    private var terminateObserver: NSObjectProtocol?
    private var keyMonitor: Any?
    private var dataIsReadOnly = false
    private(set) var dataReadOnlyMessage: String?
    private var lastIdleRefresh = Date()

    // MARK: Init

    init(store: DatabaseStore = DatabaseStore()) {
        self.store = store
        let outcome = store.load()
        var initial = AppDatabase()
        var startupMessage: String?
        var readOnlyMessage: String?
        switch outcome {
        case .loaded(let loaded):
            initial = loaded
        case .fresh(let fresh):
            initial = fresh
        case .recovered(let recovered, let message):
            initial = recovered
            startupMessage = message
        case .unsupported(let version):
            readOnlyMessage = "This data file uses format version \(version), which this version of iPomo cannot read. Update iPomo. Changes made now are not saved; import or reset from Settings to replace the file."
        case .unreadable(let message):
            readOnlyMessage = "The data file could not be read: \(message). Changes made now are not saved; fix the file permissions or import a backup."
        }
        self.database = initial
        self.reportRange = initial.settings.reports.defaultRange
        self.dataIsReadOnly = readOnlyMessage != nil
        self.dataReadOnlyMessage = readOnlyMessage

        startTicker()
        restoreTimerIfNeeded()
        if let readOnlyMessage {
            startupMessage = readOnlyMessage
        }
        if let startupMessage {
            showBanner(startupMessage, kind: .warning)
        }

        terminateObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.willTerminateNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.flush()
            }
        }

        installSpacebarMonitor()
    }

    deinit {
        ticker?.cancel()
        saveWorkItem?.cancel()
        autoStartWorkItem?.cancel()
        if let keyMonitor {
            NSEvent.removeMonitor(keyMonitor)
        }
        if let terminateObserver {
            NotificationCenter.default.removeObserver(terminateObserver)
        }
    }

    /// Space starts/pauses the timer whenever the app is active and the user is
    /// not typing in a text control or interacting with a sheet/modal.
    private func installSpacebarMonitor() {
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self else { return event }
            guard event.keyCode == 49,
                  !event.isARepeat,
                  event.modifierFlags.intersection([.command, .control, .option, .shift]).isEmpty
            else { return event }
            guard let keyWindow = NSApp.keyWindow,
                  keyWindow === MainWindowRegistry.window else {
                return event
            }

            if NSApp.keyWindow?.attachedSheet != nil { return event }
            if NSApp.keyWindow?.isSheet == true { return event }
            if NSApp.modalWindow != nil { return event }
            if NSApp.keyWindow?.fieldEditor(false, for: nil) != nil { return event }
            if let textView = NSApp.keyWindow?.firstResponder as? NSTextView, textView.isEditable {
                return event
            }
            if let textField = NSApp.keyWindow?.firstResponder as? NSTextField, textField.isEditable {
                return event
            }
            if NSApp.keyWindow?.firstResponder is NSControl {
                return event
            }

            Task { @MainActor in
                self.toggleTimer()
            }
            return nil
        }
    }

    // MARK: Ticker

    private func startTicker() {
        let timer = DispatchSource.makeTimerSource(queue: .main)
        timer.schedule(deadline: .now() + 0.25, repeating: 0.5, leeway: .milliseconds(100))
        timer.setEventHandler { [weak self] in
            Task { @MainActor in
                self?.tick()
            }
        }
        timer.resume()
        ticker = timer
    }

    private func tick() {
        let current = Date()
        if database.timer.isRunning || current.timeIntervalSince(lastIdleRefresh) >= 30 {
            lastIdleRefresh = current
            now = current
        }
        checkTimerCompletion()
    }

    // MARK: Propagation

    func mutate(_ mutation: (inout AppDatabase) -> Void, persist: Bool = true) {
        var copy = database
        mutation(&copy)
        copy.updatedAt = Date()
        database = copy
        if persist { scheduleSave() }
    }

    private func scheduleSave() {
        saveWorkItem?.cancel()
        let item = DispatchWorkItem { [weak self] in
            self?.persistNow()
        }
        saveWorkItem = item
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4, execute: item)
    }

    func persistNow() {
        saveWorkItem?.cancel()
        saveWorkItem = nil
        guard !dataIsReadOnly else { return }
        do {
            try store.save(database)
        } catch {
            showBanner("Could not save your data: \(error.localizedDescription)", kind: .warning)
        }
    }

    func flush() {
        persistNow()
    }

    // MARK: Banner

    func showBanner(_ text: String, kind: Banner.Kind = .info) {
        let newBanner = Banner(text: text, kind: kind)
        banner = newBanner
        Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: 4_000_000_000)
            if self?.banner?.id == newBanner.id {
                self?.banner = nil
            }
        }
    }

    // MARK: Settings

    func updateSettings(_ mutation: (inout AppSettings) -> Void) {
        mutate { database in
            mutation(&database.settings)
            database.settings.timer.clamp()
            database.settings.sound.clamp()
        }
        if database.timer.isRunning, database.timer.stage == .focus {
            soundPlayer.restartTickingIfNeeded(settings: database.settings.sound)
        }
        let notificationSettings = database.settings.notifications
        if notificationSettings.notificationsEnabled {
            notifications.requestAuthorization()
        }
        if !notificationSettings.notificationsEnabled || !notificationSettings.remindersEnabled {
            notifications.removeReminders()
        }
    }

    func binding<T>(_ keyPath: WritableKeyPath<AppSettings, T>) -> Binding<T> {
        Binding(
            get: { self.database.settings[keyPath: keyPath] },
            set: { newValue in
                self.updateSettings { settings in
                    settings[keyPath: keyPath] = newValue
                }
            }
        )
    }

    // MARK: Derived data

    var calendar: Calendar {
        CalendarFactory.calendar(weekStart: database.settings.appearance.weekStart)
    }

    var projects: [Project] {
        database.projects.sorted { $0.sortOrder < $1.sortOrder }
    }

    var activeProjects: [Project] {
        database.activeProjects
    }

    var tasks: [PlanTask] { database.tasks }

    var activeTasks: [PlanTask] {
        database.activeTasks.sorted { PlanningLogic.planSort($0, $1) }
    }

    var activeTask: PlanTask? {
        database.task(id: database.timer.activeTaskID)
    }

    var todayPlanTasks: [PlanTask] {
        PlanningLogic.todayTasks(in: database, now: now, calendar: calendar)
    }

    var projectsByID: [UUID: Project] {
        database.projectByID
    }

    var theme: AppTheme { database.settings.appearance.theme }

    func project(id: UUID?) -> Project? { database.project(id: id) }

    func task(id: UUID?) -> PlanTask? { database.task(id: id) }

    func projectProgress(_ projectID: UUID) -> ProjectProgress {
        PlanningLogic.projectProgress(tasks: database.tasks.filter { $0.projectID == projectID })
    }

    func projectTasks(_ projectID: UUID, includeCompleted: Bool = true) -> [PlanTask] {
        database.tasks
            .filter { $0.projectID == projectID && (includeCompleted || !$0.isCompleted) }
            .sorted { PlanningLogic.planSort($0, $1) }
    }

    // MARK: Task intents

    func presentNewTask(projectID: UUID? = nil) {
        pendingTaskEditor = TaskEditorRequest(task: nil, projectID: projectID ?? taskProjectFilter)
    }

    func presentEditTask(_ task: PlanTask) {
        pendingTaskEditor = TaskEditorRequest(task: task, projectID: task.projectID)
    }

    func saveTask(_ task: PlanTask) {
        let trimmed = task.title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            showBanner("A task needs a title.", kind: .warning)
            return
        }
        mutate { database in
            var updated = task
            updated.title = trimmed
            updated.notes = task.notes.trimmingCharacters(in: .whitespacesAndNewlines)
            updated.updatedAt = Date()
            if let projectID = updated.projectID, database.project(id: projectID) == nil {
                updated.projectID = nil
            }
            if let index = database.tasks.firstIndex(where: { $0.id == updated.id }) {
                database.tasks[index] = updated
            } else {
                updated.sortOrder = (database.tasks.map(\.sortOrder).max() ?? -1) + 1
                database.tasks.append(updated)
            }
        }
    }

    func createTaskQuick(title: String, projectID: UUID? = nil) {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let task = PlanTask(
            title: trimmed,
            projectID: projectID,
            estimatedPomodoros: database.settings.planning.defaultEstimatedPomodoros,
            isFocusToday: true
        )
        saveTask(task)
    }

    func deleteTask(id: UUID) {
        mutate { database in
            database.tasks.removeAll { $0.id == id }
            if database.timer.activeTaskID == id {
                database.timer.activeTaskID = nil
            }
        }
    }

    func toggleTaskCompletion(id: UUID) {
        mutate { database in
            guard let index = database.tasks.firstIndex(where: { $0.id == id }) else { return }
            let now = Date()
            database.tasks[index].isCompleted.toggle()
            database.tasks[index].updatedAt = now
            if database.tasks[index].isCompleted {
                database.tasks[index].completedAt = now
                if database.settings.behavior.moveCompletedToBottom {
                    database.tasks[index].sortOrder = (database.tasks.map(\.sortOrder).max() ?? 0) + 1
                }
            } else {
                database.tasks[index].completedAt = nil
            }
        }
    }

    func setTaskCompleted(id: UUID, completed: Bool) {
        guard let task = database.task(id: id), task.isCompleted != completed else { return }
        toggleTaskCompletion(id: id)
    }

    func setFocusToday(id: UUID, value: Bool) {
        mutate { database in
            guard let index = database.tasks.firstIndex(where: { $0.id == id }) else { return }
            database.tasks[index].isFocusToday = value
            database.tasks[index].updatedAt = Date()
        }
    }

    func duplicateTask(id: UUID) {
        guard let source = database.task(id: id) else { return }
        var copy = source
        copy.id = UUID()
        copy.title = "\(source.title) copy"
        copy.isCompleted = false
        copy.completedAt = nil
        copy.completedPomodoros = 0
        copy.createdAt = Date()
        copy.updatedAt = Date()
        copy.sortOrder = (database.tasks.map(\.sortOrder).max() ?? 0) + 1
        saveTask(copy)
    }

    func deleteCompletedTasks() {
        mutate { database in
            let completedIDs = Set(database.tasks.filter(\.isCompleted).map(\.id))
            database.tasks.removeAll { completedIDs.contains($0.id) }
            if let active = database.timer.activeTaskID, completedIDs.contains(active) {
                database.timer.activeTaskID = nil
            }
        }
        showBanner("Completed tasks deleted.", kind: .success)
    }

    func deleteAllTasks() {
        mutate { database in
            database.tasks.removeAll()
            database.timer.activeTaskID = nil
        }
        showBanner("All tasks deleted.", kind: .success)
    }

    /// Reorders the visible list while preserving the set of sortOrder values,
    /// so reordering one section cannot collide with tasks in another section.
    func reorderTasks(visibleIDs: [UUID], from source: IndexSet, to destination: Int) {
        var ordered = visibleIDs.compactMap { database.task(id: $0) }
        let orders = ordered.map(\.sortOrder).sorted()
        ordered.move(fromOffsets: source, toOffset: destination)
        mutate { database in
            for (index, task) in ordered.enumerated() {
                guard index < orders.count else { break }
                guard let taskIndex = database.tasks.firstIndex(where: { $0.id == task.id }) else { continue }
                database.tasks[taskIndex].sortOrder = orders[index]
                database.tasks[taskIndex].updatedAt = Date()
            }
        }
    }

    // MARK: Project intents

    func presentNewProject() {
        pendingProjectEditor = ProjectEditorRequest(project: nil)
    }

    func presentEditProject(_ project: Project) {
        pendingProjectEditor = ProjectEditorRequest(project: project)
    }

    func saveProject(_ project: Project) {
        let name = project.name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else {
            showBanner("A project needs a name.", kind: .warning)
            return
        }
        mutate { database in
            var updated = project
            updated.name = name
            updated.details = project.details.trimmingCharacters(in: .whitespacesAndNewlines)
            updated.updatedAt = Date()
            if let index = database.projects.firstIndex(where: { $0.id == updated.id }) {
                database.projects[index] = updated
            } else {
                updated.sortOrder = (database.projects.map(\.sortOrder).max() ?? -1) + 1
                database.projects.append(updated)
            }
        }
    }

    func deleteProject(id: UUID, deleteTasks: Bool) {
        mutate { database in
            database.projects.removeAll { $0.id == id }
            if deleteTasks {
                let removedIDs = Set(database.tasks.filter { $0.projectID == id }.map(\.id))
                database.tasks.removeAll { $0.projectID == id }
                if let active = database.timer.activeTaskID, removedIDs.contains(active) {
                    database.timer.activeTaskID = nil
                }
            } else {
                for index in database.tasks.indices where database.tasks[index].projectID == id {
                    database.tasks[index].projectID = nil
                }
            }
            if database.timer.activeTaskID != nil, database.task(id: database.timer.activeTaskID) == nil {
                database.timer.activeTaskID = nil
            }
        }
        if taskProjectFilter == id { taskProjectFilter = nil }
        showBanner("Project deleted.", kind: .success)
    }

    // MARK: Data intents

    func revealDataFolder() {
        let fileManager = FileManager.default
        try? fileManager.createDirectory(
            at: store.directoryURL,
            withIntermediateDirectories: true
        )
        if fileManager.fileExists(atPath: store.fileURL.path) {
            NSWorkspace.shared.activateFileViewerSelecting([store.fileURL])
        } else {
            NSWorkspace.shared.open(store.directoryURL)
        }
    }

    func exportBackup() {
        let panel = NSSavePanel()
        panel.title = "Export iPomo Backup"
        panel.nameFieldStringValue = "iPomo-Backup-\(Self.fileStamp()).json"
        panel.allowedContentTypes = [.json]
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            let data = try store.encode(database)
            try data.write(to: url, options: .atomic)
            showBanner("Backup exported.", kind: .success)
        } catch {
            showBanner("Backup export failed: \(error.localizedDescription)", kind: .warning)
        }
    }

    func chooseImportBackup() {
        let panel = NSOpenPanel()
        panel.title = "Import iPomo Backup"
        panel.allowedContentTypes = [.json]
        panel.allowsMultipleSelection = false
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            let data = try Data(contentsOf: url)
            let imported = try store.decode(data)
            pendingImportedDatabase = imported
        } catch {
            showBanner("Import failed: \(error.localizedDescription)", kind: .warning)
        }
    }

    func applyImportedDatabase() {
        guard var imported = pendingImportedDatabase else { return }
        imported.normalize()
        store.backupIfNeeded(force: true)
        dataIsReadOnly = false
        dataReadOnlyMessage = nil
        database = imported
        reportRange = imported.settings.reports.defaultRange
        reportProjectFilter = nil
        taskProjectFilter = nil
        pendingImportedDatabase = nil
        stopTimerForDataChange()
        persistNow()
        showBanner("Backup imported.", kind: .success)
    }

    func resetAllData() {
        store.backupIfNeeded(force: true)
        dataIsReadOnly = false
        dataReadOnlyMessage = nil
        let fresh = AppDatabase()
        database = fresh
        reportRange = fresh.settings.reports.defaultRange
        reportProjectFilter = nil
        taskProjectFilter = nil
        stopTimerForDataChange()
        persistNow()
        showBanner("All data has been reset.", kind: .success)
    }

    private static func fileStamp() -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyyMMdd-HHmm"
        return formatter.string(from: Date())
    }
}
