import Charts
import iPomoCore
import SwiftUI

struct ReportsView: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.editorialAccent) private var accent
    @State private var showManualEntry = false
    @State private var sessionToDelete: FocusSession?

    private var summary: ReportSummary {
        model.currentReportSummary
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DesignTokens.s4) {
                header
                controls
                MetricLedger(metrics: metrics)
                chartSection
                HStack(alignment: .top, spacing: DesignTokens.s5) {
                    projectSection
                        .frame(maxWidth: .infinity, alignment: .topLeading)
                    sessionSection
                        .frame(maxWidth: .infinity, alignment: .topLeading)
                }
            }
            .editorialPagePadding()
        }
        .editorialBackground()
        .navigationTitle("Reports")
        .sheet(isPresented: $showManualEntry) {
            ManualSessionSheet()
                .environmentObject(model)
        }
        .confirmationDialog(
            "Delete this focus entry?",
            isPresented: Binding(
                get: { sessionToDelete != nil },
                set: { if !$0 { sessionToDelete = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                if let session = sessionToDelete {
                    model.deleteSession(id: session.id)
                }
                sessionToDelete = nil
            }
            Button("Cancel", role: .cancel) { sessionToDelete = nil }
        } message: {
            Text("The entry will be removed from reports.")
        }
    }

    private var header: some View {
        HStack(alignment: .top, spacing: DesignTokens.s4) {
            PageTitle(
                eyebrow: "Insight",
                title: "Reports",
                detail: rangeSubtitle
            )
            Spacer()
            Button {
                showManualEntry = true
            } label: {
                Label("Add Entry", systemImage: "plus")
            }
            .buttonStyle(EditorialSecondaryButtonStyle())
            Button {
                model.exportCSV()
            } label: {
                Label("Export CSV", systemImage: "square.and.arrow.up")
            }
            .buttonStyle(EditorialPrimaryButtonStyle())
            .disabled(summary.sessions.isEmpty)
        }
    }

    private var controls: some View {
        HStack(alignment: .center, spacing: DesignTokens.s4) {
            EditorialTabs(
                items: ReportRange.allCases,
                title: { $0.title },
                selection: $model.reportRange,
                spacing: DesignTokens.s4
            )
            Spacer()
            Menu {
                Button("All Projects") { model.reportProjectFilter = nil }
                Divider()
                ForEach(model.projects) { project in
                    Button(project.name) { model.reportProjectFilter = project.id }
                }
            } label: {
                HStack(spacing: 6) {
                    if let id = model.reportProjectFilter, let project = model.project(id: id) {
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

    private var rangeSubtitle: String {
        let start = AppFormat.shortDate(summary.interval.start, calendar: model.calendar)
        let end = AppFormat.shortDate(summary.interval.end.addingTimeInterval(-1), calendar: model.calendar)
        return "\(start) – \(end) · \(summary.totalFocusMinutes) minutes focused"
    }

    private var metrics: [LedgerMetric] {
        [
            LedgerMetric(
                label: "Focus time",
                value: AppFormat.duration(seconds: summary.totalFocusSeconds),
                detail: "\(summary.focusSessionCount) sessions"
            ),
            LedgerMetric(
                label: "Active days",
                value: "\(summary.daysAccessed)",
                detail: "Avg \(AppFormat.duration(seconds: summary.averageDailySeconds))"
            ),
            LedgerMetric(
                label: "Tasks completed",
                value: "\(summary.completedTaskCount)",
                detail: "In this range"
            ),
            LedgerMetric(
                label: "Overall streak",
                value: "\(summary.currentStreak) days",
                detail: "Longest \(summary.longestStreak)"
            ),
        ]
    }

    private var chartSection: some View {
        VStack(alignment: .leading, spacing: DesignTokens.s3) {
            HStack(alignment: .firstTextBaseline) {
                SectionHeading(
                    overline: "Focus",
                    title: "Focus by \(bucketUnit)",
                    detail: summary.topProject.map { "Top project · \($0.name)" }
                )
                Spacer()
            }
            Hairline()
            if summary.totalFocusSeconds == 0 {
                EditorialEmptyState(
                    overline: "No focus yet",
                    title: "The chart is waiting",
                    message: "Run a timer or add a manual entry to build this report.",
                    actionTitle: "Add entry",
                    action: { showManualEntry = true }
                )
            } else {
                Chart(summary.buckets) { bucket in
                    BarMark(
                        x: .value("Period", bucket.label),
                        y: .value("Minutes", bucket.minutes)
                    )
                    .foregroundStyle(accent)
                    .cornerRadius(2)
                }
                .chartYAxis {
                    AxisMarks(position: .leading) { value in
                        AxisGridLine().foregroundStyle(DesignTokens.hairline)
                        AxisValueLabel()
                            .font(Typography.caption(10))
                            .foregroundStyle(DesignTokens.inkTertiary)
                    }
                }
                .chartXAxis {
                    AxisMarks { value in
                        AxisValueLabel()
                            .font(Typography.caption(10))
                            .foregroundStyle(DesignTokens.inkTertiary)
                    }
                }
                .frame(height: 230)
                .padding(.top, DesignTokens.s2)
            }
        }
    }

    private var bucketUnit: String {
        switch summary.range {
        case .today: return "session"
        case .week: return "day"
        case .month: return "week"
        case .year: return "month"
        }
    }

    private var projectSection: some View {
        VStack(alignment: .leading, spacing: DesignTokens.s2) {
            SectionHeading(overline: "Projects", title: "Where time went")
            Hairline()
            if summary.projectTotals.isEmpty {
                Text("No project time in this range.")
                    .font(Typography.body(13))
                    .foregroundStyle(DesignTokens.inkTertiary)
                    .padding(.vertical, DesignTokens.s2)
            } else {
                ForEach(summary.projectTotals) { total in
                    HStack(spacing: DesignTokens.s2) {
                        ProjectDot(hex: total.colorHex, size: 8)
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text(total.name)
                                    .font(Typography.bodyMedium(13))
                                    .foregroundStyle(DesignTokens.ink)
                                    .lineLimit(1)
                                Spacer()
                                Text(AppFormat.duration(seconds: total.seconds))
                                    .font(Typography.caption(11))
                                    .monospacedDigit()
                                    .foregroundStyle(DesignTokens.inkSecondary)
                                Text("\(Int((total.share * 100).rounded()))%")
                                    .font(Typography.caption(10))
                                    .monospacedDigit()
                                    .foregroundStyle(DesignTokens.inkTertiary)
                                    .frame(width: 34, alignment: .trailing)
                            }
                            ProgressView(value: total.share)
                                .progressViewStyle(EditorialProgressViewStyle(
                                    fill: Color(hex: total.colorHex),
                                    height: 3
                                ))
                        }
                    }
                    .padding(.vertical, 6)
                }
            }
        }
    }

    private var sessionSection: some View {
        VStack(alignment: .leading, spacing: DesignTokens.s2) {
            HStack(alignment: .firstTextBaseline) {
                SectionHeading(overline: "Detail", title: "Focus sessions")
                Spacer()
                Text("\(summary.sessions.count)")
                    .font(Typography.caption(11))
                    .foregroundStyle(DesignTokens.inkTertiary)
            }
            Hairline()
            if summary.sessions.isEmpty {
                Text("No sessions in this range.")
                    .font(Typography.body(13))
                    .foregroundStyle(DesignTokens.inkTertiary)
                    .padding(.vertical, DesignTokens.s2)
            } else {
                HStack {
                    Text("Date").frame(width: 72, alignment: .leading)
                    Text("Task").frame(maxWidth: .infinity, alignment: .leading)
                    Text("Project").frame(width: 110, alignment: .leading)
                    Text("Min").frame(width: 40, alignment: .trailing)
                    Text("").frame(width: 24)
                }
                .font(Typography.overline(9))
                .tracking(0.7)
                .foregroundStyle(DesignTokens.inkTertiary)
                .padding(.vertical, 4)
                Hairline()
                ForEach(summary.sessions) { session in
                    SessionRow(session: session, onDelete: { sessionToDelete = session })
                    Hairline()
                }
            }
        }
    }
}

private struct SessionRow: View {
    @EnvironmentObject private var model: AppModel
    let session: FocusSession
    let onDelete: () -> Void
    @State private var hovering = false

    var body: some View {
        HStack(alignment: .center) {
            Text(AppFormat.shortDate(session.endedAt, calendar: model.calendar))
                .frame(width: 72, alignment: .leading)
                .foregroundStyle(DesignTokens.inkSecondary)
            HStack(spacing: 6) {
                Text(session.taskTitle)
                    .foregroundStyle(DesignTokens.ink)
                    .lineLimit(1)
                if session.isManual {
                    EditorialTag(text: "Manual", color: DesignTokens.slate)
                }
                if !session.completed {
                    EditorialTag(text: "Partial", color: DesignTokens.warning)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            Text(session.projectName)
                .foregroundStyle(DesignTokens.inkSecondary)
                .lineLimit(1)
                .frame(width: 110, alignment: .leading)
            Text("\(session.minutes)")
                .monospacedDigit()
                .foregroundStyle(DesignTokens.inkSecondary)
                .frame(width: 40, alignment: .trailing)
            Button {
                onDelete()
            } label: {
                Image(systemName: "trash")
                    .font(.system(size: 10))
                    .foregroundStyle(DesignTokens.inkTertiary)
                    .frame(width: 24, height: 24)
            }
            .buttonStyle(.plain)
            .opacity(hovering ? 1 : 0)
            .help("Delete focus entry")
        }
        .font(Typography.body(12))
        .padding(.vertical, 7)
        .background(hovering ? DesignTokens.surfaceMuted.opacity(0.3) : Color.clear)
        .onHover { hovering = $0 }
    }
}
