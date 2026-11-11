import Foundation

extension AgentToolbox {
    func workoutExercisePage(_ reference: Any?, index pages: AgentPageIndex, label: String) throws -> ExercisePageManifest {
        let page = try pages.resolve(reference as? String ?? "")
        guard page.pageType == .exercise || page.pageType == .skill || page.pageType == .tutorial else {
            let what = page.pageType == .note ? "a note" : "a folder"
            throw AgentToolError("invalid_argument", "\(label): '\(page.title)' is \(what), not an exercise.", hint: "Pick an exercise page; list_pages shows kind exercise.")
        }
        return page
    }

    func sectionManifest(_ raw: [String: Any], index pages: AgentPageIndex, position: Int, restAfter: Int) throws -> WorkoutSectionManifest {
        let label = "sections[\(position)]"
        let rest = max(0, raw["restAfter"] as? Int ?? restAfter)
        let name = (raw["name"] as? String).flatMap { $0.isEmpty ? nil : $0 }
        if let spec = raw["bundle"] as? [String: Any] {
            guard raw["exercise"] == nil else {
                throw AgentToolError("invalid_argument", "\(label): give either exercise or bundle, not both.")
            }
            let exercises = try bundleExercises(spec["exercises"], index: pages, label: label)
            guard !exercises.isEmpty else {
                throw AgentToolError("invalid_argument", "\(label).bundle: a bundle needs at least one exercise.", hint: "Pass bundle.exercises as a list of {exercise, duration, restAfter}.")
            }
            return makeBundleSection(
                name: name, exercises: exercises, sets: spec["sets"] as? Int ?? 1,
                restBetweenSets: spec["restBetweenSets"] as? Int ?? 30, prepareTime: spec["prepareTime"] as? Int ?? 4,
                order: (spec["order"] as? String).flatMap(WorkoutBundleOrder.init(rawValue:)) ?? .ordered,
                voice: spec["voice"] as? Bool ?? true, restAfter: rest
            )
        }
        guard raw["exercise"] != nil else {
            throw AgentToolError("invalid_argument", "\(label): give an exercise for a timed section, or a bundle.")
        }
        let page = try workoutExercisePage(raw["exercise"], index: pages, label: label)
        return WorkoutSectionManifest(
            exerciseID: page.id,
            name: name ?? page.title,
            duration: raw["duration"] as? Int ?? page.duration ?? 30,
            sets: raw["sets"] as? Int ?? page.sets ?? 1,
            repCount: raw["repCount"] as? Int,
            restBetweenSets: raw["restBetweenSets"] as? Int ?? page.restBetweenSets ?? 10,
            prepareTime: raw["prepareTime"] as? Int ?? page.prepareTime ?? 4,
            customRestAfter: rest,
            bigRestRow: WorkoutRestRowManifest(kind: .big, duration: rest)
        )
    }

    func bundleExercises(_ value: Any?, index pages: AgentPageIndex, label: String) throws -> [WorkoutSetSlotManifest] {
        let items = value as? [[String: Any]] ?? []
        return try items.enumerated().map { entry in
            let item = entry.element
            let page = try workoutExercisePage(item["exercise"], index: pages, label: "\(label).bundle.exercises[\(entry.offset)]")
            return WorkoutSetSlotManifest(
                exerciseID: page.id,
                name: (item["name"] as? String).flatMap { $0.isEmpty ? nil : $0 } ?? page.title,
                duration: item["duration"] as? Int ?? page.duration ?? 30,
                repCount: item["repCount"] as? Int,
                restAfter: item["restAfter"] as? Int ?? page.restAfter ?? 5,
                prepareTime: 0
            )
        }
    }

