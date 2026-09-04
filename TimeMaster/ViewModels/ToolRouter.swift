import Foundation
import TimeMasterCore

private typealias WT = TimeMasterCore.WorkoutType
private typealias CoreExerciseManifest = TimeMasterCore.ExerciseManifest
private typealias CoreWorkoutManifest = TimeMasterCore.WorkoutManifest
private typealias CoreWorkoutSectionManifest = TimeMasterCore.WorkoutSectionManifest

struct ToolResult: Codable {
    let success: Bool
    let data: String
    let toolName: String
}

final class ToolRouter {
    let db: DatabaseManager
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    init(db: DatabaseManager = .shared) {
        self.db = db
        self.encoder = JSONEncoder()
        self.encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        self.encoder.dateEncodingStrategy = .iso8601
        self.decoder = JSONDecoder()
        self.decoder.dateDecodingStrategy = .iso8601
    }

    func execute(toolName: String, args: [String: Any]) async -> ToolResult {
        do {
            try db.bootstrapIfNeeded()
            let data = try await executeTool(toolName, args: args)
            await MainActor.run {
                DatabaseStore.shared.reload()
            }
            return ToolResult(success: true, data: data, toolName: toolName)
        } catch {
            return ToolResult(success: false, data: "Error: \(error.localizedDescription)", toolName: toolName)
        }
    }

    private func executeTool(_ name: String, args: [String: Any]) async throws -> String {
        switch name {
        case "search_exercises": return try searchExercises(args)
        case "get_exercise": return try getExercise(args)
        case "list_folders": return try listFolders(args)
        case "create_exercise": return try createExercise(args)
        case "create_folder": return try createFolder(args)
        case "create_container_page": return try createContainerPage(args)
        case "create_exercise_page": return try createExercisePage(args)
        case "get_recent_workouts": return try getRecentWorkouts(args)
        case "build_workout": return try buildWorkout(args)
        case "get_analytics": return try getAnalytics(args)
        case "get_stats": return try getStats(args)
        case "add_media_note": return try addMediaNote(args)
        case "get_settings": return try getSettings()
        case "update_settings": return try updateSettings(args)
        default:
            throw ToolError.unknownTool(name)
        }
    }

    // MARK: - search_exercises

    private func searchExercises(_ args: [String: Any]) throws -> String {
        let query = args["query"] as? String ?? ""
        let typeName = args["type"] as? String
        let type: WT? = typeName.flatMap { name in
            WT.builtIn.first { $0.name.localizedCaseInsensitiveCompare(name) == .orderedSame }
        }
        let results = try db.searchExercises(query: query, type: type)
        let output = results.map { r in
            let result: [String: Any] = [
                "id": r.manifest.id,
                "name": r.manifest.name,
                "type": r.manifest.workoutType?.name ?? "Other",
                "duration": r.manifest.duration,
                "restAfter": r.manifest.restAfter,
                "sets": r.manifest.sets as Any,
                "details": r.manifest.details,
                "path": r.path,
            ]
            return result
        }
        let jsonData = try JSONSerialization.data(withJSONObject: output, options: [.prettyPrinted, .sortedKeys])
        return String(data: jsonData, encoding: .utf8) ?? "[]"
    }

    // MARK: - get_exercise

    private func getExercise(_ args: [String: Any]) throws -> String {
        let id = args["id"] as? String ?? ""
        let parentPath = args["parentID"] as? String

        let manifest = try db.getExercise(id: id, parentPath: parentPath)

        let base = db.exercisesDatabaseURL
        let folder: URL
        if let parent = parentPath {
            folder = base.appendingPathComponent(parent, isDirectory: true).appendingPathComponent(id, isDirectory: true)
        } else {
            folder = base.appendingPathComponent(id, isDirectory: true)
        }
        let guideURL = folder.appendingPathComponent("guide.md")
        var guideContent = ""
        if let content = try? String(contentsOf: guideURL, encoding: .utf8) {
            guideContent = content
        }

        var result: [String: Any] = [
            "id": manifest.id,
            "name": manifest.name,
            "details": manifest.details,
            "duration": manifest.duration,
            "restAfter": manifest.restAfter,
            "workoutType": manifest.workoutType?.name ?? "Other",
            "workoutTypeId": manifest.workoutType?.id ?? "",
            "sets": manifest.sets as Any,
            "restBetweenSets": manifest.restBetweenSets as Any,
            "mediaFilenames": manifest.mediaFilenames,
            "linkURLs": manifest.linkURLs,
            "guide": guideContent,
        ]
        let jsonData = try JSONSerialization.data(withJSONObject: result, options: [.prettyPrinted, .sortedKeys])
        return String(data: jsonData, encoding: .utf8) ?? "{}"
    }

