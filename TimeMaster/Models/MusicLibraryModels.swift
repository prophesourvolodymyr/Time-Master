import Foundation

enum MusicProvider: String, Codable, CaseIterable, Hashable, Identifiable {
    case local, spotify, youtubeMusic, soundCloud, dropbox, googleDrive
    var id: String { rawValue }
    var displayName: String {
        switch self {
        case .local: return "Local"
        case .spotify: return "Spotify"
        case .youtubeMusic: return "YouTube Music"
        case .soundCloud: return "SoundCloud"
        case .dropbox: return "Dropbox"
        case .googleDrive: return "Google Drive"
        }
    }
    static let youtube: MusicProvider = .youtubeMusic
    static let soundcloud: MusicProvider = .soundCloud
    static let drive: MusicProvider = .googleDrive
}

struct MusicLocalTrackReference: Codable, Hashable, Identifiable {
    var filename: String
    var displayName: String
    var bookmarkData: Data?
    var duration: TimeInterval?
    var id: String { filename }
    var localFilename: String { get { filename } set { filename = newValue } }

    init(filename: String, displayName: String? = nil, bookmarkData: Data? = nil, duration: TimeInterval? = nil) {
        self.filename = filename
        self.displayName = displayName ?? Self.defaultDisplayName(for: filename)
        self.bookmarkData = bookmarkData
        self.duration = duration
    }
    init(id: String, filename: String? = nil, displayName: String? = nil, bookmarkData: Data? = nil, duration: TimeInterval? = nil) {
        self.init(filename: filename ?? id, displayName: displayName, bookmarkData: bookmarkData, duration: duration)
    }
    static func defaultDisplayName(for filename: String) -> String {
        let basename = URL(fileURLWithPath: filename).deletingPathExtension().lastPathComponent
        guard let separator = basename.firstIndex(of: "_") else { return basename }
        let suffix = basename.index(after: separator)
        return suffix < basename.endIndex ? String(basename[suffix...]) : basename
    }
}

struct MusicProviderReference: Codable, Hashable, Identifiable {
    var provider: MusicProvider
    var identifier: String
    var title: String?
    var metadata: [String: String]
    var id: String { "\(provider.rawValue):\(identifier)" }
    var referenceID: String { get { identifier } set { identifier = newValue } }
    init(provider: MusicProvider, identifier: String, title: String? = nil, metadata: [String: String] = [:]) {
        self.provider = provider; self.identifier = identifier; self.title = title; self.metadata = metadata
    }
    init(provider: MusicProvider, id: String, title: String? = nil, metadata: [String: String] = [:]) {
        self.init(provider: provider, identifier: id, title: title, metadata: metadata)
    }
}

enum MusicSourceReference: Codable, Hashable {
    case none
    case local
    case provider(MusicProviderReference)
    var provider: MusicProvider? {
        switch self { case .none: return nil; case .local: return .local; case .provider(let ref): return ref.provider }
    }
    var referenceID: String? { if case .provider(let ref) = self { return ref.identifier }; return nil }
    var providerReference: MusicProviderReference? { if case .provider(let ref) = self { return ref }; return nil }
    static func provider(provider: MusicProvider, id: String, title: String? = nil, metadata: [String: String] = [:]) -> MusicSourceReference {
        .provider(MusicProviderReference(provider: provider, identifier: id, title: title, metadata: metadata))
    }
    private enum CodingKeys: String, CodingKey { case kind, provider, identifier, title, metadata }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        switch try c.decodeIfPresent(String.self, forKey: .kind) {
        case "local": self = .local
        case "provider":
            self = .provider(MusicProviderReference(provider: try c.decode(MusicProvider.self, forKey: .provider), identifier: try c.decode(String.self, forKey: .identifier), title: try c.decodeIfPresent(String.self, forKey: .title), metadata: try c.decodeIfPresent([String: String].self, forKey: .metadata) ?? [:]))
        default: self = .none
        }
    }
    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .none: try c.encode("none", forKey: .kind)
        case .local: try c.encode("local", forKey: .kind)
        case .provider(let ref):
            try c.encode("provider", forKey: .kind); try c.encode(ref.provider, forKey: .provider); try c.encode(ref.identifier, forKey: .identifier); try c.encodeIfPresent(ref.title, forKey: .title); try c.encode(ref.metadata, forKey: .metadata)
        }
    }
}

