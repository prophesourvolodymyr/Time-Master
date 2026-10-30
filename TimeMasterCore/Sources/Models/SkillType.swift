import Foundation

/// How a skill page's card is drawn when the page wears a type.
public enum SkillTypeEffect: String, Codable, CaseIterable, Sendable {
    /// Only the chip shows the type.
    case none
    /// A soft wash of the type's colour.
    case tint
    /// A soft glow in the type's colour.
    case glow
    /// An outline in the type's colour.
    case outline
    /// A gradient that starts from the type's colour.
    case gradient
}

/// Where a type moves its pages inside the list, row or column they are shown in. Never stored as an order: the app
/// applies it when it draws (top-ruled pages first, bottom-ruled pages last, the rest in their stored order).
public enum SkillTypeSortRule: String, Codable, CaseIterable, Sendable {
    case none
    case top
    case bottom
}

/// A custom tag a skill page can wear: a title with its own colour (the chip and text highlight), an icon, an effect
/// on the card and a sort rule. Types live in the highest skill's `ExercisePageManifest.typePresets`; its nested
/// sub-skills share them, while sibling skills inside an untyped container keep separate presets.
public struct SkillType: Codable, Equatable, Hashable, Identifiable, Sendable {
    public var id: String
    public var title: String
    /// Highlight colour (`RRGGBB`, no `#`); nil = the app's fallback colour.
    public var colorHex: String?
    /// An SF Symbol name or an emoji (see `iconType`); nil = a tag.
    public var iconName: String?
    public var iconType: SkillBoardIconType
    public var effect: SkillTypeEffect
    public var sortRule: SkillTypeSortRule
    /// Position inside its preset.
    public var order: Int

    public init(
        id: String = UUID().uuidString,
        title: String,
        colorHex: String? = nil,
        iconName: String? = nil,
        iconType: SkillBoardIconType = .system,
        effect: SkillTypeEffect = .tint,
        sortRule: SkillTypeSortRule = .none,
        order: Int = 0
    ) {
        self.id = id
        self.title = title
        self.colorHex = colorHex
        self.iconName = iconName
        self.iconType = iconType
        self.effect = effect
        self.sortRule = sortRule
        self.order = max(0, order)
    }

    enum CodingKeys: String, CodingKey {
        case id, title, colorHex, iconName, iconType, effect, sortRule, order
    }

    public init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            id: try values.decode(String.self, forKey: .id),
            title: values.lenient(String.self, .title) ?? "",
            colorHex: values.lenient(String.self, .colorHex),
            iconName: values.lenient(String.self, .iconName),
            iconType: values.lenient(SkillBoardIconType.self, .iconType) ?? .system,
            effect: values.lenient(SkillTypeEffect.self, .effect) ?? .tint,
            sortRule: values.lenient(SkillTypeSortRule.self, .sortRule) ?? SkillTypeSortRule.none,
            order: values.lenient(Int.self, .order) ?? 0
        )
    }

    public func encode(to encoder: Encoder) throws {
        var values = encoder.container(keyedBy: CodingKeys.self)
        try values.encode(id, forKey: .id)
        try values.encode(title, forKey: .title)
        try values.encodeIfPresent(colorHex, forKey: .colorHex)
        try values.encodeIfPresent(iconName, forKey: .iconName)
        try values.encode(iconType, forKey: .iconType)
        try values.encode(effect, forKey: .effect)
        try values.encode(sortRule, forKey: .sortRule)
        try values.encode(order, forKey: .order)
    }
}

/// A named collection of types, like a Notion "Select" property: it has a name and an icon, and holds the types
/// ("Tricks", "Chords") a page of the skill can pick from. A skill can keep several presets; a page wears one type of
/// one of them (the types of all of them are one pool for its tree). Other skills keep their own presets.
public struct SkillTypePreset: Codable, Equatable, Hashable, Identifiable, Sendable {
    public var id: String
    public var title: String
    /// The preset's icon (an SF Symbol name or an emoji, see `iconType`); nil = none.
    public var iconName: String?
    public var iconType: SkillBoardIconType
    /// Position among the board's presets.
    public var order: Int
    public var types: [SkillType]

