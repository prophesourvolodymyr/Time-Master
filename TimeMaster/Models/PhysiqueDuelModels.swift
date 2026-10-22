import Foundation

enum PhysiquePose: String, Codable, CaseIterable, Identifiable, Hashable {
    case front, side, rear
    var id: String { rawValue }
    var shortTitle: String { rawValue.capitalized }
    var title: String {
        switch self {
        case .front: return "Front double biceps"
        case .side: return "Side physique"
        case .rear: return "Rear double biceps"
        }
    }
    var instruction: String {
        switch self {
        case .front: return "Face the camera. Raise both arms. Keep shoulders, arms and legs in frame."
        case .side: return "Turn to your side. Keep your upper arm and calf visible. Pose comfortably."
        case .rear: return "Face away. Raise both arms. Keep your back and legs in frame."
        }
    }
}

enum PhysiqueStage: String, Codable, Hashable {
    case idle, searching, ready, countdown, capture, submitting, judging, completed, forfeited, noContest, cancelled, noOpponent
    var title: String {
        switch self {
        case .idle: return "Physique"
        case .searching: return "Finding your opponent"
        case .ready: return "Ready room"
        case .countdown: return "Starts in"
        case .capture: return "Capture"
        case .submitting: return "Submitting poses"
        case .judging: return "Judging"
        case .completed: return "Match ended"
        case .forfeited: return "Forfeit"
        case .noContest: return "No contest"
        case .cancelled: return "Cancelled"
        case .noOpponent: return "No opponent found"
        }
    }
    var terminal: Bool {
        switch self {
        case .completed, .forfeited, .noContest, .cancelled, .noOpponent: return true
        default: return false
        }
    }
}

struct PhysiqueBadge: Codable, Identifiable, Hashable {
    let id: String
    let title: String
    let symbol: String
    let detail: String
    let earnedAt: Double?
}

struct PhysiqueIdentity: Codable, Identifiable, Hashable {
    let id: String
    let displayName: String
    let countryCode: String?
    let rating: Int?
    let games: Int
    let tier: String?
    let badges: [PhysiqueBadge]
    let streak: Int?
    var placementLabel: String {
        if games == 0 { return "Unplaced" }
        if games < 5 { return "Provisional · \(games) of 5" }
        return tier ?? "Tier unavailable"
    }
}

struct PhysiqueConsent: Codable, Hashable {
    var adult: Bool
    var adultMan: Bool
    var rulesAccepted: Bool
    var aiProcessing: Bool
    var opponentSharing: Bool
    var policyVersion: String
    static let empty = Self(adult: false, adultMan: false, rulesAccepted: false, aiProcessing: false, opponentSharing: false, policyVersion: "")
    var accepted: Bool { adult && rulesAccepted && aiProcessing && opponentSharing && !policyVersion.isEmpty }
}

struct PhysiquePolicy: Codable {
    let version: String
    let operatorName: String
    let processor: String
    let region: String
    let retention: String
    let judgeVersion: String
    let supportURL: String?
    let ready: Bool
    let unavailableReason: String?
}

struct PhysiqueRecord: Codable {
    let rating: Int?
    let best: Int?
    let games: Int
    let wins: Int
    let losses: Int
    let draws: Int
}

struct PhysiqueAllowance: Codable {
    let remaining: Int
    let limit: Int
    let nextAvailableAt: Double?
}

struct PhysiqueAccount: Codable {
    let identity: PhysiqueIdentity
    let consent: PhysiqueConsent
    let record: PhysiqueRecord
    let allowance: PhysiqueAllowance
    let listed: Bool
    let restrictedReason: String?
    let consentRevision: Double?
}

struct PhysiqueParticipant: Codable {
    let identity: PhysiqueIdentity
    let ready: Bool
    let submitted: Bool
    let acceptedCount: Int
}

struct PhysiqueEvidence: Codable, Identifiable {
    let id: String
    let pose: PhysiquePose
    let status: String
    let retakes: Int
    let reason: String?
    let appealCaseID: String?
}

enum PhysiqueCategory: String, Codable, CaseIterable, Identifiable {
    case muscularity, definition, symmetry, presentation
    var id: String { rawValue }
    var title: String {
        switch self {
        case .muscularity: return "Visible muscularity"
        case .definition: return "Definition"
        case .symmetry: return "Symmetry & balance"
        case .presentation: return "Pose presentation"
        }
    }
    var weight: Int {
        switch self {
        case .muscularity: return 40
        case .definition: return 30
        case .symmetry: return 20
        case .presentation: return 10
        }
    }
}

