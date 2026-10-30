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
    /// Set aside on purpose. Added after the first three: older builds cannot read it, newer builds read any value
    /// they do not know as "not started" (see `ExercisePageManifest.init(from:)`).
    case abandoned
}

public enum SkillBoardIconType: String, Codable, Equatable, Sendable {
    case emoji
    case system
}

/// A named group on a skill board ("Chords", "Scales"). Skill pages point at it with `skillBoardSectionID`.
///
/// A group is also a page of its own: it opens like one and holds the same material a skill page holds (notes, media
/// with comments, links with comments, prerequisites) next to the pages it groups. That material lives here; its media
/// files sit in `<board page folder>/Sections/<section id>/media/` (see `SkillGroupID`). Every field added after
/// `iconType` is optional in the file and only written when it holds something, so older manifests read unchanged.
public struct SkillBoardSection: Codable, Equatable, Identifiable {
    public var id: String
    public var title: String
    public var order: Int
    public var icon: String?
    public var iconType: SkillBoardIconType?
    /// Strip colour of the group (`RRGGBB`, no `#`); nil draws the neutral strip.
    public var colorHex: String?
    /// One of `mediaFilenames`: the picture clipped inside the strip; the strip, card and header take its colours.
    public var imageFilename: String?
    /// Notes of the group (Markdown).
    public var markdownBody: String
    public var mediaFilenames: [String]
    /// Markdown comment per media file name.
    public var mediaComments: [String: String]
    public var linkURLs: [String]
    public var linkMetadata: [LinkMetadata]
    /// Markdown comment per link URL.
    public var linkComments: [String: String]
    /// Pages (or groups) to learn first, in the order to learn them.
    public var dependencyPageIDs: [String]
    /// Media of this group that are prerequisites rather than reference material.
    public var dependencyMediaFilenames: [String]
    /// Links of this group that are prerequisites rather than reference material.
    public var dependencyLinkURLs: [String]

    public init(
        id: String = UUID().uuidString,
        title: String,
        order: Int = 0,
        icon: String? = nil,
        iconType: SkillBoardIconType? = nil,
        colorHex: String? = nil,
        imageFilename: String? = nil,
        markdownBody: String = "",
        mediaFilenames: [String] = [],
        mediaComments: [String: String] = [:],
        linkURLs: [String] = [],
        linkMetadata: [LinkMetadata] = [],
        linkComments: [String: String] = [:],
        dependencyPageIDs: [String] = [],
        dependencyMediaFilenames: [String] = [],
        dependencyLinkURLs: [String] = []
    ) {
        self.id = id
        self.title = title
        self.order = max(0, order)
        self.icon = icon
        self.iconType = iconType
        self.colorHex = colorHex
        self.imageFilename = imageFilename
        self.markdownBody = markdownBody
        self.mediaFilenames = mediaFilenames
        self.mediaComments = mediaComments
        self.linkURLs = linkURLs
        self.linkMetadata = linkMetadata
        self.linkComments = linkComments
        self.dependencyPageIDs = dependencyPageIDs
        self.dependencyMediaFilenames = dependencyMediaFilenames
        self.dependencyLinkURLs = dependencyLinkURLs
    }

    enum CodingKeys: String, CodingKey {
        case id, title, order, icon, iconType, colorHex, imageFilename, markdownBody, mediaFilenames, mediaComments
        case linkURLs, linkMetadata, linkComments, dependencyPageIDs, dependencyMediaFilenames, dependencyLinkURLs
    }

