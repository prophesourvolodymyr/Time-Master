import Foundation

/// A milestone of a page: a step worth marking, drawn as a card with an icon and a cover of its own (Skillmax's
/// `Milestone`, with Tmax's section dividers, picture strip and links). Where a `TodoItem` is a line of a checklist, a
/// milestone is that checklist's big sibling: a title, a few lines about what reaching it means, an icon, a colour, a
/// cover and pictures, links to workouts and pages, and milestones of its own (up to four levels). The fields Skillmax
/// knows are written as it writes them; the rest only when set.
public struct Milestone: ChecklistEntry {
    public static let kind = ChecklistKind.milestone
    public static let maxDepth = 4
    public static let maxPerPage = 200
    public static let maxTitleLength = 200
    public static let maxNoteLength = 2_000
    public static let maxLinks = 12
    public static let maxImages = 6
    public static var pageList: WritableKeyPath<ExercisePageManifest, [Milestone]> { \.milestones }

    public var id: String
    public var title: String
    public var note: String
    public var isDone: Bool
    public var doneAt: Date?
    public var iconName: String?
    public var iconType: SkillBoardIconType?
    public var colorHex: String?
    public var children: [Milestone]
    public var createdAt: Date
    public var isSection: Bool
    public var iconImage: String?
    public var coverMediaFilename: String?
    public var imageFilenames: [String]
    public var links: [TodoLink]

    public init(
        id: String = UUID().uuidString,
        title: String,
        note: String = "",
        isDone: Bool = false,
        doneAt: Date? = nil,
        iconName: String? = nil,
        iconType: SkillBoardIconType? = nil,
        colorHex: String? = nil,
        children: [Milestone] = [],
        createdAt: Date = Date(),
        isSection: Bool = false,
        iconImage: String? = nil,
        coverMediaFilename: String? = nil,
        imageFilenames: [String] = [],
        links: [TodoLink] = []
    ) {
        self.id = id
        self.title = title
        self.note = note
        self.isDone = isDone
        self.doneAt = doneAt
        self.iconName = iconName
        self.iconType = iconType
        self.colorHex = colorHex
        self.children = children
        self.createdAt = createdAt
        self.isSection = isSection
        self.iconImage = iconImage
        self.coverMediaFilename = coverMediaFilename
        self.imageFilenames = imageFilenames
        self.links = links
    }

    public static func blank(id: String, title: String) -> Milestone { Milestone(id: id, title: title) }

    enum CodingKeys: String, CodingKey {
        case id, title, note, isDone, doneAt, iconName, iconType, colorHex, children, createdAt
        case kind, iconImage, coverMediaFilename, imageFilenames, links
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            id: try c.decode(String.self, forKey: .id),
            title: c.lenient(String.self, .title) ?? "",
            note: c.lenient(String.self, .note) ?? "",
            isDone: c.lenient(Bool.self, .isDone) ?? false,
            doneAt: c.lenient(Date.self, .doneAt),
            iconName: c.lenient(String.self, .iconName),
            iconType: SkillBoardIconType.lenient(c.lenient(String.self, .iconType)),
            colorHex: c.lenient(String.self, .colorHex),
            children: c.lenientList(Milestone.self, .children),
            createdAt: c.lenient(Date.self, .createdAt) ?? Date(timeIntervalSince1970: 0),
            isSection: c.lenient(String.self, .kind)?.lowercased() == "section",
            iconImage: c.lenient(String.self, .iconImage),
            coverMediaFilename: c.lenient(String.self, .coverMediaFilename),
            imageFilenames: c.lenient([String].self, .imageFilenames) ?? [],
            links: c.lenientList(TodoLink.self, .links)
        )
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(title, forKey: .title)
        try c.encode(note, forKey: .note)
        try c.encode(isDone, forKey: .isDone)
        try c.encodeIfPresent(doneAt, forKey: .doneAt)
        try c.encodeIfPresent(iconName, forKey: .iconName)
        if iconName != nil { try c.encodeIfPresent(iconType, forKey: .iconType) }
        try c.encodeIfPresent(colorHex, forKey: .colorHex)
        try c.encode(children, forKey: .children)
        try c.encode(createdAt, forKey: .createdAt)
        if isSection { try c.encode("section", forKey: .kind) }
        try c.encodeIfPresent(iconImage, forKey: .iconImage)
        try c.encodeIfPresent(coverMediaFilename, forKey: .coverMediaFilename)
        try c.encodeUnlessEmpty(imageFilenames, forKey: .imageFilenames)
        try c.encodeUnlessEmpty(links, forKey: .links)
    }
}