struct PhysiqueScores: Codable {
    let muscularity: Int
    let definition: Int
    let symmetry: Int
    let presentation: Int
    let total: Double
    func value(for category: PhysiqueCategory) -> Int {
        switch category {
        case .muscularity: return muscularity
        case .definition: return definition
        case .symmetry: return symmetry
        case .presentation: return presentation
        }
    }
}

struct PhysiqueRatingReceipt: Codable {
    let before: Int?
    let change: Int
    let after: Int
    let games: Int
}

struct PhysiqueCorrection: Codable {
    let id: String
    let createdAt: Double
    let reason: String
    let originalOutcome: String
    let correctedOutcome: String
    let originalChange: Int
    let adjustment: Int
    let after: Int
}

struct PhysiqueResult: Codable {
    let outcome: String
    let you: PhysiqueScores?
    let opponent: PhysiqueScores?
    let rating: PhysiqueRatingReceipt?
    let explanation: String?
    let judgeVersion: String?
    let corrected: Bool
    let correction: PhysiqueCorrection?
    var title: String {
        switch outcome {
        case "win": return "You won"
        case "loss": return "Opponent won"
        case "draw": return "Draw"
        case "forfeitWin": return "Opponent forfeited"
        case "forfeitLoss": return "You forfeited"
        case "noContest": return "No contest"
        default: return "Result unavailable"
        }
    }
    var isJudged: Bool {
        (outcome == "win" || outcome == "loss" || outcome == "draw") && you != nil && opponent != nil
    }
}

struct PhysiqueMatch: Codable, Identifiable {
    let id: String
    let stage: PhysiqueStage
    let createdAt: Double
    let startAt: Double?
    let deadline: Double?
    let judgingStartedAt: Double?
    let judgingDeadline: Double?
    let finalizedAt: Double?
    let reason: String?
    let you: PhysiqueParticipant
    let opponent: PhysiqueParticipant
    let evidence: [PhysiqueEvidence]
    let result: PhysiqueResult?
    let galleryAvailable: Bool
    let mediaExpiresAt: Double?
}

struct PhysiqueSnapshot: Codable {
    let serverTime: Double
    let policy: PhysiquePolicy
    let account: PhysiqueAccount
    let match: PhysiqueMatch?
    let queueStartedAt: Double?
    let queueDeadline: Double?
    let queueOutcome: String?
}

struct PhysiquePageResponse<Item: Decodable>: Decodable {
    let items: [Item]
    let cursor: String?
}

struct PhysiqueStanding: Codable, Identifiable {
    let id: String
    let position: Int?
    let identity: PhysiqueIdentity
    let record: PhysiqueRecord
}

struct PhysiqueCaseMessage: Codable, Identifiable {
    let id: String
    let text: String
    let createdAt: Double
    let fromStaff: Bool
}

struct PhysiqueCase: Codable, Identifiable {
    let id: String
    let kind: String
    let status: String
    let summary: String
    let createdAt: Double
    let updatedAt: Double
    let matchID: String?
    let decision: String?
    let needsReply: Bool
    let canAppeal: Bool
    let canWithdraw: Bool
    let messages: [PhysiqueCaseMessage]
}

struct PhysiqueMedia: Codable, Identifiable {
    let id: String
    let ownerID: String
    let pose: PhysiquePose
    let status: String
    let imageBase64: String?
    let expiresAt: Double?
}

struct PhysiquePrivacyReceipt: Codable, Identifiable {
    let id: String
    let scope: String
    let status: String
    let createdAt: Double
    let updatedAt: Double
    let detail: String
    let retainedReason: String?
}

struct PhysiqueBlockedPlayer: Codable, Identifiable {
    let id: String
    let displayName: String
}

struct PhysiqueReportTarget: Hashable {
    let kind: String
    let id: String
    var matchID: String? = nil
}

struct PhysiqueReviewTarget: Hashable {
    let kind: String
    let id: String
    var matchID: String? = nil
}

enum PhysiqueRoute: Hashable {
    case lobby, account, consent, rules, guide, camera, search, ready, battle
    case poseReview(PhysiquePose), judging, result(String), breakdown(String), gallery(String)
    case history, standings, player(String), safety, report(PhysiqueReportTarget)
    case cases, caseDetail(String), review(PhysiqueReviewTarget), privacy, deletion, badges
}

struct PhysiqueCommand: Encodable {
    let operation: String
    let requestID: String
    let matchID: String?
    let targetID: String?
    let pose: PhysiquePose?
    let imageBase64: String?
    let text: String?
    let reason: String?
    let value: Bool?
    let countryCode: String?
    let consent: PhysiqueConsent?
    let expectedRevision: Double?
}

struct PhysiqueCommandResponse: Decodable {
    let snapshot: PhysiqueSnapshot
    let receiptID: String?
    let message: String?
}

struct PhysiqueItems<Item: Decodable>: Decodable {
    let items: [Item]
}
