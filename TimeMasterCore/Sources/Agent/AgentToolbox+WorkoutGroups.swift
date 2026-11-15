import Foundation

extension AgentToolbox {
    func runWorkoutGroupTool(_ name: String, _ args: AgentArguments, dryRun: Bool) throws -> AgentToolOutput? {
        switch name {
        case "list_workout_groups": return try listWorkoutGroups()
        case "create_workout_group": return try createWorkoutGroup(args, dryRun: dryRun)
        case "update_workout_group": return try updateWorkoutGroup(args, dryRun: dryRun)
        case "delete_workout_group": return try deleteWorkoutGroup(args, dryRun: dryRun)
        default: return nil
        }
    }

    /// Takes a deleted workout out of every group so no group points at nothing.
    func removeWorkoutFromGroups(_ workoutID: String) throws {
        var config = try database.loadConfig()
        var changed = false
        for index in config.workoutGroups.indices where config.workoutGroups[index].workoutIDs.contains(workoutID) {
            config.workoutGroups[index].workoutIDs.removeAll { $0 == workoutID }
            changed = true
        }
        if changed { try database.saveConfig(config) }
    }

    func removeWorkoutGroup(id: String) throws {
        var config = try database.loadConfig()
        let before = config.workoutGroups.count
        config.workoutGroups.removeAll { $0.id == id }
        if config.workoutGroups.count != before { try database.saveConfig(config) }
    }

    private func groupIndex(_ reference: String, in groups: [WorkoutGroupManifest]) throws -> Int {
        let text = reference.trimmingCharacters(in: .whitespacesAndNewlines)
        if let index = groups.firstIndex(where: { $0.id.caseInsensitiveCompare(text) == .orderedSame }) { return index }
        let named = groups.indices.filter { AgentValue.fold(groups[$0].title) == AgentValue.fold(text) }
        if named.count == 1 { return named[0] }
        if named.count > 1 {
            throw AgentToolError("ambiguous", "\(named.count) workout groups are titled '\(text)'.", hint: "Use one of the ids: \(named.map { groups[$0].id }.joined(separator: ", ")).")
        }
        throw AgentToolError("not_found", "No workout group matches '\(text)'.", hint: "Use list_workout_groups to see the groups.")
    }

    private func groupIcon(_ value: String?) -> (icon: String, type: SkillBoardIconType?) {
        let clean = value?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return clean.isEmpty ? ("", nil) : (clean, SkillBoardIconType.inferred(from: clean))
    }

    private func groupWorkoutIDs(_ references: [String]?) throws -> [String] {
        var seen = Set<String>()
        return try (references ?? []).compactMap { reference in
            let id = try findWorkout(reference).id
            return seen.insert(id).inserted ? id : nil
        }
    }

    private func groupTitle(_ value: String?) throws -> String {
        let clean = value?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !clean.isEmpty else { throw AgentToolError("invalid_argument", "A workout group needs a title.") }
        return clean
    }

    private func groupSummary(_ group: WorkoutGroupManifest, names: [String: String]) -> [String: Any] {
        var value: [String: Any] = ["id": group.id, "title": group.title, "workouts": group.workoutIDs.compactMap { names[$0] }]
        if !group.icon.isEmpty { value["icon"] = group.icon }
        return value
    }

    private func workoutNames() throws -> [String: String] {
        Dictionary(try database.listWorkouts().map { ($0.id, $0.name) }, uniquingKeysWith: { first, _ in first })
    }

    private func listWorkoutGroups() throws -> AgentToolOutput {
        let config = try database.loadConfig()
        let names = try workoutNames()
        let grouped = Set(config.workoutGroups.flatMap(\.workoutIDs))
        let loose = names.filter { !grouped.contains($0.key) }.map(\.value).sorted()
        return AgentToolOutput(value: [
            "groups": config.workoutGroups.map { groupSummary($0, names: names) },
            "ungrouped": loose,
        ])
    }

