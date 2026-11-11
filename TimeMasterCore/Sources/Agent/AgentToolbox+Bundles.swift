import Foundation

extension AgentToolbox {
    func runBundleTool(_ name: String, _ args: AgentArguments, dryRun: Bool) throws -> AgentToolOutput? {
        switch name {
        case "add_workout_section": return try addWorkoutSection(args, dryRun: dryRun)
        case "update_workout_section": return try updateWorkoutSection(args, dryRun: dryRun)
        case "remove_workout_section": return try removeWorkoutSection(args, dryRun: dryRun)
        case "update_workout": return try updateWorkout(args, dryRun: dryRun)
        default: return nil
        }
    }

    private static let sectionKeys = ["exercise", "bundle", "name", "duration", "sets", "repCount", "restBetweenSets", "prepareTime", "restAfter"]

    private func sectionIndex(_ reference: String, in workout: WorkoutManifest) throws -> Int {
        let text = reference.trimmingCharacters(in: .whitespacesAndNewlines)
        if let number = Int(text) {
            guard number >= 1, number <= workout.sections.count else {
                throw AgentToolError("not_found", "'\(workout.name)' has \(workout.sections.count) section\(workout.sections.count == 1 ? "" : "s"); there is no section \(number).", hint: "Use get_workout to see the positions.")
            }
            return number - 1
        }
        let named = workout.sections.enumerated().filter { AgentValue.fold($0.element.name) == AgentValue.fold(text) }
        if named.count == 1 { return named[0].offset }
        if named.count > 1 {
            throw AgentToolError("ambiguous", "\(named.count) sections are named '\(text)'.", hint: "Use a position from get_workout.")
        }
        throw AgentToolError("not_found", "No section named '\(text)' in '\(workout.name)'.", hint: "Use get_workout to see section names and positions.")
    }

    private func setRest(_ seconds: Int, on section: inout WorkoutSectionManifest) {
        let value = max(0, seconds)
        section.customRestAfter = value
        section.bigRestRow = WorkoutRestRowManifest(
            id: section.bigRestRow?.id ?? UUID().uuidString, kind: .big, duration: value, contents: section.bigRestRow?.contents ?? []
        )
    }

    private func setRest(_ seconds: Int, onSlot slot: inout WorkoutSetSlotManifest) {
        let value = max(0, seconds)
        slot.restAfter = value
        if value > 0 {
            var row = slot.restRow ?? WorkoutRestRowManifest(duration: value)
            row.duration = value
            slot.restRow = row
        } else {
            slot.restRow = nil
        }
    }

    private func save(_ workout: WorkoutManifest, dryRun: Bool, changed: [String], extra: [String: Any] = [:]) throws -> AgentToolOutput {
        var value = extra
        value["workout"] = workout.name
        value["sections"] = workout.sections.count
        value["totalSeconds"] = workout.totalDuration
        if dryRun {
            value["dryRun"] = true
            value["wouldChange"] = changed
            return AgentToolOutput(value: value)
        }
        try database.updateWorkout(id: workout.id, manifest: workout)
        value["changed"] = changed
        return AgentToolOutput(value: value)
    }

    private func addWorkoutSection(_ args: AgentArguments, dryRun: Bool) throws -> AgentToolOutput {
        var workout = try findWorkout(try args.requiredString("workout"))
        let index = try AgentPageIndex(database: database)
        let raw = args.values.filter { Self.sectionKeys.contains($0.key) }
        let position = min(max(1, args.int("position") ?? workout.sections.count + 1), workout.sections.count + 1)
        let isLast = position == workout.sections.count + 1
        let section = try sectionManifest(raw, index: index, position: position - 1, restAfter: isLast ? 0 : workout.restBetweenSections)
        var extra: [String: Any] = ["position": position, "kind": section.mode == .bundle ? "bundle" : "exercise"]
        if isLast, let previous = workout.sections.indices.last,
           workout.sections[previous].customRestAfter == 0, (workout.sections[previous].bigRestRow?.duration ?? 0) == 0 {
            setRest(workout.restBetweenSections, on: &workout.sections[previous])
            extra["previousSectionRest"] = workout.restBetweenSections
        }
        workout.sections.insert(section, at: position - 1)
        return try save(workout, dryRun: dryRun, changed: ["section"], extra: extra)
    }

