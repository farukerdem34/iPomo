import Foundation

public enum UpdateVersion {
    /// Returns true when `candidate` is a newer dotted version than `current`.
    /// Returns false when either side has no numeric version component.
    public static func isNewer(_ candidate: String, than current: String) -> Bool {
        guard let candidateParts = parts(candidate),
              let currentParts = parts(current) else { return false }
        for index in 0..<max(candidateParts.count, currentParts.count) {
            let lhs = index < candidateParts.count ? candidateParts[index] : 0
            let rhs = index < currentParts.count ? currentParts[index] : 0
            if lhs != rhs { return lhs > rhs }
        }
        return false
    }

    private static func parts(_ version: String) -> [Int]? {
        var text = version.trimmingCharacters(in: .whitespacesAndNewlines)
        if text.hasPrefix("v") || text.hasPrefix("V") { text.removeFirst() }
        if let suffix = text.firstIndex(where: { $0 == "-" || $0 == "+" }) {
            text = String(text[..<suffix])
        }
        let components = text.split(separator: ".", omittingEmptySubsequences: false)
        guard !components.isEmpty else { return nil }
        var numbers: [Int] = []
        numbers.reserveCapacity(components.count)
        for component in components {
            let digits = component.prefix { $0.isASCII && $0.isNumber }
            guard !digits.isEmpty, let number = Int(digits) else { return nil }
            numbers.append(number)
        }
        return numbers
    }
}
