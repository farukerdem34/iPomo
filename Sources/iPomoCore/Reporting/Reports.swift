import Foundation

public struct ProjectFocusTotal: Identifiable, Sendable {
    public let id: String
    public let projectID: UUID?
    public let name: String
    public let colorHex: String
    public let seconds: Int
    public let sessionCount: Int
    public var share: Double

    public var minutes: Int { Int((Double(seconds) / 60.0).rounded()) }
}

public struct ReportBucket: Identifiable, Sendable {
    public let start: Date
    public let label: String
    public let seconds: Int

    public var id: Date { start }
    public var minutes: Int { Int((Double(seconds) / 60.0).rounded()) }
}

public struct ReportSummary: Sendable {
    public let range: ReportRange
    public let interval: DateInterval
    public let totalFocusSeconds: Int
    public let focusSessionCount: Int
    public let completedTaskCount: Int
    public let daysAccessed: Int
    public let currentStreak: Int
    public let longestStreak: Int
    public let buckets: [ReportBucket]
    public let projectTotals: [ProjectFocusTotal]
    public let sessions: [FocusSession]

    public var totalFocusMinutes: Int { Int((Double(totalFocusSeconds) / 60.0).rounded()) }
    public var averageDailySeconds: Int {
        guard daysAccessed > 0 else { return 0 }
        return totalFocusSeconds / daysAccessed
    }

    public var topProject: ProjectFocusTotal? { projectTotals.first }
}

public enum ReportAggregator {
    public static func summary(
        database: AppDatabase,
        range: ReportRange,
        projectFilter: UUID? = nil,
        now: Date = Date(),
        calendar: Calendar
    ) -> ReportSummary {
        let interval = range.dateInterval(now: now, calendar: calendar)
        let allFocusSessions = database.sessions.filter(\.isFocus)
        let filtered = allFocusSessions.filter { session in
            guard interval.contains(session.endedAt) else { return false }
            if let projectFilter {
                return session.projectID == projectFilter
            }
            return true
        }

        let totalSeconds = filtered.reduce(0) { $0 + max(0, $1.actualSeconds) }
        let days = Set(filtered.map { calendar.startOfDay(for: $0.endedAt) })
        let streaks = streakValues(sessions: allFocusSessions, now: now, calendar: calendar)
        let buckets = makeBuckets(
            range: range,
            interval: interval,
            sessions: filtered,
            now: now,
            calendar: calendar
        )
        let projectTotals = makeProjectTotals(
            sessions: filtered,
            projects: database.projects,
            totalSeconds: totalSeconds
        )
        let completedTasks = database.tasks.filter { task in
            guard let completedAt = task.completedAt else { return false }
            guard interval.contains(completedAt) else { return false }
            if let projectFilter {
                return task.projectID == projectFilter
            }
            return true
        }

        return ReportSummary(
            range: range,
            interval: interval,
            totalFocusSeconds: totalSeconds,
            focusSessionCount: filtered.count,
            completedTaskCount: completedTasks.count,
            daysAccessed: days.count,
            currentStreak: streaks.current,
            longestStreak: streaks.longest,
            buckets: buckets,
            projectTotals: projectTotals,
            sessions: filtered.sorted { $0.endedAt > $1.endedAt }
        )
    }

    public static func makeBuckets(
        range: ReportRange,
        interval: DateInterval,
        sessions: [FocusSession],
        now: Date,
        calendar: Calendar
    ) -> [ReportBucket] {
        let starts = range.bucketStarts(now: now, calendar: calendar)
        var totals: [Date: Int] = [:]
        for start in starts { totals[start] = 0 }

        for session in sessions {
            let bucket = range.bucketStart(for: session.endedAt, calendar: calendar)
            guard totals[bucket] != nil else { continue }
            totals[bucket, default: 0] += max(0, session.actualSeconds)
        }

        return starts.map { start in
            ReportBucket(
                start: start,
                label: range.bucketLabel(for: start, calendar: calendar),
                seconds: totals[start] ?? 0
            )
        }
    }

