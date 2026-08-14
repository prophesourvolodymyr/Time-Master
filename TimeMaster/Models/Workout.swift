import Foundation

struct WorkoutType: Identifiable, Codable, Hashable {
    var id: String
    var name: String
    var iconName: String
    var colorHex: String

    static let strength = WorkoutType(id: "Strength", name: "Strength", iconName: "dumbbell.fill", colorHex: "FF9500")
    static let stretch  = WorkoutType(id: "Stretch", name: "Stretch", iconName: "figure.cooldown", colorHex: "34C759")
    static let cardio   = WorkoutType(id: "Cardio", name: "Cardio", iconName: "heart.fill", colorHex: "FF3B30")
    static let hiit     = WorkoutType(id: "HIIT", name: "HIIT", iconName: "flame.fill", colorHex: "FF2D55")
    static let yoga     = WorkoutType(id: "Yoga", name: "Yoga", iconName: "figure.mind.and.body", colorHex: "AF52DE")
    static let face     = WorkoutType(id: "Face", name: "Face", iconName: "face.smiling.fill", colorHex: "FFCC00")
    static let other    = WorkoutType(id: "Other", name: "Other", iconName: "star.fill", colorHex: "007AFF")

    static var builtIn: [WorkoutType] { [strength, stretch, cardio, hiit, yoga, face, other] }

    static func all(custom: [WorkoutType] = []) -> [WorkoutType] { builtIn + custom }

    var icon: String { iconName }

    enum CodingKeys: String, CodingKey { case id, name, iconName, colorHex }

    init(id: String, name: String, iconName: String, colorHex: String = "FFFFFF") {
        self.id = id
        self.name = name
        self.iconName = iconName
        self.colorHex = colorHex
    }

    init(from decoder: Decoder) throws {
        if let container = try? decoder.container(keyedBy: CodingKeys.self),
           let decodedId = try? container.decode(String.self, forKey: .id) {
            id = decodedId
            name = (try? container.decode(String.self, forKey: .name)) ?? id
            iconName = (try? container.decode(String.self, forKey: .iconName)) ?? "star.fill"
            colorHex = (try? container.decode(String.self, forKey: .colorHex)) ?? "FFFFFF"
            return
        }
        let container = try decoder.singleValueContainer()
        let rawValue = try container.decode(String.self)
        if let match = WorkoutType.builtIn.first(where: { $0.name == rawValue || $0.id == rawValue }) {
            self = match
        } else {
            self = WorkoutType(id: rawValue.lowercased(), name: rawValue, iconName: "star.fill")
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(iconName, forKey: .iconName)
        try container.encode(colorHex, forKey: .colorHex)
    }
}

enum SectionMode: String, Codable, Equatable {
    case timed
    case bundle
}

enum RestRowKind: String, Codable, Equatable {
    case normal
    case big
}

enum RestContentKind: String, Codable, Equatable {
    case note
    case stretch
}

struct RestContent: Identifiable, Codable, Equatable {
    var id: UUID
    var kind: RestContentKind
    var pageID: UUID?
    var text: String

    init(
        id: UUID = UUID(),
        kind: RestContentKind = .note,
        pageID: UUID? = nil,
        text: String = ""
    ) {
        self.id = id
        self.kind = kind
        self.pageID = pageID
        self.text = text
    }
}

struct RestRow: Identifiable, Codable, Equatable {
    var id: UUID
    var kind: RestRowKind
    var duration: Int
    var contents: [RestContent]

    init(
        id: UUID = UUID(),
        kind: RestRowKind = .normal,
        duration: Int = 30,
        contents: [RestContent] = []
    ) {
        self.id = id
        self.kind = kind
        self.duration = max(0, duration)
        self.contents = contents
    }
}

struct DropSet: Identifiable, Codable, Equatable {
    var id: UUID
    var exercisePageID: UUID?
    var name: String
    var alias: String?
    var duration: Int
    var restAfter: Int

