import Foundation

extension AgentToolbox {
    func runSkillTrainingTool(_ name: String, _ args: AgentArguments, dryRun: Bool) throws -> AgentToolOutput? {
        switch name {
        case "set_skill_training": return try setSkillTraining(args, dryRun: dryRun)
        case "get_skill_training": return try getSkillTraining(args)
        default: return nil
        }
    }

    private static let trainingLimit = 400

    private func trainedSkill(_ reference: String, index: AgentPageIndex) throws -> ExercisePageManifest {
        let page = try index.resolve(reference)
        guard page.pageType == .skill || page.pageType == .tutorial else {
            throw AgentToolError(
                "invalid_argument", "'\(index.titlePath(page.id))' is not a skill or a tutorial.",
                hint: "Pass the skill page, for example 'Calisthenics/Handstand'."
            )
        }
        return page
    }

    private func setSkillTraining(_ args: AgentArguments, dryRun: Bool) throws -> AgentToolOutput {
        let index = try AgentPageIndex(database: database)
        let skill = try trainedSkill(try args.requiredString("skill"), index: index)
        let entries = args.objects("exercises")
        let replace = args.bool("replace") == true
        guard !entries.isEmpty || replace else {
            throw AgentToolError("invalid_argument", "Nothing to link.", hint: "Pass exercises as a list of {exercise, tier}.")
        }
        guard entries.count <= Self.trainingLimit else {
            throw AgentToolError(
                "invalid_argument", "\(entries.count) exercises in one call; the limit is \(Self.trainingLimit).",
                hint: "Split the list over several calls."
            )
        }
        var wanted: [String: SkillTier] = [:]
        for (position, entry) in entries.enumerated() {
            let label = "exercises[\(position)]"
            let page = try workoutExercisePage(entry["exercise"], index: index, label: label)
            guard page.id != skill.id else {
                throw AgentToolError("invalid_argument", "\(label): a skill cannot train itself.")
            }
            guard let tier = (entry["tier"] as? String).flatMap({ SkillTier(rawValue: $0.lowercased()) }) else {
                throw AgentToolError("invalid_argument", "\(label): tier must be S, A, B, C or D.")
            }
            wanted[page.id] = tier
        }

        var added = 0, updated = 0, removed = 0
        var changes: [(page: ExercisePageManifest, next: [SkillTraining])] = []
        for page in index.pages {
            let current = page.trains
            let existing = current.first { $0.skillID == skill.id }?.tier
            var next = current.filter { $0.skillID != skill.id }
            if let tier = wanted[page.id] {
                next.append(SkillTraining(skillID: skill.id, tier: tier))
                guard existing != tier else { continue }
                if existing == nil { added += 1 } else { updated += 1 }
            } else if replace, existing != nil {
                removed += 1
            } else {
                continue
            }
            changes.append((page, next))
        }

        let changed = Dictionary(uniqueKeysWithValues: changes.map { ($0.page.id, $0.next) })
        let total = index.pages.filter { page in (changed[page.id] ?? page.trains).contains { $0.skillID == skill.id } }.count
        var value: [String: Any] = [
            "skill": index.titlePath(skill.id), "added": added, "updated": updated, "removed": removed, "total": total,
        ]
        if dryRun {
            value["dryRun"] = true
            return AgentToolOutput(value: value)
        }
        var effects: [AgentEffect] = []
        for change in changes {
            var manifest = try database.getPage(id: change.page.id)
            manifest.trains = change.next
            try database.updatePage(id: change.page.id, manifest: manifest, newParentID: manifest.parentID)
            effects.append(.changedTraining(pageID: change.page.id, previous: change.page.trains))
        }
        return AgentToolOutput(value: value, effects: effects)
    }

    private func getSkillTraining(_ args: AgentArguments) throws -> AgentToolOutput {
        let index = try AgentPageIndex(database: database)
        let skill = try trainedSkill(try args.requiredString("skill"), index: index)
        var byTier: [SkillTier: [String]] = [:]
        for page in index.pages {
            for link in page.trains where link.skillID == skill.id {
                byTier[link.tier, default: []].append(index.titlePath(page.id))
            }
        }
        let tiers = SkillTier.allCases.compactMap { tier -> [String: Any]? in
            guard let paths = byTier[tier] else { return nil }
            return ["tier": tier.title, "exercises": paths.sorted()]
        }
        return AgentToolOutput(value: [
            "skill": index.titlePath(skill.id), "count": byTier.values.reduce(0) { $0 + $1.count }, "tiers": tiers,
        ])
    }
}