    func makeBundleSection(
        id: String = UUID().uuidString, name: String?, exercises: [WorkoutSetSlotManifest], sets: Int,
        restBetweenSets: Int, prepareTime: Int, order: WorkoutBundleOrder, voice: Bool, restAfter: Int
    ) -> WorkoutSectionManifest {
        let setSlots = Self.makeBundleSets(exercises: exercises, count: sets, rest: restBetweenSets, prepare: prepareTime)
        let names = exercises.map(\.name)
        let title = name ?? "Bundle: " + names.prefix(3).joined(separator: ", ") + (names.count > 3 ? " +\(names.count - 3)" : "")
        return WorkoutSectionManifest(
            id: id, exerciseID: exercises[0].exerciseID, name: title, duration: exercises[0].duration, sets: setSlots.count,
            restBetweenSets: max(0, restBetweenSets), prepareTime: prepareTime, customRestAfter: restAfter, mode: .bundle,
            slots: setSlots, bigRestRow: WorkoutRestRowManifest(kind: .big, duration: restAfter),
            bundleOrder: order, bundleVoiceEnabled: voice
        )
    }

    static func makeBundleSets(exercises: [WorkoutSetSlotManifest], count: Int, rest: Int, prepare: Int) -> [WorkoutSetSlotManifest] {
        let total = max(1, count)
        return (0..<total).map { index in
            WorkoutSetSlotManifest(
                exerciseID: "", name: "Set \(index + 1)", duration: 5, restAfter: index + 1 < total ? max(0, rest) : 0,
                prepareTime: prepare, children: exercises.map(freshCopy)
            )
        }
    }

    static func freshCopy(_ slot: WorkoutSetSlotManifest) -> WorkoutSetSlotManifest {
        var copy = slot
        copy.id = UUID().uuidString
        copy.children = slot.children.map(freshCopy)
        if var row = copy.restRow {
            row.id = UUID().uuidString
            copy.restRow = row
        }
        copy.drops = slot.drops.map { drop in
            var item = drop
            item.id = UUID().uuidString
            return item
        }
        return copy
    }

    func buildWorkout(_ args: AgentArguments, dryRun: Bool) throws -> AgentToolOutput {
        let index = try AgentPageIndex(database: database)
        let name = try args.requiredString("name")
        let type = try resolveType(args.string("type")) ?? .strength
        let raw = args.objects("sections")
        guard !raw.isEmpty else { throw AgentToolError("invalid_argument", "A workout needs at least one section.") }
        let restBetween = max(0, args.int("restBetweenSections") ?? 30)
        let sections = try raw.enumerated().map { entry in
            try sectionManifest(entry.element, index: index, position: entry.offset, restAfter: entry.offset == raw.count - 1 ? 0 : restBetween)
        }
        let manifest = WorkoutManifest(id: UUID().uuidString, name: name, type: type, sections: sections, restBetweenSections: restBetween)
        var summary: [String: Any] = ["name": name, "type": type.name, "sections": sections.count, "totalSeconds": manifest.totalDuration]
        let bundles = sections.filter { $0.mode == .bundle }.count
        if bundles > 0 { summary["bundles"] = bundles }
        if dryRun {
            summary["dryRun"] = true
            return AgentToolOutput(value: summary)
        }
        try database.createWorkout(id: manifest.id, manifest: manifest)
        summary["id"] = manifest.id
        return AgentToolOutput(value: summary, effects: [.createdWorkout(id: manifest.id)])
    }

    func findWorkout(_ reference: String) throws -> WorkoutManifest {
        let all = try database.listWorkouts()
        let text = reference.trimmingCharacters(in: .whitespacesAndNewlines)
        if let match = all.first(where: { $0.id.caseInsensitiveCompare(text) == .orderedSame }) { return match }
        let named = all.filter { AgentValue.fold($0.name) == AgentValue.fold(text) }
        if named.count == 1 { return named[0] }
        if named.count > 1 {
            throw AgentToolError("ambiguous", "\(named.count) workouts are named '\(text)'.", hint: "Use one of the ids: \(named.map(\.id).joined(separator: ", ")).")
        }
        throw AgentToolError("not_found", "No workout matches '\(text)'.", hint: "Use list_workouts to see ids.")
    }

    func listWorkouts() throws -> AgentToolOutput {
        let all = try database.listWorkouts().sorted { $0.name < $1.name }
        let repeated = Set(Dictionary(grouping: all, by: { AgentValue.fold($0.name) }).filter { $0.value.count > 1 }.keys)
        let items = all.map { workout -> [String: Any] in
            var item: [String: Any] = ["name": workout.name, "type": workout.type.name, "sections": workout.sections.count, "totalSeconds": workout.totalDuration]
            let bundles = workout.sections.filter { $0.mode == .bundle }.count
            if bundles > 0 { item["bundles"] = bundles }
            if repeated.contains(AgentValue.fold(workout.name)) { item["id"] = workout.id }
            return item
        }
        return AgentToolOutput(value: ["workouts": items])
    }