    init(
        id: UUID = UUID(),
        exercisePageID: UUID? = nil,
        name: String,
        alias: String? = nil,
        duration: Int = 30,
        restAfter: Int = 10
    ) {
        self.id = id
        self.exercisePageID = exercisePageID
        self.name = name
        self.alias = alias
        self.duration = max(5, duration)
        self.restAfter = max(0, restAfter)
    }

    var displayName: String {
        alias?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false ? alias! : name
    }
}

struct SetSlot: Identifiable, Codable, Equatable {
    var id: UUID
    var exercisePageID: UUID?
    var name: String
    var alias: String?
    var duration: Int
    var repCount: Int?
    var restAfter: Int
    var restExercisePageID: UUID?
    var drops: [DropSet]
    var restRow: RestRow?

    init(
        id: UUID = UUID(),
        exercisePageID: UUID? = nil,
        name: String,
        alias: String? = nil,
        duration: Int = 30,
        repCount: Int? = nil,
        restAfter: Int = 10,
        restExercisePageID: UUID? = nil,
        drops: [DropSet] = [],
        restRow: RestRow? = nil
    ) {
        self.id = id
        self.exercisePageID = exercisePageID
        self.name = name
        self.alias = alias
        self.duration = max(5, duration)
        self.repCount = repCount.map { max(1, $0) }
        self.restAfter = max(0, restAfter)
        self.restExercisePageID = restExercisePageID
        self.drops = drops
        self.restRow = restRow ?? (restAfter > 0 ? RestRow(duration: restAfter) : nil)
    }

    enum CodingKeys: String, CodingKey {
        case id, exercisePageID, name, alias, duration, repCount, restAfter
        case restExercisePageID, drops, restRow
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        exercisePageID = try c.decodeIfPresent(UUID.self, forKey: .exercisePageID)
        name = try c.decode(String.self, forKey: .name)
        alias = try c.decodeIfPresent(String.self, forKey: .alias)
        duration = max(5, try c.decodeIfPresent(Int.self, forKey: .duration) ?? 30)
        repCount = try c.decodeIfPresent(Int.self, forKey: .repCount).map { max(1, $0) }
        restAfter = max(0, try c.decodeIfPresent(Int.self, forKey: .restAfter) ?? 10)
        restExercisePageID = try c.decodeIfPresent(UUID.self, forKey: .restExercisePageID)
        drops = try c.decodeIfPresent([DropSet].self, forKey: .drops) ?? []
        restRow = try c.decodeIfPresent(RestRow.self, forKey: .restRow)
        if restRow == nil, restAfter > 0 {
            restRow = RestRow(duration: restAfter)
        }
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encodeIfPresent(exercisePageID, forKey: .exercisePageID)
        try c.encode(name, forKey: .name)
        try c.encodeIfPresent(alias, forKey: .alias)
        try c.encode(duration, forKey: .duration)
        try c.encodeIfPresent(repCount, forKey: .repCount)
        try c.encode(restAfter, forKey: .restAfter)
        try c.encodeIfPresent(restExercisePageID, forKey: .restExercisePageID)
        try c.encode(drops, forKey: .drops)
        try c.encodeIfPresent(restRow, forKey: .restRow)
    }

    var displayName: String {
        alias?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false ? alias! : name
    }

    var effectiveRestRow: RestRow? {
        restRow ?? (restAfter > 0 ? RestRow(duration: restAfter) : nil)
    }
}

struct Section: Identifiable, Codable, Equatable {
    var id: UUID
    var name: String
    var alias: String?
    var duration: Int
    var mediaItems: [MediaItem]
    var isTimerEnabled: Bool
    var sets: Int
    var repCount: Int?
    var restBetweenSets: Int
    var prepareTime: Int
    var customRestAfter: Int?
    var pageID: UUID?
    var mode: SectionMode
    var slots: [SetSlot]
    var bigRestRow: RestRow?

