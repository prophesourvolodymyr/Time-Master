import Foundation

public final class SchemaManager {
    private let fs: FileSystemHelper

    public init(fs: FileSystemHelper) {
        self.fs = fs
    }

    public func generateSchema() throws -> SchemaDefinition {
        let objects: [String: ObjectSchema] = [
            "page": ObjectSchema(
                description: "A page in the Exercises Database. Root containers own categories and workout type; descendants inherit it. Leaf pages are workout-ready exercises.",
                folderPath: "Exercises Database/{parentPath}/{id}",
                manifestName: "manifest.json",
                required: ["id", "title", "pageKind", "markdownBody", "createdAt", "updatedAt"],
                properties: [
                    "id": PropertySchema(type: "string", description: "UUID string — also used as folder name"),
                    "title": PropertySchema(type: "string", description: "Display name of the page"),
                    "pageKind": PropertySchema(type: "string", description: "container for organization pages; leaf for workout-ready exercises"),
                    "coverImageFilename": PropertySchema(type: "string", description: "Cover image filename in page folder root; containers only", optional: true),
                    "iconName": PropertySchema(type: "string", description: "SF Symbol name for fallback icon when no cover", optional: true),
                    "markdownBody": PropertySchema(type: "string", description: "Rich content — stored as guide.md, cached for search"),
                    "mediaFilenames": PropertySchema(type: "array<string>", description: "Media files in page's media/ subdir", optional: true),
                    "linkURLs": PropertySchema(type: "array<string>", description: "External URLs (YouTube, Instagram, TikTok, web)", optional: true),
                    "linkMetadata": PropertySchema(type: "array<object>", description: "Pre-fetched metadata for link previews", optional: true),
                    "workoutType": PropertySchema(type: "object", description: "Assigned only to the absolute root container; all descendants inherit it", optional: true),
                    "duration": PropertySchema(type: "integer", description: "Leaf exercise duration in seconds; forbidden on containers", format: "seconds", optional: true),
                    "restAfter": PropertySchema(type: "integer", description: "Rest after this exercise in seconds", format: "seconds", optional: true),
                    "sets": PropertySchema(type: "integer", description: "Default set count", optional: true),
                    "restBetweenSets": PropertySchema(type: "integer", description: "Rest between sets in seconds", format: "seconds", optional: true),
                    "childIDs": PropertySchema(type: "array<string>", description: "Ordered list of child page IDs; containers only", optional: true),
                    "parentID": PropertySchema(type: "string", description: "Parent page ID — nil = root container", optional: true),
                    "order": PropertySchema(type: "integer", description: "Manual sort position among siblings"),
                    "createdAt": PropertySchema(type: "string", description: "ISO 8601 creation timestamp", format: "date-time"),
                    "updatedAt": PropertySchema(type: "string", description: "ISO 8601 last-modified timestamp", format: "date-time"),
                ]
            ),
            "exercise": ObjectSchema(
                description: "A single exercise in the database. Can be nested inside folders.",
                folderPath: "Exercises Database/{folderPath}/{id}",
                manifestName: "manifest.json",
                required: ["id", "name", "duration", "restAfter", "createdAt", "updatedAt"],
                properties: [
                    "id": PropertySchema(type: "string", description: "UUID string — also used as folder name"),
                    "name": PropertySchema(type: "string", description: "Display name of the exercise"),
                    "details": PropertySchema(type: "string", description: "Instructions, description, or notes", optional: true),
                    "duration": PropertySchema(type: "integer", description: "Default duration in seconds", format: "seconds"),
                    "restAfter": PropertySchema(type: "integer", description: "Rest after this exercise in seconds", format: "seconds"),
                    "workoutType": PropertySchema(type: "object", description: "Assigned workout type (Strength, Cardio, etc.)", optional: true),
                    "mediaFilenames": PropertySchema(type: "array<string>", description: "References to files in Media/", optional: true),
                    "linkURLs": PropertySchema(type: "array<string>", description: "External links (YouTube, articles, etc.)", optional: true),
                    "createdAt": PropertySchema(type: "string", description: "ISO 8601 creation timestamp", format: "date-time"),
                    "updatedAt": PropertySchema(type: "string", description: "ISO 8601 last-modified timestamp", format: "date-time"),
                    "sets": PropertySchema(type: "integer", description: "Default number of sets", optional: true),
                    "restBetweenSets": PropertySchema(type: "integer", description: "Rest between sets in seconds", optional: true),
                ]
            ),
            "workout": ObjectSchema(
                description: "A workout plan composed of sections that reference exercises.",
                folderPath: "Workouts/{id}",
                manifestName: "manifest.json",
                required: ["id", "name", "type", "sections", "createdAt"],
                properties: [
                    "id": PropertySchema(type: "string", description: "UUID string — also used as folder name"),
                    "name": PropertySchema(type: "string", description: "Display name of the workout"),
                    "type": PropertySchema(type: "object", description: "WorkoutType { id, name, iconName, colorHex }"),
                    "sections": PropertySchema(type: "array<object>", description: "Ordered list of WorkoutSectionManifest"),
                    "musicTrackFilenames": PropertySchema(type: "array<string>", description: "Music files in Music/", optional: true),
                    "colorHex": PropertySchema(type: "string", description: "Display color", optional: true),
                    "createdAt": PropertySchema(type: "string", description: "ISO 8601 creation timestamp", format: "date-time"),
                    "restBetweenSections": PropertySchema(type: "integer", description: "Rest between sections in seconds"),
                    "imageFilename": PropertySchema(type: "string", description: "Cover image in Media/", optional: true),
                ]
            ),
            "historyEntry": ObjectSchema(
                description: "Completed workout log entry stored in JSONL format.",
                folderPath: "History/entries.jsonl",
                manifestName: "entries.jsonl",
                required: ["id", "workoutId", "workoutName", "completedAt", "durationCompleted"],
                properties: [
                    "id": PropertySchema(type: "string", description: "UUID string"),
                    "workoutId": PropertySchema(type: "string", description: "ID of the workout performed"),
                    "workoutName": PropertySchema(type: "string", description: "Name of the workout performed"),
                    "completedAt": PropertySchema(type: "string", description: "ISO 8601 completion timestamp", format: "date-time"),
                    "durationCompleted": PropertySchema(type: "integer", description: "Actual duration completed in seconds"),
                    "workoutType": PropertySchema(type: "object", description: "WorkoutType at time of completion"),
                    "isPartial": PropertySchema(type: "boolean", description: "Whether workout was partially completed"),
                    "elapsedSeconds": PropertySchema(type: "integer", description: "Elapsed seconds for partial workouts"),
                ]
            ),
            "config": ObjectSchema(
                description: "App configuration — custom types, schedule, goals.",
                folderPath: "Config/",
                manifestName: "manifest.json",
                required: ["weeklyGoal"],
                properties: [
                    "customWorkoutTypes": PropertySchema(type: "array<object>", description: "User-defined workout types"),
                    "weeklyGoal": PropertySchema(type: "integer", description: "Weekly workout goal (1-7)"),
                    "restDays": PropertySchema(type: "array<string>", description: "ISO date strings for rest days"),
                    "trainingDays": PropertySchema(type: "array<integer>", description: "Days of week for training (1=Mon, 7=Sun)"),
                    "trainingStartDate": PropertySchema(type: "string", description: "Start date of training schedule", format: "date-time"),
                    "trainingDurationMonths": PropertySchema(type: "integer", description: "Training schedule duration"),
                    "typeSchedules": PropertySchema(type: "array<object>", description: "Per-type workout schedules"),
                ]
            ),
        ]

        let tools: [ToolSchema] = [
            ToolSchema(name: "listPages", description: "List all pages in the Exercises Database", write: false),
            ToolSchema(name: "getPage", description: "Read a single page manifest", write: false, parameters: [
                "id": PropertySchema(type: "string", description: "Page UUID"),
            ]),
            ToolSchema(name: "searchPages", description: "Search pages by title, content, or type", write: false, parameters: [
                "query": PropertySchema(type: "string", description: "Search term for title/content matching"),
                "type": PropertySchema(type: "string", description: "Optional workout type filter", optional: true),
            ]),
            ToolSchema(name: "createPage", description: "Create a new page folder with manifest and guide.md", write: true, parameters: [
                "title": PropertySchema(type: "string", description: "Page title"),
                "parentID": PropertySchema(type: "string", description: "Optional parent page UUID", optional: true),
            ]),
            ToolSchema(name: "create_container_page", description: "Create a root organization container. Containers can have children and an optional cover, but no workout timing. Only root containers may define workoutType; nested containers inherit it.", write: true, parameters: [
                "title": PropertySchema(type: "string", description: "Container title"),
                "parentID": PropertySchema(type: "string", description: "Optional parent container UUID; nested containers inherit the root type", optional: true),
                "coverImageFilename": PropertySchema(type: "string", description: "Optional cover filename in the container folder", optional: true),
                "iconName": PropertySchema(type: "string", description: "Optional SF Symbol fallback", optional: true),
                "workoutType": PropertySchema(type: "object", description: "Optional workout type; accepted only when parentID is omitted", optional: true),
            ]),
            ToolSchema(name: "create_exercise_page", description: "Create a workout-ready leaf exercise inside a container. Its first media item is its cover; explicit cover filenames and per-page workout types are forbidden.", write: true, parameters: [
                "title": PropertySchema(type: "string", description: "Exercise title"),
                "parentID": PropertySchema(type: "string", description: "Required parent container UUID"),
                "duration": PropertySchema(type: "integer", description: "Exercise duration in seconds", format: "seconds"),
                "restAfter": PropertySchema(type: "integer", description: "Rest after the exercise in seconds", format: "seconds", optional: true),
                "sets": PropertySchema(type: "integer", description: "Default number of sets", optional: true),
                "restBetweenSets": PropertySchema(type: "integer", description: "Rest between sets in seconds", format: "seconds", optional: true),
                "mediaFilenames": PropertySchema(type: "array<string>", description: "Media files; first item becomes the cover", optional: true),
            ]),
            ToolSchema(name: "updatePage", description: "Update an existing page manifest", write: true, parameters: [
                "id": PropertySchema(type: "string", description: "Page UUID to update"),
            ]),
            ToolSchema(name: "deletePage", description: "Move a page (and children) to .trash/", write: true, parameters: [
                "id": PropertySchema(type: "string", description: "Page UUID to delete"),
            ]),
            ToolSchema(name: "movePage", description: "Move a page to a different parent", write: true, parameters: [
                "id": PropertySchema(type: "string", description: "Page UUID to move"),
                "newParentID": PropertySchema(type: "string", description: "New parent page UUID", optional: true),
            ]),
            ToolSchema(name: "getPagePath", description: "Get breadcrumb path string for a page", write: false, parameters: [
                "id": PropertySchema(type: "string", description: "Page UUID"),
            ]),
            ToolSchema(name: "listExercises", description: "List all exercises in the database", write: false),
            ToolSchema(name: "getExercise", description: "Read a single exercise manifest", write: false, parameters: [
                "id": PropertySchema(type: "string", description: "Exercise UUID"),
            ]),
            ToolSchema(name: "searchExercises", description: "Search exercises by name or type", write: false, parameters: [
                "query": PropertySchema(type: "string", description: "Search term for name matching"),
                "type": PropertySchema(type: "string", description: "Optional workout type filter", optional: true),
            ]),
            ToolSchema(name: "createExercise", description: "Create a new exercise folder with manifest", write: true, parameters: [
                "id": PropertySchema(type: "string", description: "UUID for the new exercise"),
                "name": PropertySchema(type: "string", description: "Exercise name"),
                "duration": PropertySchema(type: "integer", description: "Duration in seconds", optional: true),
            ]),
            ToolSchema(name: "updateExercise", description: "Update an existing exercise manifest", write: true, parameters: [
                "id": PropertySchema(type: "string", description: "Exercise UUID to update"),
            ]),
            ToolSchema(name: "deleteExercise", description: "Move an exercise to .trash/", write: true, parameters: [
                "id": PropertySchema(type: "string", description: "Exercise UUID to delete"),
            ]),
            ToolSchema(name: "listWorkouts", description: "List all workout manifests", write: false),
            ToolSchema(name: "getWorkout", description: "Read a single workout manifest", write: false, parameters: [
                "id": PropertySchema(type: "string", description: "Workout UUID"),
            ]),
            ToolSchema(name: "createWorkout", description: "Create a new workout plan", write: true, parameters: [
                "id": PropertySchema(type: "string", description: "UUID for the new workout"),
                "name": PropertySchema(type: "string", description: "Workout name"),
            ]),
            ToolSchema(name: "getStats", description: "Get workout statistics", write: false, parameters: [
                "type": PropertySchema(type: "string", description: "Optional workout type filter", optional: true),
                "days": PropertySchema(type: "integer", description: "Number of days to look back", optional: true),
            ]),
        ]

        let directories: [String: String] = [
            "Exercises Database": "All exercises, nested in folders",
            "Workouts": "Workout plans referencing exercise IDs",
            "Media": "Shared media storage (UUID filenames)",
            "Workspace": "AI sandbox — ignored by the app",
            "Knowledge": "AI system prompt material (.md files)",
            "skills": "Reusable agent skill definitions",
            "Config": "App configuration",
            "History": "Completed workout logs (JSONL)",
            "Music": "Background music files",
            "Backups": "Auto-backups before AI sessions",
            ".trash": "Soft-deleted items (30-day retention)",
        ]

        return SchemaDefinition(
            version: "1.0.0",
            objects: objects,
            tools: tools,
            filesystem: FilesystemSchema(root: "TimeMaster", directories: directories)
        )
    }

