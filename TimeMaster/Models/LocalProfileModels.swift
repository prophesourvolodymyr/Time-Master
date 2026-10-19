import Foundation

enum LocalProfileTab: String, Codable, CaseIterable, Identifiable {
    case posts, activity, ranked, reposted
    var id: String { rawValue }
    var title: String { rawValue.capitalized }
    var symbol: String {
        switch self {
        case .posts: return "text.bubble"
        case .activity: return "waveform.path.ecg"
        case .ranked: return "shield.lefthalf.filled"
        case .reposted: return "arrow.2.squarepath"
        }
    }
}

enum LocalPostAudience: String, Codable, CaseIterable, Identifiable {
    case profile, onlyMe
    var id: String { rawValue }
    var title: String { self == .profile ? "Profile" : "Only me" }
}

enum LocalBadgeTier: String, Codable, CaseIterable, Identifiable {
    case blue, silver, gold
    var id: String { rawValue }
    var title: String { rawValue.capitalized }
}

struct LocalSocialLink: Codable, Equatable, Identifiable {
    var id = UUID()
    var title = "Website"
    var url = ""
    var symbol: String {
        switch title.lowercased() {
        case "youtube": return "play.rectangle"
        case "tiktok": return "music.note"
        case "instagram": return "camera"
        case "x": return "at"
        default: return "link"
        }
    }
}

struct LocalUserProfile: Codable, Equatable, Identifiable {
    var id = UUID()
    var createdAt = Date()
    var displayName = "Your name"
    var handle = "you"
    var location = ""
    var biography = ""
    var avatarFilename: String?
    var bannerFilename: String?
    var links: [LocalSocialLink] = []
    var isPrivate = true
    var showPostsToVisitors = true
    var showActivityToVisitors = false
    var showRepostsToVisitors = true
    var showAchievements = true
    var showLinks = true
    var allowReplies = true

    var visibleTabs: [LocalProfileTab] {
        LocalProfileTab.allCases.filter {
            switch $0 {
            case .posts: return showPostsToVisitors
            case .activity: return showActivityToVisitors
            case .ranked: return false
            case .reposted: return showRepostsToVisitors
            }
        }
    }
}

struct LocalPostReply: Codable, Equatable, Identifiable {
    var id = UUID()
    var body: String
    var createdAt = Date()
}

struct LocalProfilePost: Codable, Equatable, Identifiable {
    var id = UUID()
    var body: String
    var imageFilename: String?
    var createdAt = Date()
    var editedAt: Date?
    var audience: LocalPostAudience = .profile
    var allowsReplies = true
    var reactions: Set<String> = []
    var replies: [LocalPostReply] = []
}

struct LocalProfileReport: Codable, Equatable, Identifiable {
    var id = UUID()
    var reason: String
    var details: String
    var createdAt = Date()
}

struct LocalProfileSnapshot: Codable, Equatable {
    var version = 1
    var profile = LocalUserProfile()
    var posts: [LocalProfilePost] = []
    var repostedIDs: Set<UUID> = []
    var cosmeticSelections: [String: String] = [:]
    var savedCollectibleIDs: Set<String> = []
    var badgePreview: LocalBadgeTier?
    var earnedMilestoneClaimed = false
    var reportDrafts: [LocalProfileReport] = []
    var rankedLevels: RankedLevels?

    func visiblePosts(asVisitor: Bool, repostsOnly: Bool = false) -> [LocalProfilePost] {
        guard !asVisitor || !profile.isPrivate else { return [] }
        if asVisitor && !(repostsOnly ? profile.showRepostsToVisitors : profile.showPostsToVisitors) { return [] }
        return posts.filter {
            (!asVisitor || $0.audience == .profile) && (!repostsOnly || repostedIDs.contains($0.id))
        }.sorted { $0.createdAt > $1.createdAt }
    }

