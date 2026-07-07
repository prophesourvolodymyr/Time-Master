import Foundation

public struct SessionContext: Codable {
    public var knowledge: String
    public var database: DatabaseSummary
    public var recentActivity: RecentActivity
    public var schedule: ScheduleSummary

    public struct DatabaseSummary: Codable {
        public var totalExercises: Int
        public var byType: [String: Int]
        public var folders: [String]

        public init(totalExercises: Int = 0, byType: [String: Int] = [:], folders: [String] = []) {
            self.totalExercises = totalExercises
            self.byType = byType
            self.folders = folders
        }
    }

    public struct RecentActivity: Codable {
        public var last7Days: Int
        public var currentStreak: Int
        public var lastWorkout: String

        public init(last7Days: Int = 0, currentStreak: Int = 0, lastWorkout: String = "None") {
            self.last7Days = last7Days
            self.currentStreak = currentStreak
            self.lastWorkout = lastWorkout
        }
    }

    public struct ScheduleSummary: Codable {
        public var trainingDays: [String]
        public var durationMonths: Int

        public init(trainingDays: [String] = [], durationMonths: Int = 0) {
            self.trainingDays = trainingDays
            self.durationMonths = durationMonths
        }
    }

    public init(knowledge: String = "", database: DatabaseSummary = DatabaseSummary(), recentActivity: RecentActivity = RecentActivity(), schedule: ScheduleSummary = ScheduleSummary()) {
        self.knowledge = knowledge
        self.database = database
        self.recentActivity = recentActivity
        self.schedule = schedule
    }

    public func toJSON() -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        guard let data = try? encoder.encode(self),
              let json = String(data: data, encoding: .utf8) else { return "{}" }
        return json
    }

    public func toSystemMessage() -> String {
        var parts: [String] = []
        if !knowledge.isEmpty {
            parts.append("# Knowledge\n\(knowledge)")
        }
        parts.append("# Database Summary")
        parts.append("- Total Exercises: \(database.totalExercises)")
        if !database.byType.isEmpty {
            let typesStr = database.byType.map { "\($0.key): \($0.value)" }.sorted().joined(separator: ", ")
            parts.append("- By Type: \(typesStr)")
        }
        if !database.folders.isEmpty {
            parts.append("- Folders: \(database.folders.joined(separator: ", "))")
        }
        parts.append("\n# Recent Activity")
        parts.append("- Workouts in last 7 days: \(recentActivity.last7Days)")
        parts.append("- Current streak: \(recentActivity.currentStreak) days")
        parts.append("- Last workout: \(recentActivity.lastWorkout)")
        parts.append("\n# Schedule")
        if schedule.trainingDays.isEmpty {
            parts.append("- No training schedule set.")
        } else {
            parts.append("- Training days: \(schedule.trainingDays.joined(separator: ", "))")
            parts.append("- Duration: \(schedule.durationMonths) months")
        }
        return parts.joined(separator: "\n")
    }
}

public final class AISystemPromptBuilder {
    public enum Error: Swift.Error, LocalizedError {
        case knowledgeDirectoryNotFound(String)

        public var errorDescription: String? {
            switch self {
            case .knowledgeDirectoryNotFound(let path): "Knowledge directory not found: \(path)"
            }
        }
    }

    private let fs: FileSystemHelper

    public init(fs: FileSystemHelper) {
        self.fs = fs
    }

    public func listKnowledgeFiles() -> [URL] {
        guard fs.directoryExists(at: fs.knowledgeDirectory) else { return [] }

        let enumerator = FileManager.default.enumerator(
            at: fs.knowledgeDirectory,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles, .skipsPackageDescendants]
        )

        var files: [URL] = []
        while let url = enumerator?.nextObject() as? URL {
            if url.pathExtension.lowercased() == "md" {
                files.append(url)
            }
        }

        return files.sorted { $0.lastPathComponent.localizedStandardCompare($1.lastPathComponent) == .orderedAscending }
    }

    public func buildSystemPrompt() -> String {
        let files = listKnowledgeFiles()
        guard !files.isEmpty else { return "" }

        let fileManager = FileManager.default
        let parts: [String] = files.compactMap { url in
            guard let data = fileManager.contents(atPath: url.path),
                  let content = String(data: data, encoding: .utf8) else {
                return nil
            }
            return content.trimmingCharacters(in: .whitespacesAndNewlines)
        }

        guard !parts.isEmpty else { return "" }
        return parts.joined(separator: "\n\n---\n\n")
    }

    public func buildSessionContext(db: DatabaseManager) throws -> SessionContext {
        let knowledge = buildSystemPrompt()
        let exercises = (try? db.searchAllExercises()) ?? []
        let byType = Dictionary(grouping: exercises, by: { $0.workoutType?.name ?? "Other" })
            .mapValues { $0.count }
        let folders = (try? db.listFolders().map { $0.name }) ?? []
        let history = (try? db.readHistory()) ?? []
        let recentStats = (try? db.getStats(days: 7)) ?? (0, 0, 0, 0)
        let lastEntry = history.last

        let dayNames = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
        let config: ConfigManifest
        do {
            config = try db.loadConfig()
        } catch {
            config = ConfigManifest()
        }
        let trainingDays = config.trainingDays.map { $0 >= 0 && $0 < 7 ? dayNames[$0] : "Unknown" }

        var lastWorkout = "None"
        if let last = lastEntry {
            let formatter = DateFormatter()
            formatter.dateFormat = "EEE"
            let dayName = formatter.string(from: last.completedAt)
            let diff = Calendar.current.dateComponents([.day], from: last.completedAt, to: Date()).day ?? 0
            let when = diff == 0 ? "today" : diff == 1 ? "yesterday" : "\(diff) days ago"
            lastWorkout = "\(last.workoutName) (\(when), \(last.durationCompleted / 60) min)"
        }

        return SessionContext(
            knowledge: knowledge,
            database: SessionContext.DatabaseSummary(
                totalExercises: exercises.count,
                byType: byType,
                folders: folders
            ),
            recentActivity: SessionContext.RecentActivity(
                last7Days: recentStats.0,
                currentStreak: recentStats.1,
                lastWorkout: lastWorkout
            ),
            schedule: SessionContext.ScheduleSummary(
                trainingDays: trainingDays,
                durationMonths: config.trainingDurationMonths
            )
        )
    }
}
