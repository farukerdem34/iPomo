import SwiftUI

public struct iPomoRoot: App {
    @StateObject private var model = AppModel()
    @StateObject private var themeManager = ThemeManager.shared

    public init() {}

    public var body: some Scene {
        Window("iPomo", id: "main") {
            RootView()
                .environmentObject(model)
                .environmentObject(themeManager)
                .onAppear {
                    let appearance = model.database.settings.appearance
                    themeManager.configure(
                        theme: appearance.theme,
                        customThemes: appearance.customThemes,
                        selectedCustomThemeID: appearance.selectedCustomThemeID
                    )
                }
                .onChange(of: model.database.settings.appearance.theme) { _, _ in
                    let appearance = model.database.settings.appearance
                    themeManager.configure(
                        theme: appearance.theme,
                        customThemes: appearance.customThemes,
                        selectedCustomThemeID: appearance.selectedCustomThemeID
                    )
                }
                .onChange(of: model.database.settings.appearance.customThemes) { _, _ in
                    let appearance = model.database.settings.appearance
                    themeManager.configure(
                        theme: appearance.theme,
                        customThemes: appearance.customThemes,
                        selectedCustomThemeID: appearance.selectedCustomThemeID
                    )
                }
                .onChange(of: model.database.settings.appearance.selectedCustomThemeID) { _, _ in
                    let appearance = model.database.settings.appearance
                    themeManager.configure(
                        theme: appearance.theme,
                        customThemes: appearance.customThemes,
                        selectedCustomThemeID: appearance.selectedCustomThemeID
                    )
                }
                // Inject the accent above RootView so sheets it presents
                // (task/project editors) inherit the chosen theme too.
                .environment(\.editorialAccent, resolvedAccent(model: model, themeManager: themeManager))
                .tint(resolvedAccent(model: model, themeManager: themeManager))
                .id(themeManager.revision)
        }
        .defaultSize(width: 1_180, height: 760)
        .commands {
            AppCommands(model: model)
        }

        MenuBarExtra {
            MenuBarPanel()
                .environmentObject(model)
                .environmentObject(themeManager)
                .environment(\.editorialAccent, resolvedAccent(model: model, themeManager: themeManager))
        } label: {
            MenuBarLabel()
                .environmentObject(model)
        }
        .menuBarExtraStyle(.window)

        Settings {
            SettingsView()
                .environmentObject(model)
                .environmentObject(themeManager)
                .environment(\.editorialAccent, resolvedAccent(model: model, themeManager: themeManager))
        }
    }
}

@MainActor
private func resolvedAccent(model: AppModel, themeManager: ThemeManager) -> Color {
    let appearance = model.database.settings.appearance
    if appearance.theme == .custom,
       let id = appearance.selectedCustomThemeID,
       let custom = appearance.customThemes.first(where: { $0.id == id }) {
        return ThemeColors.accent(custom: custom, isDark: NSApp?.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua)
    }
    return ThemeColors.accent(appearance.theme)
}

private struct MenuBarLabel: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        if model.database.settings.appearance.showTimerInMenuBar {
            Text(model.menuBarTitle)
                .monospacedDigit()
        } else {
            Label("iPomo", systemImage: "timer")
        }
    }
}

struct AppCommands: Commands {
    @ObservedObject var model: AppModel

    var body: some Commands {
        CommandGroup(after: .appInfo) {
            Button("Check for Updates…") {
                Task { await model.checkForUpdates() }
            }
        }

        CommandGroup(replacing: .appSettings) {
            Button("Settings…") { model.selectedSidebar = .settings }
                .keyboardShortcut(",", modifiers: [.command])
        }

        CommandGroup(replacing: .newItem) {
            Button("New Task…") {
                model.presentNewTask()
            }
            .keyboardShortcut("n", modifiers: [.command])

            Button("New Project…") {
                model.presentNewProject()
            }
            .keyboardShortcut("n", modifiers: [.command, .shift])
        }

        CommandMenu("Timer") {
            Button(model.isTimerRunning ? "Pause" : "Start") {
                model.toggleTimer()
            }
            .keyboardShortcut("p", modifiers: [.command, .option])

            Button("Skip Stage (Counts as Completed)") {
                model.skipStage()
            }
            .keyboardShortcut("]", modifiers: [.command, .shift])

            Button("Reset Round") {
                model.resetTimer()
            }
            .keyboardShortcut("r", modifiers: [.command, .shift])

            Button("Reset Cycle") {
                model.resetCycle()
            }

            Divider()

            Button("Focus") { model.selectStage(.focus) }
                .keyboardShortcut("1", modifiers: [.command, .option])
            Button("Short Break") { model.selectStage(.shortBreak) }
                .keyboardShortcut("2", modifiers: [.command, .option])
            Button("Long Break") { model.selectStage(.longBreak) }
                .keyboardShortcut("3", modifiers: [.command, .option])
        }

        CommandMenu("Navigate") {
            Button("Today") { model.selectedSidebar = .today }
                .keyboardShortcut("1", modifiers: [.command])
            Button("Timer") { model.selectedSidebar = .timer }
                .keyboardShortcut("2", modifiers: [.command])
            Button("Tasks") { model.selectedSidebar = .tasks }
                .keyboardShortcut("3", modifiers: [.command])
            Button("Projects") { model.selectedSidebar = .projects }
                .keyboardShortcut("4", modifiers: [.command])
            Button("Reports") { model.selectedSidebar = .reports }
                .keyboardShortcut("5", modifiers: [.command])
            Button("Settings") { model.selectedSidebar = .settings }
                .keyboardShortcut("6", modifiers: [.command])
        }

        CommandGroup(after: .saveItem) {
            Button("Export CSV Report…") {
                model.selectedSidebar = .reports
                model.exportCSV()
            }
            .keyboardShortcut("e", modifiers: [.command, .shift])

            Button("Export Backup…") {
                model.exportBackup()
            }
            .keyboardShortcut("b", modifiers: [.command, .shift])
        }

        CommandGroup(after: .toolbar) {
            Button("Search Tasks") {
                model.selectedSidebar = .tasks
                model.searchFocusRequest += 1
            }
            .keyboardShortcut("f", modifiers: [.command])
        }
    }
}
