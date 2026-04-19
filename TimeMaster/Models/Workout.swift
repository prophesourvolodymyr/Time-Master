import Foundation

enum WorkoutType: String, Codable, CaseIterable {
    case strength = "Strength"
    case stretch  = "Stretch"
    case cardio   = "Cardio"
    case hiit     = "HIIT"
    case yoga     = "Yoga"
    case face     = "Face"
    case other    = "Other"

    var icon: String {
        switch self {
        case .strength: return "dumbbell.fill"
        case .stretch:  return "figure.cooldown"
        case .cardio:   return "heart.fill"
        case .hiit:     return "flame.fill"
        case .yoga:     return "figure.mind.and.body"
        case .face:     return "face.smiling.fill"
        case .other:    return "star.fill"
        }
    }
}

struct Section: Identifiable, Codable, Equatable {
    var id: UUID
    var name: String
    var duration: Int
    var mediaItems: [MediaItem]
    // Sets
    var sets: Int             // how many times this section repeats (≥ 1)
    var restBetweenSets: Int  // rest between set repetitions; only used when sets > 1
    // Rest after this section
    var customRestAfter: Int? // per-section override; nil = use workout.restBetweenSections

    init(
        id: UUID = UUID(),
        name: String,
        duration: Int = 30,
        photoFilename: String? = nil,    // legacy convenience — kept for backward compat
        photoFilenames: [String] = [],   // legacy convenience — kept for backward compat
        mediaItems: [MediaItem] = [],
        restAfter: Int = 0,              // legacy convenience — kept for backward compat
        sets: Int = 1,
        restBetweenSets: Int = 10,
        customRestAfter: Int? = nil
    ) {
        self.id = id
        self.name = name
        self.duration = max(5, duration)
        self.sets = max(1, sets)
        self.restBetweenSets = max(0, restBetweenSets)
        self.customRestAfter = customRestAfter
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

    // MARK: Custom Codable

    enum CodingKeys: String, CodingKey {
        case id, name, duration
        case sets, restBetweenSets, customRestAfter
        case mediaItems
        case photoFilenames  // legacy — decode only
        case photoFilename   // legacy — decode only
        case restAfter       // legacy — decode only → migrates to customRestAfter
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id       = try c.decodeIfPresent(UUID.self,   forKey: .id)       ?? UUID()
        name     = try c.decode(String.self,           forKey: .name)
        duration = try c.decodeIfPresent(Int.self,    forKey: .duration) ?? 30
        sets     = max(1, try c.decodeIfPresent(Int.self, forKey: .sets) ?? 1)
        restBetweenSets = try c.decodeIfPresent(Int.self, forKey: .restBetweenSets) ?? 10

        // customRestAfter: new key first, fall back to legacy restAfter
        if let v = try c.decodeIfPresent(Int.self, forKey: .customRestAfter) {
            customRestAfter = v
        } else if let v = try c.decodeIfPresent(Int.self, forKey: .restAfter), v > 0 {
            customRestAfter = v
        } else {
            customRestAfter = nil
        }

        // mediaItems: new key first, fall back to legacy keys
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
        try c.encode(id,              forKey: .id)
        try c.encode(name,            forKey: .name)
        try c.encode(duration,        forKey: .duration)
        try c.encode(sets,            forKey: .sets)
        try c.encode(restBetweenSets, forKey: .restBetweenSets)
        try c.encodeIfPresent(customRestAfter, forKey: .customRestAfter)
        try c.encode(mediaItems,      forKey: .mediaItems)
        // legacy keys NOT written
    }
}

struct Workout: Identifiable, Codable, Equatable {
    var id: UUID
    var name: String
    var type: WorkoutType
    var sections: [Section]
    var createdAt: Date
    var restBetweenSections: Int  // workout-wide default inter-section rest (seconds)

    init(
        id: UUID = UUID(),
        name: String,
        type: WorkoutType = .strength,
        sections: [Section] = [],
        createdAt: Date = Date(),
        restBetweenSections: Int = 30
    ) {
        self.id = id
        self.name = name
        self.type = type
        self.sections = sections
        self.createdAt = createdAt
        self.restBetweenSections = max(0, restBetweenSections)
    }

    enum CodingKeys: String, CodingKey {
        case id, name, type, sections, createdAt, restBetweenSections
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id                  = try c.decodeIfPresent(UUID.self,        forKey: .id)       ?? UUID()
        name                = try c.decode(String.self,               forKey: .name)
        type                = try c.decodeIfPresent(WorkoutType.self, forKey: .type)     ?? .strength
        sections            = try c.decodeIfPresent([Section].self,   forKey: .sections) ?? []
        createdAt           = try c.decodeIfPresent(Date.self,        forKey: .createdAt) ?? Date()
        restBetweenSections = try c.decodeIfPresent(Int.self, forKey: .restBetweenSections) ?? 30
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id,                  forKey: .id)
        try c.encode(name,                forKey: .name)
        try c.encode(type,                forKey: .type)
        try c.encode(sections,            forKey: .sections)
        try c.encode(createdAt,           forKey: .createdAt)
        try c.encode(restBetweenSections, forKey: .restBetweenSections)
    }

    var totalDuration: Int {
        guard !sections.isEmpty else { return 0 }
        let total = sections.reduce(0) { acc, s in
            let workTime = s.duration * s.sets + s.restBetweenSets * max(0, s.sets - 1)
            let restTime = s.customRestAfter ?? restBetweenSections
            return acc + workTime + restTime
        }
        let lastRest = sections.last.map { $0.customRestAfter ?? restBetweenSections } ?? 0
        return total - lastRest
    }

    var sectionCount: Int { sections.count }
}
