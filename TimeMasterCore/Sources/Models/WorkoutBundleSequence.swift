import Foundation

extension WorkoutSectionManifest {
    public var calculatedDuration: Int {
        if mode == .bundle {
            let sequence = bundlePlaybackSlots()
            return sequence.enumerated().reduce(0) { total, entry in
                total + (entry.element.prepareTime ?? 0) + entry.element.duration
                    + (entry.offset + 1 < sequence.count ? entry.element.restAfter : 0)
            }
        }
        if slots.isEmpty {
            return (prepareTime + duration) * sets + restBetweenSets * max(0, sets - 1)
        }
        return slots.enumerated().reduce(0) { total, entry in
            let slot = entry.element
            let drops = slot.drops.reduce(0) { $0 + $1.duration + $1.restAfter }
            let rest = entry.offset + 1 < slots.count ? (slot.restRow?.duration ?? slot.restAfter) : 0
            return total + (slot.prepareTime ?? prepareTime) + slot.duration + drops + rest
        }
    }

    public func bundlePlaybackSlots(order: [String]? = nil) -> [WorkoutSetSlotManifest] {
        let rawSlots = slots.isEmpty ? (0..<self.sets).map { index in
            WorkoutSetSlotManifest(
                id: "\(id)-set-\(index)", exerciseID: exerciseID, name: name,
                duration: duration, restAfter: index + 1 < self.sets ? restBetweenSets : 0
            )
        } : slots
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
            var exercises = bundleLeaves(set)
            if !ranks.isEmpty {
                exercises = exercises.enumerated().sorted { left, right in
                    let lhs = ranks[left.element.id] ?? Int.max
                    let rhs = ranks[right.element.id] ?? Int.max
                    return lhs == rhs ? left.offset < right.offset : lhs < rhs
                }.map(\.element)
            }
            guard !exercises.isEmpty else { continue }
            exercises[0].prepareTime = set.prepareTime ?? prepareTime
            if let last = exercises.indices.last {
                let rest = setIndex + 1 < sets.count ? (set.restRow?.duration ?? set.restAfter) : 0
                exercises[last].restAfter = rest
                exercises[last].restRow = rest > 0 ? WorkoutRestRowManifest(duration: rest) : nil
            }
            result.append(contentsOf: exercises)
        }
        return result
    }

    private func bundleLeaves(_ slot: WorkoutSetSlotManifest) -> [WorkoutSetSlotManifest] {
        if !slot.children.isEmpty {
            return slot.children.flatMap { bundleLeaves($0) }
        }
        var leaf = slot
        leaf.children = []
        leaf.drops = []
        leaf.prepareTime = slot.prepareTime ?? 0
        leaf.restAfter = slot.restRow?.duration ?? slot.restAfter
        var result = [leaf]
        for drop in slot.drops {
            result.append(WorkoutSetSlotManifest(
                id: drop.id, exerciseID: drop.exerciseID, name: drop.name, alias: drop.alias,
                duration: drop.duration, restAfter: drop.restAfter, prepareTime: 0
            ))
        }
        return result
    }
}
