import Foundation

private struct RemovedHistoryEntry: Codable {
    var entry: HistoryEntry
    var after: String?
    var before: String?

    private enum Neighbors: String, CodingKey {
        case after, before
    }

    init(entry: HistoryEntry, after: String?, before: String?) {
        self.entry = entry
        self.after = after
        self.before = before
    }

    init(from decoder: Decoder) throws {
        entry = try HistoryEntry(from: decoder)
        let container = try decoder.container(keyedBy: Neighbors.self)
        after = try container.decodeIfPresent(String.self, forKey: .after)
        before = try container.decodeIfPresent(String.self, forKey: .before)
    }

    func encode(to encoder: Encoder) throws {
        try entry.encode(to: encoder)
        var container = encoder.container(keyedBy: Neighbors.self)
        try container.encodeIfPresent(after, forKey: .after)
        try container.encodeIfPresent(before, forKey: .before)
    }
}

private enum RecordSupport {
    static func sameID(_ left: String, _ right: String) -> Bool {
        left.caseInsensitiveCompare(right) == .orderedSame
    }

    static func restoredPosition(of removed: RemovedHistoryEntry, in history: [HistoryEntry]) -> Int {
        if let after = removed.after, let index = history.firstIndex(where: { sameID($0.id, after) }) { return index + 1 }
        if let before = removed.before, let index = history.firstIndex(where: { sameID($0.id, before) }) { return index }
        let completedAt = removed.entry.completedAt
        let ascending = (history.first?.completedAt ?? .distantPast) <= (history.last?.completedAt ?? .distantFuture)
        let later = ascending ? history.firstIndex { $0.completedAt > completedAt } : history.firstIndex { $0.completedAt < completedAt }
        return later ?? history.count
    }

    static func stampFormatter() -> (Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = .autoupdatingCurrent
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mmXXX"
        return { formatter.string(from: $0) }
    }

    static func rounded(_ value: Double, _ places: Int) -> Double {
        let factor = pow(10, Double(places))
        return (value * factor).rounded() / factor
    }

    static func whole(_ value: Double) -> Int? {
        value.isFinite && abs(value) < 1e12 ? Int(value.rounded()) : nil
    }

    static let momentPattern = try! NSRegularExpression(
        pattern: #"^(\d{4})-(\d{2})-(\d{2})(?:[T ](\d{2}):(\d{2})(?::(\d{2})(?:\.\d+)?)?\s*(Z|[+-]\d{2}(?::?\d{2})?)?)?$"#,
        options: [.caseInsensitive]
    )

    static func offsetZone(_ text: String) -> TimeZone? {
        if text.caseInsensitiveCompare("Z") == .orderedSame { return TimeZone(secondsFromGMT: 0) }
        let digits = text.dropFirst().filter(\.isNumber)
        guard digits.count == 2 || digits.count == 4, let hours = Int(digits.prefix(2)),
              let minutes = digits.count == 4 ? Int(digits.suffix(2)) : 0, hours <= 14, minutes <= 59 else { return nil }
        return TimeZone(secondsFromGMT: (text.hasPrefix("-") ? -1 : 1) * (hours * 3600 + minutes * 60))
    }

    static func recordMoment(_ text: String, key: String, now: Date) throws -> Date {
        let invalid = AgentToolError(
            "invalid_argument", "'\(key)' is not a date or date-time: '\(text)'.",
            hint: "Use ISO 8601, for example 2026-11-24, 2026-11-24T18:30 (your local time) or 2026-11-24T18:30+02:00."
        )
        let clean = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let match = momentPattern.firstMatch(in: clean, range: NSRange(clean.startIndex..., in: clean)) else { throw invalid }
        func group(_ index: Int) -> String? {
            let found = match.range(at: index)
            return found.location == NSNotFound ? nil : Range(found, in: clean).map { String(clean[$0]) }
        }
        guard let year = group(1).flatMap(Int.init), let month = group(2).flatMap(Int.init), let day = group(3).flatMap(Int.init) else { throw invalid }
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .autoupdatingCurrent
        if let suffix = group(7) {
            guard let zone = offsetZone(suffix) else { throw invalid }
            calendar.timeZone = zone
        }
        let parts = DateComponents(
            year: year, month: month, day: day,
            hour: group(4).flatMap(Int.init) ?? 12, minute: group(5).flatMap(Int.init) ?? 0, second: group(6).flatMap(Int.init) ?? 0
        )
        guard var date = calendar.date(from: parts) else { throw invalid }
        let check = calendar.dateComponents([.year, .month, .day, .hour, .minute, .second], from: date)
        guard check.year == year, check.month == month, check.day == day,
              check.hour == parts.hour, check.minute == parts.minute, check.second == parts.second else { throw invalid }
        if group(4) == nil, date > now, calendar.isDate(date, inSameDayAs: now) { date = now }
        guard date <= now.addingTimeInterval(60) else {
            throw AgentToolError("invalid_argument", "'\(key)' is in the future.", hint: "A workout can be logged once it is done: use a time up to now, or leave \(key) out.")
        }
        return date
    }

