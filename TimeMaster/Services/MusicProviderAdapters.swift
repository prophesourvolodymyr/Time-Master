import Foundation
private func musicProviderDisplayName(_ provider: MusicProvider) -> String {
    switch provider {
    case .local:
        return "Local Files"
    case .spotify:
        return "Spotify"
    case .youtubeMusic:
        return "YouTube Music"
    case .soundCloud:
        return "SoundCloud"
    case .dropbox:
        return "Dropbox"
    case .googleDrive:
        return "Google Drive"
    }
}


/// Runtime OAuth configuration supplied by the host app. Secrets and access tokens
/// are deliberately not stored in this value; an eventual official implementation
/// should obtain those through its secure authentication/credential boundary.
struct MusicProviderAdapterConfiguration: Equatable, Sendable {
    let clientIdentifier: String?
    let redirectURI: URL?
    let scopes: Set<String>

    init(
        clientIdentifier: String? = nil,
        redirectURI: URL? = nil,
        scopes: Set<String> = []
    ) {
        self.clientIdentifier = clientIdentifier?.trimmingCharacters(in: .whitespacesAndNewlines)
        self.redirectURI = redirectURI
        self.scopes = scopes
    }

    var isConfigured: Bool {
        guard let clientIdentifier, !clientIdentifier.isEmpty, redirectURI != nil else {
            return false
        }
        return true
    }
}

struct MusicProviderAccount: Equatable {
    let provider: MusicProvider
    let accountIdentifier: String
    let displayName: String
    let emailAddress: String?
    let avatarURL: URL?

    init(
        provider: MusicProvider,
        accountIdentifier: String,
        displayName: String,
        emailAddress: String? = nil,
        avatarURL: URL? = nil
    ) {
        self.provider = provider
        self.accountIdentifier = accountIdentifier
        self.displayName = displayName
        self.emailAddress = emailAddress
        self.avatarURL = avatarURL
    }
}

enum MusicProviderAccountState: Equatable {
    case notConfigured
    case signedOut
    case signedIn(MusicProviderAccount)
}

/// Short errors intended to be presented directly by an import/search sheet.
enum MusicProviderAdapterError: LocalizedError, Equatable {
    case notConfigured(provider: MusicProvider)
    case authenticationRequired(provider: MusicProvider)
    case authenticationUnavailable(provider: MusicProvider)
    case searchUnavailable(provider: MusicProvider)
    case playbackUnavailable(provider: MusicProvider)
    case emptySearchQuery
    case invalidSearchLimit

    var errorDescription: String? {
        switch self {
        case .notConfigured(let provider):
            return "\(musicProviderDisplayName(provider)) is not configured."
        case .authenticationRequired(let provider):
            return "Sign in to \(musicProviderDisplayName(provider)) to continue."
        case .authenticationUnavailable(let provider):
            return "\(musicProviderDisplayName(provider)) sign-in is unavailable."
        case .searchUnavailable(let provider):
            return "\(musicProviderDisplayName(provider)) search is unavailable."
        case .playbackUnavailable(let provider):
            return "\(musicProviderDisplayName(provider)) playback is unavailable."
        case .emptySearchQuery:
            return "Enter a search term."
        case .invalidSearchLimit:
            return "The search request is invalid."
        }
    }
}

enum MusicProviderPlaybackMode: String, Sendable {
    case spotifyAppOrSDK
    case youtubeEmbeddedPlayer
    case soundCloudSupportedStream
}

enum MusicPlaybackCapability: Equatable, Sendable {
    case providerBacked(mode: MusicProviderPlaybackMode)
    case localFileOnly
    case unavailable(MusicProviderAdapterError)
}

struct MusicProviderAdapterCapabilities: Equatable, Sendable {
    let supportsAccount: Bool
    let supportsSearch: Bool
    let supportsFileImport: Bool
    let declaredPlaybackMode: MusicProviderPlaybackMode?

    init(
        supportsAccount: Bool,
        supportsSearch: Bool,
        supportsFileImport: Bool,
        declaredPlaybackMode: MusicProviderPlaybackMode? = nil
    ) {
        self.supportsAccount = supportsAccount
        self.supportsSearch = supportsSearch
        self.supportsFileImport = supportsFileImport
        self.declaredPlaybackMode = declaredPlaybackMode
    }
}

/// A provider result contains metadata only. It never contains downloaded provider
/// audio; the native store can turn an authorized result into a MusicLibraryItem.
struct MusicProviderSearchResult: Identifiable {
    enum Kind: String {
        case track
        case album
        case playlist
        case library
        case file
    }

    let provider: MusicProvider
    let remoteIdentifier: String
    let title: String
    let subtitle: String?
    let kind: Kind
    let duration: TimeInterval?
    let artworkURL: URL?
    let providerURL: URL?
    let metadata: [String: String]