    public static func makeProjectTotals(
        sessions: [FocusSession],
        projects: [Project],
        totalSeconds: Int
    ) -> [ProjectFocusTotal] {
        let projectIndex = Dictionary(uniqueKeysWithValues: projects.map { ($0.id, $0) })
        var secondsByKey: [String: Int] = [:]
        var sessionsByKey: [String: Int] = [:]
        var nameByKey: [String: String] = [:]
        var projectIDByKey: [String: UUID?] = [:]

        for session in sessions {
            let key = session.projectID?.uuidString ?? "inbox"
            secondsByKey[key, default: 0] += max(0, session.actualSeconds)
            sessionsByKey[key, default: 0] += 1
            if let project = projectIndex[session.projectID ?? UUID()] {
                nameByKey[key] = project.name
            } else {
                nameByKey[key] = session.projectName.isEmpty ? "No Project" : session.projectName
            }
            projectIDByKey[key] = session.projectID
        }

        return secondsByKey.keys.compactMap { key -> ProjectFocusTotal? in
            guard let seconds = secondsByKey[key] else { return nil }
            let projectID = projectIDByKey[key] ?? nil
            let project = projectID.flatMap { projectIndex[$0] }
            let name = project?.name ?? nameByKey[key] ?? "No Project"
            let color = project?.colorHex ?? "#6B7280"
            let share = totalSeconds > 0 ? Double(seconds) / Double(totalSeconds) : 0
            return ProjectFocusTotal(
                id: key,
                projectID: projectID,
                name: name,
                colorHex: color,
                seconds: seconds,
                sessionCount: sessionsByKey[key] ?? 0,
                share: share
            )
        }
        .sorted { $0.seconds > $1.seconds }
    }

    /// Current and longest streak of consecutive days with at least one focus session.
    public static func streakValues(
        sessions: [FocusSession],
        now: Date,
        calendar: Calendar
    ) -> (current: Int, longest: Int) {
        let dayStarts = Set(sessions.map { calendar.startOfDay(for: $0.endedAt) })
        guard !dayStarts.isEmpty else { return (0, 0) }

        let today = calendar.startOfDay(for: now)
        var cursor = today
        var current = 0
        if !dayStarts.contains(today) {
            guard let yesterday = calendar.date(byAdding: .day, value: -1, to: today) else {
                return (0, 0)
            }
            cursor = yesterday
        }
        while dayStarts.contains(cursor) {
            current += 1
            guard let previous = calendar.date(byAdding: .day, value: -1, to: cursor) else { break }
            cursor = previous
        }

        let sortedDays = dayStarts.sorted()
        var longest = 1
        var run = 1
        for index in 1..<sortedDays.count {
            let previous = sortedDays[index - 1]
            let day = sortedDays[index]
            if let expected = calendar.date(byAdding: .day, value: 1, to: previous),
               calendar.isDate(expected, inSameDayAs: day) {
                run += 1
            } else {
                run = 1
            }
            longest = max(longest, run)
        }
        return (current, longest)
    }
}

// MARK: - CSV

public enum ReportCSV {
    public static func makeCSV(sessions: [FocusSession], calendar: Calendar) -> String {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = calendar.timeZone
        formatter.dateFormat = "yyyy-MM-dd"
        let timeFormatter = DateFormatter()
        timeFormatter.calendar = calendar
        timeFormatter.locale = Locale(identifier: "en_US_POSIX")
        timeFormatter.timeZone = calendar.timeZone
        timeFormatter.dateFormat = "HH:mm"

        var lines = ["Date,Start,End,Task,Project,Stage,Minutes,Completed,Manual"]
        let sorted = sessions.sorted { $0.endedAt < $1.endedAt }
        for session in sorted {
            let columns = [
                formatter.string(from: session.endedAt),
                timeFormatter.string(from: session.startedAt),
                timeFormatter.string(from: session.endedAt),
                session.taskTitle,
                session.projectName,
                session.stage.title,
                String(session.minutes),
                session.completed ? "yes" : "no",
                session.isManual ? "yes" : "no",
            ]
            lines.append(columns.map(escape).joined(separator: ","))
        }
        return lines.joined(separator: "\n") + "\n"
    }

    public static func escape(_ value: String) -> String {
        let guarded = value.first.map { "=+-@".contains($0) } == true ? "'" + value : value
        let needsQuoting = guarded.contains(",") || guarded.contains("\"") || guarded.contains("\n") || guarded.contains("\r")
        let escaped = guarded.replacingOccurrences(of: "\"", with: "\"\"")
        return needsQuoting ? "\"\(escaped)\"" : escaped
    }
}