    // MARK: - list_folders

    private func listFolders(_ args: [String: Any]) throws -> String {
        let parentPath = args["parentID"] as? String
        let folders = try db.listFolders(parentPath: parentPath)
        let output = folders.map { f in
            let result: [String: Any] = [
                "name": f.name,
                "path": f.path,
                "hasManifest": f.hasManifest,
            ]
            return result
        }
        let jsonData = try JSONSerialization.data(withJSONObject: output, options: [.prettyPrinted, .sortedKeys])
        return String(data: jsonData, encoding: .utf8) ?? "[]"
    }

    // MARK: - create_exercise

    private func createExercise(_ args: [String: Any]) throws -> String {
        let name = args["name"] as? String ?? "New Exercise"
        let typeName = args["type"] as? String
        let duration = args["duration"] as? Int ?? 30
        let restAfter = args["restAfter"] as? Int ?? 10
        let parentPath = args["parentID"] as? String
        let details = args["details"] as? String ?? ""
        let sets = args["sets"] as? Int
        let mediaFilenames = args["mediaFilenames"] as? [String] ?? []
        let linkURLs = args["linkURLs"] as? [String] ?? []

        let type: WT? = typeName.flatMap { name in
            WT.builtIn.first { $0.name.localizedCaseInsensitiveCompare(name) == .orderedSame }
        }
        let id = UUID().uuidString
        let manifest = CoreExerciseManifest(
            id: id,
            name: name,
            details: details,
            duration: duration,
            restAfter: restAfter,
            workoutType: type,
            mediaFilenames: mediaFilenames,
            linkURLs: linkURLs,
            sets: sets
        )
        try db.createExercise(id: id, manifest: manifest, parentPath: parentPath)
        var result: [String: Any] = [
            "id": id,
            "name": name,
            "duration": duration,
            "restAfter": restAfter,
            "message": "Exercise '\(name)' created successfully.",
        ]
        if let p = parentPath {
            result["parentPath"] = p
        }
        if let wt = type {
            result["type"] = wt.name
        }
        let jsonData = try JSONSerialization.data(withJSONObject: result, options: [.prettyPrinted, .sortedKeys])
        return String(data: jsonData, encoding: .utf8) ?? "{}"
    }

    // MARK: - create_folder

    private func createFolder(_ args: [String: Any]) throws -> String {
        let name = args["name"] as? String ?? "New Folder"
        let parentPath = args["parentID"] as? String
        let folderName = try db.createFolder(name: name, parentPath: parentPath)
        let result: [String: Any] = [
            "name": folderName,
            "message": "Folder '\(folderName)' created successfully.",
        ]
        let jsonData = try JSONSerialization.data(withJSONObject: result, options: [.prettyPrinted, .sortedKeys])
        return String(data: jsonData, encoding: .utf8) ?? "{}"
    }

    // MARK: - V2 page creation

    private func createContainerPage(_ args: [String: Any]) throws -> String {
        let title = args["title"] as? String ?? "New Container"
        let parentID = args["parentID"] as? String
        if parentID != nil, args["workoutType"] != nil {
            throw ToolError.invalidSettings("Nested containers inherit the root container workout type.")
        }
        let workoutType: WT? = {
            guard parentID == nil, let raw = args["workoutType"] as? [String: Any] else { return nil }
            return WT(
                id: raw["id"] as? String ?? "other",
                name: raw["name"] as? String ?? "Other",
                iconName: raw["iconName"] as? String ?? "star.fill",
                colorHex: raw["colorHex"] as? String ?? "FFFFFF"
            )
        }()
        let manifest = ExercisePageManifest(
            title: title,
            pageKind: .container,
            coverImageFilename: args["coverImageFilename"] as? String,
            iconName: args["iconName"] as? String,
            workoutType: workoutType,
            parentID: parentID
        )
        try db.createPage(manifest: manifest, parentID: parentID)
        return try pageCreationResult(id: manifest.id, title: title, kind: "container")
    }

