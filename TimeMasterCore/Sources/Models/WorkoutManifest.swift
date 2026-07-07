import Foundation

public struct WorkoutSectionManifest: Codable, Equatable {
    public var exerciseID: String
    public var name: String
    public var duration: Int
    public var sets: Int
    public var restBetweenSets: Int
    public var prepareTime: Int
    public var customRestAfter: Int?
    public var isTimerEnabled: Bool
    public var mediaFilenames: [String]

    public init(
        exerciseID: String,
        name: String,
        duration: Int = 30,
        sets: Int = 1,
        restBetweenSets: Int = 10,
        prepareTime: Int = 4,
        customRestAfter: Int? = nil,
        isTimerEnabled: Bool = true,
        mediaFilenames: [String] = []
    ) {
        self.exerciseID = exerciseID
        self.name = name
        self.duration = max(5, duration)
        self.sets = max(1, sets)
        self.restBetweenSets = max(0, restBetweenSets)
        self.prepareTime = max(0, prepareTime)
        self.customRestAfter = customRestAfter
        self.isTimerEnabled = isTimerEnabled
        self.mediaFilenames = mediaFilenames
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
    public var restBetweenSections: Int
    public var imageFilename: String?

    public var kind: String { "workout" }

    enum CodingKeys: String, CodingKey {
        case id, name, type, sections, musicTrackFilenames, colorHex
        case createdAt, restBetweenSections, imageFilename
    }

    public init(
        id: String,
        name: String,
        type: WorkoutType = .strength,
        sections: [WorkoutSectionManifest] = [],
        musicTrackFilenames: [String] = [],
        colorHex: String = "FFFFFF",
        createdAt: Date = Date(),
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
        self.restBetweenSections = max(0, restBetweenSections)
        self.imageFilename = imageFilename
    }

    public var totalDuration: Int {
        guard !sections.isEmpty else { return 0 }
        let total = sections.reduce(0) { acc, s in
            let workTime = s.duration * s.sets + s.restBetweenSets * max(0, s.sets - 1)
            let restTime = s.customRestAfter ?? restBetweenSections
            return acc + workTime + restTime
        }
        let lastRest = sections.last.map { $0.customRestAfter ?? restBetweenSections } ?? 0
        return total - lastRest
    }
}
