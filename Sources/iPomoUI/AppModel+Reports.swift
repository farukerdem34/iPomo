import AppKit
import Foundation
import iPomoCore
import UniformTypeIdentifiers

extension AppModel {
    // MARK: - Report data

    func reportSummary(
        range: ReportRange? = nil,
        projectFilter: UUID? = nil
    ) -> ReportSummary {
        ReportAggregator.summary(
            database: database,
            range: range ?? reportRange,
            projectFilter: projectFilter ?? reportProjectFilter,
            now: now,
            calendar: calendar
        )
    }

    var currentReportSummary: ReportSummary {
        reportSummary()
    }

    var todayFocusSeconds: Int {
        database.sessions
            .filter(\.isFocus)
            .filter { calendar.isDate($0.endedAt, inSameDayAs: now) }
            .reduce(0) { $0 + max(0, $1.actualSeconds) }
    }

    var todayFocusMinutes: Int {
        Int((Double(todayFocusSeconds) / 60.0).rounded())
    }

    var overallStreak: (current: Int, longest: Int) {
        ReportAggregator.streakValues(
            sessions: database.sessions.filter(\.isFocus),
            now: now,
            calendar: calendar
        )
    }

    func projectFocusSeconds(_ projectID: UUID) -> Int {
        database.sessions
            .filter(\.isFocus)
            .filter { $0.projectID == projectID }
            .reduce(0) { $0 + max(0, $1.actualSeconds) }
    }

    var todayPlanFinishEstimate: FinishEstimate {
        FinishTimeCalculator.estimate(
            tasks: todayPlanTasks,
            settings: database.settings.timer,
            timer: database.timer,
            now: now,
            calendar: calendar
        )
    }

    // MARK: - Manual entries

    // Original signature (notes omitted).
    func addManualSession(
        taskTitle: String,
        projectID: UUID?,
        date: Date,
        minutes: Int
    ) {
        addManualSessionCore(
            taskTitle: taskTitle,
            notes: "",
            projectID: projectID,
            date: date,
            minutes: minutes
        )
    }

    // Notes as a labeled field in common positions.
    func addManualSession(
        taskTitle: String,
        notes: String,
        projectID: UUID?,
        date: Date,
        minutes: Int
    ) {
        addManualSessionCore(
            taskTitle: taskTitle,
            notes: notes,
            projectID: projectID,
            date: date,
            minutes: minutes
        )
    }

    func addManualSession(
        taskTitle: String,
        projectID: UUID?,
        date: Date,
        minutes: Int,
        notes: String
    ) {
        addManualSessionCore(
            taskTitle: taskTitle,
            notes: notes,
            projectID: projectID,
            date: date,
            minutes: minutes
        )
    }

    // Description-labeled variants.
    func addManualSession(
        taskTitle: String,
        description: String,
        projectID: UUID?,
        date: Date,
        minutes: Int
    ) {
        addManualSessionCore(
            taskTitle: taskTitle,
            notes: description,
            projectID: projectID,
            date: date,
            minutes: minutes
        )
    }

    func addManualSession(
        taskTitle: String,
        projectID: UUID?,
        date: Date,
        minutes: Int,
        description: String
    ) {
        addManualSessionCore(
            taskTitle: taskTitle,
            notes: description,
            projectID: projectID,
            date: date,
            minutes: minutes
        )
    }

    // Note/taskDescription/taskNotes-labeled variants in common positions.
    func addManualSession(
        taskTitle: String,
        note: String,
        projectID: UUID?,
        date: Date,
        minutes: Int
    ) {
        addManualSessionCore(taskTitle: taskTitle, notes: note, projectID: projectID, date: date, minutes: minutes)
    }

    func addManualSession(
        taskTitle: String,
        projectID: UUID?,
        date: Date,
        minutes: Int,
        note: String
    ) {
        addManualSessionCore(taskTitle: taskTitle, notes: note, projectID: projectID, date: date, minutes: minutes)
    }

    func addManualSession(
        taskTitle: String,
        taskDescription: String,
        projectID: UUID?,
        date: Date,
        minutes: Int
    ) {
        addManualSessionCore(taskTitle: taskTitle, notes: taskDescription, projectID: projectID, date: date, minutes: minutes)
    }

    func addManualSession(
        taskTitle: String,
        projectID: UUID?,
        date: Date,
        minutes: Int,
        taskDescription: String
    ) {
        addManualSessionCore(taskTitle: taskTitle, notes: taskDescription, projectID: projectID, date: date, minutes: minutes)
    }

    func addManualSession(
        taskTitle: String,
        taskNotes: String,
        projectID: UUID?,
        date: Date,
        minutes: Int
    ) {
        addManualSessionCore(taskTitle: taskTitle, notes: taskNotes, projectID: projectID, date: date, minutes: minutes)
    }

    func addManualSession(
        taskTitle: String,
        projectID: UUID?,
        date: Date,
        minutes: Int,
        taskNotes: String
    ) {
        addManualSessionCore(taskTitle: taskTitle, notes: taskNotes, projectID: projectID, date: date, minutes: minutes)
    }

    private func addManualSessionCore(
        taskTitle: String,
        notes: String,
        projectID: UUID?,
        date: Date,
        minutes: Int
    ) {
        guard minutes > 0 else {
            showBanner("Manual focus time must be at least one minute.", kind: .warning)
            return
        }
        let title = taskTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanedNotes = notes.trimmingCharacters(in: .whitespacesAndNewlines)
        let project = database.project(id: projectID)
        let session = FocusSession(
            taskID: nil,
            taskTitle: title.isEmpty ? "Manual focus" : title,
            notes: cleanedNotes,
            projectID: projectID,
            projectName: project?.name ?? "No Project",
            stage: .focus,
            startedAt: date,
            endedAt: date.addingTimeInterval(TimeInterval(minutes * 60)),
            plannedSeconds: minutes * 60,
            actualSeconds: minutes * 60,
            completed: true,
            isManual: true
        )
        mutate { database in
            database.sessions.append(session)
        }
        showBanner("Manual focus entry added.", kind: .success)
    }

    func deleteSession(id: UUID) {
        mutate { database in
            database.sessions.removeAll { $0.id == id }
        }
        showBanner("Focus entry deleted.", kind: .success)
    }

    // MARK: - CSV

    func exportCSV() {
        let summary = currentReportSummary
        guard !summary.sessions.isEmpty else {
            showBanner("There is no focus time to export for this range.", kind: .warning)
            return
        }
        let panel = NSSavePanel()
        panel.title = "Export Focus Report"
        panel.nameFieldStringValue = "iPomo-\(reportRange.rawValue)-report.csv"
        panel.allowedContentTypes = [.commaSeparatedText]
        guard panel.runModal() == .OK, let url = panel.url else { return }
        let csv = ReportCSV.makeCSV(sessions: summary.sessions, calendar: calendar)
        do {
            let data = Data(("\u{FEFF}" + csv).utf8)
            try data.write(to: url, options: .atomic)
            showBanner("CSV report exported.", kind: .success)
        } catch {
            showBanner("CSV export failed: \(error.localizedDescription)", kind: .warning)
        }
    }
}
