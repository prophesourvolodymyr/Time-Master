import Foundation

public enum SkillTier: String, Codable, CaseIterable, Equatable, Sendable {
    case s
    case a
    case b
    case c
    case d

    public var title: String { rawValue.uppercased() }

    public var rank: Int {
        switch self {
        case .s: 0
        case .a: 1
        case .b: 2
        case .c: 3
        case .d: 4
        }
    }
}

public struct SkillTraining: Codable, Equatable, Sendable {
    public var skillID: String
    public var tier: SkillTier

    public init(skillID: String, tier: SkillTier) {
        self.skillID = skillID
        self.tier = tier
    }
}
