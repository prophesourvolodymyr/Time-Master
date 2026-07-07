import Foundation

public struct ExerciseManifest: Codable {
    public var id: String
    public var name: String
    public var details: String
    public var duration: Int
    public var restAfter: Int
    public var workoutType: WorkoutType?
    public var mediaFilenames: [String]
    public var linkURLs: [String]
    public var createdAt: Date
    public var updatedAt: Date
    public var sets: Int?
    public var restBetweenSets: Int?

    public var kind: String { "exercise" }

    enum CodingKeys: String, CodingKey {
        case id, name, details, duration, restAfter, workoutType
        case mediaFilenames, linkURLs, createdAt, updatedAt
        case sets, restBetweenSets
    }

    public init(
        id: String,
        name: String,
        details: String = "",
        duration: Int = 30,
        restAfter: Int = 10,
        workoutType: WorkoutType? = nil,
        mediaFilenames: [String] = [],
        linkURLs: [String] = [],
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        sets: Int? = nil,
        restBetweenSets: Int? = nil
    ) {
        self.id = id
        self.name = name
        self.details = details
        self.duration = max(5, duration)
        self.restAfter = max(0, restAfter)
        self.workoutType = workoutType
        self.mediaFilenames = mediaFilenames
        self.linkURLs = linkURLs
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.sets = sets.map { max(1, $0) }
        self.restBetweenSets = restBetweenSets.map { max(0, $0) }
    }
}
