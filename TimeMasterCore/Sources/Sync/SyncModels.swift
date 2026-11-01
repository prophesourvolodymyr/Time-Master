import Foundation

public enum SyncUnitKind: String, Codable, CaseIterable, Sendable {
    case page
    case workout
    case activity
    case route
    case media
    case photo
    case music

    public var carriesManifest: Bool {
        switch self {
        case .page, .workout, .activity, .route: return true
        case .media, .photo, .music: return false
        }
    }

    public var isFolderUnit: Bool {
        switch self {
        case .page, .workout, .activity: return true
        default: return false
        }
    }

    public var title: String {
        switch self {
        case .page: return "page"
        case .workout: return "workout"
        case .activity: return "activity"
        case .route: return "route"
        case .media, .photo, .music: return "file"
        }
    }
}

public enum SyncUnitKey {
    public static func make(_ kind: SyncUnitKind, _ id: String) -> String { "\(kind.rawValue):\(id)" }

    public static func split(_ key: String) -> (kind: SyncUnitKind, id: String)? {
        guard let colon = key.firstIndex(of: ":"), let kind = SyncUnitKind(rawValue: String(key[..<colon])) else { return nil }
        let id = String(key[key.index(after: colon)...])
        return id.isEmpty ? nil : (kind, id)
    }

    public static func kind(_ key: String) -> SyncUnitKind? { split(key)?.kind }
}

public enum SyncLimits {
    public static let chunkBytes = 1 << 20
    public static let unitsPerRequest = 40
    public static let currentSchema = 1
}

public struct SyncUnitVersion: Codable, Equatable, Sendable {
    public var key: String
    public var hash: String
    public var stamp: SyncStamp
    public var parentID: String?
    public var title: String

    public init(key: String, hash: String, stamp: SyncStamp, parentID: String?, title: String) {
        self.key = key
        self.hash = hash
        self.stamp = stamp
        self.parentID = parentID
        self.title = title
    }
}

public struct SyncShard: Codable, Equatable, Sendable {
    public var name: String
    public var count: Int
    public var digest: String

    public init(name: String, count: Int, digest: String) {
        self.name = name
        self.count = count
        self.digest = digest
    }
}

public struct SyncRecordVersion: Codable, Equatable, Sendable {
    public var hash: String
    public var stamp: SyncStamp

    public init(hash: String, stamp: SyncStamp) {
        self.hash = hash
        self.stamp = stamp
    }
}

public struct SyncIndex: Codable, Equatable, Sendable {
    public var device: String
    public var name: String
    public var schema: Int
    public var kinds: [SyncUnitKind]
    public var units: [SyncUnitVersion]
    public var tombstones: [String: SyncStamp]
    public var shards: [SyncShard]
    public var historyTombstones: [String: SyncStamp]
    public var config: SyncRecordVersion?

    public init(
        device: String, name: String, schema: Int = SyncLimits.currentSchema, kinds: [SyncUnitKind] = SyncUnitKind.allCases,
        units: [SyncUnitVersion] = [], tombstones: [String: SyncStamp] = [:], shards: [SyncShard] = [],
        historyTombstones: [String: SyncStamp] = [:], config: SyncRecordVersion? = nil
    ) {
        self.device = device
        self.name = name
        self.schema = schema
        self.kinds = kinds
        self.units = units
        self.tombstones = tombstones
        self.shards = shards
        self.historyTombstones = historyTombstones
        self.config = config
    }
}

public struct SyncUnitBundle: Codable, Equatable, Sendable {
    public var key: String
    public var manifest: String?
    public var files: [SyncFileEntry]
    public var hash: String
    public var stamp: SyncStamp

    public init(key: String, manifest: String?, files: [SyncFileEntry], hash: String, stamp: SyncStamp) {
        self.key = key
        self.manifest = manifest
        self.files = files
        self.hash = hash
        self.stamp = stamp
    }
}

public struct SyncPushUnit: Codable, Equatable, Sendable {
    public var bundle: SyncUnitBundle
    public var expectedHash: String?
    public var removeFiles: [String]

    public init(bundle: SyncUnitBundle, expectedHash: String?, removeFiles: [String] = []) {
        self.bundle = bundle
        self.expectedHash = expectedHash
        self.removeFiles = removeFiles
    }
}

public struct SyncPushDeletion: Codable, Equatable, Sendable {
    public var key: String
    public var stamp: SyncStamp
    public var expectedHash: String?

    public init(key: String, stamp: SyncStamp, expectedHash: String?) {
        self.key = key
        self.stamp = stamp
        self.expectedHash = expectedHash
    }
}

public struct SyncPushRequest: Codable, Equatable, Sendable {
    public var units: [SyncPushUnit]
    public var deletions: [SyncPushDeletion]

    public init(units: [SyncPushUnit] = [], deletions: [SyncPushDeletion] = []) {
        self.units = units
        self.deletions = deletions
    }
}

public struct SyncNeededFile: Codable, Equatable, Hashable, Sendable {
    public var unitKey: String
    public var file: SyncFileEntry

    public init(unitKey: String, file: SyncFileEntry) {
        self.unitKey = unitKey
        self.file = file
    }
}

public struct SyncPushTicket: Codable, Equatable, Sendable {
    public var token: String
    public var needed: [SyncNeededFile]

    public init(token: String, needed: [SyncNeededFile]) {
        self.token = token
        self.needed = needed
    }
}

public struct SyncPushResult: Codable, Equatable, Sendable {
    public var applied: [String]
    public var stale: [String]
    public var deleted: [String]
    public var warnings: [String]

    public init(applied: [String] = [], stale: [String] = [], deleted: [String] = [], warnings: [String] = []) {
        self.applied = applied
        self.stale = stale
        self.deleted = deleted
        self.warnings = warnings
    }
}

public struct SyncConfigPayload: Codable, Equatable, Sendable {
    public var json: String
    public var hash: String
    public var stamp: SyncStamp

    public init(json: String, hash: String, stamp: SyncStamp) {
        self.json = json
        self.hash = hash
        self.stamp = stamp
    }
}

public struct SyncChangeSet: OptionSet, Sendable {
    public let rawValue: Int

    public init(rawValue: Int) {
        self.rawValue = rawValue
    }

    public static let pages = SyncChangeSet(rawValue: 1 << 0)
    public static let workouts = SyncChangeSet(rawValue: 1 << 1)
    public static let activities = SyncChangeSet(rawValue: 1 << 2)
    public static let routes = SyncChangeSet(rawValue: 1 << 3)
    public static let files = SyncChangeSet(rawValue: 1 << 4)
    public static let music = SyncChangeSet(rawValue: 1 << 5)
    public static let history = SyncChangeSet(rawValue: 1 << 6)
    public static let config = SyncChangeSet(rawValue: 1 << 7)

    public init(keys: [String]) {
        var set: SyncChangeSet = []
        for key in keys {
            switch SyncUnitKey.kind(key) {
            case .page?: set.insert(.pages)
            case .workout?: set.insert(.workouts)
            case .activity?: set.insert(.activities)
            case .route?: set.insert(.routes)
            case .media?, .photo?: set.insert(.files)
            case .music?: set.insert(.music)
            case nil: break
            }
        }
        self = set
    }
}
