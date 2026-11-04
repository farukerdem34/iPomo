import Foundation

public enum TaskSearch {
    /// Local, offline task search.
    ///
    /// - searches every task;
    /// - splits on any whitespace, not a single ASCII space;
    /// - never injects the literal strings "undefined"/"null" for missing fields;
    /// - folds case, diacritics and width;
    /// - ranks title matches above project and note matches.
    public static func search(
        _ tasks: [PlanTask],
        query: String,
        projects: [UUID: Project],
        scope: TaskScope = .active,
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> [PlanTask] {
        let terms = normalizedTerms(query)
        let scoped = tasks.filter { matchesScope($0, scope: scope) }

        guard !terms.isEmpty else {
            return scoped.sorted { PlanningLogic.planSort($0, $1) }
        }

        let fullQuery = terms.joined(separator: " ")
        var scored: [(task: PlanTask, score: Int)] = []

        for task in scoped {
            let projectName = task.projectID.flatMap { projects[$0] }?.name ?? ""
            let title = normalize(task.title)
            let notes = normalize(task.notes)
            let project = normalize(projectName)
            let combined = "\(title) \(notes) \(project)"

            guard terms.allSatisfy({ combined.contains($0) }) else { continue }

            var score = 0
            if title == fullQuery { score += 200 }
            if title.hasPrefix(fullQuery) { score += 120 }
            if title.contains(fullQuery) { score += 80 }
            for term in terms {
                if title.contains(term) { score += 10 }
                if project.contains(term) { score += 4 }
                if notes.contains(term) { score += 1 }
            }
            if task.isFocusToday { score += 3 }
            score += task.priority.rawValue
            scored.append((task, score))
        }

        return scored.sorted { lhs, rhs in
            if lhs.score != rhs.score { return lhs.score > rhs.score }
            return PlanningLogic.planSort(lhs.task, rhs.task)
        }.map(\.task)
    }

    public static func matchesScope(_ task: PlanTask, scope: TaskScope) -> Bool {
        switch scope {
        case .active: return true
        case .completed: return task.isCompleted
        }
    }

    public static func normalizedTerms(_ query: String) -> [String] {
        let normalized = normalize(query)
        return normalized
            .split(whereSeparator: { $0.isWhitespace })
            .map(String.init)
            .filter { !$0.isEmpty }
    }

    public static func normalize(_ string: String) -> String {
        string
            .folding(
                options: [.caseInsensitive, .diacriticInsensitive, .widthInsensitive],
                locale: .current
            )
            .lowercased()
    }
}