    var id: String {
        musicProviderDisplayName(provider) + ":" + remoteIdentifier
    }

    init(
        provider: MusicProvider,
        remoteIdentifier: String,
        title: String,
        subtitle: String? = nil,
        kind: Kind,
        duration: TimeInterval? = nil,
        artworkURL: URL? = nil,
        providerURL: URL? = nil,
        metadata: [String: String] = [:]
    ) {
        self.provider = provider
        self.remoteIdentifier = remoteIdentifier
        self.title = title
        self.subtitle = subtitle
        self.kind = kind
        self.duration = duration
        self.artworkURL = artworkURL
        self.providerURL = providerURL
        self.metadata = metadata
    }
}

/// Provider-neutral boundary for official OAuth, search, and playback adapters.
///
/// Implementations must check cancellation before doing work and must throw rather
/// than manufacture remote results when credentials or the official integration are
/// unavailable. Local Files deliberately does not conform to this protocol.
protocol MusicProviderAdapter: AnyObject {
    var provider: MusicProvider { get }
    var displayName: String { get }
    var capabilities: MusicProviderAdapterCapabilities { get }
    var accountState: MusicProviderAccountState { get }

    func authenticate() async throws -> MusicProviderAccountState
    func signOut() async throws
    func search(query: String, limit: Int) async throws -> [MusicProviderSearchResult]
    func playbackCapability(for item: MusicLibraryItem) -> MusicPlaybackCapability
}

/// Shared honest behavior for providers whose official credentials/integration are
/// not present in this build. It is intentionally not a fake network implementation.
class UnavailableMusicProviderAdapter: MusicProviderAdapter {
    let provider: MusicProvider
    let displayName: String
    let capabilities: MusicProviderAdapterCapabilities
    let configuration: MusicProviderAdapterConfiguration

    init(
        provider: MusicProvider,
        displayName: String,
        configuration: MusicProviderAdapterConfiguration,
        declaredPlaybackMode: MusicProviderPlaybackMode? = nil,
        supportsFileImport: Bool
    ) {
        self.provider = provider
        self.displayName = displayName
        self.configuration = configuration
        self.capabilities = MusicProviderAdapterCapabilities(
            supportsAccount: true,
            supportsSearch: declaredPlaybackMode != nil,
            supportsFileImport: supportsFileImport,
            declaredPlaybackMode: declaredPlaybackMode
        )
    }

    var accountState: MusicProviderAccountState {
        configuration.isConfigured ? .signedOut : .notConfigured
    }

    func authenticate() async throws -> MusicProviderAccountState {
        try Task.checkCancellation()
        guard configuration.isConfigured else {
            throw MusicProviderAdapterError.notConfigured(provider: provider)
        }

        // OAuth is intentionally left to a future official SDK/API integration.
        throw MusicProviderAdapterError.authenticationUnavailable(provider: provider)
    }

    func signOut() async throws {
        try Task.checkCancellation()
        // There is no locally-owned token/session to revoke in an unavailable
        // adapter. The no-op is limited to an already signed-out state.
    }

    func search(query: String, limit: Int = 25) async throws -> [MusicProviderSearchResult] {
        try Task.checkCancellation()
        guard !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw MusicProviderAdapterError.emptySearchQuery
        }
        guard (1...100).contains(limit) else {
            throw MusicProviderAdapterError.invalidSearchLimit
        }
        guard configuration.isConfigured else {
            throw MusicProviderAdapterError.notConfigured(provider: provider)
        }

        // Never return simulated or placeholder remote results.
        throw MusicProviderAdapterError.searchUnavailable(provider: provider)
    }

    func playbackCapability(for item: MusicLibraryItem) -> MusicPlaybackCapability {
        _ = item
        guard configuration.isConfigured else {
            return .unavailable(.notConfigured(provider: provider))
        }
        guard let declaredPlaybackMode = capabilities.declaredPlaybackMode else {
            return .unavailable(.playbackUnavailable(provider: provider))
        }
        // Even when configured, this adapter has no authenticated session. It must
        // not claim that provider playback is available.
        _ = declaredPlaybackMode
        return .unavailable(.authenticationRequired(provider: provider))
    }
}

final class SpotifyMusicProviderAdapter: UnavailableMusicProviderAdapter {
    init(configuration: MusicProviderAdapterConfiguration = MusicProviderAdapterConfiguration()) {
        super.init(
            provider: .spotify,
            displayName: "Spotify",
            configuration: configuration,
            declaredPlaybackMode: .spotifyAppOrSDK,
            supportsFileImport: false
        )
    }
}

