import Foundation

public struct WorkoutRestFoldingReport: Equatable {
    public var sections = 0
    public var fillers = 0
    public var timedSections = 0
    public var renamedSections = 0
    public var skipped: [String] = []

    public init() {}
}

public enum WorkoutRestFolding {
    public static let defaultPrefix = "Between sets"

    public static func fold(
        _ workout: inout WorkoutManifest,
        prefix: String = defaultPrefix,
        keepNames: Bool = false,
        pageDuration: (String) -> Int?
    ) -> WorkoutRestFoldingReport {
        var report = WorkoutRestFoldingReport()
        for index in workout.sections.indices {
            let section = workout.sections[index]
            guard section.mode == .bundle, section.slots.contains(where: { $0.children.contains { isFiller($0, prefix: prefix) } }) else { continue }
            let outcome = folded(section, prefix: prefix, pageDuration: pageDuration)
            guard var next = outcome.section else {
                report.skipped.append("\(workout.name) / \(section.name): \(outcome.reason ?? "unsupported shape")")
                continue
            }
            if !keepNames {
                let name = tidyName(next.name)
                if name != next.name {
                    next.name = name
                    report.renamedSections += 1
                }
            }
            workout.sections[index] = next
            report.sections += 1
            report.fillers += outcome.fillers
            if outcome.becameTimed { report.timedSections += 1 }
        }
        return report
    }

    static func isFiller(_ slot: WorkoutSetSlotManifest, prefix: String) -> Bool {
        guard slot.children.isEmpty, slot.nestedWorkoutID == nil else { return false }
        let wanted = prefix.lowercased()
        return [slot.name, slot.alias ?? ""].contains { $0.trimmingCharacters(in: .whitespaces).lowercased().hasPrefix(wanted) }
    }

    static func tidyName(_ name: String) -> String {
        guard let regex = try? NSRegularExpression(pattern: #"\s*\([^()]*\bbetween\b[^()]*\)"#, options: [.caseInsensitive]) else { return name }
        let cleaned = regex.stringByReplacingMatches(in: name, range: NSRange(name.startIndex..., in: name), withTemplate: "")
        let trimmed = cleaned.trimmingCharacters(in: CharacterSet(charactersIn: ",;·").union(.whitespacesAndNewlines))
        return trimmed.isEmpty ? name : trimmed
    }

    private struct Outcome {
        var section: WorkoutSectionManifest?
        var fillers = 0
        var becameTimed = false
        var reason: String?
    }

    private static func folded(_ section: WorkoutSectionManifest, prefix: String, pageDuration: (String) -> Int?) -> Outcome {
        func fits(_ exerciseID: String, _ seconds: Int) -> Bool {
            WorkoutRestRowManifest.canHold(exerciseSeconds: pageDuration(exerciseID), restSeconds: seconds)
        }
        var sets = section.slots
        var fillers = 0
        for setIndex in sets.indices {
            let hasNext = setIndex + 1 < sets.count
            let kids = sets[setIndex].children
            var kept: [WorkoutSetSlotManifest] = []
            var attached = Set<String>()
            var closing: (exerciseID: String, seconds: Int)?
            for (offset, kid) in kids.enumerated() {
                guard isFiller(kid, prefix: prefix) else {
                    kept.append(kid)
                    continue
                }
                guard var previous = kept.popLast() else { return Outcome(reason: "a filler comes first in a set") }
                guard !attached.contains(previous.id) else { return Outcome(reason: "two fillers in a row") }
                fillers += 1
                if offset == kids.count - 1 {
                    closing = (kid.exerciseID, previous.playbackRest + kid.duration + sets[setIndex].playbackRest)
                    previous.restAfter = 0
                    previous.restRow = nil
                    previous.restExerciseID = nil
                    previous.restExerciseAlternativeIDs = []
                } else {
                    let seconds = previous.playbackRest + kid.duration + kid.playbackRest
                    guard fits(kid.exerciseID, seconds) else { return Outcome(reason: "the rest is too short for its exercise") }
                    previous.restAfter = seconds
                    previous.restRow = WorkoutRestRowManifest(id: previous.restRow?.id ?? UUID().uuidString, duration: seconds)
                    previous.restExerciseID = kid.exerciseID
                    previous.restExerciseAlternativeIDs = []
                    attached.insert(previous.id)
                }
                kept.append(previous)
            }
            sets[setIndex].children = kept
            if let closing, hasNext {
                guard fits(closing.exerciseID, closing.seconds) else { return Outcome(reason: "the rest is too short for its exercise") }
                sets[setIndex].restAfter = closing.seconds
                sets[setIndex].restRow = WorkoutRestRowManifest(id: sets[setIndex].restRow?.id ?? UUID().uuidString, duration: closing.seconds)
                sets[setIndex].restExerciseID = closing.exerciseID
                sets[setIndex].restExerciseAlternativeIDs = []
            }
        }
        var result = section
        result.slots = sets
        if sets.count > 1 { result.restBetweenSets = sets[0].playbackRest }
        guard let first = sets.first?.children.first, first.nestedWorkoutID == nil,
              sets.allSatisfy({ $0.children.count == 1 && $0.children[0].exerciseID == first.exerciseID && $0.children[0].nestedWorkoutID == nil }) else {
            return Outcome(section: result, fillers: fillers)
        }
        result.mode = .timed
        result.exerciseID = first.exerciseID
        result.duration = max(5, first.duration)
        result.repCount = first.repCount
        result.sets = sets.count
        result.restExerciseID = sets.count > 1 ? sets[0].restExerciseID : nil
        result.restExerciseAlternativeIDs = sets.count > 1 ? sets[0].restExerciseAlternativeIDs : []
        result.slots = sets.indices.map { index in
            let set = sets[index]
            let hasRest = index + 1 < sets.count && set.playbackRest > 0
            var slot = set.children[0]
            slot.prepareTime = min(30, max(0, set.prepareTime ?? section.prepareTime))
            slot.restAfter = hasRest ? set.playbackRest : 0
            slot.restRow = hasRest ? WorkoutRestRowManifest(id: set.restRow?.id ?? UUID().uuidString, duration: set.playbackRest) : nil
            slot.restExerciseID = hasRest ? set.restExerciseID : nil
            slot.restExerciseAlternativeIDs = hasRest ? set.restExerciseAlternativeIDs : []
            return slot
        }
        return Outcome(section: result, fillers: fillers, becameTimed: true)
    }
}