    private func createWorkoutGroup(_ args: AgentArguments, dryRun: Bool) throws -> AgentToolOutput {
        var config = try database.loadConfig()
        let title = try groupTitle(args.string("title"))
        let ids = try groupWorkoutIDs(args.strings("workouts"))
        let names = try workoutNames()
        if let existing = config.workoutGroups.firstIndex(where: { AgentValue.fold($0.title) == AgentValue.fold(title) }) {
            guard args.string("ifExists") == "reuse" else {
                throw AgentToolError("exists", "A workout group titled '\(config.workoutGroups[existing].title)' already exists.", hint: "Pass ifExists reuse to add the workouts to it, or choose another title.")
            }
            let groupID = config.workoutGroups[existing].id
            Self.moveWorkouts(ids, into: groupID, groups: &config.workoutGroups)
            var value = groupSummary(config.workoutGroups[existing], names: names)
            value["reused"] = true
            if dryRun {
                value["dryRun"] = true
            } else {
                try database.saveConfig(config)
            }
            return AgentToolOutput(value: value)
        }
        let icon = groupIcon(args.string("icon"))
        let group = WorkoutGroupManifest(title: title, icon: icon.icon, iconType: icon.type)
        let place = args.int("position").map { min(max(0, $0 - 1), config.workoutGroups.count) } ?? config.workoutGroups.count
        config.workoutGroups.insert(group, at: place)
        Self.moveWorkouts(ids, into: group.id, groups: &config.workoutGroups)
        var value = groupSummary(config.workoutGroups[place], names: names)
        value["position"] = place + 1
        if dryRun {
            value["dryRun"] = true
            return AgentToolOutput(value: value)
        }
        try database.saveConfig(config)
        return AgentToolOutput(value: value, effects: [.createdWorkoutGroup(id: group.id)])
    }

    private func updateWorkoutGroup(_ args: AgentArguments, dryRun: Bool) throws -> AgentToolOutput {
        var config = try database.loadConfig()
        var index = try groupIndex(try args.requiredString("group"), in: config.workoutGroups)
        let groupID = config.workoutGroups[index].id
        if args.has("title") {
            let title = try groupTitle(args.string("title"))
            if config.workoutGroups.contains(where: { $0.id != groupID && AgentValue.fold($0.title) == AgentValue.fold(title) }) {
                throw AgentToolError("exists", "Another workout group is already titled '\(title)'.")
            }
            config.workoutGroups[index].title = title
        }
        if args.has("icon") {
            let icon = groupIcon(args.string("icon"))
            config.workoutGroups[index].icon = icon.icon
            config.workoutGroups[index].iconType = icon.type
        }
        let removing = Set(try groupWorkoutIDs(args.strings("removeWorkouts")))
        config.workoutGroups[index].workoutIDs.removeAll { removing.contains($0) }
        Self.moveWorkouts(try groupWorkoutIDs(args.strings("addWorkouts")), into: groupID, groups: &config.workoutGroups)
        if args.has("workoutOrder") {
            let order = try groupWorkoutIDs(args.strings("workoutOrder"))
            guard Set(order) == Set(config.workoutGroups[index].workoutIDs), order.count == config.workoutGroups[index].workoutIDs.count else {
                throw AgentToolError("invalid_argument", "workoutOrder must list every workout of '\(config.workoutGroups[index].title)' exactly once.", hint: "Read the group with list_workout_groups first.")
            }
            config.workoutGroups[index].workoutIDs = order
        }
        if let position = args.int("position") {
            let group = config.workoutGroups.remove(at: index)
            index = min(max(0, position - 1), config.workoutGroups.count)
            config.workoutGroups.insert(group, at: index)
        }
        var value = groupSummary(config.workoutGroups[index], names: try workoutNames())
        value["position"] = index + 1
        if dryRun {
            value["dryRun"] = true
        } else {
            try database.saveConfig(config)
        }
        return AgentToolOutput(value: value)
    }

    private func deleteWorkoutGroup(_ args: AgentArguments, dryRun: Bool) throws -> AgentToolOutput {
        var config = try database.loadConfig()
        let index = try groupIndex(try args.requiredString("group"), in: config.workoutGroups)
        let group = config.workoutGroups[index]
        if dryRun {
            return AgentToolOutput(value: ["dryRun": true, "wouldRemove": group.title, "workoutsKept": group.workoutIDs.count])
        }
        config.workoutGroups.remove(at: index)
        try database.saveConfig(config)
        return AgentToolOutput(value: ["removed": group.title, "workoutsKept": group.workoutIDs.count])
    }

    /// Puts workouts at the end of one group, in order, taking each out of whatever group held it.
    static func moveWorkouts(_ ids: [String], into groupID: String, groups: inout [WorkoutGroupManifest]) {
        guard !ids.isEmpty else { return }
        let moving = Set(ids)
        for index in groups.indices {
            groups[index].workoutIDs.removeAll { moving.contains($0) }
        }
        if let target = groups.firstIndex(where: { $0.id == groupID }) {
            groups[target].workoutIDs.append(contentsOf: ids)
        }
    }
}
