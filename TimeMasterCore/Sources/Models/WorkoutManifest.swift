import Foundation

public enum WorkoutSectionMode: String, Codable, Equatable {
    case timed
    case bundle
}

public enum WorkoutRestRowKind: String, Codable, Equatable {
    case normal
    case big
}

public enum WorkoutRestContentKind: String, Codable, Equatable {
    case note
    case stretch
}

public struct WorkoutRestContentManifest: Codable, Equatable, Identifiable {
    public var id: String
    public var kind: WorkoutRestContentKind
    public var pageID: String?
    public var text: String

    public init(
        id: String = UUID().uuidString,
        kind: WorkoutRestContentKind = .note,
        pageID: String? = nil,
        text: String = ""
    ) {
        self.id = id
        self.kind = kind
        self.pageID = pageID
        self.text = text
    }
}

public struct WorkoutRestRowManifest: Codable, Equatable, Identifiable {
    public var id: String
    public var kind: WorkoutRestRowKind
    public var duration: Int
    public var contents: [WorkoutRestContentManifest]

    public init(
        id: String = UUID().uuidString,
        kind: WorkoutRestRowKind = .normal,
        duration: Int = 30,
        contents: [WorkoutRestContentManifest] = []
    ) {
        self.id = id
        self.kind = kind
        self.duration = max(0, duration)
        self.contents = contents
    }
}

public struct WorkoutDropSetManifest: Codable, Equatable, Identifiable {
    public var id: String
    public var exerciseID: String
    public var name: String
    public var alias: String?
    public var duration: Int
    public var restAfter: Int

    public init(
        id: String = UUID().uuidString,
        exerciseID: String,
        name: String,
        alias: String? = nil,
        duration: Int = 30,
        restAfter: Int = 10
    ) {
        self.id = id
        self.exerciseID = exerciseID
        self.name = name
        self.alias = alias
        self.duration = max(5, duration)
        self.restAfter = max(0, restAfter)
    }
}

public struct WorkoutSetSlotManifest: Codable, Equatable, Identifiable {
    public var id: String
    public var exerciseID: String
    public var name: String
    public var alias: String?
    public var duration: Int
    public var repCount: Int?
    public var restAfter: Int
    public var restExerciseID: String?
    public var drops: [WorkoutDropSetManifest]
    public var restRow: WorkoutRestRowManifest?

    public init(
        id: String = UUID().uuidString,
        exerciseID: String,
        name: String,
        alias: String? = nil,
        duration: Int = 30,
        repCount: Int? = nil,
        restAfter: Int = 10,
        restExerciseID: String? = nil,
        drops: [WorkoutDropSetManifest] = [],
        restRow: WorkoutRestRowManifest? = nil
    ) {
        self.id = id
        self.exerciseID = exerciseID
        self.name = name
        self.alias = alias
        self.duration = max(5, duration)
        self.repCount = repCount.map { max(1, $0) }
        self.restAfter = max(0, restAfter)
        self.restExerciseID = restExerciseID
        self.drops = drops
        self.restRow = restRow ?? (restAfter > 0 ? WorkoutRestRowManifest(duration: restAfter) : nil)
    }

    enum CodingKeys: String, CodingKey {
        case id, exerciseID, name, alias, duration, repCount, restAfter
        case restExerciseID, drops, restRow
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decodeIfPresent(String.self, forKey: .id) ?? UUID().uuidString
        exerciseID = try c.decodeIfPresent(String.self, forKey: .exerciseID) ?? ""
        name = try c.decodeIfPresent(String.self, forKey: .name) ?? "Exercise"
        alias = try c.decodeIfPresent(String.self, forKey: .alias)
        duration = max(5, try c.decodeIfPresent(Int.self, forKey: .duration) ?? 30)
        repCount = try c.decodeIfPresent(Int.self, forKey: .repCount).map { max(1, $0) }
        restAfter = max(0, try c.decodeIfPresent(Int.self, forKey: .restAfter) ?? 10)
        restExerciseID = try c.decodeIfPresent(String.self, forKey: .restExerciseID)
        drops = try c.decodeIfPresent([WorkoutDropSetManifest].self, forKey: .drops) ?? []
        restRow = try c.decodeIfPresent(WorkoutRestRowManifest.self, forKey: .restRow)
        if restRow == nil, restAfter > 0 {
            restRow = WorkoutRestRowManifest(duration: restAfter)
        }
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(exerciseID, forKey: .exerciseID)
        try c.encode(name, forKey: .name)
        try c.encodeIfPresent(alias, forKey: .alias)
        try c.encode(duration, forKey: .duration)
        try c.encodeIfPresent(repCount, forKey: .repCount)
        try c.encode(restAfter, forKey: .restAfter)
        try c.encodeIfPresent(restExerciseID, forKey: .restExerciseID)
        try c.encode(drops, forKey: .drops)
        try c.encodeIfPresent(restRow, forKey: .restRow)
    }
}

