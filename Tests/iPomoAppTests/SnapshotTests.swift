import AppKit
import Foundation
import SwiftUI
import Testing
import iPomoCore
@testable import iPomoUI

/// Opt-in visual QA: set IPOMO_SNAPSHOT_DIR to a directory to render the
/// redesigned screens with ImageRenderer. Normal test runs skip this.
@Suite @MainActor
struct SnapshotTests {
    @Test func renderScreens() throws {
        guard let outputPath = ProcessInfo.processInfo.environment["IPOMO_SNAPSHOT_DIR"] else {
            return
        }
        let output = URL(fileURLWithPath: outputPath, isDirectory: true)
        try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)

        let storeDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("iPomoSnapshot-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: storeDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: storeDir) }

        let model = AppModel(store: DatabaseStore(directoryURL: storeDir))
        model.updateSettings { settings in
            settings.appearance.theme = .tomato
            settings.planning.dailyGoalMinutes = 120
            settings.sound.soundsEnabled = false
            settings.notifications.notificationsEnabled = false
        }
        let calendar = model.calendar
        let today = Date()
        let start = calendar.startOfDay(for: today)

        let work = Project(
            name: "FocusLab",
            details: "Launch the local-first planning tool.",
            colorHex: ProjectPalette.colors[0],
            dueDate: calendar.date(byAdding: .day, value: 12, to: today)
        )
        let writing = Project(
            name: "Writing",
            details: "Essays on calm software.",
            colorHex: ProjectPalette.colors[3]
        )
        let personal = Project(
            name: "Personal",
            details: "Small, deliberate tasks.",
            colorHex: ProjectPalette.colors[6]
        )
        [work, writing, personal].forEach(model.saveProject)

        let tasks = [
            PlanTask(
                title: "Write the launch note",
                notes: "Explain the local-first model and the editorial timer.",
                projectID: work.id,
                estimatedPomodoros: 2,
                completedPomodoros: 0.5,
                dueDate: today,
                priority: .high,
                isFocusToday: true
            ),
            PlanTask(
                title: "Review the onboarding copy",
                projectID: work.id,
                estimatedPomodoros: 1,
                dueDate: today,
                priority: .medium,
                isFocusToday: true
            ),
            PlanTask(
                title: "Outline the essay on quiet software",
                notes: "Start with the paper metaphor, not the feature list.",
                projectID: writing.id,
                estimatedPomodoros: 3,
                dueDate: calendar.date(byAdding: .day, value: 2, to: today),
                priority: .medium,
                isFocusToday: true
            ),
            PlanTask(
                title: "Plan the weekend walk",
                projectID: personal.id,
                estimatedPomodoros: 0.5,
                dueDate: calendar.date(byAdding: .day, value: 1, to: today),
                priority: .low,
                isFocusToday: true
            ),
            PlanTask(
                title: "Tidy the reading list",
                projectID: personal.id,
                estimatedPomodoros: 0.5,
                isFocusToday: true
            ),
            PlanTask(
                title: "Ship the icon refresh",
                projectID: work.id,
                estimatedPomodoros: 1,
                completedPomodoros: 1,
                isCompleted: true,
                completedAt: today
            ),
        ]
        tasks.forEach(model.saveTask)

        for offset in 0..<6 {
            let date = calendar.date(byAdding: .day, value: -offset, to: start.addingTimeInterval(10 * 3600)) ?? today
            model.addManualSession(
                taskTitle: offset % 2 == 0 ? "Launch note" : "Essay outline",
                projectID: offset % 2 == 0 ? work.id : writing.id,
                date: date,
                minutes: [50, 25, 75, 25, 50, 25][offset]
            )
        }
        model.reportRange = .week

        let accent = ThemeColors.accent(model.theme)
        func snap<V: View>(
            _ view: V,
            name: String,
            size: CGSize = CGSize(width: 1_000, height: 800),
            scheme: ColorScheme = .light
        ) throws {
            try render(
                view
                    .environmentObject(model)
                    .environment(\.editorialAccent, accent),
                size: size,
                name: name,
                scheme: scheme,
                in: output
            )
        }

        try snap(SidebarView(), name: "sidebar", size: CGSize(width: 232, height: 760))
        try snap(DashboardView(), name: "today")
        try snap(DashboardView(), name: "today-wide", size: CGSize(width: 1_600, height: 900))
        try snap(TimerView(), name: "timer")
        try snap(TasksView(), name: "tasks")
        try snap(ProjectsView(), name: "projects")
        try snap(ReportsView(), name: "reports")
        try snap(SettingsView(embedded: true), name: "settings", size: CGSize(width: 1_000, height: 900))
        try snap(DashboardView(), name: "today-dark", scheme: .dark)
        try snap(TimerView(), name: "timer-dark", scheme: .dark)
        try snap(SettingsView(embedded: true), name: "settings-dark", size: CGSize(width: 1_000, height: 900), scheme: .dark)

        if let task = model.database.tasks.first {
            try render(
                TaskEditorView(request: TaskEditorRequest(task: task, projectID: task.projectID))
                    .environmentObject(model)
                    .environment(\.editorialAccent, ThemeColors.accent(model.theme)),
                size: CGSize(width: 600, height: 700),
                name: "task-editor",
                in: output
            )
        }
        try render(
            ProjectEditorView(request: ProjectEditorRequest(project: work))
                .environmentObject(model)
                .environment(\.editorialAccent, ThemeColors.accent(model.theme)),
            size: CGSize(width: 580, height: 680),
            name: "project-editor",
            in: output
        )
        try render(
            ManualSessionSheet()
                .environmentObject(model)
                .environment(\.editorialAccent, ThemeColors.accent(model.theme)),
            size: CGSize(width: 480, height: 560),
            name: "manual-entry",
            in: output
        )
        try render(
            MenuBarPanel()
                .environmentObject(model)
                .environment(\.editorialAccent, ThemeColors.accent(model.theme)),
            size: CGSize(width: 306, height: 380),
            name: "menu-bar",
            in: output
        )

        let emptyProject = Project(name: "Reading", colorHex: ProjectPalette.colors[8])
        model.saveProject(emptyProject)
        model.taskProjectFilter = emptyProject.id
        try snap(TasksView(), name: "tasks-empty")
    }

    private func render<V: View>(
        _ view: V,
        size: CGSize,
        name: String,
        scheme: ColorScheme = .light,
        in directory: URL
    ) throws {
        _ = NSApplication.shared
        let hosting = NSHostingView(
            rootView: view
                .frame(width: size.width, height: size.height)
                .environment(\.colorScheme, scheme)
        )
        hosting.frame = NSRect(origin: .zero, size: size)

        let window = NSWindow(
            contentRect: NSRect(x: -12_000, y: -12_000, width: size.width, height: size.height),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        window.contentView = hosting
        window.orderBack(nil)
        hosting.layoutSubtreeIfNeeded()
        RunLoop.main.run(until: Date().addingTimeInterval(0.15))
        hosting.layoutSubtreeIfNeeded()

        guard let bitmap = hosting.bitmapImageRepForCachingDisplay(in: hosting.bounds) else {
            Issue.record("Could not create bitmap for \(name)")
            return
        }
        hosting.cacheDisplay(in: hosting.bounds, to: bitmap)
        guard let png = bitmap.representation(using: .png, properties: [:]) else {
            Issue.record("Could not encode \(name)")
            return
        }
        try png.write(to: directory.appendingPathComponent("\(name).png"), options: .atomic)
        window.orderOut(nil)
    }
}