    public init(
        id: String = UUID().uuidString,
        title: String,
        iconName: String? = nil,
        iconType: SkillBoardIconType = .system,
        order: Int = 0,
        types: [SkillType] = []
    ) {
        self.id = id
        self.title = title
        self.iconName = iconName
        self.iconType = iconType
        self.order = max(0, order)
        self.types = types
    }

    /// The types sorted by `order`.
    public var orderedTypes: [SkillType] { types.sorted { $0.order < $1.order } }

    enum CodingKeys: String, CodingKey {
        case id, title, iconName, iconType, order, types
    }

    public init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            id: try values.decode(String.self, forKey: .id),
            title: values.lenient(String.self, .title) ?? "",
            iconName: values.lenient(String.self, .iconName),
            iconType: values.lenient(SkillBoardIconType.self, .iconType) ?? .system,
            order: values.lenient(Int.self, .order) ?? 0,
            types: values.lenient([SkillType].self, .types) ?? []
        )
    }

    public func encode(to encoder: Encoder) throws {
        var values = encoder.container(keyedBy: CodingKeys.self)
        try values.encode(id, forKey: .id)
        try values.encode(title, forKey: .title)
        // Optional and new: a preset without an icon keeps the bytes it always had (and older builds still read it).
        if let iconName {
            try values.encode(iconName, forKey: .iconName)
            try values.encode(iconType, forKey: .iconType)
        }
        try values.encode(order, forKey: .order)
        try values.encode(types, forKey: .types)
    }
}

/// The colours a new group or type can start with (`RRGGBB`): the same eight the colour pickers offer.
public enum SkillColors {
    public static let palette: [String] = ["5CE1E6", "8B7CFF", "FFB020", "FF7AB6", "34D399", "FF6B6B", "5AA7FF", "D58CFF"]

    /// A random palette colour, preferring one not in `taken` (the colours the board's other groups or types wear).
    /// When every colour is taken any palette colour may come up.
    public static func random(avoiding taken: [String] = [], using generator: inout some RandomNumberGenerator) -> String {
        let used = Set(taken.compactMap(normalizedHex))
        let free = palette.filter { !used.contains($0) }
        return (free.isEmpty ? palette : free).randomElement(using: &generator) ?? palette[0]
    }

    public static func random(avoiding taken: [String] = []) -> String {
        var generator = SystemRandomNumberGenerator()
        return random(avoiding: taken, using: &generator)
    }

    /// A user colour as stored: `#` stripped, uppercased, `RGB` expanded to `RRGGBB`; nil when it is not a colour.
    public static func normalizedHex(_ value: String?) -> String? {
        guard var hex = value?.trimmingCharacters(in: .whitespacesAndNewlines), !hex.isEmpty else { return nil }
        if hex.hasPrefix("#") { hex.removeFirst() }
        hex = hex.uppercased()
        if hex.count == 3 { hex = hex.map { "\($0)\($0)" }.joined() }
        guard hex.count == 6 || hex.count == 8, hex.allSatisfy(\.isHexDigit) else { return nil }
        return hex
    }
}

/// The "move to the top / bottom" rule of types applied to the order pages are shown in: top types first, bottom
/// types last, everything else in between, each part in its own order. Only the display changes; nothing is stored.
public enum SkillTypeOrdering {
    public static func rank(of rule: SkillTypeSortRule?) -> Int {
        guard let rule else { return 1 }
        switch rule {
        case .top: return 0
        case .bottom: return 2
        case .none: return 1
        }
    }

    /// `items` reordered by the rules of the types they wear (`typeID(item)` looked up in `types`, keyed by type id).
    /// Stable: items of the same rank keep their relative order.
    public static func ordered<Item>(_ items: [Item], types: [String: SkillType], typeID: (Item) -> String?) -> [Item] {
        guard !types.isEmpty else { return items }
        let ranks = items.map { item in rank(of: typeID(item).flatMap { types[$0] }?.sortRule) }
        guard ranks.contains(where: { $0 != 1 }) else { return items }
        return zip(items, ranks).enumerated()
            .sorted { lhs, rhs in
                lhs.element.1 == rhs.element.1 ? lhs.offset < rhs.offset : lhs.element.1 < rhs.element.1
            }
            .map(\.element.0)
    }
}