    private func createExercisePage(_ args: [String: Any]) throws -> String {
        let parentID = (args["parentID"] as? String).flatMap { $0.isEmpty ? nil : $0 }
        if args["coverImageFilename"] != nil {
            throw ToolError.invalidSettings("Exercise pages cannot define coverImageFilename; the first media item is the cover.")
        }
        guard let duration = args["duration"] as? Int else {
            throw ToolError.missingParameter("duration")
        }

        let title = args["title"] as? String ?? "New Exercise"
        let manifest = ExercisePageManifest(
            title: title,
            pageKind: .leaf,
            markdownBody: args["markdownBody"] as? String ?? "",
            mediaFilenames: args["mediaFilenames"] as? [String] ?? [],
            linkURLs: args["linkURLs"] as? [String] ?? [],
            duration: duration,
            restAfter: args["restAfter"] as? Int ?? 0,
            sets: args["sets"] as? Int ?? 1,
            restBetweenSets: args["restBetweenSets"] as? Int ?? 0,
            parentID: parentID
        )
        try db.createPage(manifest: manifest, parentID: parentID)
        return try pageCreationResult(id: manifest.id, title: title, kind: "leaf")
    }

    private func pageCreationResult(id: String, title: String, kind: String) throws -> String {
        let result: [String: Any] = [
            "id": id,
            "title": title,
            "pageKind": kind,
            "message": "Page '\(title)' created successfully.",
        ]
        let jsonData = try JSONSerialization.data(withJSONObject: result, options: [.prettyPrinted, .sortedKeys])
        return String(data: jsonData, encoding: .utf8) ?? "{}"
    }

    // MARK: - get_recent_workouts

    private func getRecentWorkouts(_ args: [String: Any]) throws -> String {
        let days = args["days"] as? Int ?? 7
        let entries = try db.readHistory()
        let cutoff = Date().addingTimeInterval(-Double(days) * 86400)
        let recent = entries.filter { $0.completedAt >= cutoff }
        let output = recent.map { e in
            let result: [String: Any] = [
                "id": e.id,
                "workoutId": e.workoutId,
                "workoutName": e.workoutName,
                "completedAt": ISO8601DateFormatter().string(from: e.completedAt),
                "durationCompleted": e.durationCompleted,
                "type": e.workoutType.name,
                "isPartial": e.isPartial,
            ]
            return result
        }
        let jsonData = try JSONSerialization.data(withJSONObject: output, options: [.prettyPrinted, .sortedKeys])
        return String(data: jsonData, encoding: .utf8) ?? "[]"
    }

    // MARK: - build_workout

    private func buildWorkout(_ args: [String: Any]) throws -> String {
        let name = args["name"] as? String ?? "New Workout"
        let typeName = args["type"] as? String ?? "Strength"
        let type = WT.builtIn.first { $0.name.localizedCaseInsensitiveCompare(typeName) == .orderedSame } ?? .strength
        let restBetweenSections = args["restBetweenSections"] as? Int ?? 30
        let sectionsRaw = args["sections"] as? [[String: Any]] ?? []

        var sections: [CoreWorkoutSectionManifest] = []
        for raw in sectionsRaw {
            let exerciseID = raw["exerciseID"] as? String ?? UUID().uuidString
            let secName = raw["name"] as? String ?? "Section"
            let duration = raw["duration"] as? Int ?? 30
            let sets = raw["sets"] as? Int ?? 1
            let restBetweenSets = raw["restBetweenSets"] as? Int ?? 10
            let prepareTime = raw["prepareTime"] as? Int ?? 4
            let section = CoreWorkoutSectionManifest(
                exerciseID: exerciseID,
                name: secName,
                duration: duration,
                sets: sets,
                restBetweenSets: restBetweenSets,
                prepareTime: prepareTime
            )
            sections.append(section)
        }

        let id = UUID().uuidString
        let manifest = CoreWorkoutManifest(
            id: id,
            name: name,
            type: type,
            sections: sections,
            restBetweenSections: restBetweenSections
        )
        try db.createWorkout(id: id, manifest: manifest)
        let buildResult: [String: Any] = [
            "id": id,
            "name": name,
            "type": type.name,
            "sectionsCount": sections.count,
            "totalDuration": manifest.totalDuration,
            "restBetweenSections": restBetweenSections,
            "message": "Workout '\(name)' created with \(sections.count) sections.",
        ]
        let jsonData = try JSONSerialization.data(withJSONObject: buildResult, options: [.prettyPrinted, .sortedKeys])
        return String(data: jsonData, encoding: .utf8) ?? "{}"
    }