    init(
        id: UUID = UUID(),
        name: String,
        alias: String? = nil,
        duration: Int = 30,
        isTimerEnabled: Bool = true,
        photoFilename: String? = nil,
        photoFilenames: [String] = [],
        mediaItems: [MediaItem] = [],
        restAfter: Int = 0,
        sets: Int = 1,
        repCount: Int? = nil,
        restBetweenSets: Int = 10,
        customRestAfter: Int? = nil,
        prepareTime: Int = 4,
        pageID: UUID? = nil,
        mode: SectionMode = .timed,
        slots: [SetSlot] = [],
        bigRestRow: RestRow? = nil
    ) {
        self.id = id
        self.name = name
        self.alias = alias
        self.duration = max(5, duration)
        self.isTimerEnabled = isTimerEnabled
        self.sets = max(1, sets)
        self.repCount = repCount.map { max(1, $0) }
        self.restBetweenSets = max(0, restBetweenSets)
        self.customRestAfter = customRestAfter
        self.prepareTime = max(0, prepareTime)
        self.pageID = pageID
        self.mode = mode
        self.bigRestRow = bigRestRow ?? RestRow(kind: .big, duration: customRestAfter ?? restAfter)
        if !slots.isEmpty {
            self.slots = slots
        } else {
            self.slots = (0..<max(1, sets)).map { _ in
                SetSlot(
                    exercisePageID: pageID,
                    name: name,
                    duration: duration,
                    repCount: repCount,
                    restAfter: restBetweenSets
                )
            }
        }
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

    enum CodingKeys: String, CodingKey {
        case id, name, alias, duration, isTimerEnabled
        case sets, repCount, restBetweenSets, customRestAfter, prepareTime
        case mediaItems, photoFilenames, photoFilename, restAfter
        case pageID, mode, slots, bigRestRow
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        name = try c.decode(String.self, forKey: .name)
        alias = try c.decodeIfPresent(String.self, forKey: .alias)
        duration = max(5, try c.decodeIfPresent(Int.self, forKey: .duration) ?? 30)
        isTimerEnabled = try c.decodeIfPresent(Bool.self, forKey: .isTimerEnabled) ?? true
        sets = max(1, try c.decodeIfPresent(Int.self, forKey: .sets) ?? 1)
        repCount = try c.decodeIfPresent(Int.self, forKey: .repCount).map { max(1, $0) }
        restBetweenSets = max(0, try c.decodeIfPresent(Int.self, forKey: .restBetweenSets) ?? 10)
        prepareTime = max(0, try c.decodeIfPresent(Int.self, forKey: .prepareTime) ?? 4)
        pageID = try c.decodeIfPresent(UUID.self, forKey: .pageID)
        mode = try c.decodeIfPresent(SectionMode.self, forKey: .mode) ?? .timed
        var decodedSlots = try c.decodeIfPresent([SetSlot].self, forKey: .slots) ?? []
        if let value = try c.decodeIfPresent(Int.self, forKey: .customRestAfter) {
            customRestAfter = value
        } else {
            customRestAfter = try c.decodeIfPresent(Int.self, forKey: .restAfter)
        }
        bigRestRow = try c.decodeIfPresent(RestRow.self, forKey: .bigRestRow)
        if bigRestRow == nil {
            bigRestRow = RestRow(kind: .big, duration: customRestAfter ?? 30)
        }
        if decodedSlots.isEmpty {
            slots = []
        } else {
            slots = decodedSlots
        }
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
        try c.encode(id, forKey: .id)
        try c.encode(name, forKey: .name)
        try c.encodeIfPresent(alias, forKey: .alias)
        try c.encode(duration, forKey: .duration)
        try c.encode(isTimerEnabled, forKey: .isTimerEnabled)
        try c.encode(sets, forKey: .sets)
        try c.encodeIfPresent(repCount, forKey: .repCount)
        try c.encode(restBetweenSets, forKey: .restBetweenSets)
        try c.encodeIfPresent(customRestAfter, forKey: .customRestAfter)
        try c.encode(prepareTime, forKey: .prepareTime)
        try c.encode(mediaItems, forKey: .mediaItems)
        try c.encodeIfPresent(pageID, forKey: .pageID)
        try c.encode(mode, forKey: .mode)
        try c.encode(slots, forKey: .slots)
        try c.encodeIfPresent(bigRestRow, forKey: .bigRestRow)
    }

    var effectiveSlots: [SetSlot] {
        slots.isEmpty
            ? (0..<max(1, sets)).map { _ in
                SetSlot(
                    exercisePageID: pageID,
                    name: name,
                    duration: duration,
                    repCount: repCount,
                    restAfter: restBetweenSets
                )
            }
            : slots
    }

    var slotCount: Int { max(1, effectiveSlots.count) }

    var calculatedDuration: Int {
        effectiveSlots.reduce(0) { total, slot in
            let drops = slot.drops.reduce(0) { $0 + $1.duration + $1.restAfter }
            let rest = slot.effectiveRestRow?.duration ?? 0
            return total + slot.duration + drops + rest
        }
    }
}

struct Workout: Identifiable, Codable, Equatable {
    var id: UUID
    var name: String
    var type: WorkoutType
    var sections: [Section]
    var createdAt: Date
    var prepareTime: Int
    var restBetweenSections: Int
    var colorHex: String
    var imageFilename: String?
    var musicTrackFilenames: [String]