public struct WorkoutSectionManifest: Codable, Equatable {
    public var exerciseID: String
    public var name: String
    public var alias: String?
    public var duration: Int
    public var sets: Int
    public var repCount: Int?
    public var restBetweenSets: Int
    public var prepareTime: Int
    public var customRestAfter: Int?
    public var isTimerEnabled: Bool
    public var mediaFilenames: [String]
    public var mode: WorkoutSectionMode
    public var slots: [WorkoutSetSlotManifest]
    public var bigRestRow: WorkoutRestRowManifest?

    enum CodingKeys: String, CodingKey {
        case exerciseID, name, alias, duration, sets, repCount, restBetweenSets
        case prepareTime, customRestAfter, isTimerEnabled, mediaFilenames, mode, slots
        case bigRestRow
    }

    public init(
        exerciseID: String,
        name: String,
        alias: String? = nil,
        duration: Int = 30,
        sets: Int = 1,
        repCount: Int? = nil,
        restBetweenSets: Int = 10,
        prepareTime: Int = 4,
        customRestAfter: Int? = nil,
        isTimerEnabled: Bool = true,
        mediaFilenames: [String] = [],
        mode: WorkoutSectionMode = .timed,
        slots: [WorkoutSetSlotManifest] = [],
        bigRestRow: WorkoutRestRowManifest? = nil
    ) {
        self.exerciseID = exerciseID
        self.name = name
        self.alias = alias
        self.duration = max(5, duration)
        self.sets = max(1, sets)
        self.repCount = repCount.map { max(1, $0) }
        self.restBetweenSets = max(0, restBetweenSets)
        self.prepareTime = max(0, prepareTime)
        self.customRestAfter = customRestAfter
        self.isTimerEnabled = isTimerEnabled
        self.mediaFilenames = mediaFilenames
        self.mode = mode
        self.slots = slots
        self.bigRestRow = bigRestRow
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        exerciseID = try c.decodeIfPresent(String.self, forKey: .exerciseID) ?? ""
        name = try c.decodeIfPresent(String.self, forKey: .name) ?? "Section"
        alias = try c.decodeIfPresent(String.self, forKey: .alias)
        duration = max(5, try c.decodeIfPresent(Int.self, forKey: .duration) ?? 30)
        sets = max(1, try c.decodeIfPresent(Int.self, forKey: .sets) ?? 1)
        repCount = try c.decodeIfPresent(Int.self, forKey: .repCount).map { max(1, $0) }
        restBetweenSets = max(0, try c.decodeIfPresent(Int.self, forKey: .restBetweenSets) ?? 10)
        prepareTime = max(0, try c.decodeIfPresent(Int.self, forKey: .prepareTime) ?? 4)
        customRestAfter = try c.decodeIfPresent(Int.self, forKey: .customRestAfter)
        isTimerEnabled = try c.decodeIfPresent(Bool.self, forKey: .isTimerEnabled) ?? true
        mediaFilenames = try c.decodeIfPresent([String].self, forKey: .mediaFilenames) ?? []
        mode = try c.decodeIfPresent(WorkoutSectionMode.self, forKey: .mode) ?? .timed
        slots = try c.decodeIfPresent([WorkoutSetSlotManifest].self, forKey: .slots) ?? []
        bigRestRow = try c.decodeIfPresent(WorkoutRestRowManifest.self, forKey: .bigRestRow)
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(exerciseID, forKey: .exerciseID)
        try c.encode(name, forKey: .name)
        try c.encodeIfPresent(alias, forKey: .alias)
        try c.encode(duration, forKey: .duration)
        try c.encode(sets, forKey: .sets)
        try c.encodeIfPresent(repCount, forKey: .repCount)
        try c.encode(restBetweenSets, forKey: .restBetweenSets)
        try c.encode(prepareTime, forKey: .prepareTime)
        try c.encodeIfPresent(customRestAfter, forKey: .customRestAfter)
        try c.encode(isTimerEnabled, forKey: .isTimerEnabled)
        try c.encode(mediaFilenames, forKey: .mediaFilenames)
        try c.encode(mode, forKey: .mode)
        try c.encode(slots, forKey: .slots)
        try c.encodeIfPresent(bigRestRow, forKey: .bigRestRow)
    }
}