    // MARK: - get_analytics

    private func getAnalytics(_ args: [String: Any]) throws -> String {
        let typeName = args["type"] as? String
        let days = args["days"] as? Int
        let type: WT? = typeName.flatMap { name in
            WT.builtIn.first { $0.name.localizedCaseInsensitiveCompare(name) == .orderedSame }
        }
        let stats = try db.getStats(type: type, days: days)
        let result: [String: Any] = [
            "count": stats.count,
            "currentStreak": stats.streak,
            "bestStreak": stats.bestStreak,
            "totalDurationSeconds": stats.totalDuration,
            "totalDurationMinutes": stats.totalDuration / 60,
        ]
        let jsonData = try JSONSerialization.data(withJSONObject: result, options: [.prettyPrinted, .sortedKeys])
        return String(data: jsonData, encoding: .utf8) ?? "{}"
    }

    // MARK: - get_stats

    private func getStats(_ args: [String: Any]) throws -> String {
        let stats = try db.getStats()
        let exercises = (try? db.searchAllExercises()) ?? []
        let result: [String: Any] = [
            "totalWorkouts": stats.count,
            "currentStreak": stats.streak,
            "bestStreak": stats.bestStreak,
            "totalDurationSeconds": stats.totalDuration,
            "totalDurationMinutes": stats.totalDuration / 60,
            "totalExercises": exercises.count,
        ]
        let jsonData = try JSONSerialization.data(withJSONObject: result, options: [.prettyPrinted, .sortedKeys])
        return String(data: jsonData, encoding: .utf8) ?? "{}"
    }

    // MARK: - add_media_note

    private func addMediaNote(_ args: [String: Any]) throws -> String {
        let exerciseID = args["exerciseID"] as? String ?? ""
        let note = args["note"] as? String ?? ""
        guard !exerciseID.isEmpty, !note.isEmpty else {
            throw ToolError.missingParameter("exerciseID and note are required")
        }

        let base = db.exercisesDatabaseURL
        let guideURL = findGuideURL(for: exerciseID, in: base, parentPath: args["parentID"] as? String)
            ?? findGuideURLRecursive(for: exerciseID, in: base)

        guard let guidePath = guideURL else {
            throw ToolError.exerciseNotFound(exerciseID)
        }

        let timestamp = ISO8601DateFormatter().string(from: Date())
        let entry = "\n\n---\n\n**AI Note** (\(timestamp)): \(note)\n"
        if let existing = try? String(contentsOf: guidePath, encoding: .utf8) {
            let updated = existing + entry
            try updated.write(to: guidePath, atomically: true, encoding: .utf8)
        } else {
            let newContent = "# Notes\n\n\(entry)"
            try newContent.write(to: guidePath, atomically: true, encoding: .utf8)
        }

        let result: [String: Any] = [
            "message": "Note added to exercise '\(exerciseID)'.",
        ]
        let jsonData = try JSONSerialization.data(withJSONObject: result, options: [.prettyPrinted, .sortedKeys])
        return String(data: jsonData, encoding: .utf8) ?? "{}"
    }

    // MARK: - Agent-safe settings

