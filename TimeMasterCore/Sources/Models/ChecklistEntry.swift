import Foundation

/// The two lists a skill or tutorial page keeps: its to-dos and its milestones.
public enum ChecklistKind: String, CaseIterable, Sendable {
    case todo
    case milestone

    public var noun: String { self == .todo ? "to-do" : "milestone" }
    public var plural: String { self == .todo ? "to-dos" : "milestones" }
}

/// Why a change to a to-do list or the milestones was refused, in plain words.
public enum ChecklistError: Error, LocalizedError, Equatable {
    case invalid(String)
    case notFound(String)

    public var errorDescription: String? {
        switch self {
        case .invalid(let message), .notFound(let message): return message
        }
    }
}

/// What a to-do (`TodoItem`) and a milestone (`Milestone`) share. Both lists are trees: an entry can hold entries of
/// its own. Checking an entry checks everything under it; opening one under a checked parent opens the parent again,
/// so a checked entry never has an open one below it.
///
/// Either list can also hold section dividers (`isSection`): an entry with only a title (and optionally an icon and a
/// colour) that splits the list into named parts. A section stays at the top level, holds nothing, is never checked
/// and does not count in progress; the entries after it, up to the next section, are its part.
///
/// Pictures are references to the page's own media (`mediaFilenames`), so Device Sync, backups and the trash carry
/// them with the page; removing a file from the page takes every reference to it away.
public protocol ChecklistEntry: Codable, Hashable, Identifiable, Sendable where ID == String {
    static var kind: ChecklistKind { get }
    /// Levels of nesting a list can have.
    static var maxDepth: Int { get }
    /// Entries on one page, all levels and sections together.
    static var maxPerPage: Int { get }
    static var maxTitleLength: Int { get }
    static var maxNoteLength: Int { get }
    static var maxLinks: Int { get }
    /// Pictures in an entry's strip.
    static var maxImages: Int { get }
    /// Where a page keeps this list.
    static var pageList: WritableKeyPath<ExercisePageManifest, [Self]> { get }

    /// A new open entry with nothing but a title.
    static func blank(id: String, title: String) -> Self

    var id: String { get set }
    var title: String { get set }
    /// A few lines about it. Plain text; line breaks are kept.
    var note: String { get set }
    var isDone: Bool { get set }
    var doneAt: Date? { get set }
    var isSection: Bool { get set }
    /// An SF Symbol name or an emoji, drawn as `iconType` says.
    var iconName: String? { get set }
    var iconType: SkillBoardIconType? { get set }
    /// A picture icon: one of the page's media files or an http(s) image address. Wins over `iconName`.
    var iconImage: String? { get set }
    /// `RRGGBB`: tints the icon and the card. Nil = the app's accent.
    var colorHex: String? { get set }
    /// One of the page's media files, drawn as the entry's cover.
    var coverMediaFilename: String? { get set }
    /// Some of the page's media files, drawn as a small strip.
    var imageFilenames: [String] { get set }
    /// Workouts, pages, files of the page and web addresses (`TmaxLink`), drawn as chips.
    var links: [TodoLink] { get set }
    var children: [Self] { get set }
    var createdAt: Date { get set }
}

extension ChecklistEntry {
    public static func newID() -> String { UUID().uuidString }

    /// This entry's id and every id under it.
    public var flattenedIDs: Set<String> {
        var ids: Set<String> = [id]
        for child in children { ids.formUnion(child.flattenedIDs) }
        return ids
    }

    /// The link whose target lends its picture to an entry without a cover or an icon of its own: the first workout
    /// or page link, in order. An explicit cover or icon always wins (see `derivesCover`, `derivesIcon`).
    public var visualLink: TmaxLink? {
        links.lazy.compactMap(\.target).first { $0.providesVisual }
    }

    /// True when the cover is drawn from `visualLink`'s target.
    public var derivesCover: Bool { coverMediaFilename == nil && visualLink != nil }

    /// True when the icon is drawn from `visualLink`'s target.
    public var derivesIcon: Bool { iconName == nil && iconImage == nil && visualLink != nil }

