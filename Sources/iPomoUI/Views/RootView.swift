import iPomoCore
import SwiftUI

struct RootView: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        NavigationSplitView {
            SidebarView()
                .navigationSplitViewColumnWidth(min: 220, ideal: DesignTokens.sidebarWidth, max: 264)
        } detail: {
            detailView
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(DesignTokens.canvas)
        }
        .frame(minWidth: 1_080, minHeight: 680)
        .background(DesignTokens.canvas)
        .environment(\.editorialAccent, ThemeColors.accent(model.theme))
        .tint(ThemeColors.accent(model.theme))
        .preferredColorScheme(preferredScheme)
        .sheet(item: $model.pendingTaskEditor) { request in
            TaskEditorView(request: request)
                .environmentObject(model)
        }
        .sheet(item: $model.pendingProjectEditor) { request in
            ProjectEditorView(request: request)
                .environmentObject(model)
        }
        .alert(
            "Switch task?",
            isPresented: Binding(
                get: { model.pendingSwitch != nil },
                set: { if !$0 { model.pendingSwitch = nil } }
            )
        ) {
            Button("Switch") {
                if let request = model.pendingSwitch {
                    model.confirmTaskSwitch(request)
                }
            }
            Button("Cancel", role: .cancel) {
                model.cancelTaskSwitch()
            }
        } message: {
            Text("The current focus round will be reset for “\(model.pendingSwitch?.taskTitle ?? "the new task")”.")
        }
        .overlay(alignment: .top) {
            if let banner = model.banner {
                BannerView(banner: banner)
                    .padding(.top, DesignTokens.s3)
                    .padding(.horizontal, DesignTokens.s4)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .animation(.easeInOut(duration: 0.2), value: model.banner?.id)
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase != .active {
                model.flush()
            }
        }
    }

    @ViewBuilder
    private var detailView: some View {
        switch model.selectedSidebar ?? .today {
        case .today:
            DashboardView()
        case .timer:
            TimerView()
        case .tasks:
            TasksView()
        case .projects:
            ProjectsView()
        case .reports:
            ReportsView()
        case .settings:
            SettingsView(embedded: true)
        }
    }

    private var preferredScheme: ColorScheme? {
        guard model.database.settings.appearance.darkModeWhenRunning,
              model.isTimerRunning else { return nil }
        return .dark
    }
}

struct SidebarView: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.editorialAccent) private var accent

    private let planItems: [SidebarItem] = [.today, .timer, .tasks, .projects, .reports]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            brand
            ScrollView {
                VStack(alignment: .leading, spacing: DesignTokens.s4) {
                    sidebarSection("Plan", items: planItems)
                    sidebarSection("App", items: [.settings])
                }
                .padding(.horizontal, DesignTokens.s2)
                .padding(.top, DesignTokens.s4)
                .padding(.bottom, DesignTokens.s4)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(DesignTokens.sidebar)
    }

    private var brand: some View {
        HStack(spacing: 10) {
            PomoMark(size: 24)
            Text("iPomo")
                .font(Typography.title(20))
                .foregroundStyle(DesignTokens.ink)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, DesignTokens.s3)
        .padding(.top, DesignTokens.s4)
        .padding(.bottom, DesignTokens.s2)
    }

    private func sidebarSection(_ title: String, items: [SidebarItem]) -> some View {
        VStack(alignment: .leading, spacing: DesignTokens.s1) {
            Overline(title)
                .padding(.horizontal, DesignTokens.s2)
                .padding(.bottom, DesignTokens.s1)
            ForEach(items) { item in
                sidebarRow(item)
            }
        }
    }

    private func sidebarRow(_ item: SidebarItem) -> some View {
        let isSelected = model.selectedSidebar == item
        return Button {
            model.selectedSidebar = item
        } label: {
            HStack(spacing: 10) {
                Image(systemName: item.systemImage)
                    .font(.system(size: 14, weight: .medium))
                    .frame(width: 18, alignment: .center)
                Text(item.title)
                    .font(Typography.bodyMedium(14))
                Spacer(minLength: DesignTokens.s2)
                Text(shortcut(for: item))
                    .font(Typography.overline(9))
                    .foregroundStyle(isSelected ? accent.opacity(0.7) : DesignTokens.inkTertiary)
            }
            .foregroundStyle(isSelected ? accent : DesignTokens.inkSecondary)
            .padding(.horizontal, DesignTokens.s2)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(isSelected ? accent.opacity(0.12) : Color.clear)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func shortcut(for item: SidebarItem) -> String {
        switch item {
        case .today: return "⌘1"
        case .timer: return "⌘2"
        case .tasks: return "⌘3"
        case .projects: return "⌘4"
        case .reports: return "⌘5"
        case .settings: return "⌘6"
        }
    }
}

struct BannerView: View {
    let banner: Banner

    var body: some View {
        HStack(spacing: 10) {
            Circle()
                .fill(tint)
                .frame(width: 7, height: 7)
            Text(banner.text)
                .font(Typography.body(13))
                .foregroundStyle(DesignTokens.ink)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
            Image(systemName: icon)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(tint)
        }
        .padding(.horizontal, DesignTokens.s3)
        .padding(.vertical, 10)
        .frame(maxWidth: 620)
        .background(
            RoundedRectangle(cornerRadius: DesignTokens.r2, style: .continuous)
                .fill(DesignTokens.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: DesignTokens.r2, style: .continuous)
                .strokeBorder(DesignTokens.hairline, lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.06), radius: 10, y: 4)
    }

    private var icon: String {
        switch banner.kind {
        case .info: return "info.circle"
        case .success: return "checkmark.circle"
        case .warning: return "exclamationmark.triangle"
        }
    }

    private var tint: Color {
        switch banner.kind {
        case .info: return DesignTokens.slate
        case .success: return DesignTokens.success
        case .warning: return DesignTokens.warning
        }
    }
}