    private func getSettings() throws -> String {
        let preferences = NotificationManager.shared.preferences
        let config = try? db.loadConfig()
        let schedules = config?.typeSchedules.map { schedule in
            [
                "type": schedule.type.name,
                "daysOfWeek": schedule.daysOfWeek,
                "weeklyGoal": schedule.weeklyGoal,
                "durationMonths": schedule.durationMonths,
            ] as [String: Any]
        } ?? []
        let result: [String: Any] = [
            "extraRestSeconds": UserDefaults.standard.object(forKey: "extra_rest_seconds") as? Int ?? 15,
            "motivationEnabled": MotivationManager.shared.isEnabled,
            "motivationInterval": MotivationManager.shared.interval,
            "notifications": [
                "enabled": preferences.isEnabled,
                "reminderHour": preferences.reminderHour,
                "reminderMinute": preferences.reminderMinute,
                "reminderLeadMinutes": preferences.reminderLeadMinutes,
                "streakMotivationEnabled": preferences.streakMotivationEnabled,
                "missedDayNudgesEnabled": preferences.missedDayNudgesEnabled,
                "restDayAffirmationsEnabled": preferences.restDayAffirmationsEnabled,
            ],
            "typeSchedules": schedules,
            "excluded": ["API keys", "provider credentials", "filesystem paths", "music files"],
        ]
        let data = try JSONSerialization.data(withJSONObject: result, options: [.prettyPrinted, .sortedKeys])
        return String(data: data, encoding: .utf8) ?? "{}"
    }

    private func updateSettings(_ args: [String: Any]) throws -> String {
        let allowed = Set([
            "extraRestSeconds", "motivationEnabled", "motivationInterval", "notifications",
        ])
        let unsupported = Set(args.keys).subtracting(allowed)
        guard unsupported.isEmpty else {
            throw ToolError.invalidSettings("Unsupported setting: \(unsupported.sorted().joined(separator: ", "))")
        }
        guard !args.isEmpty else { throw ToolError.missingParameter("at least one supported setting") }

        var changed: [String: Any] = [:]
        if let value = args["extraRestSeconds"] {
            guard let seconds = value as? Int, (5...120).contains(seconds), seconds.isMultiple(of: 5) else {
                throw ToolError.invalidSettings("extraRestSeconds must be a multiple of 5 from 5 through 120")
            }
            UserDefaults.standard.set(seconds, forKey: "extra_rest_seconds")
            changed["extraRestSeconds"] = seconds
        }
        if let value = args["motivationEnabled"] {
            guard let enabled = value as? Bool else {
                throw ToolError.invalidSettings("motivationEnabled must be true or false")
            }
            MotivationManager.shared.isEnabled = enabled
            changed["motivationEnabled"] = enabled
        }
        if let value = args["motivationInterval"] {
            guard let seconds = value as? Int, (30...120).contains(seconds), seconds.isMultiple(of: 5) else {
                throw ToolError.invalidSettings("motivationInterval must be a multiple of 5 from 30 through 120")
            }
            MotivationManager.shared.interval = seconds
            changed["motivationInterval"] = seconds
        }
        if let rawNotifications = args["notifications"] {
            guard let values = rawNotifications as? [String: Any] else {
                throw ToolError.invalidSettings("notifications must be an object")
            }
            let allowedNotificationKeys = Set([
                "enabled", "reminderHour", "reminderMinute", "reminderLeadMinutes",
                "streakMotivationEnabled", "missedDayNudgesEnabled", "restDayAffirmationsEnabled",
            ])
            let unsupportedKeys = Set(values.keys).subtracting(allowedNotificationKeys)
            guard unsupportedKeys.isEmpty else {
                throw ToolError.invalidSettings("Unsupported notification setting: \(unsupportedKeys.sorted().joined(separator: ", "))")
            }
            var preferences = NotificationManager.shared.preferences
            if let enabled = values["enabled"] {
                guard let value = enabled as? Bool else { throw ToolError.invalidSettings("notifications.enabled must be true or false") }
                preferences.isEnabled = value
            }
            if let hour = values["reminderHour"] {
                guard let value = hour as? Int, (0...23).contains(value) else { throw ToolError.invalidSettings("notifications.reminderHour must be 0 through 23") }
                preferences.reminderHour = value
            }
            if let minute = values["reminderMinute"] {
                guard let value = minute as? Int, (0...59).contains(value) else { throw ToolError.invalidSettings("notifications.reminderMinute must be 0 through 59") }
                preferences.reminderMinute = value
            }
            if let lead = values["reminderLeadMinutes"] {
                guard let value = lead as? Int, (0...60).contains(value), value.isMultiple(of: 5) else { throw ToolError.invalidSettings("notifications.reminderLeadMinutes must be a multiple of 5 from 0 through 60") }
                preferences.reminderLeadMinutes = value
            }
            for keyPath in ["streakMotivationEnabled", "missedDayNudgesEnabled", "restDayAffirmationsEnabled"] {
                if let raw = values[keyPath] {
                    guard let value = raw as? Bool else { throw ToolError.invalidSettings("notifications.\(keyPath) must be true or false") }
                    switch keyPath {
                    case "streakMotivationEnabled": preferences.streakMotivationEnabled = value
                    case "missedDayNudgesEnabled": preferences.missedDayNudgesEnabled = value
                    default: preferences.restDayAffirmationsEnabled = value
                    }
                }
            }
            let config = try? db.loadConfig()
            let schedules = config?.typeSchedules.map {
                TypeSchedule(
                    id: UUID(uuidString: $0.id) ?? UUID(),
                    folderID: UUID(uuidString: $0.folderID),
                    type: WorkoutType(core: $0.type),
                    daysOfWeek: Set($0.daysOfWeek),
                    startDate: $0.startDate,
                    durationMonths: $0.durationMonths,
                    weeklyGoal: $0.weeklyGoal,
                    endedAt: $0.endedAt
                )
            } ?? []
            NotificationManager.shared.applyPreferences(preferences, schedules: schedules, restDays: Set(config?.restDays ?? []))
            changed["notifications"] = values
        }
        let result: [String: Any] = ["message": "Settings updated.", "changed": changed]
        let data = try JSONSerialization.data(withJSONObject: result, options: [.prettyPrinted, .sortedKeys])
        return String(data: data, encoding: .utf8) ?? "{}"
    }

