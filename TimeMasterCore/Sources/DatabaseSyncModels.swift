import Foundation

public struct DatabaseSyncReport: Sendable {
    public let uploadedFiles: Int
    public let downloadedFiles: Int
    public let conflicts: Int
    public let completedAt: Date

    public init(uploadedFiles: Int, downloadedFiles: Int, conflicts: Int, completedAt: Date = Date()) {
        self.uploadedFiles = uploadedFiles
        self.downloadedFiles = downloadedFiles
        self.conflicts = conflicts
        self.completedAt = completedAt
    }
}

public enum DatabaseSyncError: Error, LocalizedError, Sendable {
    case unauthorized
    case busy
    case accountNotActive
    case invalidAccount
    case invalidServiceURL
    case unsafePath(String)
    case invalidResponse(String)
    case server(status: Int, detail: String)
    case localFileChanged(String)
    case invalidManifest(String)
    case corruptJournal(String)

    public var errorDescription: String? {
        switch self {
        case .unauthorized:
            return "Your cloud session has expired. Sign in again to synchronize."
        case .busy:
            return "Database synchronization is still stopping. Wait for it before changing accounts."
        case .accountNotActive:
            return "Activate this account's exercise library before synchronizing."
        case .invalidAccount:
            return "The cloud account identifier is invalid."
        case .invalidServiceURL:
            return "Exercise synchronization needs an HTTPS service URL."
        case .unsafePath(let path):
            return "Synchronization refused an unsafe file path: \(path)"
        case .invalidResponse(let detail):
            return "The synchronization service returned invalid data: \(detail)"
        case .server(let status, let detail):
            return "Synchronization failed (\(status)): \(detail)"
        case .localFileChanged(let path):
            return "The exercise library changed during synchronization: \(path). Your changes are saved locally; sync again."
        case .invalidManifest(let path):
            return "The exercise manifest could not be read safely: \(path)"
        case .corruptJournal(let detail):
            return "The synchronization journal needs recovery: \(detail). No local files were discarded."
        }
    }
}

struct DatabaseSyncFile: Codable, Equatable, Sendable {
    var path: String
    var revision: Int64
    var hash: String?
    var size: Int64
    var chunks: [String]
    var deleted: Bool

    func hasSameContent(as other: DatabaseSyncFile?) -> Bool {
        guard let other else { return deleted }
        return deleted == other.deleted && (deleted || (hash == other.hash && size == other.size))
    }
}

struct DatabaseSyncMutation: Codable, Sendable {
    var path: String
    var baseRevision: Int64
    var hash: String?
    var size: Int64
    var chunks: [String]
    var deleted: Bool

    init(path: String, revision: Int64, local: DatabaseSyncLocalFile?) {
        self.path = path
        baseRevision = revision
        hash = local?.hash
        size = local?.size ?? 0
        chunks = local?.chunks ?? []
        deleted = local == nil
    }
}

struct DatabaseSyncManifestResponse: Decodable {
    var cursor: Int64
    var files: [DatabaseSyncFile]
    var hasMore: Bool
}

struct DatabaseSyncCommitResponse: Decodable {
    var files: [DatabaseSyncFile]
    var cursor: Int64
}

struct DatabaseSyncCommitRequest: Encodable {
    var deviceID: String
    var mutations: [DatabaseSyncMutation]
}

struct DatabaseSyncConflictResponse: Decodable {
    var detail: String
    var conflicts: [DatabaseSyncFile]
}

struct DatabaseSyncFingerprint: Codable, Equatable, Hashable, Sendable {
    var device: UInt64
    var inode: UInt64
    var size: Int64
    var modifiedSeconds: Int64
    var modifiedNanoseconds: Int64
    var changedSeconds: Int64
    var changedNanoseconds: Int64
}

struct DatabaseSyncLocalFile: Codable, Equatable, Sendable {
    var fingerprint: DatabaseSyncFingerprint
    var hash: String
    var size: Int64
    var chunks: [String]

    func hasSameContent(as remote: DatabaseSyncFile?) -> Bool {
        guard let remote, !remote.deleted else { return false }
        return hash == remote.hash && size == remote.size
    }
}

struct DatabaseSyncJournal: Codable {
    var version = 1
    var accountID: String
    var service: String
    var deviceID = UUID().uuidString.lowercased()
    var cursor: Int64 = 0
    var remote: [String: DatabaseSyncFile] = [:]
    var baseline: [String: DatabaseSyncFile] = [:]
    var local: [String: DatabaseSyncLocalFile] = [:]
    var conflictVersions: Set<String> = []
    var unreportedConflicts = 0
    var publication: DatabaseSyncPublication?
}

struct DatabaseSyncPublication: Codable {
    var remote: DatabaseSyncFile
    var stagingName: String
    var expectedLocal: DatabaseSyncLocalFile?
    var isOrphanDeletion: Bool
}