struct MusicArtworkReference: Codable, Hashable {
    var localFilename: String?
    var remoteURL: URL?
    var placeholderSystemImage: String?
    init(localFilename: String? = nil, remoteURL: URL? = nil, placeholderSystemImage: String? = nil) { self.localFilename = localFilename; self.remoteURL = remoteURL; self.placeholderSystemImage = placeholderSystemImage }
    var url: URL? { get { remoteURL } set { remoteURL = newValue } }
    var localFileName: String? { get { localFilename } set { localFilename = newValue } }
}
typealias ArtworkReference = MusicArtworkReference

enum MusicCollectionKind: String, Codable, CaseIterable, Hashable, Identifiable {
    case track, playlist, album, library, folder
    var id: String { rawValue }
    var isCollection: Bool { self != .track }
    static let music: MusicCollectionKind = .track
}

struct MusicCollectionTrack: Codable, Hashable, Identifiable {
    var id: UUID
    var name: String
    var duration: TimeInterval
    var source: MusicSourceReference?
    var localReference: MusicLocalTrackReference?
    var artwork: MusicArtworkReference?
    var title: String { get { name } set { name = newValue } }
    var durationSeconds: Int { max(0, Int(duration.rounded())) }
    init(id: UUID = UUID(), name: String, duration: TimeInterval = 0, source: MusicSourceReference? = nil, localReference: MusicLocalTrackReference? = nil, artwork: MusicArtworkReference? = nil) {
        self.id = id; self.name = name; self.duration = max(0, duration); self.source = source; self.localReference = localReference; self.artwork = artwork
    }
    init(id: UUID = UUID(), title: String, duration: TimeInterval = 0, source: MusicSourceReference? = nil, localReference: MusicLocalTrackReference? = nil, artwork: MusicArtworkReference? = nil) {
        self.init(id: id, name: title, duration: duration, source: source, localReference: localReference, artwork: artwork)
    }
}

struct MusicLibraryItem: Codable, Hashable, Identifiable {
    var id: UUID
    var name: String
    var kind: MusicCollectionKind
    var source: MusicSourceReference
    var localReference: MusicLocalTrackReference?
    var artwork: MusicArtworkReference?
    var duration: TimeInterval
    var tracks: [MusicCollectionTrack]
    var metadata: [String: String]
    var title: String { get { name } set { name = newValue } }
    var artworkReference: MusicArtworkReference? { get { artwork } set { artwork = newValue } }
    var localTrackReference: MusicLocalTrackReference? { get { localReference } set { localReference = newValue } }
    var stableID: UUID { id }
    var isCollection: Bool { kind.isCollection }
    var durationSeconds: Int { max(0, Int(totalDuration.rounded())) }
    var totalDuration: TimeInterval { duration > 0 ? duration : tracks.reduce(0) { $0 + $1.duration } }
    init(id: UUID = UUID(), name: String, kind: MusicCollectionKind = .track, source: MusicSourceReference = .none, localReference: MusicLocalTrackReference? = nil, artwork: MusicArtworkReference? = nil, duration: TimeInterval = 0, tracks: [MusicCollectionTrack] = [], metadata: [String: String] = [:]) {
        self.id = id; self.name = name; self.kind = kind; self.localReference = localReference; self.source = source == .none && localReference != nil ? .local : source; self.artwork = artwork; self.duration = max(0, duration); self.tracks = tracks; self.metadata = metadata
    }
    init(id: UUID = UUID(), title: String, kind: MusicCollectionKind = .track, source: MusicSourceReference = .none, localReference: MusicLocalTrackReference? = nil, artwork: MusicArtworkReference? = nil, duration: TimeInterval = 0, tracks: [MusicCollectionTrack] = [], metadata: [String: String] = [:]) {
        self.init(id: id, name: title, kind: kind, source: source, localReference: localReference, artwork: artwork, duration: duration, tracks: tracks, metadata: metadata)
    }
    func containsTrack(matching query: String) -> [MusicCollectionTrack] {
        let q = query.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
        return q.isEmpty ? [] : tracks.filter { $0.name.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current).contains(q) }
    }
}

enum MusicDestinationFamily: String, Codable, CaseIterable, Hashable, Identifiable {
    case general, type, mine, route
    var id: String { rawValue }
    static let workoutType: MusicDestinationFamily = .type
    static let workout: MusicDestinationFamily = .mine
}

enum MusicRouteDestination: String, Codable, CaseIterable, Hashable, Identifiable {
    case run, bike, walk, more
    var id: String { rawValue }
    var displayName: String {
        switch self {
        case .run: return "Run"
        case .bike: return "Bike"
        case .walk: return "Walk"
        case .more: return "More"
        }
    }
}