    private func findGuideURL(for id: String, in base: URL, parentPath: String?) -> URL? {
        let folder: URL
        if let parent = parentPath {
            folder = base.appendingPathComponent(parent, isDirectory: true).appendingPathComponent(id, isDirectory: true)
        } else {
            folder = base.appendingPathComponent(id, isDirectory: true)
        }
        let url = folder.appendingPathComponent("guide.md")
        var isDir: ObjCBool = false
        if FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir) && !isDir.boolValue {
            return url
        }
        return nil
    }

    private func findGuideURLRecursive(for id: String, in dir: URL) -> URL? {
        let candidate = dir.appendingPathComponent(id, isDirectory: true).appendingPathComponent("guide.md")
        var isDir: ObjCBool = false
        if FileManager.default.fileExists(atPath: candidate.path, isDirectory: &isDir) && !isDir.boolValue {
            return candidate
        }
        guard let entries = try? FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: [.isDirectoryKey], options: .skipsHiddenFiles) else {
            return nil
        }
        for entry in entries {
            var entryIsDir: ObjCBool = false
            FileManager.default.fileExists(atPath: entry.path, isDirectory: &entryIsDir)
            if entryIsDir.boolValue {
                if let found = findGuideURLRecursive(for: id, in: entry) {
                    return found
                }
            }
        }
        return nil
    }

    enum ToolError: LocalizedError {
        case unknownTool(String)
        case missingParameter(String)
        case exerciseNotFound(String)
        case invalidSettings(String)

        var errorDescription: String? {
            switch self {
            case .unknownTool(let name): "Unknown tool: \(name)"
            case .missingParameter(let p): "Missing required parameter: \(p)"
            case .exerciseNotFound(let id): "Exercise not found: \(id)"
            case .invalidSettings(let reason): reason
            }
        }
    }
}
