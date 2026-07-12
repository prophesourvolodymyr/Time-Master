import Foundation

// MARK: - Media Types (app-wide)

enum MediaType: String, Codable, Equatable {
    case photo
    case video
}

struct MediaItem: Codable, Identifiable, Equatable {
    var id: UUID
    var filename: String
    var type: MediaType

    init(id: UUID = UUID(), filename: String, type: MediaType) {
        self.id = id
        self.filename = filename
        self.type = type
    }
}

// MARK: - DatabaseNote

struct DatabaseNote: Identifiable, Codable, Equatable {
    var id: UUID = UUID()
    var title: String
    var body: String
    var createdAt: Date

    init(id: UUID = UUID(), title: String, body: String = "", createdAt: Date = Date()) {
        self.id = id
        self.title = title
        self.body = body
        self.createdAt = createdAt
    }
}

// MARK: - Exercise

@available(*, deprecated, message: "Use ExercisePage")
struct Exercise: Identifiable, Codable {
    var id: UUID = UUID()
    var name: String
    var details: String = ""        // stored as "details"; avoids CustomStringConvertible ambiguity
    var duration: Int = 30
    var restAfter: Int = 10
    var mediaItems: [MediaItem] = []

    init(
        id: UUID = UUID(),
        name: String,
        description: String = "",
        duration: Int = 30,
        restAfter: Int = 10,
        photoFilename: String? = nil,   // legacy single-photo convenience param
        photoFilenames: [String] = [],  // legacy multi-photo convenience param
        mediaItems: [MediaItem] = []
    ) {
        self.id = id
        self.name = name
        self.details = description
        self.duration = max(5, duration)
        self.restAfter = restAfter
        if !mediaItems.isEmpty {
            self.mediaItems = mediaItems
        } else if !photoFilenames.isEmpty {
            self.mediaItems = photoFilenames.map { MediaItem(filename: $0, type: .photo) }
        } else if let f = photoFilename {
            self.mediaItems = [MediaItem(filename: f, type: .photo)]
        } else {
            self.mediaItems = []
        }
    }

    // MARK: Custom Codable — migrates old `photoFilename/photoFilenames` to `mediaItems`

    enum CodingKeys: String, CodingKey {
        case id, name, details, duration, restAfter
        case mediaItems
        case photoFilenames  // legacy key — decode only
        case photoFilename   // legacy-legacy key — decode only
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id        = try c.decodeIfPresent(UUID.self,   forKey: .id) ?? UUID()
        name      = try c.decode(String.self,          forKey: .name)
        details   = try c.decodeIfPresent(String.self, forKey: .details) ?? ""
        duration  = try c.decodeIfPresent(Int.self,    forKey: .duration) ?? 30
        restAfter = try c.decodeIfPresent(Int.self,    forKey: .restAfter) ?? 10
        if let arr = try c.decodeIfPresent([MediaItem].self, forKey: .mediaItems) {
            mediaItems = arr
        } else if let arr = try c.decodeIfPresent([String].self, forKey: .photoFilenames) {
            mediaItems = arr.map { MediaItem(filename: $0, type: .photo) }
        } else if let single = try c.decodeIfPresent(String.self, forKey: .photoFilename) {
            mediaItems = [MediaItem(filename: single, type: .photo)]
        } else {
            mediaItems = []
        }
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id,         forKey: .id)
        try c.encode(name,       forKey: .name)
        try c.encode(details,    forKey: .details)
        try c.encode(duration,   forKey: .duration)
        try c.encode(restAfter,  forKey: .restAfter)
        try c.encode(mediaItems, forKey: .mediaItems)
        // legacy keys are NOT written on save
    }

    /// Convert to a workout Section for use in the player.
    func toSection() -> Section {
        Section(name: name, duration: duration, mediaItems: mediaItems, restAfter: restAfter)
    }
}

// MARK: - ExerciseFolder

@available(*, deprecated, message: "Use ExercisePage with manifest.childIDs")
struct ExerciseFolder: Identifiable, Codable {
    var id: UUID = UUID()
    var name: String
    var colorHex: String
    var workoutType: WorkoutType? = nil
    var subfolders: [ExerciseFolder] = []
    var exercises: [Exercise] = []
    var notes: [DatabaseNote] = []

    init(
        id: UUID = UUID(),
        name: String,
        colorHex: String = "FFFFFF",
        subfolders: [ExerciseFolder] = [],
        exercises: [Exercise] = [],
        notes: [DatabaseNote] = []
    ) {
        self.id = id
        self.name = name
        self.colorHex = colorHex
        self.subfolders = subfolders
        self.exercises = exercises
        self.notes = notes
    }

    enum CodingKeys: String, CodingKey {
        case id, name, colorHex, subfolders, exercises, notes, workoutType
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id         = try c.decodeIfPresent(UUID.self,              forKey: .id)         ?? UUID()
        name       = try c.decode(String.self,                     forKey: .name)
        colorHex   = try c.decodeIfPresent(String.self,            forKey: .colorHex)   ?? "FFFFFF"
        workoutType = try c.decodeIfPresent(WorkoutType.self,      forKey: .workoutType)
        subfolders = try c.decodeIfPresent([ExerciseFolder].self,  forKey: .subfolders) ?? []
        exercises  = try c.decodeIfPresent([Exercise].self,        forKey: .exercises)  ?? []
        notes      = try c.decodeIfPresent([DatabaseNote].self,    forKey: .notes)      ?? []
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id,         forKey: .id)
        try c.encode(name,       forKey: .name)
        try c.encode(colorHex,   forKey: .colorHex)
        try c.encodeIfPresent(workoutType, forKey: .workoutType)
        try c.encode(subfolders, forKey: .subfolders)
        try c.encode(exercises,  forKey: .exercises)
        try c.encode(notes,      forKey: .notes)
    }

    /// Total exercise count including all subfolders recursively.
    var totalExerciseCount: Int {
        exercises.count + subfolders.reduce(0) { $0 + $1.totalExerciseCount }
    }
}

// MARK: - TypeSchedule

struct TypeSchedule: Identifiable, Codable, Equatable {
    var id: UUID = UUID()
    var folderID: UUID
    var type: WorkoutType
    var daysOfWeek: Set<Int>
    var startDate: Date
    var durationMonths: Int
    var weeklyGoal: Int

    var endDate: Date {
        Calendar.current.date(byAdding: .month, value: durationMonths, to: startDate) ?? startDate
    }

    var isActive: Bool {
        Date() <= endDate
    }

    static func == (lhs: TypeSchedule, rhs: TypeSchedule) -> Bool {
        lhs.id == rhs.id
    }
}