    /// Every media file of the page the entry points at: its cover, picture icon, strip and file links.
    public var mediaReferences: Set<String> {
        var names = Set(imageFilenames)
        if let coverMediaFilename { names.insert(coverMediaFilename) }
        if let iconImage { names.insert(iconImage) }
        for link in links { if let name = link.target?.mediaFilename { names.insert(name) } }
        return names
    }

    /// The entry with every reference to `filename` taken off (the file is leaving the page).
    func droppingMedia(_ filename: String) -> Self {
        var copy = self
        if copy.coverMediaFilename == filename { copy.coverMediaFilename = nil }
        if copy.iconImage == filename { copy.iconImage = nil }
        copy.imageFilenames.removeAll { $0 == filename }
        copy.links.removeAll { $0.target?.mediaFilename == filename }
        copy.children = copy.children.map { $0.droppingMedia(filename) }
        return copy
    }
}

// MARK: - The list as a tree

/// One named part of a list: the entries between a section and the next one (`section` nil = before the first).
public struct ChecklistPart<Entry: ChecklistEntry>: Identifiable {
    public let section: Entry?
    public let entries: [Entry]

    public var id: String { section?.id ?? "checklist.lead" }
}

extension Array where Element: ChecklistEntry {
    /// Every entry with its depth (1 = top level), parents before their children, in list order. Sections included.
    public func flattened() -> [(item: Element, depth: Int)] {
        var result: [(item: Element, depth: Int)] = []
        func walk(_ items: [Element], depth: Int) {
            for item in items {
                result.append((item, depth))
                walk(item.children, depth: depth + 1)
            }
        }
        walk(self, depth: 1)
        return result
    }

    /// Entries that count, at every level (sections do not).
    public var progressTotal: Int { flattened().filter { !$0.item.isSection }.count }
    /// Checked entries at every level.
    public var progressDone: Int { flattened().filter { !$0.item.isSection && $0.item.isDone }.count }
    /// Entries still open, at every level.
    public var openCount: Int { progressTotal - progressDone }
    /// The share checked off, 0…1 (0 without any).
    public var progressFraction: Double { progressTotal == 0 ? 0 : Double(progressDone) / Double(progressTotal) }

    public func entry(_ id: String) -> Element? {
        for item in self {
            if item.id == id { return item }
            if let found = item.children.entry(id) { return found }
        }
        return nil
    }

    /// Depth of an entry (1 = top level); nil when there is none with that id.
    public func depth(of id: String) -> Int? {
        flattened().first { $0.item.id == id }?.depth
    }

    /// The id of the entry that holds `id` (nil at the top level or when `id` is not in the list).
    public func parentID(of id: String) -> String? {
        for (item, _) in flattened() where item.children.contains(where: { $0.id == id }) { return item.id }
        return nil
    }

    /// The entries on the same level as `id`, itself included (the top level for an unknown id).
    public func siblings(of id: String) -> [Element] {
        parentID(of: id).flatMap { entry($0)?.children } ?? self
    }

    /// Levels `item` and everything under it takes (1 for an entry without children).
    public static func height(of item: Element) -> Int { 1 + (item.children.map { height(of: $0) }.max() ?? 0) }

    /// Changes the entry with `id` in place; false when there is none.
    @discardableResult
    public mutating func mutateEntry(_ id: String, _ change: (inout Element) throws -> Void) rethrows -> Bool {
        for index in indices {
            if self[index].id == id {
                try change(&self[index])
                return true
            }
            if try self[index].children.mutateEntry(id, change) { return true }
        }
        return false
    }

    /// Takes the entry with `id` out of the list (with everything under it).
    public mutating func removeEntry(_ id: String) -> Element? {
        if let index = firstIndex(where: { $0.id == id }) { return remove(at: index) }
        for index in indices {
            if let removed = self[index].children.removeEntry(id) { return removed }
        }
        return nil
    }

    /// Puts `item` under the entry `parentID` (top level when nil) at `index` (the end when nil or too big).
    /// False when `parentID` is not in the list.
    @discardableResult
    public mutating func insertEntry(_ item: Element, under parentID: String?, at index: Int? = nil) -> Bool {
        guard let parentID else {
            insert(item, at: Swift.min(Swift.max(0, index ?? count), count))
            return true
        }
        return mutateEntry(parentID) { parent in
            parent.children.insert(item, at: Swift.min(Swift.max(0, index ?? parent.children.count), parent.children.count))
        }
    }