    public init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            id: try values.decode(String.self, forKey: .id),
            title: values.lenient(String.self, .title) ?? "",
            order: values.lenient(Int.self, .order) ?? 0,
            icon: values.lenient(String.self, .icon),
            iconType: values.lenient(SkillBoardIconType.self, .iconType),
            colorHex: values.lenient(String.self, .colorHex),
            imageFilename: values.lenient(String.self, .imageFilename),
            markdownBody: values.lenient(String.self, .markdownBody) ?? "",
            mediaFilenames: values.lenient([String].self, .mediaFilenames) ?? [],
            mediaComments: values.lenient([String: String].self, .mediaComments) ?? [:],
            linkURLs: values.lenient([String].self, .linkURLs) ?? [],
            linkMetadata: values.lenient([LinkMetadata].self, .linkMetadata) ?? [],
            linkComments: values.lenient([String: String].self, .linkComments) ?? [:],
            dependencyPageIDs: values.lenient([String].self, .dependencyPageIDs) ?? [],
            dependencyMediaFilenames: values.lenient([String].self, .dependencyMediaFilenames) ?? [],
            dependencyLinkURLs: values.lenient([String].self, .dependencyLinkURLs) ?? []
        )
    }

    public func encode(to encoder: Encoder) throws {
        var values = encoder.container(keyedBy: CodingKeys.self)
        try values.encode(id, forKey: .id)
        try values.encode(title, forKey: .title)
        try values.encode(order, forKey: .order)
        try values.encodeIfPresent(icon, forKey: .icon)
        try values.encodeIfPresent(iconType, forKey: .iconType)
        try values.encodeIfPresent(colorHex, forKey: .colorHex)
        try values.encodeIfPresent(imageFilename, forKey: .imageFilename)
        try values.encodeUnlessEmpty(markdownBody, forKey: .markdownBody)
        try values.encodeUnlessEmpty(mediaFilenames, forKey: .mediaFilenames)
        try values.encodeUnlessEmpty(mediaComments, forKey: .mediaComments)
        try values.encodeUnlessEmpty(linkURLs, forKey: .linkURLs)
        try values.encodeUnlessEmpty(linkMetadata, forKey: .linkMetadata)
        try values.encodeUnlessEmpty(linkComments, forKey: .linkComments)
        try values.encodeUnlessEmpty(dependencyPageIDs, forKey: .dependencyPageIDs)
        try values.encodeUnlessEmpty(dependencyMediaFilenames, forKey: .dependencyMediaFilenames)
        try values.encodeUnlessEmpty(dependencyLinkURLs, forKey: .dependencyLinkURLs)
    }

    /// The group's material with every reference pointing inside it: comments, the strip picture and the dependency
    /// flags only for media and links the group still holds; prerequisites without repeats.
    public func normalizedMaterial() -> SkillBoardSection {
        var section = self
        let media = Set(mediaFilenames)
        let links = Set(linkURLs)
        section.mediaComments = mediaComments.filter { media.contains($0.key) && !$0.value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        section.linkComments = linkComments.filter { links.contains($0.key) && !$0.value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        section.linkMetadata = linkMetadata.filter { links.contains($0.url) }
        section.dependencyMediaFilenames = dependencyMediaFilenames.uniqued().filter(media.contains)
        section.dependencyLinkURLs = dependencyLinkURLs.uniqued().filter(links.contains)
        section.dependencyPageIDs = dependencyPageIDs.uniqued()
        if let image = imageFilename, !media.contains(image) { section.imageFilename = nil }
        section.colorHex = SkillColors.normalizedHex(colorHex)
        return section
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
    /// Skill and tutorial pages only: an SF Symbol name or an emoji (see `iconType`). nil = automatic (the app may
    /// pick one from the title). Other pages never keep one.
    public var iconName: String?
    /// How `iconName` is drawn (skill and tutorial pages).
    public var iconType: SkillBoardIconType?
    /// Skill and tutorial pages: a picture icon, one of `mediaFilenames` or an http(s) image URL. Wins over `iconName`
    /// wherever a picture can be drawn.
    public var iconImage: String?
    /// The cover the page chose (one of `mediaFilenames`). Without one the first media item stays the page's cover;
    /// skill boards only show a chosen cover on their cards.
    public var coverMediaFilename: String?
    public var markdownBody: String
    public var mediaFilenames: [String]
    public var mediaComments: [String: String]
    public var linkURLs: [String]
    public var linkMetadata: [LinkMetadata]
    /// Markdown comment per link URL.
    public var linkComments: [String: String]
    public var workoutType: WorkoutType?
    public var pageType: PageType?
    public var skillStatus: SkillStatus?
    public var skillBoardSectionID: String?
    public var skillBoardOrder: Int?
    public var skillBoardSections: [SkillBoardSection]
    public var linkedPageIDs: [String]
    /// Skill and tutorial pages: pages (or groups) to learn first, in the order to learn them.
    public var dependencyPageIDs: [String]
    /// Skill and tutorial pages: media that are prerequisites rather than reference material.
    public var dependencyMediaFilenames: [String]
    /// Skill and tutorial pages: links that are prerequisites rather than reference material.
    public var dependencyLinkURLs: [String]
    /// Presets shared by one skill tree, owned by its highest skill even inside a container. An untyped board
    /// with no skill ancestor can also keep presets.
    public var typePresets: [SkillTypePreset]
    /// Skill and tutorial pages: a type from their highest skill's presets (see `DatabaseManager.skillTypeOwnerID`).
    public var typeID: String?
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
        case mediaFilenames, mediaComments, linkURLs, linkMetadata, linkedPageIDs
        case workoutType, duration, restAfter, prepareTime, sets, restBetweenSets, dropSetTemplates
        case skillStatus, skillBoardSectionID, skillBoardOrder, skillBoardSections
        case childIDs, parentID, order, createdAt, updatedAt
        case iconType, iconImage, coverMediaFilename, linkComments
        case dependencyPageIDs, dependencyMediaFilenames, dependencyLinkURLs, typePresets, typeID
    }

    public init(
        id: String = UUID().uuidString,
        title: String,
        pageKind: PageKind = .container,
        pageType: PageType? = nil,
        coverImageFilename: String? = nil,
        iconName: String? = nil,
        iconType: SkillBoardIconType? = nil,
        iconImage: String? = nil,
        coverMediaFilename: String? = nil,
        markdownBody: String = "",
        mediaFilenames: [String] = [],
        mediaComments: [String: String] = [:],
        linkURLs: [String] = [],
        linkMetadata: [LinkMetadata] = [],
        linkComments: [String: String] = [:],
        linkedPageIDs: [String] = [],
        dependencyPageIDs: [String] = [],
        dependencyMediaFilenames: [String] = [],
        dependencyLinkURLs: [String] = [],
        typePresets: [SkillTypePreset] = [],
        typeID: String? = nil,
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
        let ownsBoard = resolvedPageKind == .container && (resolvedPageType == nil || isSkillPage)

        self.id = id
        self.title = title
        self.pageKind = resolvedPageKind
        self.pageType = resolvedPageType
        self.coverImageFilename = coverImageFilename
        self.iconName = iconName
        self.iconType = isSkillPage ? iconType : nil
        self.iconImage = isSkillPage ? iconImage : nil
        self.coverMediaFilename = coverMediaFilename
        self.markdownBody = markdownBody
        self.mediaFilenames = mediaFilenames
        self.mediaComments = mediaComments
        self.linkURLs = linkURLs
        self.linkMetadata = linkMetadata
        self.linkComments = linkComments
        self.linkedPageIDs = resolvedPageType == nil ? [] : linkedPageIDs
        self.dependencyPageIDs = isSkillPage ? dependencyPageIDs : []
        self.dependencyMediaFilenames = isSkillPage ? dependencyMediaFilenames : []
        self.dependencyLinkURLs = isSkillPage ? dependencyLinkURLs : []
        self.typePresets = resolvedPageKind == .container && (resolvedPageType == nil || isSkillPage) ? typePresets : []
        self.typeID = isSkillPage ? typeID : nil
        self.workoutType = workoutType
        self.skillStatus = isSkillPage ? skillStatus ?? .notStarted : nil
        self.skillBoardSectionID = isSkillPage ? skillBoardSectionID : nil
        self.skillBoardOrder = isSkillPage ? max(0, skillBoardOrder ?? 0) : nil
        self.skillBoardSections = ownsBoard
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
            iconType: values.lenient(SkillBoardIconType.self, .iconType),
            iconImage: values.lenient(String.self, .iconImage),
            coverMediaFilename: values.lenient(String.self, .coverMediaFilename),
            markdownBody: try values.decodeIfPresent(String.self, forKey: .markdownBody) ?? "",
            mediaFilenames: try values.decodeIfPresent([String].self, forKey: .mediaFilenames) ?? [],
            mediaComments: try values.decodeIfPresent([String: String].self, forKey: .mediaComments) ?? [:],
            linkURLs: try values.decodeIfPresent([String].self, forKey: .linkURLs) ?? [],
            linkMetadata: try values.decodeIfPresent([LinkMetadata].self, forKey: .linkMetadata) ?? [],
            linkComments: values.lenient([String: String].self, .linkComments) ?? [:],
            linkedPageIDs: try values.decodeIfPresent([String].self, forKey: .linkedPageIDs) ?? [],
            dependencyPageIDs: values.lenient([String].self, .dependencyPageIDs) ?? [],
            dependencyMediaFilenames: values.lenient([String].self, .dependencyMediaFilenames) ?? [],
            dependencyLinkURLs: values.lenient([String].self, .dependencyLinkURLs) ?? [],
            typePresets: values.lenient([SkillTypePreset].self, .typePresets) ?? [],
            typeID: values.lenient(String.self, .typeID),
            workoutType: try values.decodeIfPresent(WorkoutType.self, forKey: .workoutType),
            skillStatus: values.lenient(String.self, .skillStatus).map { SkillStatus(rawValue: $0) ?? .notStarted },
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

    /// Writes the keys the synthesized encoder wrote before the skill fields existed (optionals only when set,
    /// collections always) and the skill fields only when they hold something, so untouched pages keep identical
    /// manifests and older builds keep reading them.
    public func encode(to encoder: Encoder) throws {
        var values = encoder.container(keyedBy: CodingKeys.self)
        try values.encode(id, forKey: .id)
        try values.encode(title, forKey: .title)
        try values.encode(pageKind, forKey: .pageKind)
        try values.encodeIfPresent(pageType, forKey: .pageType)
        try values.encodeIfPresent(coverImageFilename, forKey: .coverImageFilename)
        try values.encodeIfPresent(iconName, forKey: .iconName)
        try values.encode(markdownBody, forKey: .markdownBody)
        try values.encode(mediaFilenames, forKey: .mediaFilenames)
        try values.encode(mediaComments, forKey: .mediaComments)
        try values.encode(linkURLs, forKey: .linkURLs)
        try values.encode(linkMetadata, forKey: .linkMetadata)
        try values.encode(linkedPageIDs, forKey: .linkedPageIDs)
        try values.encodeIfPresent(workoutType, forKey: .workoutType)
        try values.encodeIfPresent(duration, forKey: .duration)
        try values.encodeIfPresent(restAfter, forKey: .restAfter)
        try values.encodeIfPresent(prepareTime, forKey: .prepareTime)
        try values.encodeIfPresent(sets, forKey: .sets)
        try values.encodeIfPresent(restBetweenSets, forKey: .restBetweenSets)
        try values.encode(dropSetTemplates, forKey: .dropSetTemplates)
        try values.encodeIfPresent(skillStatus, forKey: .skillStatus)
        try values.encodeIfPresent(skillBoardSectionID, forKey: .skillBoardSectionID)
        try values.encodeIfPresent(skillBoardOrder, forKey: .skillBoardOrder)
        try values.encode(skillBoardSections, forKey: .skillBoardSections)
        try values.encode(childIDs, forKey: .childIDs)
        try values.encodeIfPresent(parentID, forKey: .parentID)
        try values.encode(order, forKey: .order)
        try values.encode(createdAt, forKey: .createdAt)
        try values.encode(updatedAt, forKey: .updatedAt)
        try values.encodeIfPresent(iconType, forKey: .iconType)
        try values.encodeIfPresent(iconImage, forKey: .iconImage)
        try values.encodeIfPresent(coverMediaFilename, forKey: .coverMediaFilename)
        try values.encodeUnlessEmpty(linkComments, forKey: .linkComments)
        try values.encodeUnlessEmpty(dependencyPageIDs, forKey: .dependencyPageIDs)
        try values.encodeUnlessEmpty(dependencyMediaFilenames, forKey: .dependencyMediaFilenames)
        try values.encodeUnlessEmpty(dependencyLinkURLs, forKey: .dependencyLinkURLs)
        try values.encodeUnlessEmpty(typePresets, forKey: .typePresets)
        try values.encodeIfPresent(typeID, forKey: .typeID)
    }

    /// The skill board groups this page owns, sorted by `order`.
    public var orderedSkillBoardSections: [SkillBoardSection] { skillBoardSections.sorted { $0.order < $1.order } }

    /// One of this page's skill board groups.
    public func skillBoardSection(_ id: String) -> SkillBoardSection? { skillBoardSections.first { $0.id == id } }

    /// A type of this page's presets, whichever preset holds it.
    public func skillType(_ id: String) -> SkillType? {
        typePresets.lazy.flatMap(\.types).first { $0.id == id }
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
