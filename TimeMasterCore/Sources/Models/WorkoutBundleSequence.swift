import Foundation

extension WorkoutSetSlotManifest {
    public var playbackRest: Int { restRow?.duration ?? restAfter }
}

extension WorkoutSectionManifest {
    public var calculatedDuration: Int {
        let sequence = playbackSlots()
        return sequence.enumerated().reduce(0) { total, entry in
            total + (entry.element.prepareTime ?? prepareTime) + entry.element.duration
                + (entry.offset + 1 < sequence.count ? entry.element.playbackRest : 0)
        }
    }

    public func playbackSlots(order: [String]? = nil) -> [WorkoutSetSlotManifest] {
        mode == .bundle ? bundlePlaybackSlots(order: order) : timedPlaybackSlots()
    }

    public func timedPlaybackSlots() -> [WorkoutSetSlotManifest] {
        (slots.isEmpty ? generatedSlots : slots).flatMap { slot -> [WorkoutSetSlotManifest] in
            var plain = slot
            plain.children = []
            return Self.expandingDrops(plain)
        }
    }

    public func bundlePlaybackSlots(order: [String]? = nil) -> [WorkoutSetSlotManifest] {
        let rawSlots = slots.isEmpty ? generatedSlots : slots
        let sets: [WorkoutSetSlotManifest]
        if !slots.isEmpty, rawSlots.allSatisfy({ $0.children.isEmpty }) {
            sets = [WorkoutSetSlotManifest(
                id: id, exerciseID: "", name: "Set 1", restAfter: 0,
                prepareTime: rawSlots.first?.prepareTime ?? prepareTime, children: rawSlots
            )]
        } else {
            sets = rawSlots
        }
        let ranks = Dictionary((order ?? []).enumerated().map { ($0.element, $0.offset) }, uniquingKeysWith: min)
        var result: [WorkoutSetSlotManifest] = []
        for (setIndex, set) in sets.enumerated() {
            var units = bundleUnits(set)
            if !ranks.isEmpty {
                units = units.enumerated().sorted { left, right in
                    let lhs = ranks[left.element[0].id] ?? Int.max
                    let rhs = ranks[right.element[0].id] ?? Int.max
                    return lhs == rhs ? left.offset < right.offset : lhs < rhs
                }.map(\.element)
            }
            var exercises = units.flatMap { $0 }
            guard !exercises.isEmpty else { continue }
            exercises[0].prepareTime = set.prepareTime ?? prepareTime
            if let last = exercises.indices.last {
                let rest = setIndex + 1 < sets.count ? set.playbackRest : 0
                exercises[last].restAfter = rest
                if rest > 0 {
                    var row = set.restRow ?? WorkoutRestRowManifest(duration: rest)
                    row.duration = rest
                    exercises[last].restRow = row
                    exercises[last].restExerciseID = set.restExerciseID
                } else {
                    exercises[last].restRow = nil
                    exercises[last].restExerciseID = nil
                }
            }
            result.append(contentsOf: exercises)
        }
        return result
    }

    private var generatedSlots: [WorkoutSetSlotManifest] {
        (0..<sets).map { index in
            WorkoutSetSlotManifest(
                id: "\(id)-set-\(index)", exerciseID: exerciseID, name: name,
                duration: duration, restAfter: index + 1 < sets ? restBetweenSets : 0
            )
        }
    }

    private func bundleUnits(_ slot: WorkoutSetSlotManifest) -> [[WorkoutSetSlotManifest]] {
        if !slot.children.isEmpty {
            return slot.children.flatMap { bundleUnits($0) }
        }
        var leaf = slot
        leaf.children = []
        leaf.prepareTime = slot.prepareTime ?? 0
        return [Self.expandingDrops(leaf)]
    }

    private static func expandingDrops(_ slot: WorkoutSetSlotManifest) -> [WorkoutSetSlotManifest] {
        guard !slot.drops.isEmpty else { return [slot] }
        let rest = slot.playbackRest
        var main = slot
        main.drops = []
        main.restAfter = 0
        main.restRow = nil
        main.restExerciseID = nil
        var result = [main]
        for (index, drop) in slot.drops.enumerated() {
            let isLast = index + 1 == slot.drops.count
            var item = WorkoutSetSlotManifest(
                id: drop.id, exerciseID: drop.exerciseID, name: drop.name, alias: drop.alias,
                duration: drop.duration, restAfter: drop.restAfter + (isLast ? rest : 0), prepareTime: 0
            )
            if isLast {
                item.restExerciseID = slot.restExerciseID
                if var row = slot.restRow {
                    row.duration = item.restAfter
                    item.restRow = row
                }
            }
            result.append(item)
        }
        return result
    }
}