    /// The top-level index where the part of `sectionID` ends: the place of the next section, or the end of the list.
    /// `sectionID` nil is the part before the first section.
    public func partEnd(of sectionID: String?) -> Int {
        let start: Int
        if let sectionID {
            guard let position = firstIndex(where: { $0.id == sectionID }) else { return count }
            start = position + 1
        } else {
            start = 0
        }
        return self[start...].firstIndex(where: \.isSection) ?? count
    }

    /// The section whose part holds the top-level entry `id` (nil before the first section or for a nested entry).
    public func section(holding id: String) -> Element? {
        guard let position = firstIndex(where: { $0.id == id }) else { return nil }
        return self[..<position].last(where: \.isSection)
    }

    /// The list cut at its sections: the entries before the first section, then each section with the entries after
    /// it. A list without sections is one part.
    public var parts: [ChecklistPart<Element>] {
        var result: [ChecklistPart<Element>] = []
        var section: Element?
        var entries: [Element] = []
        for item in self {
            if item.isSection {
                if section != nil || !entries.isEmpty { result.append(ChecklistPart(section: section, entries: entries)) }
                section = item
                entries = []
            } else {
                entries.append(item)
            }
        }
        if section != nil || !entries.isEmpty { result.append(ChecklistPart(section: section, entries: entries)) }
        return result
    }

    /// The list with every reference to the media file `filename` taken off.
    public func droppingMedia(_ filename: String) -> [Element] {
        map { $0.droppingMedia(filename) }
    }

    /// Every link with the entry that carries it, in list order.
    public var allLinks: [(entry: Element, link: TodoLink)] {
        flattened().flatMap { pair in pair.item.links.map { (pair.item, $0) } }
    }
}

// MARK: - Rules

extension ChecklistEntry {
    /// The list as it is saved. Titles are one trimmed line, notes trimmed, ids unique, at most `maxDepth` levels and
    /// `maxPerPage` entries, colours `RRGGBB`, links readable (`TmaxLink`), pictures only while they are media of the
    /// page (`mediaFilenames`), sections at the top level and empty, and a checked entry never has an open one below
    /// it. Throws for what it will not guess (an empty title, a nested section, too many of something).
    public static func normalized(_ items: [Self], mediaFilenames media: Set<String>, now: Date = Date()) throws -> [Self] {
        var seen = Set<String>()
        var total = 0
        func clean(_ source: Self, depth: Int) throws -> Self {
            guard depth <= maxDepth else {
                throw ChecklistError.invalid("\(kind.plural.capitalizedFirst) nest up to \(maxDepth) levels.")
            }
            total += 1
            guard total <= maxPerPage else {
                throw ChecklistError.invalid("A page holds up to \(maxPerPage) \(kind.plural) and sections.")
            }
            var item = source
            guard !item.id.isEmpty, seen.insert(item.id).inserted else {
                throw ChecklistError.invalid("The \(kind.noun) id \(item.id) is used twice.")
            }
            item.title = oneLine(item.title)
            guard !item.title.isEmpty else {
                throw ChecklistError.invalid(item.isSection ? "A section needs a title." : "A \(kind.noun) needs a title.")
            }
            guard item.title.count <= maxTitleLength else {
                throw ChecklistError.invalid("A \(kind.noun) title holds up to \(maxTitleLength) characters; put the rest in its note.")
            }
            item.note = cleanedNote(item.note)
            guard item.note.count <= maxNoteLength else {
                throw ChecklistError.invalid("A \(kind.noun) note holds up to \(maxNoteLength) characters.")
            }
            item.iconName = item.iconName?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
            item.iconType = item.iconName == nil ? nil : item.iconType ?? SkillBoardIconType.inferred(from: item.iconName ?? "")
            item.iconImage = item.iconImage?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
            if let picture = item.iconImage, !isWebImage(picture), !(media.contains(picture) && ChecklistMedia.isPicture(picture)) {
                item.iconImage = nil
            }
            if let raw = item.colorHex?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty {
                guard let hex = SkillColors.normalizedHex(raw) else {
                    throw ChecklistError.invalid("“\(raw)” is not a colour. Use six hex digits, like FF6A00.")
                }
                item.colorHex = hex
            } else {
                item.colorHex = nil
            }
            if let cover = item.coverMediaFilename, !media.contains(cover) || !ChecklistMedia.isPicture(cover) {
                item.coverMediaFilename = nil
            }
            item.imageFilenames = item.imageFilenames.uniqued().filter { media.contains($0) && ChecklistMedia.isPicture($0) }
            guard item.imageFilenames.count <= maxImages else {
                throw ChecklistError.invalid("A \(kind.noun) shows up to \(maxImages) pictures.")
            }
            item.links = try cleanedLinks(item.links, media: media)
            if item.isSection {
                guard depth == 1 else {
                    throw ChecklistError.invalid("A section stays at the top level; it cannot go inside a \(kind.noun).")
                }
                guard item.children.isEmpty else {
                    throw ChecklistError.invalid("A section holds no \(kind.plural) of its own; put them after it.")
                }
                item.note = ""
                item.isDone = false
                item.coverMediaFilename = nil
                item.iconImage = nil
                item.imageFilenames = []
                item.links = []
            }
            item.children = try item.children.map { try clean($0, depth: depth + 1) }
            if item.children.contains(where: { !$0.isSection && !$0.isDone }) { item.isDone = false }
            if item.isDone {
                if item.doneAt == nil { item.doneAt = now }
            } else {
                item.doneAt = nil
            }
            return item
        }
        return try items.map { try clean($0, depth: 1) }
    }

