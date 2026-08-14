import Foundation

public struct PageDropSetTemplate: Codable, Equatable, Identifiable {
    public var id: String
    public var setIndex: Int
    public var exerciseID: String
    public var name: String
    public var duration: Int
    public var restAfter: Int

    public init(
        id: String = UUID().uuidString,
        setIndex: Int,
        exerciseID: String,
        name: String,
        duration: Int = 30,
        restAfter: Int = 10
    ) {
        self.id = id
        self.setIndex = max(0, setIndex)
        self.exerciseID = exerciseID
        self.name = name
        self.duration = max(5, duration)
        self.restAfter = max(0, restAfter)
    }
}

public struct ExercisePageManifest: Codable {
    public enum PageKind: String, Codable, Equatable {
        case container
        case leaf
    }

    public var id: String
    public var title: String
    public var pageKind: PageKind
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
    public var dropSetTemplates: [PageDropSetTemplate]
    public var childIDs: [String]
    public var parentID: String?
    public var order: Int
    public var createdAt: Date
    public var updatedAt: Date

    public var kind: String { "page" }

    enum CodingKeys: String, CodingKey {
        case id, title, pageKind, coverImageFilename, iconName, markdownBody
        case mediaFilenames, linkURLs, linkMetadata
        case workoutType, duration, restAfter, sets, restBetweenSets, dropSetTemplates
        case childIDs, parentID, order, createdAt, updatedAt
    }

    public init(
        id: String = UUID().uuidString,
        title: String,
        pageKind: PageKind = .container,
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
        dropSetTemplates: [PageDropSetTemplate] = [],
        childIDs: [String] = [],
        parentID: String? = nil,
        order: Int = 0,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.title = title
        self.pageKind = pageKind
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
        self.dropSetTemplates = dropSetTemplates
        self.childIDs = childIDs
        self.parentID = parentID
        self.order = order
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    public init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        let id = try values.decode(String.self, forKey: .id)
        let title = try values.decode(String.self, forKey: .title)
        let parentID = try values.decodeIfPresent(String.self, forKey: .parentID)
        let childIDs = try values.decodeIfPresent([String].self, forKey: .childIDs) ?? []
        let duration = try values.decodeIfPresent(Int.self, forKey: .duration)
        let pageKind = try values.decodeIfPresent(PageKind.self, forKey: .pageKind)
            ?? (childIDs.isEmpty && duration != nil ? .leaf : .container)

        self.init(
            id: id,
            title: title,
            pageKind: pageKind,
            coverImageFilename: try values.decodeIfPresent(String.self, forKey: .coverImageFilename),
            iconName: try values.decodeIfPresent(String.self, forKey: .iconName),
            markdownBody: try values.decodeIfPresent(String.self, forKey: .markdownBody) ?? "",
            mediaFilenames: try values.decodeIfPresent([String].self, forKey: .mediaFilenames) ?? [],
            linkURLs: try values.decodeIfPresent([String].self, forKey: .linkURLs) ?? [],
            linkMetadata: try values.decodeIfPresent([LinkMetadata].self, forKey: .linkMetadata) ?? [],
            workoutType: try values.decodeIfPresent(WorkoutType.self, forKey: .workoutType),
            duration: duration,
            restAfter: try values.decodeIfPresent(Int.self, forKey: .restAfter),
            sets: try values.decodeIfPresent(Int.self, forKey: .sets),
            restBetweenSets: try values.decodeIfPresent(Int.self, forKey: .restBetweenSets),
            dropSetTemplates: try values.decodeIfPresent([PageDropSetTemplate].self, forKey: .dropSetTemplates) ?? [],
            childIDs: childIDs,
            parentID: parentID,
            order: try values.decodeIfPresent(Int.self, forKey: .order) ?? 0,
            createdAt: try values.decodeIfPresent(Date.self, forKey: .createdAt) ?? Date(),
            updatedAt: try values.decodeIfPresent(Date.self, forKey: .updatedAt) ?? Date()
        )
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
