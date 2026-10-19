import Foundation

struct RankedIdentity: Codable, Equatable {
    let publicID: String
    let displayName: String
    let listed: Bool
}

struct RankedRating: Codable, Equatable, Identifiable {
    let variation: RankedVariation
    let rating: Int
    let games: Int
    var id: String { variation.rawValue }
    var provisional: Bool { games < 5 }
    var label: String { "\(rating.formatted()) Elo" + (provisional ? " · Placement \(games)/5" : "") }
}

struct RankedAllowance: Codable, Equatable, Identifiable {
    let family: String
    let remaining: Int?
    let nextSlot: Double?
    var id: String { family }
}

struct RankedAccountSnapshot: Codable {
    let identity: RankedIdentity
    let ratings: [RankedRating]
    let allowances: [RankedAllowance]
}

struct RankedParticipant: Codable, Equatable, Identifiable {
    let publicID: String
    let displayName: String
    let isYou: Bool
    let ready: Bool
    let score: Double
    let lastSeen: Double
    let verification: String
    let beforeRating: Int?
    let afterRating: Int?
    let nonce: String?
    let nextSequence: Int?
    var id: String { publicID }
    var delta: Int? {
        guard let beforeRating, let afterRating else { return nil }
        return afterRating - beforeRating
    }
}

struct RankedMatch: Codable, Identifiable, Equatable {
    let id: String
    let variation: RankedVariation
    let ruleVersion: String
    let state: String
    let createdAt: Double
    let readyDeadline: Double
    let startAt: Double?
    let endAt: Double?
    let reason: String?
    let winner: String?
    let revision: Int
    let participants: [RankedParticipant]
    var you: RankedParticipant? { participants.first(where: \.isYou) }
    var opponent: RankedParticipant? { participants.first(where: { !$0.isYou }) }
    var terminal: Bool { ["completed", "forfeited", "invalid", "cancelled"].contains(state) }
    var outcomeTitle: String {
        switch state {
        case "cancelled": return "Cancelled before Go"
        case "invalid": return "Not verified"
        case "forfeited": return winner == you?.publicID ? "Opponent forfeited" : "Forfeited"
        case "completed": return winner == nil ? "Draw" : winner == you?.publicID ? "You won" : "Round lost"
        default: return state == "verifying" ? "Verification pending" : "Round in progress"
        }
    }
}

struct RankedQueue: Codable, Equatable {
    let variation: RankedVariation
    let expiresAt: Double
}

struct RankedServiceState: Codable {
    let serverTime: Double
    var queue: RankedQueue?
    var match: RankedMatch?
}

struct RankedMatchResponse: Codable {
    let serverTime: Double
    let match: RankedMatch
}

struct RankedHistoryPage: Codable {
    let matches: [RankedMatch]
    let nextCursor: String?
}

struct RankedStanding: Codable, Equatable, Identifiable {
    let publicID: String
    let displayName: String
    let rating: Int
    let games: Int
    let position: Int
    var id: String { publicID }
}

struct RankedLeaderboardPage: Codable {
    let rows: [RankedStanding]
    let me: RankedStanding?
    let nextCursor: String?
}

struct RankedPublicPlayer: Codable {
    let publicID: String
    let displayName: String
    let ratings: [RankedRating]
}

struct RankedEvidenceReceipt: Codable {
    let nextSequence: Int
    let score: Double
}

struct RankedDuelFrame: Equatable {
    var remaining = 60
    var yourScore: Double = 0
    var opponentScore: Double = 0
    var feedback = "Get into position"
    var opponentName = "Opponent"
    var connected = true
    var phase = "Set position"
}