    public func writeSchema() throws {
        let schema = try generateSchema()
        try fs.writeAtomically(to: fs.schemaURL, value: schema)
    }

    public func validateAll() -> [(path: String, valid: Bool, errors: [String], warnings: [String])] {
        var results: [(String, Bool, [String], [String])] = []
        let schema = (try? generateSchema()) ?? SchemaDefinition(version: "1.0.0")
        let fsDecoder = JSONDecoder()
        fsDecoder.dateDecodingStrategy = .iso8601

        let exercisesDir = fs.exercisesDatabaseDirectory
        if fs.directoryExists(at: exercisesDir) {
            validateDirectory(exercisesDir, basePath: "Exercises Database", type: "exercise", schema: schema, decoder: fsDecoder, results: &results)
        }

        let workoutsDir = fs.workoutsDirectory
        if fs.directoryExists(at: workoutsDir) {
            let entries = (try? fs.listDirectory(workoutsDir)) ?? []
            for entry in entries {
                let manifestURL = entry.appendingPathComponent("manifest.json")
                if fs.fileExists(at: manifestURL) {
                    if let manifest: WorkoutManifest = try? fs.readManifest(from: manifestURL, decoder: fsDecoder) {
                        let result = validate(manifest: manifest, type: "workout", schema: schema)
                        let path = "Workouts/\(entry.lastPathComponent)"
                        results.append((path, result.valid, result.errors, result.warnings))
                    } else {
                        results.append(("Workouts/\(entry.lastPathComponent)", false, ["Failed to parse manifest.json"], []))
                    }
                }
            }
        }

        return results
    }