    /// The list with what `normalized` refuses fixed instead of refused: entries without a title lose their line
    /// (what is under them moves up a level), repeated ids get new ones, levels and counts past the limits are cut,
    /// text is shortened, links that are not links and pictures the page no longer has are dropped, a nested section
    /// becomes an ordinary entry and a section's children follow it. Then the usual tidying. What a merge from Device
    /// Sync, an older build or a hand-edited file goes through.
    public static func repaired(_ items: [Self], mediaFilenames media: Set<String>, now: Date = Date()) -> [Self] {
        var seen = Set<String>()
        var total = 0
        func fix(_ source: [Self], depth: Int) -> [Self] {
            var result: [Self] = []
            for var item in source {
                let title = oneLine(item.title)
                if title.isEmpty {
                    result.append(contentsOf: fix(item.children, depth: depth))
                    continue
                }
                guard total < maxPerPage else { break }
                total += 1
                item.title = String(title.prefix(maxTitleLength))
                if item.id.isEmpty || !seen.insert(item.id).inserted {
                    item.id = newID()
                    seen.insert(item.id)
                }
                item.note = String(cleanedNote(item.note).prefix(maxNoteLength))
                item.colorHex = SkillColors.normalizedHex(item.colorHex)
                item.imageFilenames = Array(item.imageFilenames.uniqued().filter { media.contains($0) && ChecklistMedia.isPicture($0) }.prefix(maxImages))
                item.links = Array(repairedLinks(item.links, media: media).prefix(maxLinks))
                if item.isSection {
                    if depth > 1 {
                        item.isSection = false
                    } else {
                        let lifted = fix(item.children, depth: depth)
                        item.children = []
                        result.append(item)
                        result.append(contentsOf: lifted)
                        continue
                    }
                }
                if depth >= maxDepth {
                    let deeper = fix(item.children, depth: depth)
                    item.children = []
                    result.append(item)
                    result.append(contentsOf: deeper)
                } else {
                    item.children = fix(item.children, depth: depth + 1)
                    result.append(item)
                }
            }
            return result
        }
        let fixed = fix(items, depth: 1)
        return (try? normalized(fixed, mediaFilenames: media, now: now)) ?? fixed
    }