final class YouTubeMusicProviderAdapter: UnavailableMusicProviderAdapter {
    init(configuration: MusicProviderAdapterConfiguration = MusicProviderAdapterConfiguration()) {
        super.init(
            provider: .youtubeMusic,
            displayName: "YouTube Music",
            configuration: configuration,
            declaredPlaybackMode: .youtubeEmbeddedPlayer,
            supportsFileImport: false
        )
    }
}

final class SoundCloudMusicProviderAdapter: UnavailableMusicProviderAdapter {
    init(configuration: MusicProviderAdapterConfiguration = MusicProviderAdapterConfiguration()) {
        super.init(
            provider: .soundCloud,
            displayName: "SoundCloud",
            configuration: configuration,
            declaredPlaybackMode: .soundCloudSupportedStream,
            supportsFileImport: false
        )
    }
}

final class DropboxMusicProviderAdapter: UnavailableMusicProviderAdapter {
    init(configuration: MusicProviderAdapterConfiguration = MusicProviderAdapterConfiguration()) {
        super.init(
            provider: .dropbox,
            displayName: "Dropbox",
            configuration: configuration,
            declaredPlaybackMode: nil,
            supportsFileImport: true
        )
    }
}

final class GoogleDriveMusicProviderAdapter: UnavailableMusicProviderAdapter {
    init(configuration: MusicProviderAdapterConfiguration = MusicProviderAdapterConfiguration()) {
        super.init(
            provider: .googleDrive,
            displayName: "Google Drive",
            configuration: configuration,
            declaredPlaybackMode: nil,
            supportsFileImport: true
        )
    }
}

/// Factory/registry used by the import and search UI. It contains only remote
/// providers; Local Files is intentionally handled by the native file importer.
struct MusicProviderAdapterRegistry {
    private let adaptersByProvider: [MusicProvider: any MusicProviderAdapter]

    init(configurations: [MusicProvider: MusicProviderAdapterConfiguration] = [:]) {
        let adapters: [any MusicProviderAdapter] = [
            SpotifyMusicProviderAdapter(
                configuration: configurations[.spotify] ?? MusicProviderAdapterConfiguration()
            ),
            YouTubeMusicProviderAdapter(
                configuration: configurations[.youtubeMusic] ?? MusicProviderAdapterConfiguration()
            ),
            SoundCloudMusicProviderAdapter(
                configuration: configurations[.soundCloud] ?? MusicProviderAdapterConfiguration()
            ),
            DropboxMusicProviderAdapter(
                configuration: configurations[.dropbox] ?? MusicProviderAdapterConfiguration()
            ),
            GoogleDriveMusicProviderAdapter(
                configuration: configurations[.googleDrive] ?? MusicProviderAdapterConfiguration()
            )
        ]
        self.adaptersByProvider = Dictionary(uniqueKeysWithValues: adapters.map { ($0.provider, $0) })
    }

    init(adapters: [any MusicProviderAdapter]) {
        self.adaptersByProvider = Dictionary(uniqueKeysWithValues: adapters.map { ($0.provider, $0) })
    }

    var all: [any MusicProviderAdapter] {
        adaptersByProvider.values.sorted { $0.displayName < $1.displayName }
    }

    func adapter(for provider: MusicProvider) -> (any MusicProviderAdapter)? {
        adaptersByProvider[provider]
    }
}

enum MusicProviderAdapterFactory {
    static func spotify(configuration: MusicProviderAdapterConfiguration = MusicProviderAdapterConfiguration()) -> any MusicProviderAdapter {
        SpotifyMusicProviderAdapter(configuration: configuration)
    }

    static func youtubeMusic(configuration: MusicProviderAdapterConfiguration = MusicProviderAdapterConfiguration()) -> any MusicProviderAdapter {
        YouTubeMusicProviderAdapter(configuration: configuration)
    }

    static func soundCloud(configuration: MusicProviderAdapterConfiguration = MusicProviderAdapterConfiguration()) -> any MusicProviderAdapter {
        SoundCloudMusicProviderAdapter(configuration: configuration)
    }

    static func dropbox(configuration: MusicProviderAdapterConfiguration = MusicProviderAdapterConfiguration()) -> any MusicProviderAdapter {
        DropboxMusicProviderAdapter(configuration: configuration)
    }

    static func googleDrive(configuration: MusicProviderAdapterConfiguration = MusicProviderAdapterConfiguration()) -> any MusicProviderAdapter {
        GoogleDriveMusicProviderAdapter(configuration: configuration)
    }

    static func makeRegistry(
        configurations: [MusicProvider: MusicProviderAdapterConfiguration] = [:]
    ) -> MusicProviderAdapterRegistry {
        MusicProviderAdapterRegistry(configurations: configurations)
    }
}