    var mediaFilenames: [String] {
        [profile.avatarFilename, profile.bannerFilename].compactMap { $0 } + posts.compactMap(\.imageFilename)
    }

    func remappingMedia(_ mapping: [String: String]) -> Self {
        var copy = self
        copy.profile.avatarFilename = profile.avatarFilename.map { mapping[$0] ?? $0 }
        copy.profile.bannerFilename = profile.bannerFilename.map { mapping[$0] ?? $0 }
        for index in copy.posts.indices {
            copy.posts[index].imageFilename = copy.posts[index].imageFilename.map { mapping[$0] ?? $0 }
        }
        return copy
    }

    func merging(_ imported: Self) -> Self {
        var emptyProfile = LocalUserProfile()
        emptyProfile.id = profile.id
        emptyProfile.createdAt = profile.createdAt
        if profile == emptyProfile, posts.isEmpty, cosmeticSelections.isEmpty,
           savedCollectibleIDs.isEmpty, badgePreview == nil, reportDrafts.isEmpty, !earnedMilestoneClaimed,
           rankedLevels?.isEmpty != false {
            return imported
        }
        var next = self
        let existing = Set(posts.map(\.id))
        next.posts.append(contentsOf: imported.posts.filter { !existing.contains($0.id) }.map {
            var post = $0
            if imported.profile.isPrivate { post.audience = .onlyMe }
            return post
        })
        next.repostedIDs.formUnion(imported.repostedIDs)
        next.repostedIDs.formIntersection(Set(next.posts.map(\.id)))
        next.savedCollectibleIDs.formUnion(imported.savedCollectibleIDs)
        let existingReports = Set(reportDrafts.map(\.id))
        next.reportDrafts.append(contentsOf: imported.reportDrafts.filter { !existingReports.contains($0.id) })
        return next
    }
}

struct LocalTrainingSession {
    let id: String
    let completedAt: Date
    let isComplete: Bool
}

struct LocalVerificationProgress {
    let accountDays: Int
    let completedSessions: Int
    let activeDays: Int
    static let requiredAccountDays = 180
    static let requiredSessions = 100
    static let requiredActiveDays = 75

    init(createdAt: Date, sessions: [LocalTrainingSession], now: Date = Date(), calendar: Calendar = .current) {
        accountDays = max(0, calendar.dateComponents([.day], from: calendar.startOfDay(for: createdAt), to: calendar.startOfDay(for: now)).day ?? 0)
        let start = calendar.date(byAdding: .day, value: -180, to: now) ?? now
        var identifiers: Set<String> = []
        var days: Set<Date> = []
        var count = 0
        for session in sessions where session.isComplete && session.completedAt >= start && session.completedAt <= now {
            guard identifiers.insert(session.id).inserted else { continue }
            count += 1
            days.insert(calendar.startOfDay(for: session.completedAt))
        }
        completedSessions = count
        activeDays = days.count
    }

    var isEligible: Bool {
        accountDays >= Self.requiredAccountDays && completedSessions >= Self.requiredSessions && activeDays >= Self.requiredActiveDays
    }
}

enum LocalProfileError: LocalizedError {
    case invalidName, invalidHandle, invalidLinks, emptyPost, postUnavailable, repliesDisabled, storageUnreadable, notEligible
    var errorDescription: String? {
        switch self {
        case .invalidName: return "Enter a display name of 1–60 characters."
        case .invalidHandle: return "Use 1–30 letters, numbers, underscores, or periods for your handle."
        case .invalidLinks: return "Add up to three links with valid https:// or http:// addresses."
        case .emptyPost: return "Add text or a photo before saving the post."
        case .postUnavailable: return "This post is no longer available."
        case .repliesDisabled: return "Replies are turned off for this post."
        case .storageUnreadable: return "The saved profile could not be read. The original file is preserved. Retry loading before making changes."
        case .notEligible: return "Complete all three consistency requirements before claiming the local milestone."
        }
    }
}