    func getWorkout(_ args: AgentArguments) throws -> AgentToolOutput {
        let workout = try findWorkout(try args.requiredString("workout"))
        let pages = try? AgentPageIndex(database: database)
        func label(_ id: String, _ fallback: String) -> String {
            if let pages, pages.byID[id] != nil { return pages.titlePath(id) }
            return fallback
        }
        let sections = workout.sections.enumerated().map { entry -> [String: Any] in
            let section = entry.element
            var item: [String: Any] = ["position": entry.offset + 1, "seconds": section.calculatedDuration]
            if section.mode == .bundle {
                item["kind"] = "bundle"
                item["name"] = section.name
                item["order"] = section.bundleOrder.rawValue
                item["voice"] = section.bundleVoiceEnabled
                let setSlots = bundleSetSlots(of: section)
                item["sets"] = setSlots.count
                item["prepareTime"] = section.prepareTime
                if setSlots.count > 1 { item["restBetweenSets"] = setSlots[0].playbackRest }
                let rounds = setSlots.map { set in
                    set.children.map { exercise -> [String: Any] in
                        ["exercise": label(exercise.exerciseID, exercise.alias.flatMap { $0.isEmpty ? nil : $0 } ?? exercise.name), "duration": exercise.duration, "restAfter": exercise.playbackRest]
                    }
                }
                let signature = { (round: [[String: Any]]) in round.map { "\($0["exercise"] ?? "")|\($0["duration"] ?? 0)|\($0["restAfter"] ?? 0)" } }
                if let first = rounds.first, rounds.allSatisfy({ signature($0) == signature(first) }) {
                    item["exercises"] = first
                } else {
                    item["rounds"] = rounds
                }
            } else {
                item["kind"] = "exercise"
                item["exercise"] = label(section.exerciseID, section.name)
                item["duration"] = section.duration
                if section.sets > 1 {
                    item["sets"] = section.sets
                    item["restBetweenSets"] = section.restBetweenSets
                }
            }
            if entry.offset + 1 < workout.sections.count {
                let rest = section.bigRestRow?.duration ?? (section.customRestAfter == 0 ? 0 : workout.restBetweenSections)
                if rest != workout.restBetweenSections { item["restAfter"] = rest }
            }
            return item
        }
        return AgentToolOutput(value: [
            "id": workout.id, "name": workout.name, "type": workout.type.name, "totalSeconds": workout.totalDuration,
            "restBetweenSections": workout.restBetweenSections, "sections": sections,
        ])
    }

    func deleteWorkout(_ args: AgentArguments, dryRun: Bool) throws -> AgentToolOutput {
        let workout = try findWorkout(try args.requiredString("workout"))
        if dryRun { return AgentToolOutput(value: ["dryRun": true, "wouldTrash": workout.name]) }
        try database.deleteWorkout(id: workout.id)
        return AgentToolOutput(value: ["trashed": workout.name, "id": workout.id])
    }

    func bundleSetSlots(of section: WorkoutSectionManifest) -> [WorkoutSetSlotManifest] {
        if section.slots.isEmpty {
            let leaf = WorkoutSetSlotManifest(exerciseID: section.exerciseID, name: section.name, duration: section.duration, restAfter: 0, prepareTime: 0)
            return (0..<section.sets).map { index in
                WorkoutSetSlotManifest(
                    exerciseID: "", name: "Set \(index + 1)", restAfter: index + 1 < section.sets ? section.restBetweenSets : 0,
                    prepareTime: section.prepareTime, children: [Self.freshCopy(leaf)]
                )
            }
        }
        if section.slots.allSatisfy({ $0.children.isEmpty }) {
            return [WorkoutSetSlotManifest(
                exerciseID: "", name: "Set 1", restAfter: 0, prepareTime: section.slots.first?.prepareTime ?? section.prepareTime,
                children: section.slots
            )]
        }
        return section.slots
    }
}
