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
        case "get_recent_workouts": return try getRecentWorkouts(args)
        case "build_workout": return try buildWorkout(args)
        case "get_analytics": return try getAnalytics(args)
        case "add_media_note": return try addMediaNote(args)
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
        let parentPath = args["parentID"] as? String
        let details = args["details"] as? String ?? ""
        let sets = args["sets"] as? Int

        let type: WT? = typeName.flatMap { name in
            WT.builtIn.first { $0.name.localizedCaseInsensitiveCompare(name) == .orderedSame }
        }
        let id = UUID().uuidString
        let manifest = CoreExerciseManifest(
            id: id,
            name: name,
            details: details,
            duration: duration,
            restAfter: 10,
            workoutType: type,
            sets: sets
        )
        try db.createExercise(id: id, manifest: manifest, parentPath: parentPath)
        var result: [String: Any] = [
            "id": id,
            "name": name,
            "message": "Exercise '\(name)' created successfully.",
        ]
        if let p = parentPath {
            result["parentPath"] = p
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
            sections: sections
        )
        try db.createWorkout(id: id, manifest: manifest)
        let buildResult: [String: Any] = [
            "id": id,
            "name": name,
            "type": type.name,
            "sections": sectionsRaw,
            "totalDuration": manifest.totalDuration,
            "message": "Workout '\(name)' created with \(sections.count) sections.",
        ]
        let jsonData = try JSONSerialization.data(withJSONObject: result, options: [.prettyPrinted, .sortedKeys])
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

        var errorDescription: String? {
            switch self {
            case .unknownTool(let name): "Unknown tool: \(name)"
            case .missingParameter(let p): "Missing required parameter: \(p)"
            case .exerciseNotFound(let id): "Exercise not found: \(id)"
            }
        }
    }
}