public struct WorkoutManifest: Codable {
    public var id: String
    public var name: String
    public var type: WorkoutType
    public var sections: [WorkoutSectionManifest]
    public var musicTrackFilenames: [String]
    public var colorHex: String
    public var createdAt: Date
    public var prepareTime: Int
    public var restBetweenSections: Int
    public var imageFilename: String?

    public var kind: String { "workout" }

    enum CodingKeys: String, CodingKey {
        case id, name, type, sections, musicTrackFilenames, colorHex
        case createdAt, prepareTime, restBetweenSections, imageFilename
    }

    public init(
        id: String,
        name: String,
        type: WorkoutType = .strength,
        sections: [WorkoutSectionManifest] = [],
        musicTrackFilenames: [String] = [],
        colorHex: String = "FFFFFF",
        createdAt: Date = Date(),
        prepareTime: Int = 4,
        restBetweenSections: Int = 30,
        imageFilename: String? = nil
    ) {
        self.id = id
        self.name = name
        self.type = type
        self.sections = sections
        self.musicTrackFilenames = musicTrackFilenames
        self.colorHex = colorHex
        self.createdAt = createdAt
        self.prepareTime = max(0, prepareTime)
        self.restBetweenSections = max(0, restBetweenSections)
        self.imageFilename = imageFilename
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        name = try c.decodeIfPresent(String.self, forKey: .name) ?? "Untitled Workout"
        type = try c.decodeIfPresent(WorkoutType.self, forKey: .type) ?? .strength
        sections = try c.decodeIfPresent([WorkoutSectionManifest].self, forKey: .sections) ?? []
        musicTrackFilenames = try c.decodeIfPresent([String].self, forKey: .musicTrackFilenames) ?? []
        colorHex = try c.decodeIfPresent(String.self, forKey: .colorHex) ?? "FFFFFF"
        createdAt = try c.decodeIfPresent(Date.self, forKey: .createdAt) ?? Date()
        prepareTime = max(0, try c.decodeIfPresent(Int.self, forKey: .prepareTime) ?? 4)
        restBetweenSections = max(0, try c.decodeIfPresent(Int.self, forKey: .restBetweenSections) ?? 30)
        imageFilename = try c.decodeIfPresent(String.self, forKey: .imageFilename)
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(name, forKey: .name)
        try c.encode(type, forKey: .type)
        try c.encode(sections, forKey: .sections)
        try c.encode(musicTrackFilenames, forKey: .musicTrackFilenames)
        try c.encode(colorHex, forKey: .colorHex)
        try c.encode(createdAt, forKey: .createdAt)
        try c.encode(prepareTime, forKey: .prepareTime)
        try c.encode(restBetweenSections, forKey: .restBetweenSections)
        try c.encodeIfPresent(imageFilename, forKey: .imageFilename)
    }

    public var totalDuration: Int {
        sections.reduce(0) { total, section in
            let slots = section.slots
            let workTime: Int
            if slots.isEmpty {
                workTime = section.duration * section.sets + section.restBetweenSets * max(0, section.sets - 1)
            } else if section.mode == .timed {
                workTime = slots.reduce(0) { subtotal, slot in
                    let drops = slot.drops.reduce(0) { $0 + $1.duration + $1.restAfter }
                    return subtotal + slot.duration + drops + (slot.restRow?.duration ?? slot.restAfter)
                }
            } else {
                workTime = 0
            }
            return total + workTime + (section.bigRestRow?.duration ?? restBetweenSections)
        }
    }
}
