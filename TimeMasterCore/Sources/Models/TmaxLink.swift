import Foundation

/// A link into the library or the web, written as a URL so the same text works on a to-do or a milestone, in a note,
/// on the command line and as a deep link that opens the app:
///
///     timemaster://workout/<workout id>          a workout (its detail opens)
///     timemaster://page/<page id>                a database page, or a group (`<page id>~<section id>`)
///     timemaster://media/<file name>             a media file of the page that holds the link
///     timemaster://start?workoutID=<workout id>  starts a workout (without an id: today's)
///     timemaster://detail?workoutID=<id>         a workout, the older form of `workout/<id>`
///     https://…                                  the web
///
/// The app's deep-link handler reads URLs with this type too, so a link written here always opens the same thing.
public enum TmaxLink: Equatable, Hashable, Sendable {
    case workout(id: String)
    case page(id: String)
    case media(filename: String)
    case web(String)
    case start(workoutID: String?)

    public static let scheme = "timemaster"

    /// Reads a link; nil for anything that is not one (other schemes, unknown hosts, an id that cannot be one).
    public init?(_ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let components = URLComponents(string: trimmed), let scheme = components.scheme?.lowercased() else { return nil }
        switch scheme {
        case "http", "https":
            guard let host = components.host, !host.isEmpty else { return nil }
            self = .web(trimmed)
        case Self.scheme:
            let path = components.path.split(separator: "/", omittingEmptySubsequences: true).map(String.init)
            let workoutQuery = components.queryItems?.first { $0.name == "workoutID" }?.value
            switch components.host?.lowercased() ?? "" {
            case "workout":
                guard path.count == 1, let id = Self.workoutID(path[0]) else { return nil }
                self = .workout(id: id)
            case "detail":
                guard let id = workoutQuery.flatMap(Self.workoutID) else { return nil }
                self = .workout(id: id)
            case "start":
                self = .start(workoutID: workoutQuery.flatMap(Self.workoutID))
            case "page":
                guard path.count == 1, let id = Self.pageID(path[0]) else { return nil }
                self = .page(id: id)
            case "media":
                guard path.count == 1, Self.isSafeName(path[0]) else { return nil }
                self = .media(filename: path[0])
            default:
                return nil
            }
        default:
            return nil
        }
    }

    public init?(url: URL) {
        self.init(url.absoluteString)
    }

    /// The URL text of the link.
    public var urlString: String {
        switch self {
        case .workout(let id): return Self.workoutURL(id: id)
        case .page(let id): return Self.pageURL(id: id)
        case .media(let filename): return Self.mediaURL(filename: filename)
        case .web(let url): return url
        case .start(let id): return id.map { "\(Self.scheme)://start?workoutID=\($0)" } ?? "\(Self.scheme)://start"
        }
    }

    public var url: URL? { URL(string: urlString) }

    public static func workoutURL(id: String) -> String { "\(scheme)://workout/\(workoutID(id) ?? id)" }

    public static func pageURL(id: String) -> String { "\(scheme)://page/\(pageID(id) ?? id)" }

    public static func mediaURL(filename: String) -> String {
        var allowed = CharacterSet.urlPathAllowed
        allowed.remove(charactersIn: "/?#")
        return "\(scheme)://media/\(filename.addingPercentEncoding(withAllowedCharacters: allowed) ?? filename)"
    }

    /// What a to-do or a milestone may link to: a workout, a page, a file of its page, or the web. `start` is an
    /// action, not a place.
    public var isItemTarget: Bool {
        if case .start = self { return false }
        return true
    }

    /// A workout or a page: a link whose target has a picture the item can wear when it has none of its own.
    public var providesVisual: Bool {
        switch self {
        case .workout, .page: return true
        default: return false
        }
    }

    public var workoutID: String? {
        if case .workout(let id) = self { return id }
        return nil
    }

    public var pageID: String? {
        if case .page(let id) = self { return id }
        return nil
    }

    public var mediaFilename: String? {
        if case .media(let filename) = self { return filename }
        return nil
    }

    // MARK: Ids

    /// A workout id is a UUID; written upper-case, as workouts are saved.
    static func workoutID(_ text: String) -> String? {
        UUID(uuidString: text.trimmingCharacters(in: .whitespaces))?.uuidString
    }

    /// A page id (upper-case when it is a UUID, as pages are saved) or a group id `<page id>~<section id>`.
    static func pageID(_ text: String) -> String? {
        let value = text.trimmingCharacters(in: .whitespaces)
        if let group = SkillGroupID.split(value) {
            guard let page = pageID(group.containerID), SkillGroupID.isUsableSectionID(group.sectionID) else { return nil }
            return SkillGroupID.make(containerID: page, sectionID: group.sectionID)
        }
        guard isSafeName(value), !value.contains(SkillGroupID.separator) else { return nil }
        return UUID(uuidString: value)?.uuidString ?? value
    }

    static func isSafeName(_ name: String) -> Bool {
        !name.isEmpty && name.utf8.count <= 255 && name != "." && name != ".." && !name.hasPrefix(".")
            && !name.contains("/") && !name.contains("\\")
            && !name.unicodeScalars.contains { CharacterSet.controlCharacters.contains($0) }
    }
}