    init(
        id: UUID = UUID(),
        name: String,
        type: WorkoutType = .strength,
        sections: [Section] = [],
        createdAt: Date = Date(),
        prepareTime: Int = 4,
        restBetweenSections: Int = 30,
        colorHex: String = "FFFFFF",
        imageFilename: String? = nil,
        musicTrackFilenames: [String] = []
    ) {
        self.id = id
        self.name = name
        self.type = type
        self.sections = sections
        self.createdAt = createdAt
        self.prepareTime = max(0, prepareTime)
        self.restBetweenSections = max(0, restBetweenSections)
        self.colorHex = colorHex
        self.imageFilename = imageFilename
        self.musicTrackFilenames = musicTrackFilenames
    }

    enum CodingKeys: String, CodingKey {
        case id, name, type, sections, createdAt, prepareTime, restBetweenSections
        case colorHex, imageFilename, musicTrackFilenames
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        name = try c.decode(String.self, forKey: .name)
        type = try c.decodeIfPresent(WorkoutType.self, forKey: .type) ?? .strength
        sections = try c.decodeIfPresent([Section].self, forKey: .sections) ?? []
        createdAt = try c.decodeIfPresent(Date.self, forKey: .createdAt) ?? Date()
        prepareTime = max(0, try c.decodeIfPresent(Int.self, forKey: .prepareTime) ?? 4)
        restBetweenSections = max(0, try c.decodeIfPresent(Int.self, forKey: .restBetweenSections) ?? 30)
        colorHex = try c.decodeIfPresent(String.self, forKey: .colorHex) ?? "FFFFFF"
        imageFilename = try c.decodeIfPresent(String.self, forKey: .imageFilename)
        musicTrackFilenames = try c.decodeIfPresent([String].self, forKey: .musicTrackFilenames) ?? []
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(name, forKey: .name)
        try c.encode(type, forKey: .type)
        try c.encode(sections, forKey: .sections)
        try c.encode(createdAt, forKey: .createdAt)
        try c.encode(prepareTime, forKey: .prepareTime)
        try c.encode(restBetweenSections, forKey: .restBetweenSections)
        try c.encode(colorHex, forKey: .colorHex)
        try c.encodeIfPresent(imageFilename, forKey: .imageFilename)
        try c.encode(musicTrackFilenames, forKey: .musicTrackFilenames)
    }

    var totalDuration: Int {
        sections.reduce(0) { $0 + $1.calculatedDuration + ($1.bigRestRow?.duration ?? restBetweenSections) }
    }

    var sectionCount: Int { sections.count }
}



// MARK: - Hashable (keyed by id — required for NavigationPath)

extension Workout: Hashable {
    static func == (lhs: Workout, rhs: Workout) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}
