import Foundation
import TimeMasterCore

let HELP_TEXT = """
timemaster-tool — TimeMaster CLI for external AI agents

Commands:
  list-exercises [--type <type>] [--query <query>]
  get-exercise <id>
  create-exercise <json>           (use "-" for stdin)
  update-exercise <id> <json>      (use "-" for stdin)
  delete-exercise <id>
  search-exercises <query> [--type <type>]
  list-workouts
  build-workout <json>             (use "-" for stdin)
  import-media <path>
  get-stats [--type <type>] [--days <days>]
  list-folders [<parent-path>]
  list-types
  validate

Output: JSON to stdout. Errors: to stderr, exit 1.
"""

// MARK: - Helpers

struct ExerciseDetail: Encodable {
    let manifest: ExerciseManifest
    let guide: String?
}

struct StatsResponse: Encodable {
    let count: Int
    let streak: Int
    let bestStreak: Int
    let totalDuration: Int
}

struct ValidateResponse: Encodable {
    let valid: Bool
    let results: [ValidateItem]

    struct ValidateItem: Encodable {
        let path: String
        let valid: Bool
        let errors: [String]
        let warnings: [String]
    }
}

struct FolderEntry: Encodable {
    let name: String
    let path: String
    let hasManifest: Bool
}

let encoder: JSONEncoder = {
    let e = JSONEncoder()
    e.outputFormatting = [.prettyPrinted, .sortedKeys]
    e.dateEncodingStrategy = .iso8601
    return e
}()

let decoder: JSONDecoder = {
    let d = JSONDecoder()
    d.dateDecodingStrategy = .iso8601
    return d
}()

func fail(_ message: String) -> Never {
    FileHandle.standardError.write(Data("Error: \(message)\n".utf8))
    exit(1)
}

func failJSON(_ message: String) -> Never {
    FileHandle.standardError.write(Data("Error: \(message)\n".utf8))
    exit(1)
}

func outputJSON<T: Encodable>(_ value: T) {
    do {
        let data = try encoder.encode(value)
        FileHandle.standardOutput.write(data)
        print()
    } catch {
        fail("Failed to encode response: \(error.localizedDescription)")
    }
}

func readInputJSON() -> String? {
    guard let data = readStdinAll() else { return nil }
    return String(data: data, encoding: .utf8)
}

func readStdinAll() -> Data? {
    let input = FileHandle.standardInput
    let rawData = input.readDataToEndOfFile()
    return rawData.isEmpty ? nil : rawData
}

struct ExerciseManifestInput: Decodable {
    let id: String
    let name: String
    let details: String?
    let duration: Int?
    let restAfter: Int?
    let workoutType: WorkoutType?
    let mediaFilenames: [String]?
    let linkURLs: [String]?
    let createdAt: Date?
    let sets: Int?
    let restBetweenSets: Int?
    let parentPath: String?
}

struct WorkoutManifestInput: Decodable {
    let id: String
    let name: String
    let type: WorkoutType?
    let sections: [WorkoutSectionManifest]?
    let musicTrackFilenames: [String]?
    let colorHex: String?
    let restBetweenSections: Int?
    let imageFilename: String?
}

func decodeExerciseManifest(from data: Data) throws -> ExerciseManifest {
    let input = try decoder.decode(ExerciseManifestInput.self, from: data)
    return ExerciseManifest(
        id: input.id,
        name: input.name,
        details: input.details ?? "",
        duration: input.duration ?? 30,
        restAfter: input.restAfter ?? 10,
        workoutType: input.workoutType,
        mediaFilenames: input.mediaFilenames ?? [],
        linkURLs: input.linkURLs ?? [],
        createdAt: input.createdAt ?? Date(),
        updatedAt: Date(),
        sets: input.sets,
        restBetweenSets: input.restBetweenSets
    )
}

func decodeWorkoutManifest(from data: Data) throws -> WorkoutManifest {
    let input = try decoder.decode(WorkoutManifestInput.self, from: data)
    return WorkoutManifest(
        id: input.id,
        name: input.name,
        type: input.type ?? .strength,
        sections: input.sections ?? [],
        musicTrackFilenames: input.musicTrackFilenames ?? [],
        colorHex: input.colorHex ?? "FFFFFF",
        createdAt: Date(),
        restBetweenSections: input.restBetweenSections ?? 30,
        imageFilename: input.imageFilename
    )
}