    /// Links as they are saved: readable item targets in their canonical form, a file link only while the page holds
    /// the file, one link per address, ids unique, at most `maxLinks`.
    static func cleanedLinks(_ links: [TodoLink], media: Set<String>) throws -> [TodoLink] {
        var ids = Set<String>()
        var urls = Set<String>()
        var result: [TodoLink] = []
        for source in links {
            var link = source
            let text = link.url.trimmingCharacters(in: .whitespacesAndNewlines)
            guard let target = TmaxLink(text), target.isItemTarget else {
                throw ChecklistError.invalid("“\(text)” is not a link Tmax can open. Use an http(s) address, timemaster://workout/<id>, timemaster://page/<id> or timemaster://media/<file>.")
            }
            if let name = target.mediaFilename, !media.contains(name) { continue }
            link.url = target.urlString
            guard urls.insert(link.url).inserted else { continue }
            link.label = link.label?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
            if link.id.isEmpty || !ids.insert(link.id).inserted {
                link.id = newID()
                ids.insert(link.id)
            }
            result.append(link)
        }
        guard result.count <= maxLinks else {
            throw ChecklistError.invalid("A \(kind.noun) holds up to \(maxLinks) links.")
        }
        return result
    }

    static func repairedLinks(_ links: [TodoLink], media: Set<String>) -> [TodoLink] {
        links.compactMap { link in
            guard let target = TmaxLink(link.url), target.isItemTarget else { return nil }
            if let name = target.mediaFilename, !media.contains(name) { return nil }
            return link
        }
    }

    static func oneLine(_ text: String) -> String {
        text.replacingOccurrences(of: "\r", with: " ").replacingOccurrences(of: "\n", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func cleanedNote(_ text: String) -> String {
        text.replacingOccurrences(of: "\r\n", with: "\n").replacingOccurrences(of: "\r", with: "\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func isWebImage(_ value: String) -> Bool {
        guard let url = URL(string: value), let scheme = url.scheme?.lowercased() else { return false }
        return (scheme == "https" || scheme == "http") && url.host != nil
    }

    /// Checks an entry and everything under it (sections stay unchecked).
    static func markDone(_ item: inout Self, at date: Date) {
        guard !item.isSection else { return }
        item.isDone = true
        if item.doneAt == nil { item.doneAt = date }
        for index in item.children.indices { markDone(&item.children[index], at: date) }
    }
}

extension SkillBoardIconType {
    /// Guesses how a user-given icon is drawn: emoji scalars and no ASCII is an emoji, anything else an SF Symbol.
    public static func inferred(from value: String) -> SkillBoardIconType {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        let hasASCII = trimmed.unicodeScalars.contains { $0.isASCII }
        let hasEmoji = trimmed.unicodeScalars.contains { $0.properties.isEmojiPresentation || ($0.properties.isEmoji && $0.value > 0x2000) }
        return hasEmoji && !hasASCII ? .emoji : .system
    }

    /// Reads an icon type written by Tmax (`emoji`, `system`) or by Skillmax (`symbol`, `nerd`); nil for anything else.
    static func lenient(_ raw: String?) -> SkillBoardIconType? {
        switch raw?.lowercased() {
        case "emoji": return .emoji
        case "system", "symbol", "sfsymbol", "nerd": return .system
        default: return nil
        }
    }
}

/// Which media files a cover, an icon or a picture strip can show.
public enum ChecklistMedia {
    public static let pictureExtensions: Set<String> = ["jpg", "jpeg", "png", "heic", "heif", "gif", "webp", "tif", "tiff", "bmp"]

    /// True for a file name a cover, an icon or a strip can show.
    public static func isPicture(_ name: String) -> Bool {
        pictureExtensions.contains((name as NSString).pathExtension.lowercased())
    }
}

// MARK: - Coding support

extension KeyedDecodingContainer {
    /// An array decoded element by element: a malformed element is dropped instead of failing the whole list.
    func lenientList<T: Decodable>(_ type: T.Type, _ key: Key) -> [T] {
        guard contains(key) else { return [] }
        let elements = (try? decodeIfPresent([ChecklistLenientElement<T>].self, forKey: key)) ?? nil
        return (elements ?? []).compactMap(\.value)
    }
}

private struct ChecklistLenientElement<T: Decodable>: Decodable {
    let value: T?

    init(from decoder: Decoder) throws {
        value = try? T(from: decoder)
    }
}

fileprivate extension String {
    var nilIfEmpty: String? { isEmpty ? nil : self }
    var capitalizedFirst: String { prefix(1).uppercased() + dropFirst() }
}
