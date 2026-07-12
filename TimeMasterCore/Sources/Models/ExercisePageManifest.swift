import Foundation

public struct ExercisePageManifest: Codable {
    public var id: String
    public var title: String
    public var coverImageFilename: String?
    public var iconName: String?
    public var markdownBody: String
    public var mediaFilenames: [String]
    public var linkURLs: [String]
    public var linkMetadata: [LinkMetadata]
    public var workoutType: WorkoutType?
    public var duration: Int?
    public var restAfter: Int?
    public var sets: Int?
    public var restBetweenSets: Int?
    public var tags: [String]
    public var childIDs: [String]
    public var parentID: String?
    public var order: Int
    public var createdAt: Date
    public var updatedAt: Date

    public var kind: String { "page" }

    enum CodingKeys: String, CodingKey {
        case id, title, coverImageFilename, iconName, markdownBody
        case mediaFilenames, linkURLs, linkMetadata
        case workoutType, duration, restAfter, sets, restBetweenSets
        case tags, childIDs, parentID, order, createdAt, updatedAt
    }

    public init(
        id: String = UUID().uuidString,
        title: String,
        coverImageFilename: String? = nil,
        iconName: String? = nil,
        markdownBody: String = "",
        mediaFilenames: [String] = [],
        linkURLs: [String] = [],
        linkMetadata: [LinkMetadata] = [],
        workoutType: WorkoutType? = nil,
        duration: Int? = nil,
        restAfter: Int? = nil,
        sets: Int? = nil,
        restBetweenSets: Int? = nil,
        tags: [String] = [],
        childIDs: [String] = [],
        parentID: String? = nil,
        order: Int = 0,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.title = title
        self.coverImageFilename = coverImageFilename
        self.iconName = iconName
        self.markdownBody = markdownBody
        self.mediaFilenames = mediaFilenames
        self.linkURLs = linkURLs
        self.linkMetadata = linkMetadata
        self.workoutType = workoutType
        self.duration = duration.map { max(5, $0) }
        self.restAfter = restAfter.map { max(0, $0) }
        self.sets = sets.map { max(1, $0) }
        self.restBetweenSets = restBetweenSets.map { max(0, $0) }
        self.tags = tags
        self.childIDs = childIDs
        self.parentID = parentID
        self.order = order
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

public struct LinkMetadata: Codable, Equatable {
    public var url: String
    public var title: String?
    public var description: String?
    public var thumbnailURL: String?
    public var platform: LinkPlatform

    public init(
        url: String,
        title: String? = nil,
        description: String? = nil,
        thumbnailURL: String? = nil,
        platform: LinkPlatform = .web
    ) {
        self.url = url
        self.title = title
        self.description = description
        self.thumbnailURL = thumbnailURL
        self.platform = platform
    }
}

public enum LinkPlatform: String, Codable, Equatable {
    case youtube
    case instagram
    case tiktok
    case facebook
    case web
}