    static func backupLabel(_ raw: String?) throws -> String {
        let text = (raw ?? "").split(whereSeparator: \.isWhitespace).joined(separator: "-")
        if text.isEmpty { return "tmax" }
        let allowed = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-")
        guard text.count <= 40, text.unicodeScalars.allSatisfy(allowed.contains) else {
            throw AgentToolError("invalid_argument", "'label' may hold letters, digits and dashes, up to 40 characters.", hint: "For example before-cleanup.")
        }
        return text
    }

    static func freshSection(_ section: WorkoutSectionManifest) -> WorkoutSectionManifest {
        var copy = section
        copy.id = UUID().uuidString
        copy.slots = section.slots.map(AgentToolbox.freshCopy)
        if var row = copy.bigRestRow {
            row.id = UUID().uuidString
            row.contents = row.contents.map { content in
                var item = content
                item.id = UUID().uuidString
                return item
            }
            copy.bigRestRow = row
        }
        return copy
    }

    static func copyName(of name: String, taken: Set<String>) -> String {
        let base = "\(name) Copy"
        var candidate = base
        var number = 2
        while taken.contains(AgentValue.fold(candidate)) {
            candidate = "\(base) \(number)"
            number += 1
        }
        return candidate
    }

    static func groupIndex(_ reference: String, in groups: [WorkoutGroupManifest]) throws -> Int {
        let text = reference.trimmingCharacters(in: .whitespacesAndNewlines)
        if let index = groups.firstIndex(where: { sameID($0.id, text) }) { return index }
        let named = groups.indices.filter { AgentValue.fold(groups[$0].title) == AgentValue.fold(text) }
        if named.count == 1 { return named[0] }
        if named.count > 1 {
            throw AgentToolError("ambiguous", "\(named.count) workout groups are titled '\(text)'.", hint: "Use one of the ids: \(named.map { groups[$0].id }.joined(separator: ", ")).")
        }
        throw AgentToolError("not_found", "No workout group matches '\(text)'.", hint: "Use list_workout_groups to see the groups.")
    }
}

extension AgentToolbox {
    func runRecordTool(_ name: String, _ args: AgentArguments, dryRun: Bool) throws -> AgentToolOutput? {
        switch name {
        case "list_history": return try listHistory(args)
        case "log_workout": return try logWorkout(args, dryRun: dryRun)
        case "delete_history_entry": return try deleteHistoryEntry(args, dryRun: dryRun)
        case "list_outdoor_activities": return try listOutdoorActivities(args)
        case "get_outdoor_activity": return try getOutdoorActivity(args)
        case "update_outdoor_activity": return try updateOutdoorActivity(args, dryRun: dryRun)
        case "delete_outdoor_activity": return try deleteOutdoorActivity(args, dryRun: dryRun)
        case "validate_library": return validateLibrary()
        case "create_backup": return try createBackup(args, dryRun: dryRun)
        case "duplicate_workout": return try duplicateWorkout(args, dryRun: dryRun)
        default: return nil
        }
    }

    func revertLoggedHistoryEntry(_ id: String) throws -> String {
        let history = try database.readHistory()
        guard history.contains(where: { RecordSupport.sameID($0.id, id) }) else {
            return "The logged workout \(id) was already gone from the history."
        }
        try database.replaceHistory(history.filter { !RecordSupport.sameID($0.id, id) })
        return "Removed the logged workout \(id) from the history."
    }

    func revertRemovedHistoryEntry(_ payload: String) throws -> String {
        let removed = try JSONDecoder().decode(RemovedHistoryEntry.self, from: Data(payload.utf8))
        var history = try database.readHistory()
        guard !history.contains(where: { RecordSupport.sameID($0.id, removed.entry.id) }) else {
            return "The history entry \(removed.entry.id) was already back."
        }
        history.insert(removed.entry, at: RecordSupport.restoredPosition(of: removed, in: history))
        let sync = SyncStateStore(fs: database.fs)
        try sync.locked {
            try database.replaceHistory(history)
            database.forgetHistoryTombstones([removed.entry.id], store: sync)
        }
        return "Put the history entry \(removed.entry.workoutName) back."
    }

