import Foundation

enum AgentCombo {
    static let moves = ["1", "2", "3", "4", "5", "6", "slip", "roll", "duck", "block", "pivot", "reset"]
    static let moveGuide = "1 jab, 2 cross, 3 lead hook, 4 rear hook, 5 lead uppercut, 6 rear uppercut, slip, roll, duck, block, pivot, reset"
    static let longestCall = 8
    static let mostCalls = 40
    static let defaultName = "Combo"
    static let defaultRounds = 3
    static let defaultSeconds = 5
    static let defaultRest = 20
    static let defaultPrepare = 3

    static func tokens(in text: String) -> [String] {
        var result: [String] = []
        var word = ""
        var numeric = false
        func flush() {
            guard !word.isEmpty else { return }
            result.append(contentsOf: numeric ? word.map(String.init) : [word])
            word = ""
        }
        for character in text.lowercased() {
            guard character.isNumber || character.isLetter else {
                flush()
                continue
            }
            if !word.isEmpty, character.isNumber != numeric { flush() }
            numeric = character.isNumber
            word.append(character)
        }
        flush()
        return result
    }

    static func call(_ text: String, label: String) throws -> String {
        let found = tokens(in: text)
        guard !found.isEmpty else {
            throw AgentToolError("invalid_argument", "\(label) is empty.", hint: "Write a call as moves joined by dashes, for example \"1-2-3\". Moves: \(moveGuide).")
        }
        if let unknown = found.first(where: { !moves.contains($0) }) {
            throw AgentToolError(
                "invalid_argument", "\(label): '\(unknown)' is not a move.",
                hint: "Moves: \(moveGuide). Write a call as moves joined by dashes, for example \"1-2-slip\"."
            )
        }
        guard found.count <= longestCall else {
            throw AgentToolError("invalid_argument", "\(label) has \(found.count) moves; a call holds at most \(longestCall).", hint: "Split it into two calls.")
        }
        return found.joined(separator: "-")
    }

    static func calls(_ values: [String]?, label: String) throws -> [String] {
        let list = values ?? []
        guard !list.isEmpty else {
            throw AgentToolError("invalid_argument", "A combo needs calls.", hint: "Pass combo.calls as a list of calls, for example [\"1-2\", \"1-2-3\", \"1-1-2-slip\"].")
        }
        guard list.count <= mostCalls else {
            throw AgentToolError("invalid_argument", "A round holds at most \(mostCalls) calls; \(label) has \(list.count).", hint: "Use fewer calls and more rounds.")
        }
        return try list.enumerated().map { try call($0.element, label: "\(label)[\($0.offset)]") }
    }

    static func text(of slot: WorkoutSetSlotManifest) -> String {
        let shown = slot.alias.flatMap { $0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : $0 } ?? slot.name
        let found = tokens(in: shown)
        return found.isEmpty ? shown : found.joined(separator: "-")
    }

    static func slot(call: String, seconds: Int) -> WorkoutSetSlotManifest {
        WorkoutSetSlotManifest(exerciseID: "", name: call, duration: seconds, restAfter: 0, prepareTime: 0)
    }

    static func icon(_ text: String) -> (name: String?, type: String?) {
        let clean = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return clean.isEmpty ? (nil, nil) : (clean, SkillBoardIconType.inferred(from: clean).rawValue)
    }

    static func sharedSeconds(_ rounds: [WorkoutSetSlotManifest]) -> Int? {
        let every = rounds.flatMap { $0.children.map(\.duration) }
        guard let first = every.first, every.allSatisfy({ $0 == first }) else { return nil }
        return first
    }
}

extension WorkoutSectionManifest {
    var isPlayableCombo: Bool { isCombo && mode == .bundle }

    var agentKind: String { isPlayableCombo ? "combo" : mode == .bundle ? "bundle" : "exercise" }
}

extension AgentToolbox {
    func rejectComboConflicts(_ raw: [String: Any], label: String) throws {
        let instead = ["duration": "combo.secondsPerCall", "sets": "combo.rounds", "restBetweenSets": "combo.restBetweenRounds"]
        for key in ["duration", "sets", "restBetweenSets"] where raw[key] != nil {
            throw AgentToolError("invalid_argument", "\(label): '\(key)' does not apply to a combo.", hint: "Use \(instead[key] ?? "the combo argument") instead.")
        }
        if raw["repCount"] != nil {
            throw AgentToolError("invalid_argument", "\(label): 'repCount' does not apply to a combo.", hint: "A combo counts calls, not reps.")
        }
    }

    private func comboTitle(_ spec: [String: Any], name: String?, label: String) throws -> String? {
        func clean(_ text: String?) -> String? {
            text.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.flatMap { $0.isEmpty ? nil : $0 }
        }
        let inner = clean(spec["name"] as? String)
        let outer = clean(name)
        if let inner, let outer, AgentValue.fold(inner) != AgentValue.fold(outer) {
            throw AgentToolError("invalid_argument", "\(label): 'name' and 'combo.name' differ.", hint: "Pass the name once.")
        }
        return outer ?? inner
    }

