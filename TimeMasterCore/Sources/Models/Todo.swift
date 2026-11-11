import Foundation

/// A link on a to-do or a milestone: a workout, a page, a file of the page or a web address (see `TmaxLink`).
public struct TodoLink: Codable, Equatable, Hashable, Identifiable, Sendable {
    public var id: String
    /// What the chip says; nil = the app writes it from the target (the workout's name, the page's title, the host).
    public var label: String?
    public var url: String

    public init(id: String = UUID().uuidString, label: String? = nil, url: String) {
        self.id = id
        self.label = label
        self.url = url
    }

    public init(id: String = UUID().uuidString, label: String? = nil, target: TmaxLink) {
        self.init(id: id, label: label, url: target.urlString)
    }

    public var target: TmaxLink? { TmaxLink(url) }

    enum CodingKeys: String, CodingKey {
        case id, label, url
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            id: c.lenient(String.self, .id) ?? UUID().uuidString,
            label: c.lenient(String.self, .label),
            url: c.lenient(String.self, .url) ?? ""
        )
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encodeIfPresent(label, forKey: .label)
        try c.encode(url, forKey: .url)
    }
}

/// One line of a page's to-do list (Skillmax's `TodoItem`, with Tmax's section dividers and pictures). A to-do can
/// hold to-dos of its own: the list is a tree. The fields Skillmax knows are always written; the rest only when set,
/// so a plain to-do reads the same in both apps.
public struct TodoItem: ChecklistEntry {
    public static let kind = ChecklistKind.todo
    public static let maxDepth = 8
    public static let maxPerPage = 500
    public static let maxTitleLength = 500
    public static let maxNoteLength = 2_000
    public static let maxLinks = 12
    public static let maxImages = 6
    public static var pageList: WritableKeyPath<ExercisePageManifest, [TodoItem]> { \.todos }

    public var id: String
    public var title: String
    public var isDone: Bool
    public var doneAt: Date?
    public var children: [TodoItem]
    public var links: [TodoLink]
    public var createdAt: Date
    public var isSection: Bool
    public var note: String
    public var iconName: String?
    public var iconType: SkillBoardIconType?
    public var iconImage: String?
    public var colorHex: String?
    public var coverMediaFilename: String?
    public var imageFilenames: [String]

    public init(
        id: String = UUID().uuidString,
        title: String,
        isDone: Bool = false,
        doneAt: Date? = nil,
        children: [TodoItem] = [],
        links: [TodoLink] = [],
        createdAt: Date = Date(),
        isSection: Bool = false,
        note: String = "",
        iconName: String? = nil,
        iconType: SkillBoardIconType? = nil,
        iconImage: String? = nil,
        colorHex: String? = nil,
        coverMediaFilename: String? = nil,
        imageFilenames: [String] = []
    ) {
        self.id = id
        self.title = title
        self.isDone = isDone
        self.doneAt = doneAt
        self.children = children
        self.links = links
        self.createdAt = createdAt
        self.isSection = isSection
        self.note = note
        self.iconName = iconName
        self.iconType = iconType
        self.iconImage = iconImage
        self.colorHex = colorHex
        self.coverMediaFilename = coverMediaFilename
        self.imageFilenames = imageFilenames
    }

    public static func blank(id: String, title: String) -> TodoItem { TodoItem(id: id, title: title) }

    enum CodingKeys: String, CodingKey {
        case id, title, isDone, doneAt, children, links, createdAt
        case kind, note, iconName, iconType, iconImage, colorHex, coverMediaFilename, imageFilenames
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            id: try c.decode(String.self, forKey: .id),
            title: c.lenient(String.self, .title) ?? "",
            isDone: c.lenient(Bool.self, .isDone) ?? false,
            doneAt: c.lenient(Date.self, .doneAt),
            children: c.lenientList(TodoItem.self, .children),
            links: c.lenientList(TodoLink.self, .links),
            createdAt: c.lenient(Date.self, .createdAt) ?? Date(timeIntervalSince1970: 0),
            isSection: c.lenient(String.self, .kind)?.lowercased() == "section",
            note: c.lenient(String.self, .note) ?? "",
            iconName: c.lenient(String.self, .iconName),
            iconType: SkillBoardIconType.lenient(c.lenient(String.self, .iconType)),
            iconImage: c.lenient(String.self, .iconImage),
            colorHex: c.lenient(String.self, .colorHex),
            coverMediaFilename: c.lenient(String.self, .coverMediaFilename),
            imageFilenames: c.lenient([String].self, .imageFilenames) ?? []
        )
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(title, forKey: .title)
        try c.encode(isDone, forKey: .isDone)
        try c.encodeIfPresent(doneAt, forKey: .doneAt)
        try c.encode(children, forKey: .children)
        try c.encode(links, forKey: .links)
        try c.encode(createdAt, forKey: .createdAt)
        if isSection { try c.encode("section", forKey: .kind) }
        try c.encodeUnlessEmpty(note, forKey: .note)
        try c.encodeIfPresent(iconName, forKey: .iconName)
        if iconName != nil { try c.encodeIfPresent(iconType, forKey: .iconType) }
        try c.encodeIfPresent(iconImage, forKey: .iconImage)
        try c.encodeIfPresent(colorHex, forKey: .colorHex)
        try c.encodeIfPresent(coverMediaFilename, forKey: .coverMediaFilename)
        try c.encodeUnlessEmpty(imageFilenames, forKey: .imageFilenames)
    }
}
