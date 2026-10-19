import Foundation
import Combine
import TimeMasterCore

extension Notification.Name {
    static let localProfileDidChange = Notification.Name("TimeMaster.localProfileDidChange")
}

enum LocalProfilePersistence {
    static var fileURL: URL {
        DatabaseManager.shared.dataRoot.appendingPathComponent("profile/local-profile.json")
    }

    static func load(from url: URL = fileURL) throws -> LocalProfileSnapshot? {
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let value = try decoder.decode(LocalProfileSnapshot.self, from: Data(contentsOf: url))
        guard value.version == 1, value.rankedLevels?.isValid != false, value.mediaFilenames.allSatisfy({
            !$0.isEmpty && $0 != "." && $0 != ".." && !$0.contains("/") && !$0.contains("\\")
        }) else { throw LocalProfileError.storageUnreadable }
        return value
    }

    static func save(_ snapshot: LocalProfileSnapshot, to url: URL = fileURL) throws {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(snapshot)
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try data.write(to: url, options: .atomic)
    }
}

@MainActor
final class LocalProfileStore: ObservableObject {
    @Published private(set) var snapshot = LocalProfileSnapshot()
    @Published private(set) var isReadOnly = false
    @Published var errorMessage: String?
    private let fileURL: URL
    private var importObserver: AnyCancellable?
    var profile: LocalUserProfile { snapshot.profile }

    init(fileURL: URL = LocalProfilePersistence.fileURL) {
        self.fileURL = fileURL
        reload()
        importObserver = NotificationCenter.default.publisher(for: .localProfileDidChange)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.reload() }
    }

    func reload() {
        do {
            if let saved = try LocalProfilePersistence.load(from: fileURL) {
                snapshot = saved
            } else {
                try LocalProfilePersistence.save(snapshot, to: fileURL)
            }
            isReadOnly = false
            errorMessage = nil
        } catch {
            isReadOnly = true
            errorMessage = LocalProfileError.storageUnreadable.localizedDescription
        }
    }

    @discardableResult
    func perform(_ action: () throws -> Void) -> Bool {
        do {
            try action()
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    func updateProfile(_ value: LocalUserProfile) throws {
        var profile = value
        profile.id = snapshot.profile.id
        profile.createdAt = snapshot.profile.createdAt
        profile.displayName = profile.displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        profile.handle = profile.handle.trimmingCharacters(in: .whitespacesAndNewlines)
        if profile.handle.hasPrefix("@") { profile.handle.removeFirst() }
        guard (1...60).contains(profile.displayName.count) else { throw LocalProfileError.invalidName }
        guard profile.handle.range(of: "^[A-Za-z0-9_.]{1,30}$", options: .regularExpression) != nil else {
            throw LocalProfileError.invalidHandle
        }
        profile.links = profile.links.filter { !$0.url.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        guard profile.links.count <= 3 else { throw LocalProfileError.invalidLinks }
        for index in profile.links.indices {
            profile.links[index].url = profile.links[index].url.trimmingCharacters(in: .whitespacesAndNewlines)
            guard let url = URL(string: profile.links[index].url),
                  ["https", "http"].contains(url.scheme?.lowercased() ?? ""),
                  let host = url.host, !host.isEmpty, url.user == nil, url.password == nil else {
                throw LocalProfileError.invalidLinks
            }
        }
        try change { $0.profile = profile }
    }

    @discardableResult
    func publish(body: String, imageFilename: String?, audience: LocalPostAudience, allowsReplies: Bool) throws -> UUID {
        let body = body.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !body.isEmpty || imageFilename != nil else { throw LocalProfileError.emptyPost }
        let post = LocalProfilePost(body: body, imageFilename: imageFilename, audience: audience, allowsReplies: allowsReplies)
        try change { $0.posts.append(post) }
        return post.id
    }

    func updatePost(id: UUID, body: String, imageFilename: String?, audience: LocalPostAudience, allowsReplies: Bool) throws {
        let body = body.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !body.isEmpty || imageFilename != nil else { throw LocalProfileError.emptyPost }
        guard let index = snapshot.posts.firstIndex(where: { $0.id == id }) else { throw LocalProfileError.postUnavailable }
        try change {
            $0.posts[index].body = body
            $0.posts[index].imageFilename = imageFilename
            $0.posts[index].audience = audience
            $0.posts[index].allowsReplies = allowsReplies
            $0.posts[index].editedAt = Date()
        }
    }

    func deletePost(id: UUID) throws {
        guard snapshot.posts.contains(where: { $0.id == id }) else { throw LocalProfileError.postUnavailable }
        try change {
            $0.posts.removeAll { $0.id == id }
            $0.repostedIDs.remove(id)
        }
    }

    func addReply(postID: UUID, body: String) throws {
        let body = body.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !body.isEmpty else { throw LocalProfileError.emptyPost }
        guard let index = snapshot.posts.firstIndex(where: { $0.id == postID }) else { throw LocalProfileError.postUnavailable }
        guard snapshot.posts[index].allowsReplies, profile.allowReplies else { throw LocalProfileError.repliesDisabled }
        try change { $0.posts[index].replies.append(LocalPostReply(body: body)) }
    }

    func deleteReply(postID: UUID, replyID: UUID) throws {
        guard let index = snapshot.posts.firstIndex(where: { $0.id == postID }) else { throw LocalProfileError.postUnavailable }
        try change { $0.posts[index].replies.removeAll { $0.id == replyID } }
    }

    func toggleReaction(postID: UUID, reaction: String) throws {
        guard let index = snapshot.posts.firstIndex(where: { $0.id == postID }) else { throw LocalProfileError.postUnavailable }
        try change {
            if !$0.posts[index].reactions.insert(reaction).inserted { $0.posts[index].reactions.remove(reaction) }
        }
    }

    func toggleRepost(postID: UUID) throws {
        guard snapshot.posts.contains(where: { $0.id == postID }) else { throw LocalProfileError.postUnavailable }
        try change {
            if !$0.repostedIDs.insert(postID).inserted { $0.repostedIDs.remove(postID) }
        }
    }

    func setCosmetic(category: String, itemID: String?) throws {
        try change { $0.cosmeticSelections[category] = itemID }
    }

    func toggleSavedCollectible(id: String) throws {
        try change {
            if !$0.savedCollectibleIDs.insert(id).inserted { $0.savedCollectibleIDs.remove(id) }
        }
    }

    func setBadgePreview(_ tier: LocalBadgeTier?) throws {
        try change { $0.badgePreview = tier }
    }

    var rankedLevels: RankedLevels { snapshot.rankedLevels ?? RankedLevels() }

    func updateRankedLevels(_ levels: RankedLevels) throws {
        guard levels.isValid else { throw RankedLevelError.invalidLevel }
        try change { $0.rankedLevels = levels.isEmpty ? nil : levels }
    }

    func claimMilestone(progress: LocalVerificationProgress) throws {
        guard progress.isEligible else { throw LocalProfileError.notEligible }
        try change { $0.earnedMilestoneClaimed = true }
    }

    func saveReportDraft(reason: String, details: String) throws {
        try change { $0.reportDrafts.append(LocalProfileReport(reason: reason, details: details)) }
    }

    private func change(_ mutation: (inout LocalProfileSnapshot) -> Void) throws {
        guard !isReadOnly else { throw LocalProfileError.storageUnreadable }
        var next = snapshot
        mutation(&next)
        try LocalProfilePersistence.save(next, to: fileURL)
        snapshot = next
    }
}
