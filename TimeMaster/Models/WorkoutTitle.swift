import Foundation

enum WorkoutTitle {
    static let separator = " · "

    static func isArchived(_ name: String, groupTitle: String? = nil) -> Bool {
        if hasVersionTag(name) { return true }
        guard let groupTitle else { return false }
        return hasVersionTag(groupTitle)
            || groupTitle.range(of: "archive", options: [.caseInsensitive, .diacriticInsensitive]) != nil
    }

    static func short(_ name: String) -> String {
        var parts = name.components(separatedBy: separator)
        if parts.count > 1, isVersionTag(parts[0]) { parts.removeFirst() }
        if parts.count > 1, isPlanSlot(parts[0]) { parts.removeFirst() }
        let shortened = parts.joined(separator: separator).trimmingCharacters(in: .whitespaces)
        return shortened.isEmpty ? name : shortened
    }

    private static let weekdays: Set<String> = ["mon", "tue", "wed", "thu", "fri", "sat", "sun"]

    private static func hasVersionTag(_ title: String) -> Bool {
        guard title.contains("·"), let first = title.components(separatedBy: "·").first else { return false }
        return isVersionTag(first)
    }

    private static func isVersionTag(_ part: String) -> Bool {
        let tag = part.trimmingCharacters(in: .whitespaces).lowercased()
        guard tag.hasPrefix("v") else { return false }
        let digits = tag.dropFirst()
        return !digits.isEmpty && digits.allSatisfy(\.isNumber)
    }

    private static func isPlanSlot(_ part: String) -> Bool {
        let words = part.trimmingCharacters(in: .whitespaces).lowercased().split(separator: " ")
        guard words.count == 2 || words.count == 3 else { return false }
        let week = words[0]
        guard week.count > 1, week.hasPrefix("w"), week.dropFirst().allSatisfy(\.isNumber) else { return false }
        guard weekdays.contains(String(words[1].prefix(3))) else { return false }
        return words.count == 2 || words[2] == "am" || words[2] == "pm"
    }
}
