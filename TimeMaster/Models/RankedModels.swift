import Foundation

enum RankedMode: String, CaseIterable, Identifiable {
    case duel, practice
    var id: String { rawValue }
    var title: String { self == .duel ? "Ranked 1v1" : "Practice" }
    var symbol: String { self == .duel ? "bolt.shield.fill" : "figure.strengthtraining.traditional" }
    var assetName: String { "RankedMode_\(rawValue)" }
}

enum RankedFamily: String, CaseIterable, Identifiable {
    case pushUps, squats, core
    var id: String { rawValue }
    var title: String {
        switch self {
        case .pushUps: "Push-ups"
        case .squats: "Squats"
        case .core: "Core"
        }
    }
    var variations: [RankedVariation] {
        switch self {
        case .pushUps: RankedVariation.pushUps
        case .squats: RankedVariation.squats
        case .core: RankedVariation.core
        }
    }
}

enum RankedVariation: String, Codable, CaseIterable, Identifiable {
    case standardPushUp, widePushUp, closePushUp, kneePushUp, pausedPushUp, tempoPushUp
    case diamondPushUp, wallHandstandPushUp, freestandingHandstandPushUp, planchePushUp
    case standardSquat, wideSquat, narrowSquat, pausedSquat
    case forearmPlank, highPlank, leftSidePlank, rightSidePlank

    static let pushUps: [Self] = [.standardPushUp, .widePushUp, .closePushUp, .kneePushUp, .pausedPushUp, .tempoPushUp, .diamondPushUp, .wallHandstandPushUp, .freestandingHandstandPushUp, .planchePushUp]
    static let squats: [Self] = [.standardSquat, .wideSquat, .narrowSquat, .pausedSquat]
    static let core: [Self] = [.forearmPlank, .highPlank, .leftSidePlank, .rightSidePlank]

    var id: String { rawValue }
    var family: RankedFamily {
        switch self {
        case .standardPushUp, .widePushUp, .closePushUp, .kneePushUp, .pausedPushUp, .tempoPushUp,
             .diamondPushUp, .wallHandstandPushUp, .freestandingHandstandPushUp, .planchePushUp: .pushUps
        case .standardSquat, .wideSquat, .narrowSquat, .pausedSquat: .squats
        case .forearmPlank, .highPlank, .leftSidePlank, .rightSidePlank: .core
        }
    }
    var isTimedHold: Bool { family == .core }
    var battleRule: String { isTimedHold ? "60 seconds · Longest valid hold" : "60 seconds · Most complete reps" }
    var assetName: String { "Ranked_\(rawValue)" }
    var isAdvanced: Bool {
        switch self {
        case .diamondPushUp, .wallHandstandPushUp, .freestandingHandstandPushUp, .planchePushUp: true
        default: false
        }
    }
    var title: String {
        switch self {
        case .standardPushUp, .standardSquat: "Standard"
        case .widePushUp: "Wide-grip"
        case .closePushUp: "Close-grip"
        case .kneePushUp: "Knee"
        case .pausedPushUp, .pausedSquat: "Paused"
        case .tempoPushUp: "Tempo"
        case .diamondPushUp: "Diamond"
        case .wallHandstandPushUp: "Wall handstand"
        case .freestandingHandstandPushUp: "Freestanding handstand"
        case .planchePushUp: "Planche"
        case .wideSquat: "Wide-stance"
        case .narrowSquat: "Narrow-stance"
        case .forearmPlank: "Forearm plank"
        case .highPlank: "High plank"
        case .leftSidePlank: "Left side plank"
        case .rightSidePlank: "Right side plank"
        }
    }
    var fullTitle: String { family == .core ? title : "\(title) \(family.title.lowercased())" }
    var cue: String {
        switch self {
        case .standardPushUp: "Straight body. Hands under your shoulders."
        case .widePushUp: "Hands wider than your shoulders."
        case .closePushUp: "Keep your hands close beneath your chest."
        case .kneePushUp: "Knees supported. Keep your torso straight."
        case .pausedPushUp: "Pause at the bottom before pushing up."
        case .tempoPushUp: "Lower slowly. Keep the movement controlled."
        case .diamondPushUp: "Keep your hands together beneath your chest. Lower with control."
        case .wallHandstandPushUp: "Keep the body vertical. Wall contact is allowed only in this variation."
        case .freestandingHandstandPushUp: "Maintain a freestanding handstand without a wall or other support."
        case .planchePushUp: "Keep both feet off the floor and your body horizontal throughout the movement."
        case .standardSquat: "Feet shoulder-width apart. Sit down and back."
        case .wideSquat: "Take a wider stance. Follow your toes with your knees."
        case .narrowSquat: "Bring your feet closer. Keep your heels grounded."
        case .pausedSquat: "Hold the bottom position before standing."
        case .forearmPlank: "Elbows beneath your shoulders. Keep shoulders, hips, and ankles aligned."
        case .highPlank: "Straight arms, hands beneath your shoulders. Keep your hips level."
        case .leftSidePlank: "Support your left forearm and left foot. Stack your feet and lift your hips."
        case .rightSidePlank: "Support your right forearm and right foot. Stack your feet and lift your hips."
        }
    }
}

enum RankedTier: String, CaseIterable, Identifiable {
    case iron, bronze, silver, gold, diamond, champion
    var id: String { rawValue }
    var title: String { rawValue.capitalized }
    var assetName: String { "RankedBadge_\(rawValue)" }
    var minimum: Int {
        switch self {
        case .iron: 0
        case .bronze: 800
        case .silver: 1_000
        case .gold: 1_400
        case .diamond: 1_800
        case .champion: 2_200
        }
    }
    static func level(for elo: Int?) -> Self? {
        guard let elo else { return nil }
        return allCases.last { elo >= $0.minimum }
    }
}

struct LegacyRankedLevels: Codable, Equatable {
    let overall: Int?
    let variations: [String: Int]
    init(overall: Int? = nil, variations: [String: Int] = [:]) {
        self.overall = overall
        self.variations = variations
    }
    var isEmpty: Bool { overall == nil && variations.isEmpty }
}