    private func removeWorkoutSection(_ args: AgentArguments, dryRun: Bool) throws -> AgentToolOutput {
        var workout = try findWorkout(try args.requiredString("workout"))
        let position = try sectionIndex(try args.requiredString("section"), in: workout)
        guard workout.sections.count > 1 else {
            throw AgentToolError("invalid_argument", "A workout keeps at least one section.", hint: "Use delete_workout to remove the whole workout.")
        }
        let removed = workout.sections.remove(at: position)
        return try save(workout, dryRun: dryRun, changed: ["removed"], extra: ["removed": removed.name, "position": position + 1])
    }

    private func updateWorkout(_ args: AgentArguments, dryRun: Bool) throws -> AgentToolOutput {
        var workout = try findWorkout(try args.requiredString("workout"))
        var changed: [String] = []
        if let value = args.string("name")?.trimmingCharacters(in: .whitespacesAndNewlines), !value.isEmpty {
            workout.name = value
            changed.append("name")
        }
        if let type = try resolveType(args.string("type")) {
            workout.type = type
            changed.append("type")
        }
        if let value = args.int("restBetweenSections") {
            workout.restBetweenSections = max(0, value)
            changed.append("restBetweenSections")
        }
        guard !changed.isEmpty else { throw AgentToolError("invalid_argument", "Nothing to change.", hint: "Pass name, type or restBetweenSections.") }
        return try save(workout, dryRun: dryRun, changed: changed)
    }

    private func updateWorkoutSection(_ args: AgentArguments, dryRun: Bool) throws -> AgentToolOutput {
        var workout = try findWorkout(try args.requiredString("workout"))
        let position = try sectionIndex(try args.requiredString("section"), in: workout)
        let index = try AgentPageIndex(database: database)
        var section = workout.sections[position]
        var changed: [String] = []
        if let value = args.string("name")?.trimmingCharacters(in: .whitespacesAndNewlines), !value.isEmpty {
            section.name = value
            changed.append("name")
        }
        if let value = args.int("restAfter") {
            setRest(value, on: &section)
            changed.append("restAfter")
        }
        if section.mode == .bundle {
            for key in ["duration", "repCount"] where args.has(key) {
                throw AgentToolError("invalid_argument", "'\(key)' does not apply to a bundle.", hint: "Set each exercise's duration inside bundle.exercises.")
            }
            var spec = args.values["bundle"] as? [String: Any] ?? [:]
            for key in ["sets", "restBetweenSets", "prepareTime"] where spec[key] == nil {
                if let value = args.values[key] { spec[key] = value }
            }
            if !spec.isEmpty { changed += try applyBundle(spec, to: &section, index: index) }
        } else {
            guard args.values["bundle"] == nil else {
                throw AgentToolError("invalid_argument", "Section \(position + 1) is a timed section, not a bundle.", hint: "Use duration, sets, repCount, restBetweenSets or prepareTime.")
            }
            changed += applyTimed(args, to: &section)
        }
        workout.sections[position] = section
        var finalPosition = position
        if let target = args.int("position") {
            let destination = min(max(1, target), workout.sections.count) - 1
            if destination != position {
                let moved = workout.sections.remove(at: position)
                workout.sections.insert(moved, at: destination)
                finalPosition = destination
                changed.append("position")
            }
        }
        guard !changed.isEmpty else {
            throw AgentToolError("invalid_argument", "Nothing to change.", hint: "Pass at least one field besides workout and section.")
        }
        return try save(workout, dryRun: dryRun, changed: changed, extra: ["position": finalPosition + 1, "kind": section.mode == .bundle ? "bundle" : "exercise"])
    }