    private func historySummary(_ entry: HistoryEntry, stamp: (Date) -> String) -> [String: Any] {
        var item: [String: Any] = [
            "id": entry.id, "name": entry.workoutName, "at": stamp(entry.completedAt),
            "seconds": entry.isPartial ? entry.elapsedSeconds : entry.durationCompleted, "type": entry.workoutType.name,
        ]
        if entry.isPartial { item["partial"] = true }
        if database.workoutExists(id: entry.workoutId) { item["workout"] = entry.workoutId }
        return item
    }

    private func listHistory(_ args: AgentArguments) throws -> AgentToolOutput {
        let days = args.int("days") ?? 30
        let limit = args.int("limit") ?? 30
        let type = try resolveType(args.string("type"))
        let cutoff = Date().addingTimeInterval(-Double(days) * 86400)
        let matching = try database.readHistory()
            .filter { $0.completedAt >= cutoff && (type == nil || $0.workoutType.id == type?.id) }
            .sorted { ($0.completedAt, $0.id) > ($1.completedAt, $1.id) }
        let stamp = RecordSupport.stampFormatter()
        var value: [String: Any] = ["days": days, "total": matching.count, "entries": matching.prefix(limit).map { historySummary($0, stamp: stamp) }]
        if matching.count > limit { value["more"] = matching.count - limit }
        return AgentToolOutput(value: value)
    }

    private func logWorkout(_ args: AgentArguments, dryRun: Bool) throws -> AgentToolOutput {
        let workout = try args.string("workout").map { try findWorkout($0) }
        let typedName = args.string("name").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.flatMap { $0.isEmpty ? nil : $0 }
        guard let name = typedName ?? workout?.name else {
            throw AgentToolError("invalid_argument", "Say what was done.", hint: "Pass workout (a saved workout's id or exact name) or name.")
        }
        let partial = args.bool("partial") ?? false
        guard let seconds = args.int("seconds") ?? (partial ? nil : workout?.totalDuration) else {
            throw AgentToolError(
                "invalid_argument", partial ? "A partial workout needs seconds: the time actually done." : "Say how long it took.",
                hint: "Pass seconds, for example 1800. A saved workout that was finished supplies its planned length."
            )
        }
        let type = try resolveType(args.string("type")) ?? workout?.type ?? .other
        let now = Date()
        let when = try args.string("completedAt").map { try RecordSupport.recordMoment($0, key: "completedAt", now: now) } ?? now
        let entry = HistoryEntry(
            workoutId: workout?.id ?? UUID().uuidString, workoutName: name, completedAt: when,
            durationCompleted: partial ? (workout?.totalDuration ?? seconds) : seconds,
            workoutType: type, isPartial: partial, elapsedSeconds: partial ? seconds : 0
        )
        var value = historySummary(entry, stamp: RecordSupport.stampFormatter())
        if dryRun {
            value.removeValue(forKey: "id")
            return AgentToolOutput(value: ["dryRun": true, "wouldLog": value])
        }
        try database.appendHistoryEntry(entry)
        return AgentToolOutput(value: value, effects: [.loggedHistoryEntry(id: entry.id)])
    }

    private func deleteHistoryEntry(_ args: AgentArguments, dryRun: Bool) throws -> AgentToolOutput {
        let id = try args.requiredString("id")
        var history = try database.readHistory()
        guard let index = history.firstIndex(where: { RecordSupport.sameID($0.id, id) }) else {
            throw AgentToolError("not_found", "No history entry has the id '\(id)'.", hint: "Use list_history to see the ids.")
        }
        let entry = history[index]
        var value = historySummary(entry, stamp: RecordSupport.stampFormatter())
        if dryRun { return AgentToolOutput(value: ["dryRun": true, "wouldDelete": value]) }
        let payload = RemovedHistoryEntry(
            entry: entry, after: index > 0 ? history[index - 1].id : nil, before: index + 1 < history.count ? history[index + 1].id : nil
        )
        history.remove(at: index)
        try database.replaceHistory(history)
        value["deleted"] = true
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        return AgentToolOutput(value: value, effects: [.removedHistoryEntry(entry: String(decoding: try encoder.encode(payload), as: UTF8.self))])
    }

