import Foundation

public enum ReportRange: String, Codable, CaseIterable, Identifiable, Sendable {
    case today
    case week
    case month
    case year

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .today: return "Today"
        case .week: return "Week"
        case .month: return "Month"
        case .year: return "Year"
        }
    }

    public func dateInterval(now: Date = Date(), calendar: Calendar) -> DateInterval {
        switch self {
        case .today:
            let start = calendar.startOfDay(for: now)
            let end = calendar.date(byAdding: .day, value: 1, to: start) ?? start.addingTimeInterval(86_400)
            return DateInterval(start: start, end: end)
        case .week:
            return calendar.dateInterval(of: .weekOfYear, for: now)
                ?? DateInterval(start: calendar.startOfDay(for: now), duration: 7 * 86_400)
        case .month:
            return calendar.dateInterval(of: .month, for: now)
                ?? DateInterval(start: calendar.startOfDay(for: now), duration: 30 * 86_400)
        case .year:
            return calendar.dateInterval(of: .year, for: now)
                ?? DateInterval(start: calendar.startOfDay(for: now), duration: 365 * 86_400)
        }
    }

    /// Bucket starts used by the bar chart. Week = days, Month = weeks, Year = months.
    public func bucketStarts(now: Date = Date(), calendar: Calendar) -> [Date] {
        let interval = dateInterval(now: now, calendar: calendar)
        let component: Calendar.Component
        switch self {
        case .today: return [calendar.startOfDay(for: now)]
        case .week: component = .day
        case .month: component = .weekOfYear
        case .year: component = .month
        }

        var buckets: [Date] = []
        var cursor = bucketStart(for: interval.start, calendar: calendar)
        var guardCount = 0
        while cursor < interval.end && guardCount < 60 {
            buckets.append(cursor)
            guard let next = calendar.date(byAdding: component, value: 1, to: cursor) else { break }
            cursor = next
            guardCount += 1
        }
        return buckets
    }

    public func bucketStart(for date: Date, calendar: Calendar) -> Date {
        switch self {
        case .today:
            return calendar.startOfDay(for: date)
        case .week:
            return calendar.startOfDay(for: date)
        case .month:
            return calendar.dateInterval(of: .weekOfYear, for: date)?.start
                ?? calendar.startOfDay(for: date)
        case .year:
            return calendar.dateInterval(of: .month, for: date)?.start
                ?? calendar.startOfDay(for: date)
        }
    }

    public func bucketLabel(for date: Date, calendar: Calendar) -> String {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.locale = .current
        switch self {
        case .today:
            return "Today"
        case .week:
            formatter.dateFormat = "EEE"
        case .month:
            formatter.dateFormat = "MMM d"
        case .year:
            formatter.dateFormat = "MMM"
        }
        return formatter.string(from: date)
    }

    public func contains(_ date: Date, now: Date = Date(), calendar: Calendar) -> Bool {
        dateInterval(now: now, calendar: calendar).contains(date)
    }
}

public enum CalendarFactory {
    public static func calendar(weekStart: WeekStart) -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = .current
        calendar.timeZone = .current
        calendar.firstWeekday = weekStart.calendarWeekday
        return calendar
    }
}