    func makeComboSection(
        _ spec: [String: Any], name: String?, restAfter: Int, untimed: Bool, prepareTime: Int?, label: String
    ) throws -> WorkoutSectionManifest {
        let calls = try AgentCombo.calls(spec["calls"] as? [String], label: "\(label).combo.calls")
        let rounds = spec["rounds"] as? Int ?? AgentCombo.defaultRounds
        let seconds = spec["secondsPerCall"] as? Int ?? AgentCombo.defaultSeconds
        let rest = max(0, spec["restBetweenRounds"] as? Int ?? AgentCombo.defaultRest)
        let prepare = min(30, max(0, prepareTime ?? AgentCombo.defaultPrepare))
        let title = try comboTitle(spec, name: name, label: label) ?? AgentCombo.defaultName
        let icon = AgentCombo.icon(spec["icon"] as? String ?? "")
        let sets = (0..<rounds).map { index in
            WorkoutSetSlotManifest(
                exerciseID: "", name: "Set \(index + 1)", duration: seconds, restAfter: index + 1 < rounds ? rest : 0,
                prepareTime: index == 0 ? prepare : 0, children: calls.map { AgentCombo.slot(call: $0, seconds: seconds) }
            )
        }
        return WorkoutSectionManifest(
            exerciseID: "", name: title, duration: seconds, sets: rounds, restBetweenSets: rest, prepareTime: prepare,
            customRestAfter: restAfter, isTimerEnabled: !untimed, mode: .bundle, slots: sets,
            bigRestRow: WorkoutRestRowManifest(kind: .big, duration: restAfter),
            bundleOrder: (spec["order"] as? String).flatMap(WorkoutBundleOrder.init(rawValue:)) ?? .ordered,
            bundleVoiceEnabled: spec["voice"] as? Bool ?? true, isCombo: true, iconName: icon.name, iconType: icon.type
        )
    }

    func applyCombo(
        _ spec: [String: Any], name: String?, prepareTime: Int?, to section: inout WorkoutSectionManifest, label: String
    ) throws -> [String] {
        var changed: [String] = []
        var rounds = bundleSetSlots(of: section)
        let seconds = spec["secondsPerCall"] as? Int ?? AgentCombo.sharedSeconds(rounds) ?? section.duration
        let rest = max(0, spec["restBetweenRounds"] as? Int ?? (rounds.count > 1 ? rounds[0].playbackRest : section.restBetweenSets))
        let title = try comboTitle(spec, name: name, label: label)
        let keptRest = rounds.dropLast().first { $0.restExerciseID != nil }
        if spec["calls"] != nil {
            let calls = try AgentCombo.calls(spec["calls"] as? [String], label: "\(label).combo.calls")
            for index in rounds.indices { rounds[index].children = calls.map { AgentCombo.slot(call: $0, seconds: seconds) } }
            changed.append("calls")
        }
        if let value = spec["secondsPerCall"] as? Int {
            for index in rounds.indices {
                rounds[index].duration = max(1, value)
                for child in rounds[index].children.indices { rounds[index].children[child].duration = max(1, value) }
            }
            section.duration = max(5, value)
            changed.append("secondsPerCall")
        }
        if let count = spec["rounds"] as? Int, count != rounds.count {
            while rounds.count < count, let last = rounds.last {
                var copy = Self.freshCopy(last)
                copy.prepareTime = 0
                rounds.append(copy)
            }
            rounds = Array(rounds.prefix(count))
            changed.append("rounds")
        }
        if spec["restBetweenRounds"] != nil || changed.contains("rounds") {
            for index in rounds.indices { setRest(index + 1 < rounds.count ? rest : 0, onSlot: &rounds[index]) }
            if let keptRest, rounds.count > 1 {
                for index in rounds.indices {
                    if index + 1 < rounds.count, rounds[index].playbackRest > 0 {
                        if rounds[index].restExerciseID == nil {
                            rounds[index].restExerciseID = keptRest.restExerciseID
                            rounds[index].restExerciseAlternativeIDs = keptRest.restExerciseAlternativeIDs
                        }
                    } else {
                        rounds[index].restExerciseID = nil
                        rounds[index].restExerciseAlternativeIDs = []
                    }
                }
            }
            section.restBetweenSets = rest
            if spec["restBetweenRounds"] != nil { changed.append("restBetweenRounds") }
        }
        for index in rounds.indices { rounds[index].name = "Set \(index + 1)" }
        if let value = prepareTime, let first = rounds.indices.first {
            section.prepareTime = min(30, max(0, value))
            rounds[first].prepareTime = section.prepareTime
            changed.append("prepareTime")
        }
        section.slots = rounds
        section.sets = rounds.count
        if let raw = spec["icon"] as? String {
            let icon = AgentCombo.icon(raw)
            section.iconName = icon.name
            section.iconType = icon.type
            changed.append("icon")
        }
        if let title, title != section.name {
            section.name = title
            changed.append("name")
        }
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

    func comboSummary(_ section: WorkoutSectionManifest) -> [String: Any] {
        let rounds = bundleSetSlots(of: section)
        let calls = rounds.map { $0.children.map(AgentCombo.text(of:)) }
        let seconds = rounds.map { $0.children.map(\.duration) }
        var item: [String: Any] = ["kind": "combo", "name": section.name, "rounds": rounds.count]
        if let first = calls.first, calls.allSatisfy({ $0 == first }) {
            item["calls"] = first
        } else {
            item["roundCalls"] = calls
        }
        if let shared = AgentCombo.sharedSeconds(rounds) {
            item["secondsPerCall"] = shared
        } else if let first = seconds.first, seconds.allSatisfy({ $0 == first }) {
            item["callSeconds"] = first
        } else {
            item["roundCallSeconds"] = seconds
        }
        let rests = rounds.dropLast().map(\.playbackRest)
        if let first = rests.first {
            if rests.allSatisfy({ $0 == first }) { item["restBetweenRounds"] = first } else { item["roundRests"] = rests }
        }
        let prepare = rounds.first?.prepareTime ?? section.prepareTime
        if prepare != AgentCombo.defaultPrepare { item["prepareTime"] = prepare }
        if let icon = section.iconName, !icon.isEmpty { item["icon"] = icon }
        if !section.bundleVoiceEnabled { item["voice"] = false }
        if section.bundleOrder == .random { item["order"] = "random" }
        return item
    }
}