    private func outdoorActivity(_ reference: String) throws -> OutdoorActivityManifest {
        let text = reference.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let match = try database.listOutdoorActivities().first(where: { RecordSupport.sameID($0.id, text) }) else {
            throw AgentToolError("not_found", "No outdoor activity has the id '\(text)'.", hint: "Use list_outdoor_activities to see the ids.")
        }
        return match
    }

    private func outdoorSummary(_ activity: OutdoorActivityManifest, stamp: (Date) -> String) -> [String: Any] {
        var item: [String: Any] = [
            "id": activity.id, "kind": activity.kind.rawValue, "at": stamp(activity.startedAt),
            "distanceKm": RecordSupport.rounded(activity.distanceMeters / 1000, 2), "seconds": activity.elapsedSeconds,
        ]
        if activity.title != activity.kind.defaultTitle { item["title"] = activity.title }
        if activity.starred { item["starred"] = true }
        if !activity.finished { item["finished"] = false }
        return item
    }

    private func listOutdoorActivities(_ args: AgentArguments) throws -> AgentToolOutput {
        let limit = args.int("limit") ?? 30
        let kind = args.string("kind")
        let cutoff = args.int("days").map { Date().addingTimeInterval(-Double($0) * 86400) }
        let matching = try database.listOutdoorActivities().filter { activity in
            (kind == nil || activity.kind.rawValue == kind) && (cutoff.map { activity.startedAt >= $0 } ?? true)
        }
        let stamp = RecordSupport.stampFormatter()
        var value: [String: Any] = ["total": matching.count, "activities": matching.prefix(limit).map { outdoorSummary($0, stamp: stamp) }]
        if matching.count > limit { value["more"] = matching.count - limit }
        return AgentToolOutput(value: value)
    }

    private func getOutdoorActivity(_ args: AgentArguments) throws -> AgentToolOutput {
        let activity = try outdoorActivity(try args.requiredString("id"))
        let stamp = RecordSupport.stampFormatter()
        var value = outdoorSummary(activity, stamp: stamp)
        value["title"] = activity.title
        value["finished"] = activity.finished
        value["visibility"] = activity.visibility.rawValue
        value["distanceMeters"] = RecordSupport.rounded(activity.distanceMeters, 1)
        if let total = activity.totalDistanceMeters, total > activity.distanceMeters + 0.5 { value["totalDistanceMeters"] = RecordSupport.rounded(total, 1) }
        if activity.movingSeconds > 0 { value["movingSeconds"] = activity.movingSeconds }
        if let endedAt = activity.endedAt { value["endedAt"] = stamp(endedAt) }
        if let speed = activity.averageSpeedMetersPerSecond { value["averageSpeedMetersPerSecond"] = RecordSupport.rounded(speed, 2) }
        if let speed = activity.maxSpeedMetersPerSecond { value["maxSpeedMetersPerSecond"] = RecordSupport.rounded(speed, 2) }
        if let pace = activity.averagePaceSecondsPerKilometer, let seconds = RecordSupport.whole(pace) { value["averagePaceSecondsPerKilometer"] = seconds }
        if let gain = activity.elevationGainMeters { value["elevationGainMeters"] = RecordSupport.rounded(gain, 1) }
        if let highest = activity.highestElevationMeters { value["highestElevationMeters"] = RecordSupport.rounded(highest, 1) }
        if let target = activity.timeTargetSeconds { value["timeTargetSeconds"] = target }
        if !activity.finished { value["recordingState"] = activity.recordingState.rawValue }
        if activity.currentTravelMode == .bus { value["travelMode"] = "bus" }
        if let routeID = activity.plannedRouteID { value["plannedRouteID"] = routeID }
        if activity.plannedRouteSnapshot != nil { value["plannedRoute"] = true }
        if let establishedAt = activity.establishedAt { value["establishedAt"] = stamp(establishedAt) }
        if !activity.publicDescription.isEmpty { value["description"] = activity.publicDescription }
        if !activity.tags.isEmpty { value["tags"] = activity.tags }
        if activity.hasPublicMetadata {
            value["allowComments"] = activity.allowComments
            value["hideStartFinish"] = activity.hideStartFinish
            value["endpointPrivacyMeters"] = activity.endpointPrivacyMeters
            value["showPlayerTracks"] = activity.showPlayerTracks
        }
        if !activity.pauseIntervals.isEmpty {
            value["pauses"] = activity.pauseIntervals.count
            let paused = activity.pauseIntervals.reduce(0.0) { $0 + ($1.endedAt?.timeIntervalSince($1.startedAt) ?? 0) }
            if paused > 0, let seconds = RecordSupport.whole(paused) { value["pausedSeconds"] = seconds }
        }
        if !activity.laps.isEmpty {
            value["laps"] = activity.laps.prefix(50).map { ["number": $0.number, "seconds": $0.elapsedSeconds, "meters": RecordSupport.rounded($0.distanceMeters, 1)] as [String: Any] }
            if activity.laps.count > 50 { value["moreLaps"] = activity.laps.count - 50 }
        }
        if !activity.playedTracks.isEmpty {
            value["playedTracks"] = activity.playedTracks.prefix(10).map { track in track.artist.flatMap { $0.isEmpty ? nil : "\(track.title) - \($0)" } ?? track.title }
            if activity.playedTracks.count > 10 { value["morePlayedTracks"] = activity.playedTracks.count - 10 }
        }
        let points = try database.readOutdoorTrackPoints(id: activity.id)
        value["trackPoints"] = points.count
        if args.bool("points") == true {
            let wanted = min(max(1, args.int("limit") ?? 20), points.count)
            let sample = wanted >= points.count ? points : wanted == 1 ? Array(points.prefix(1)) : (0..<wanted).map { points[$0 * (points.count - 1) / (wanted - 1)] }
            value["points"] = sample.map { point -> [String: Any] in
                var item: [String: Any] = [
                    "t": RecordSupport.whole(point.timestamp.timeIntervalSince(activity.startedAt)).map { max(0, $0) } ?? 0,
                    "lat": RecordSupport.rounded(point.latitude, 6), "lon": RecordSupport.rounded(point.longitude, 6),
                ]
                if let elevation = point.elevationMeters { item["ele"] = RecordSupport.rounded(elevation, 1) }
                if let speed = point.speedMetersPerSecond { item["speed"] = RecordSupport.rounded(speed, 2) }
                return item
            }
        }
        return AgentToolOutput(value: value)
    }