    private func validateDirectory(_ dir: URL, basePath: String, type: String, schema: SchemaDefinition, decoder: JSONDecoder, results: inout [(String, Bool, [String], [String])]) {
        let entries = (try? fs.listDirectory(dir, skipNonSchema: false)) ?? []
        for entry in entries {
            var isDir: ObjCBool = false
            FileManager.default.fileExists(atPath: entry.path, isDirectory: &isDir)
            if isDir.boolValue {
                let manifestURL = entry.appendingPathComponent("manifest.json")
                if fs.fileExists(at: manifestURL) {
                    let relPath = basePath + "/\(entry.lastPathComponent)"
                    if let manifest: ExerciseManifest = try? fs.readManifest(from: manifestURL, decoder: decoder) {
                        let result = validate(manifest: manifest, type: "exercise", schema: schema)
                        results.append((relPath, result.valid, result.errors, result.warnings))
                    } else {
                        results.append((relPath, false, ["Failed to parse manifest.json"], []))
                    }
                }
                let subPath = basePath + "/\(entry.lastPathComponent)"
                validateDirectory(entry, basePath: subPath, type: type, schema: schema, decoder: decoder, results: &results)
            }
        }
    }

    public func validate<T: Encodable>(manifest: T, type: String, schema: SchemaDefinition? = nil) -> ValidationResult {
        let def = schema ?? (try? generateSchema()) ?? SchemaDefinition(version: "1.0.0", objects: [:], tools: [], filesystem: FilesystemSchema())

        guard let objectSchema = def.objects[type] else {
            return ValidationResult(valid: false, errors: ["Unknown object type: \(type)"])
        }

        let mirror = Mirror(reflecting: manifest)
        var errors: [String] = []
        var warnings: [String] = []

        for required in objectSchema.required {
            let child = mirror.children.first { $0.label == required }
            if child == nil {
                errors.append("Missing required field: \(required)")
            } else {
                if let optionalValue = child?.value as? OptionalProtocol, optionalValue.isNil {
                    errors.append("Required field is nil: \(required)")
                }
            }
        }

        for prop in objectSchema.properties {
            let child = mirror.children.first { $0.label == prop.key }
            if let value = child?.value {
                if let propType = validatePropertyType(value: value, expectedType: prop.value.type, format: prop.value.format) {
                    if prop.value.optional == false {
                        errors.append("Field \(prop.key): \(propType)")
                    } else {
                        warnings.append("Field \(prop.key): \(propType)")
                    }
                }
            }
        }

        return ValidationResult(
            valid: errors.isEmpty,
            errors: errors,
            warnings: warnings
        )
    }

