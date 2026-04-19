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

// MARK: - Exercise

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

struct ExerciseFolder: Identifiable, Codable {
    var id: UUID = UUID()
    var name: String
    var subfolders: [ExerciseFolder] = []
    var exercises: [Exercise] = []

    init(
        id: UUID = UUID(),
        name: String,
        subfolders: [ExerciseFolder] = [],
        exercises: [Exercise] = []
    ) {
        self.id = id
        self.name = name
        self.subfolders = subfolders
        self.exercises = exercises
    }

    /// Total exercise count including all subfolders recursively.
    var totalExerciseCount: Int {
        exercises.count + subfolders.reduce(0) { $0 + $1.totalExerciseCount }
    }
}