enum MusicDestination: Codable, Hashable, Identifiable {
    case general
    case workoutType(id: String)
    case workout(id: UUID)
    private static let routePrefix = "route."
    var id: String {
        switch self {
        case .general: return "general"
        case .workoutType(let value): return "type:\(value)"
        case .workout(let value): return "workout:\(value.uuidString.lowercased())"
        }
    }
    var stableID: String { id }
    var family: MusicDestinationFamily {
        switch self {
        case .general: return .general
        case .workoutType(let id): return id.hasPrefix(Self.routePrefix) ? .route : .type
        case .workout: return .mine
        }
    }
    static func type(_ id: String) -> MusicDestination { .workoutType(id: id) }
    static func mine(_ id: UUID) -> MusicDestination { .workout(id: id) }
    static func route(_ destination: MusicRouteDestination) -> MusicDestination {
        .workoutType(id: "\(routePrefix)\(destination.rawValue)")
    }
    static func route(id destination: MusicRouteDestination) -> MusicDestination { route(destination) }
    static func route(id: String) -> MusicDestination { route(id) }
    static func route(_ id: String) -> MusicDestination {
        .workoutType(id: "\(routePrefix)\(id.lowercased())")
    }
    static let run = route(.run)
    static let bike = route(.bike)
    static let walk = route(.walk)
    static let more = route(.more)
    var routeDestination: MusicRouteDestination? {
        guard case .workoutType(let id) = self,
              let value = id.split(separator: ".", maxSplits: 1).last,
              id.hasPrefix(Self.routePrefix) else { return nil }
        return MusicRouteDestination(rawValue: String(value))
    }
    private enum CodingKeys: String, CodingKey { case kind, value }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        switch try c.decode(String.self, forKey: .kind) {
        case "type":
            self = .workoutType(id: try c.decode(String.self, forKey: .value))
        case "route":
            self = .route(try c.decode(String.self, forKey: .value))
        case "workout":
            self = .workout(id: try c.decode(UUID.self, forKey: .value))
        default:
            self = .general
        }
    }
    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .general:
            try c.encode("general", forKey: .kind)
        case .workoutType(let id):
            if let routeDestination {
                try c.encode("route", forKey: .kind)
                try c.encode(routeDestination.rawValue, forKey: .value)
            } else {
                try c.encode("type", forKey: .kind)
                try c.encode(id, forKey: .value)
            }
        case .workout(let id):
            try c.encode("workout", forKey: .kind)
            try c.encode(id, forKey: .value)
        }
    }
}

struct MusicSessionImportReference: Hashable, Identifiable {
    var id: UUID
    var itemID: UUID
    var source: MusicDestination
    var destination: MusicDestination
    var insertionIndex: Int?
    init(id: UUID = UUID(), itemID: UUID, source: MusicDestination, destination: MusicDestination, insertionIndex: Int? = nil) {
        self.id = id
        self.itemID = itemID
        self.source = source
        self.destination = destination
        self.insertionIndex = insertionIndex
    }
}

struct MusicPlaybackTrack: Hashable, Identifiable {
    var id: String
    var title: String
    var artist: String?
    var artworkReference: String?
    var localFilename: String?
    init(id: String, title: String, artist: String? = nil, artworkReference: String? = nil, localFilename: String? = nil) {
        self.id = id
        self.title = title
        self.artist = artist
        self.artworkReference = artworkReference
        self.localFilename = localFilename
    }
}

struct MusicTransfer: Codable, Hashable, Identifiable {
    var id: UUID
    var itemID: UUID
    var source: MusicDestination
    var destination: MusicDestination
    var insertionIndex: Int?
    init(id: UUID = UUID(), itemID: UUID, source: MusicDestination, destination: MusicDestination, insertionIndex: Int? = nil) { self.id = id; self.itemID = itemID; self.source = source; self.destination = destination; self.insertionIndex = insertionIndex }
}
enum MusicTransferChoice: String, Codable, CaseIterable, Hashable { case move, duplicate, cancel }
typealias MusicTransferDecision = MusicTransferChoice

struct MusicLibrarySearchResult: Identifiable, Hashable {
    var item: MusicLibraryItem
    var destination: MusicDestination
    var matchingTrackIDs: [UUID]
    var matchesFolder: Bool
    var id: String { "\(destination.id):\(item.id.uuidString.lowercased())" }
    var matchingTracks: [MusicCollectionTrack] { item.tracks.filter { matchingTrackIDs.contains($0.id) } }
}
