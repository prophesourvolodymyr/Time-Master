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
    case standardSquat, wideSquat, narrowSquat, pausedSquat
    case forearmPlank, highPlank, leftSidePlank, rightSidePlank

    static let pushUps: [Self] = [.standardPushUp, .widePushUp, .closePushUp, .kneePushUp, .pausedPushUp, .tempoPushUp]
    static let squats: [Self] = [.standardSquat, .wideSquat, .narrowSquat, .pausedSquat]
    static let core: [Self] = [.forearmPlank, .highPlank, .leftSidePlank, .rightSidePlank]

    var id: String { rawValue }
    var family: RankedFamily {
        switch self {
        case .standardPushUp, .widePushUp, .closePushUp, .kneePushUp, .pausedPushUp, .tempoPushUp: .pushUps
        case .standardSquat, .wideSquat, .narrowSquat, .pausedSquat: .squats
        case .forearmPlank, .highPlank, .leftSidePlank, .rightSidePlank: .core
        }
    }
    var isTimedHold: Bool { family == .core }
    var battleRule: String { isTimedHold ? "60 seconds · Longest valid hold" : "60 seconds · Most complete reps" }
    var assetName: String { "Ranked_\(rawValue)" }
    var title: String {
        switch self {
        case .standardPushUp, .standardSquat: "Standard"
        case .widePushUp: "Wide-grip"
        case .closePushUp: "Close-grip"
        case .kneePushUp: "Knee"
        case .pausedPushUp, .pausedSquat: "Paused"
        case .tempoPushUp: "Tempo"
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

struct RankedLevels: Codable, Equatable {
    static let range = 0...5_000
    var overall: Int?
    var variations: [String: Int] = [:]

    subscript(_ variation: RankedVariation) -> Int? {
        get { variations[variation.rawValue] }
        set { variations[variation.rawValue] = newValue }
    }

    var isEmpty: Bool { overall == nil && variations.isEmpty }
    var isValid: Bool {
        (overall.map(Self.range.contains) ?? true) && variations.allSatisfy {
            RankedVariation(rawValue: $0.key) != nil && Self.range.contains($0.value)
        }
    }
}

enum RankedLevelError: LocalizedError {
    case invalidLevel
    var errorDescription: String? { "Choose an Elo level between 0 and 5,000." }
}