    private func validatePropertyType(value: Any, expectedType: String, format: String?) -> String? {
        if format == "date-time" {
            if value is Date { return nil }
            if value is String { return nil }
            return "expected date or date string, got \(type(of: value))"
        }
        if expectedType.hasPrefix("array") {
            if value is [Any] { return nil }
            if value is NSArray { return nil }
            return "expected array, got \(type(of: value))"
        }
        switch expectedType {
        case "string":
            return value is String ? nil : "expected string, got \(type(of: value))"
        case "integer":
            if value is Int { return nil }
            if value is NSNumber { return nil }
            return "expected integer, got \(type(of: value))"
        case "boolean":
            return value is Bool ? nil : "expected boolean, got \(type(of: value))"
        case "object":
            return nil
        default:
            return nil
        }
    }
}

public struct ValidationResult {
    public let valid: Bool
    public let errors: [String]
    public let warnings: [String]

    public init(valid: Bool, errors: [String] = [], warnings: [String] = []) {
        self.valid = valid
        self.errors = errors
        self.warnings = warnings
    }
}

private protocol OptionalProtocol {
    var isNil: Bool { get }
}

extension Optional: OptionalProtocol {
    var isNil: Bool {
        switch self {
        case .none: return true
        case .some: return false
        }
    }
}
