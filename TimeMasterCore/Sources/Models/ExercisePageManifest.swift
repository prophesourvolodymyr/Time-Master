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

public enum PageType: String, Codable, Equatable, CaseIterable {
    case exercise
    case skill
    case tutorial
}

public enum SkillStatus: String, Codable, Equatable, CaseIterable {
    case notStarted
    case learning
    case completed
}

public enum SkillBoardIconType: String, Codable, Equatable {
    case emoji
    case system
}

public struct SkillBoardSection: Codable, Equatable, Identifiable {
    public var id: String
    public var title: String
    public var order: Int
    public var icon: String?
    public var iconType: SkillBoardIconType?

    public init(
        id: String = UUID().uuidString,
        title: String,
        order: Int = 0,
        icon: String? = nil,
        iconType: SkillBoardIconType? = nil
    ) {
        self.id = id
        self.title = title
        self.order = max(0, order)
        self.icon = icon
        self.iconType = iconType
    }
}

public struct SkillBoardPlacement: Equatable {
    public var pageID: String
    public var status: SkillStatus
    public var sectionID: String?
    public var order: Int

    public init(
        pageID: String,
        status: SkillStatus,
        sectionID: String?,
        order: Int
    ) {
        self.pageID = pageID
        self.status = status
        self.sectionID = sectionID
        self.order = max(0, order)
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
    public var pageType: PageType?
    public var skillStatus: SkillStatus?
    public var skillBoardSectionID: String?
    public var skillBoardOrder: Int?
    public var skillBoardSections: [SkillBoardSection]
    public var linkedPageIDs: [String]
    public var duration: Int?
    public var restAfter: Int?
    public var prepareTime: Int?
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
        case id, title, pageKind, pageType, coverImageFilename, iconName, markdownBody
        case mediaFilenames, linkURLs, linkMetadata, linkedPageIDs
        case workoutType, duration, restAfter, prepareTime, sets, restBetweenSets, dropSetTemplates
        case skillStatus, skillBoardSectionID, skillBoardOrder, skillBoardSections
        case childIDs, parentID, order, createdAt, updatedAt
    }

    public init(
        id: String = UUID().uuidString,
        title: String,
        pageKind: PageKind = .container,
        pageType: PageType? = nil,
        coverImageFilename: String? = nil,
        iconName: String? = nil,
        markdownBody: String = "",
        mediaFilenames: [String] = [],
        linkURLs: [String] = [],
        linkMetadata: [LinkMetadata] = [],
        linkedPageIDs: [String] = [],
        workoutType: WorkoutType? = nil,
        skillStatus: SkillStatus? = nil,
        skillBoardSectionID: String? = nil,
        skillBoardOrder: Int? = nil,
        skillBoardSections: [SkillBoardSection] = [],
        duration: Int? = nil,
        restAfter: Int? = nil,
        prepareTime: Int? = nil,
        sets: Int? = nil,
        restBetweenSets: Int? = nil,
        dropSetTemplates: [PageDropSetTemplate] = [],
        childIDs: [String] = [],
        parentID: String? = nil,
        order: Int = 0,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        let resolvedPageType = pageType ?? (pageKind == .leaf ? .exercise : nil)
        let resolvedPageKind: PageKind = (resolvedPageType == .skill || resolvedPageType == .tutorial)
            ? .container
            : pageKind
        let isSkillPage = resolvedPageType == .skill || resolvedPageType == .tutorial

        self.id = id
        self.title = title
        self.pageKind = resolvedPageKind
        self.pageType = resolvedPageType
        self.coverImageFilename = coverImageFilename
        self.iconName = iconName
        self.markdownBody = markdownBody
        self.mediaFilenames = mediaFilenames
        self.linkURLs = linkURLs
        self.linkMetadata = linkMetadata
        self.linkedPageIDs = resolvedPageType == nil ? [] : linkedPageIDs
        self.workoutType = workoutType
        self.skillStatus = isSkillPage ? skillStatus ?? .notStarted : nil
        self.skillBoardSectionID = isSkillPage ? skillBoardSectionID : nil
        self.skillBoardOrder = isSkillPage ? max(0, skillBoardOrder ?? 0) : nil
        self.skillBoardSections = resolvedPageType == nil && resolvedPageKind == .container
            ? skillBoardSections.sorted { $0.order < $1.order }
            : []
        self.duration = duration.map { max(5, $0) }
        self.restAfter = restAfter.map { max(0, $0) }
        self.prepareTime = prepareTime.map { min(30, max(0, $0)) }
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
            pageType: try values.decodeIfPresent(PageType.self, forKey: .pageType),
            coverImageFilename: try values.decodeIfPresent(String.self, forKey: .coverImageFilename),
            iconName: try values.decodeIfPresent(String.self, forKey: .iconName),
            markdownBody: try values.decodeIfPresent(String.self, forKey: .markdownBody) ?? "",
            mediaFilenames: try values.decodeIfPresent([String].self, forKey: .mediaFilenames) ?? [],
            linkURLs: try values.decodeIfPresent([String].self, forKey: .linkURLs) ?? [],
            linkMetadata: try values.decodeIfPresent([LinkMetadata].self, forKey: .linkMetadata) ?? [],
            linkedPageIDs: try values.decodeIfPresent([String].self, forKey: .linkedPageIDs) ?? [],
            workoutType: try values.decodeIfPresent(WorkoutType.self, forKey: .workoutType),
            skillStatus: try values.decodeIfPresent(SkillStatus.self, forKey: .skillStatus),
            skillBoardSectionID: try values.decodeIfPresent(String.self, forKey: .skillBoardSectionID),
            skillBoardOrder: try values.decodeIfPresent(Int.self, forKey: .skillBoardOrder),
            skillBoardSections: try values.decodeIfPresent([SkillBoardSection].self, forKey: .skillBoardSections) ?? [],
            duration: duration,
            restAfter: try values.decodeIfPresent(Int.self, forKey: .restAfter),
            prepareTime: try values.decodeIfPresent(Int.self, forKey: .prepareTime),
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