    private func updateOutdoorActivity(_ args: AgentArguments, dryRun: Bool) throws -> AgentToolOutput {
        var activity = try outdoorActivity(try args.requiredString("id"))
        guard activity.finished else {
            throw AgentToolError("invalid_argument", "This activity is not finished, so the app may still be recording it.", hint: "Finish it in the app first.")
        }
        var changed: [String] = []
        if let kind = args.string("kind").flatMap(OutdoorActivityKind.init(rawValue:)) {
            if activity.title == activity.kind.defaultTitle { activity.title = kind.defaultTitle }
            activity.kind = kind
            changed.append("kind")
        }
        if args.has("title") {
            let title = args.string("title")?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            activity.title = title.isEmpty ? activity.kind.defaultTitle : title
            changed.append("title")
        }
        if let starred = args.bool("starred") {
            activity.starred = starred
            changed.append("starred")
        }
        if args.has("description") {
            activity.publicDescription = args.string("description")?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            activity.hasPublicMetadata = true
            changed.append("description")
        }
        if let tags = args.strings("tags") {
            var seen = Set<String>()
            activity.tags = tags.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty && seen.insert(AgentValue.fold($0)).inserted }
            activity.hasPublicMetadata = true
            changed.append("tags")
        }
        guard !changed.isEmpty else {
            throw AgentToolError("invalid_argument", "Nothing to change.", hint: "Pass title, kind, starred, description or tags.")
        }
        if dryRun { return AgentToolOutput(value: ["dryRun": true, "id": activity.id, "wouldChange": changed]) }
        try database.updateOutdoorActivity(id: activity.id, manifest: activity)
        return AgentToolOutput(value: ["id": activity.id, "title": activity.title, "kind": activity.kind.rawValue, "changed": changed])
    }

    private func deleteOutdoorActivity(_ args: AgentArguments, dryRun: Bool) throws -> AgentToolOutput {
        let activity = try outdoorActivity(try args.requiredString("id"))
        var value = outdoorSummary(activity, stamp: RecordSupport.stampFormatter())
        if dryRun { return AgentToolOutput(value: ["dryRun": true, "wouldTrash": value]) }
        try database.deleteOutdoorActivity(id: activity.id)
        value["trashed"] = true
        value["where"] = ".trash"
        return AgentToolOutput(value: value)
    }

    private func recordPlace(of path: String, pages: AgentPageIndex?) -> (key: String, title: String)? {
        let parts = path.split(separator: "/").map(String.init)
        if parts.first == "Workouts" {
            guard let id = parts.last, let workout = try? database.getWorkout(id: id) else { return nil }
            return ("name", workout.name)
        }
        guard let pages else { return nil }
        for offset in parts.indices.reversed() where offset > 0 && pages.byID[parts[offset]] != nil {
            return (offset == parts.count - 1 ? "name" : "in", pages.titlePath(parts[offset]))
        }
        return nil
    }

    private func validateLibrary() -> AgentToolOutput {
        let results = database.validateAll()
        let findings = results.compactMap { result -> (path: String, errors: [String], warnings: [String])? in
            let warnings = result.warnings.filter { !($0.hasPrefix("Field ") && $0.contains(", got Optional<")) }
            return result.valid && warnings.isEmpty ? nil : (result.path, result.errors, warnings)
        }.sorted { ($0.errors.isEmpty ? 1 : 0, $0.path) < ($1.errors.isEmpty ? 1 : 0, $1.path) }
        let failing = findings.filter { !$0.errors.isEmpty }.count
        var value: [String: Any] = ["checked": results.count, "healthy": results.count - findings.count, "withErrors": failing]
        if findings.count > failing { value["withWarnings"] = findings.count - failing }
        if !findings.isEmpty {
            let pages = try? AgentPageIndex(database: database)
            value["problems"] = findings.prefix(50).map { finding -> [String: Any] in
                var item: [String: Any] = ["path": finding.path]
                if let place = recordPlace(of: finding.path, pages: pages) { item[place.key] = place.title }
                if !finding.errors.isEmpty { item["errors"] = finding.errors }
                if !finding.warnings.isEmpty { item["warnings"] = finding.warnings }
                return item
            }
            if findings.count > 50 { value["more"] = findings.count - 50 }
        }
        return AgentToolOutput(value: value)
    }

    private func createBackup(_ args: AgentArguments, dryRun: Bool) throws -> AgentToolOutput {
        let label = try RecordSupport.backupLabel(args.string("label"))
        if dryRun { return AgentToolOutput(value: ["dryRun": true, "wouldCopy": "the library into a new folder under Backups"]) }
        let folder = try database.syncCreateSafetyCopy(label: label)
        let contains = ((try? FileManager.default.contentsOfDirectory(atPath: folder.path)) ?? []).sorted()
        return AgentToolOutput(value: ["folder": folder.lastPathComponent, "in": "Backups", "contains": contains])
    }

    private func duplicateWorkout(_ args: AgentArguments, dryRun: Bool) throws -> AgentToolOutput {
        let original = try findWorkout(try args.requiredString("workout"))
        let taken = Set(try database.listWorkouts().map { AgentValue.fold($0.name) })
        let wanted = args.string("name")?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let name: String
        if wanted.isEmpty {
            name = RecordSupport.copyName(of: original.name, taken: taken)
        } else if taken.contains(AgentValue.fold(wanted)) {
            throw AgentToolError("already_exists", "A workout named '\(wanted)' already exists.", hint: "Pick another name, or leave name out to get '\(original.name) Copy'.")
        } else {
            name = wanted
        }
        var config = try database.loadConfig()
        let group = try args.string("group").map { try RecordSupport.groupIndex($0, in: config.workoutGroups) }
        var copy = original
        copy.id = UUID().uuidString
        copy.name = name
        copy.createdAt = Date()
        copy.sections = original.sections.map(RecordSupport.freshSection)
        var value: [String: Any] = ["name": name, "copyOf": original.name, "sections": copy.sections.count, "totalSeconds": copy.totalDuration]
        if let group { value["group"] = config.workoutGroups[group].title }
        if dryRun {
            value["dryRun"] = true
            return AgentToolOutput(value: value)
        }
        try database.createWorkout(id: copy.id, manifest: copy)
        if let group {
            Self.moveWorkouts([copy.id], into: config.workoutGroups[group].id, groups: &config.workoutGroups)
            do {
                try database.saveConfig(config)
            } catch {
                try? database.deleteWorkout(id: copy.id)
                throw error
            }
        }
        value["id"] = copy.id
        return AgentToolOutput(value: value, effects: [.createdWorkout(id: copy.id)])
    }
}