    private func applyBundle(_ spec: [String: Any], to section: inout WorkoutSectionManifest, index pages: AgentPageIndex) throws -> [String] {
        var changed: [String] = []
        var sets = bundleSetSlots(of: section)
        let currentRest = sets.count > 1 ? sets[0].playbackRest : section.restBetweenSets
        let restBetween = max(0, spec["restBetweenSets"] as? Int ?? currentRest)
        let prepare = spec["prepareTime"] as? Int ?? section.prepareTime
        if spec["exercises"] != nil {
            let exercises = try bundleExercises(spec["exercises"], index: pages, label: "bundle")
            guard !exercises.isEmpty else {
                throw AgentToolError("invalid_argument", "A bundle needs at least one exercise.", hint: "Pass bundle.exercises as a list of {exercise, duration, restAfter}.")
            }
            sets = Self.makeBundleSets(exercises: exercises, count: spec["sets"] as? Int ?? sets.count, rest: restBetween, prepare: prepare)
            section.exerciseID = exercises[0].exerciseID
            changed.append("exercises")
            if spec["sets"] != nil { changed.append("sets") }
        } else {
            if let count = spec["sets"] as? Int, count != sets.count {
                while sets.count < count, let last = sets.last { sets.append(Self.freshCopy(last)) }
                if sets.count > count { sets = Array(sets.prefix(count)) }
                changed.append("sets")
            }
            if spec["restBetweenSets"] != nil || changed.contains("sets") {
                for position in sets.indices {
                    setRest(position + 1 < sets.count ? restBetween : 0, onSlot: &sets[position])
                }
                if spec["restBetweenSets"] != nil { changed.append("restBetweenSets") }
            }
        }
        if spec["exercises"] != nil, spec["restBetweenSets"] != nil { changed.append("restBetweenSets") }
        if spec["prepareTime"] != nil {
            for position in sets.indices { sets[position].prepareTime = prepare }
            changed.append("prepareTime")
        }
        for position in sets.indices { sets[position].name = "Set \(position + 1)" }
        section.slots = sets
        section.sets = sets.count
        section.restBetweenSets = restBetween
        section.prepareTime = prepare
        if let value = (spec["order"] as? String).flatMap(WorkoutBundleOrder.init(rawValue:)), value != section.bundleOrder {
            section.bundleOrder = value
            changed.append("order")
        }
        if let value = spec["voice"] as? Bool, value != section.bundleVoiceEnabled {
            section.bundleVoiceEnabled = value
            changed.append("voice")
        }
        return changed
    }

    private func applyTimed(_ args: AgentArguments, to section: inout WorkoutSectionManifest) -> [String] {
        var changed: [String] = []
        if let value = args.int("duration") {
            section.duration = max(5, value)
            for position in section.slots.indices { section.slots[position].duration = max(1, value) }
            changed.append("duration")
        }
        if let value = args.int("repCount") {
            section.repCount = max(1, value)
            for position in section.slots.indices { section.slots[position].repCount = max(1, value) }
            changed.append("repCount")
        }
        if let value = args.int("prepareTime") {
            section.prepareTime = max(0, value)
            for position in section.slots.indices { section.slots[position].prepareTime = min(30, max(0, value)) }
            changed.append("prepareTime")
        }
        if let value = args.int("sets") {
            let count = max(1, value)
            if !section.slots.isEmpty {
                while section.slots.count < count, let last = section.slots.last {
                    if last.playbackRest == 0 {
                        var previous = section.slots[section.slots.count - 1]
                        setRest(section.restBetweenSets, onSlot: &previous)
                        section.slots[section.slots.count - 1] = previous
                    }
                    var copy = Self.freshCopy(last)
                    setRest(0, onSlot: &copy)
                    section.slots.append(copy)
                }
                if section.slots.count > count {
                    section.slots = Array(section.slots.prefix(count))
                    if let lastIndex = section.slots.indices.last { setRest(0, onSlot: &section.slots[lastIndex]) }
                }
            }
            section.sets = count
            changed.append("sets")
        }
        if let value = args.int("restBetweenSets") {
            section.restBetweenSets = max(0, value)
            for position in section.slots.indices {
                setRest(position + 1 < section.slots.count ? value : 0, onSlot: &section.slots[position])
            }
            changed.append("restBetweenSets")
        }
        return changed
    }
}