func resolveJSONArg(_ arg: String) throws -> Data {
    if arg == "-" {
        guard let stdinData = readStdinAll(), !stdinData.isEmpty else {
            throw CLIError.invalidJSON("No JSON provided on stdin")
        }
        return stdinData
    }
    guard let data = arg.data(using: .utf8) else {
        throw CLIError.invalidJSON("Failed to parse argument as JSON")
    }
    return data
}

enum CLIError: Error, LocalizedError {
    case invalidJSON(String)
    case notFound(String)

    var errorDescription: String? {
        switch self {
        case .invalidJSON(let msg): "Invalid JSON: \(msg)"
        case .notFound(let msg): "Not found: \(msg)"
        }
    }
}

func parseFlag(_ args: [String], flag: String) -> String? {
    guard let idx = args.firstIndex(of: flag), idx + 1 < args.count else { return nil }
    return args[idx + 1]
}

func parseTypeFromArg(_ typeStr: String?) -> WorkoutType? {
    guard let typeStr else { return nil }
    let allTypes = WorkoutType.all()
    return allTypes.first { $0.id.caseInsensitiveCompare(typeStr) == .orderedSame }
}

// MARK: - Main

let args = CommandLine.arguments
guard args.count >= 2 else {
    FileHandle.standardError.write(Data(HELP_TEXT.utf8))
    exit(1)
}

let command = args[1]
let commandArgs = Array(args.dropFirst(2))

let dataRootOverride = ProcessInfo.processInfo.environment["TIMEMASTER_DATA_ROOT"].map { URL(fileURLWithPath: $0) }
let coreFS: FileSystemHelper
let db: DatabaseManager

if let overrideURL = dataRootOverride {
    let fs = FileSystemHelper(dataRoot: overrideURL)
    coreFS = fs
    db = DatabaseManager(fs: fs)
} else {
    coreFS = FileSystemHelper()
    db = DatabaseManager(fs: coreFS)
}
do {
    try db.bootstrapIfNeeded()
} catch {
    fail("Failed to bootstrap data directory: \(error.localizedDescription)")
}

do {
    switch command {
    case "help", "--help", "-h":
        FileHandle.standardOutput.write(Data(HELP_TEXT.utf8))
        exit(0)

    case "list-exercises":
        try handleListExercises(commandArgs)

    case "get-exercise":
        try handleGetExercise(commandArgs)

    case "create-exercise":
        try handleCreateExercise(commandArgs)

    case "update-exercise":
        try handleUpdateExercise(commandArgs)

    case "delete-exercise":
        try handleDeleteExercise(commandArgs)

    case "search-exercises":
        try handleSearchExercises(commandArgs)

    case "list-workouts":
        try handleListWorkouts()

    case "build-workout":
        try handleBuildWorkout(commandArgs)

    case "import-media":
        try handleImportMedia(commandArgs)

    case "get-stats":
        try handleGetStats(commandArgs)

    case "list-folders":
        try handleListFolders(commandArgs)

    case "list-types":
        try handleListTypes()

    case "validate":
        try handleValidate()

    default:
        FileHandle.standardError.write(Data("Unknown command: \(command)\n\n\(HELP_TEXT)".utf8))
        exit(1)
    }
} catch {
    fail(error.localizedDescription)
}

// MARK: - Command Handlers

func handleListExercises(_ args: [String]) throws {
    let typeStr = parseFlag(args, flag: "--type")
    let queryStr = parseFlag(args, flag: "--query")
    let type = parseTypeFromArg(typeStr)

    if let query = queryStr, !query.isEmpty {
        let results = try db.searchExercises(query: query, type: type)
        outputJSON(results.map { $0.manifest })
    } else {
        let exercises = try db.searchAllExercises()
        let filtered = type.map { t in exercises.filter { $0.workoutType?.id == t.id } } ?? exercises
        outputJSON(filtered)
    }
}

func handleGetExercise(_ args: [String]) throws {
    guard let id = args.first else { fail("Missing exercise id") }
    let manifest = try db.getExercise(id: id)

    let guideURL = db.exercisesDatabaseURL
        .appendingPathComponent(id, isDirectory: true)
        .appendingPathComponent("guide.md")

    var guide: String? = nil
    if FileManager.default.fileExists(atPath: guideURL.path) {
        guide = try? String(contentsOf: guideURL, encoding: .utf8)
    }

    outputJSON(ExerciseDetail(manifest: manifest, guide: guide))
}

