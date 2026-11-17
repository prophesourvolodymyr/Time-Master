import Foundation

extension AgentToolbox {
    func runWorkoutTypeTool(_ name: String, _ args: AgentArguments, dryRun: Bool) throws -> AgentToolOutput? {
        switch name {
        case "create_workout_type": return try createWorkoutType(args, dryRun: dryRun)
        case "update_workout_type": return try updateWorkoutType(args, dryRun: dryRun)
        case "delete_workout_type": return try deleteWorkoutType(args, dryRun: dryRun)
        default: return nil
        }
    }

    func workoutTypeDetails() -> [[String: Any]] {
        let custom = Set(((try? database.loadConfig())?.customWorkoutTypes ?? []).map(\.id))
        return workoutTypes().map { type in
            ["id": type.id, "name": type.name, "icon": type.iconName, "color": type.colorHex, "builtIn": !custom.contains(type.id)]
        }
    }

    private static let typePalette = ["FF453A", "FFD60A", "32D74B", "64D2FF", "5E5CE6", "FF6A00", "BF5AF2", "AC8E68", "30D158", "FF9F0A"]

    private func typeName(_ value: String?) throws -> String {
        let clean = value?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !clean.isEmpty else { throw AgentToolError("invalid_argument", "A workout type needs a name.") }
        return clean
    }

    private func typeColor(_ value: String?) throws -> String? {
        guard let value else { return nil }
        let clean = value.trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: "#", with: "").uppercased()
        guard clean.count == 6, clean.allSatisfy(\.isHexDigit) else {
            throw AgentToolError("invalid_argument", "'\(value)' is not a six-digit hex colour.", hint: "Use something like FF3B30.")
        }
        return clean
    }

    private func typeIcon(_ value: String?) -> String? {
        let clean = value?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return clean.isEmpty ? nil : clean
    }

    private func customTypeIndex(_ reference: String, in custom: [WorkoutType]) throws -> Int {
        let text = reference.trimmingCharacters(in: .whitespacesAndNewlines)
        if let index = custom.firstIndex(where: { $0.id.caseInsensitiveCompare(text) == .orderedSame || AgentValue.fold($0.name) == AgentValue.fold(text) }) {
            return index
        }
        if WorkoutType.builtIn.contains(where: { $0.id.caseInsensitiveCompare(text) == .orderedSame || AgentValue.fold($0.name) == AgentValue.fold(text) }) {
            throw AgentToolError("built_in", "'\(text)' is a built-in workout type and cannot change.", hint: "Create a custom type instead.")
        }
        throw AgentToolError("not_found", "No custom workout type matches '\(text)'.", hint: "Use list_types to see the types.")
    }

    private func typeSummary(_ type: WorkoutType) -> [String: Any] {
        ["id": type.id, "name": type.name, "icon": type.iconName, "color": type.colorHex]
    }

    private func createWorkoutType(_ args: AgentArguments, dryRun: Bool) throws -> AgentToolOutput {
        var config = try database.loadConfig()
        let name = try typeName(args.string("name"))
        let all = WorkoutType.all(custom: config.customWorkoutTypes)
        if let existing = all.first(where: { AgentValue.fold($0.name) == AgentValue.fold(name) || $0.id.caseInsensitiveCompare(name) == .orderedSame }) {
            guard args.string("ifExists") == "reuse" else {
                throw AgentToolError("exists", "A workout type named '\(existing.name)' already exists.", hint: "Pass ifExists reuse to use it, or choose another name.")
            }
            var value = typeSummary(existing)
            value["reused"] = true
            return AgentToolOutput(value: value)
        }
        let color = try typeColor(args.string("color")) ?? Self.typePalette[config.customWorkoutTypes.count % Self.typePalette.count]
        let type = WorkoutType(id: name, name: name, iconName: typeIcon(args.string("icon")) ?? "star.fill", colorHex: color)
        var value = typeSummary(type)
        if dryRun {
            value["dryRun"] = true
            return AgentToolOutput(value: value)
        }
        config.customWorkoutTypes.append(type)
        try database.saveConfig(config)
        return AgentToolOutput(value: value)
    }

    private func updateWorkoutType(_ args: AgentArguments, dryRun: Bool) throws -> AgentToolOutput {
        var config = try database.loadConfig()
        let index = try customTypeIndex(try args.requiredString("type"), in: config.customWorkoutTypes)
        var type = config.customWorkoutTypes[index]
        if args.has("name") {
            let name = try typeName(args.string("name"))
            let all = WorkoutType.all(custom: config.customWorkoutTypes)
            if all.contains(where: { $0.id != type.id && AgentValue.fold($0.name) == AgentValue.fold(name) }) {
                throw AgentToolError("exists", "Another workout type is already named '\(name)'.")
            }
            type.name = name
        }
        if args.has("icon"), let icon = typeIcon(args.string("icon")) { type.iconName = icon }
        if args.has("color"), let color = try typeColor(args.string("color")) { type.colorHex = color }
        var value = typeSummary(type)
        if dryRun {
            value["dryRun"] = true
        } else {
            config.customWorkoutTypes[index] = type
            try database.saveConfig(config)
        }
        return AgentToolOutput(value: value)
    }

    private func deleteWorkoutType(_ args: AgentArguments, dryRun: Bool) throws -> AgentToolOutput {
        var config = try database.loadConfig()
        let index = try customTypeIndex(try args.requiredString("type"), in: config.customWorkoutTypes)
        let type = config.customWorkoutTypes[index]
        if dryRun {
            return AgentToolOutput(value: ["dryRun": true, "wouldRemove": type.name])
        }
        config.customWorkoutTypes.remove(at: index)
        try database.saveConfig(config)
        return AgentToolOutput(value: ["removed": type.name])
    }
}
