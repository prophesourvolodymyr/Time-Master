import Foundation

extension AgentToolbox {
    func workoutSnapshot(_ id: String) -> String? {
        guard let manifest = try? database.getWorkout(id: id), let data = try? JSONEncoder().encode(manifest) else { return nil }
        return String(data: data, encoding: .utf8)
    }

    func foldRestFillers(_ args: AgentArguments, dryRun: Bool) throws -> AgentToolOutput {
        let pages = try AgentPageIndex(database: database)
        let prefix = (args.string("prefix") ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        let keepNames = args.bool("keepNames") ?? false
        let targets: [WorkoutManifest]
        if let reference = args.string("workout"), !reference.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            targets = [try findWorkout(reference)]
        } else {
            targets = try database.listWorkouts().sorted { $0.name < $1.name }
        }
        var total = WorkoutRestFoldingReport()
        var changedWorkouts: [String] = []
        var effects: [AgentEffect] = []
        for original in targets {
            var workout = original
            let report = WorkoutRestFolding.fold(
                &workout, prefix: prefix.isEmpty ? WorkoutRestFolding.defaultPrefix : prefix, keepNames: keepNames,
                pageDuration: { pages.byID[$0]?.duration }
            )
            total.skipped += report.skipped
            guard report.sections > 0 else { continue }
            if !dryRun {
                let previous = workoutSnapshot(workout.id)
                try database.updateWorkout(id: workout.id, manifest: workout)
                if let previous { effects.append(.changedWorkout(id: workout.id, previous: previous)) }
            }
            changedWorkouts.append(workout.name)
            total.sections += report.sections
            total.fillers += report.fillers
            total.timedSections += report.timedSections
            total.renamedSections += report.renamedSections
        }
        var value: [String: Any] = [
            "workouts": changedWorkouts.count,
            "sections": total.sections,
            "fillers": total.fillers,
            "becameTimed": total.timedSections,
            "renamed": total.renamedSections,
        ]
        if !total.skipped.isEmpty { value["skipped"] = total.skipped }
        if dryRun {
            value["dryRun"] = true
            value["wouldChange"] = changedWorkouts
        } else {
            value["changed"] = changedWorkouts
        }
        return AgentToolOutput(value: value, effects: effects)
    }
}