func handleCreateExercise(_ args: [String]) throws {
    guard let jsonArg = args.first else { fail("Missing exercise JSON (use '-' for stdin)") }
    let data = try resolveJSONArg(jsonArg)
    let input = try decoder.decode(ExerciseManifestInput.self, from: data)
    let parentPath = input.parentPath ?? (args.count > 1 ? args[1] : nil)
    let manifest = ExerciseManifest(
        id: input.id,
        name: input.name,
        details: input.details ?? "",
        duration: input.duration ?? 30,
        restAfter: input.restAfter ?? 10,
        workoutType: input.workoutType,
        mediaFilenames: input.mediaFilenames ?? [],
        linkURLs: input.linkURLs ?? [],
        createdAt: input.createdAt ?? Date(),
        updatedAt: Date(),
        sets: input.sets,
        restBetweenSets: input.restBetweenSets
    )

    try db.createExercise(id: manifest.id, manifest: manifest, parentPath: parentPath)

    let folder = parentPath.map { "\($0)/\(manifest.id)" } ?? manifest.id
    outputJSON(["created": folder, "id": manifest.id])
}

func handleUpdateExercise(_ args: [String]) throws {
    guard let id = args.first else { fail("Missing exercise id") }
    guard args.count >= 2 else { fail("Missing exercise JSON (use '-' for stdin)") }
    let data = try resolveJSONArg(args[1])
    let manifest = try decodeExerciseManifest(from: data)

    let parentPath = args.count > 2 ? args[2] : nil
    try db.updateExercise(id: id, manifest: manifest, parentPath: parentPath)

    let folder = parentPath.map { "\($0)/\(id)" } ?? id
    outputJSON(["updated": folder, "id": id])
}

func handleDeleteExercise(_ args: [String]) throws {
    guard let id = args.first else { fail("Missing exercise id") }
    try db.deleteExercise(id: id)
    outputJSON(["deleted": id])
}

func handleSearchExercises(_ args: [String]) throws {
    guard let query = args.first else { fail("Missing search query") }
    let typeStr = parseFlag(args, flag: "--type")
    let type = parseTypeFromArg(typeStr)

    let results = try db.searchExercises(query: query, type: type)
    outputJSON(results.map { $0.manifest })
}

func handleListWorkouts() throws {
    let workouts = try db.listWorkouts()
    outputJSON(workouts)
}

func handleBuildWorkout(_ args: [String]) throws {
    guard let jsonArg = args.first else { fail("Missing workout JSON (use '-' for stdin)") }
    let data = try resolveJSONArg(jsonArg)
    let manifest = try decodeWorkoutManifest(from: data)

    try db.createWorkout(id: manifest.id, manifest: manifest)
    outputJSON(["created": manifest.id, "name": manifest.name, "sectionCount": String(manifest.sections.count)])
}

func handleImportMedia(_ args: [String]) throws {
    guard let path = args.first else { fail("Missing file path") }
    let sourceURL = URL(fileURLWithPath: (path as NSString).expandingTildeInPath)
    let filename = try db.importMedia(from: sourceURL)
    let response: [String: String] = ["filename": filename]
    outputJSON(response)
}

func handleGetStats(_ args: [String]) throws {
    let typeStr = parseFlag(args, flag: "--type")
    let type = parseTypeFromArg(typeStr)

    var days: Int? = nil
    if let daysStr = parseFlag(args, flag: "--days"), let d = Int(daysStr) {
        days = d
    }

    let stats = try db.getStats(type: type, days: days)
    outputJSON(StatsResponse(count: stats.count, streak: stats.streak, bestStreak: stats.bestStreak, totalDuration: stats.totalDuration))
}

func handleListFolders(_ args: [String]) throws {
    let parentPath = args.first
    let folders = try db.listFolders(parentPath: parentPath)
    outputJSON(folders.map { FolderEntry(name: $0.name, path: $0.path, hasManifest: $0.hasManifest) })
}

func handleListTypes() throws {
    let config = try db.loadConfig()
    let allTypes = WorkoutType.all(custom: config.customWorkoutTypes)
    outputJSON(allTypes.map { ["id": $0.id, "name": $0.name, "iconName": $0.iconName, "colorHex": $0.colorHex] })
}

func handleValidate() throws {
    let results = db.validateAll()
    let allValid = results.allSatisfy { $0.valid }
    let items = results.map { ValidateResponse.ValidateItem(path: $0.path, valid: $0.valid, errors: $0.errors, warnings: $0.warnings) }
    outputJSON(ValidateResponse(valid: allValid, results: items))
}
