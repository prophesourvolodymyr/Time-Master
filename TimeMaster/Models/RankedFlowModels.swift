import Foundation
import Combine

enum RankedPreviewOutcome: String, CaseIterable, Identifiable, Codable {
    case pending, win, loss, draw, forfeit, unverified
    var id: String { rawValue }
    var title: String {
        switch self {
        case .pending: "Pending"
        case .win: "You won"
        case .loss: "Round lost"
        case .draw: "Draw"
        case .forfeit: "Forfeited"
        case .unverified: "Not verified"
        }
    }
    var symbol: String {
        switch self {
        case .pending: "clock"
        case .win: "trophy.fill"
        case .loss: "flag.checkered"
        case .draw: "equal.circle.fill"
        case .forfeit: "rectangle.portrait.and.arrow.right"
        case .unverified: "exclamationmark.shield"
        }
    }
}

enum RankedMovementFeedback: String, CaseIterable, Identifiable {
    case ready, accepted, incomplete, outOfFrame, reposition, connectionLost
    var id: String { rawValue }
    var title: String {
        switch self {
        case .ready: "Get into position"
        case .accepted: "Movement accepted"
        case .incomplete: "Complete the movement"
        case .outOfFrame: "Feet outside the frame"
        case .reposition: "Move the phone farther away"
        case .connectionLost: "Reconnecting"
        }
    }
    var symbol: String {
        switch self {
        case .ready: "viewfinder"
        case .accepted: "checkmark.circle.fill"
        case .incomplete: "arrow.down.to.line"
        case .outOfFrame: "figure.stand.line.dotted.figure.stand"
        case .reposition: "iphone.gen3.radiowaves.left.and.right"
        case .connectionLost: "wifi.exclamationmark"
        }
    }
}

struct RankedDuelFrame: Equatable {
    var remaining: Int
    var yourScore: Int
    var opponentScore: Int
    var feedback: RankedMovementFeedback
}

struct RankedPreviewMatch: Identifiable, Equatable {
    let id: UUID
    let variation: RankedVariation
    var outcome: RankedPreviewOutcome
    let yourScore: Int
    let opponentScore: Int
    let date: Date
}

@MainActor
final class RankedPreviewSession: ObservableObject {
    @Published var matches: [RankedPreviewMatch] = []
    @Published private var starts: [String: [Date]] = [:]
    static let matchLimit = 10
    static let window: TimeInterval = 4 * 60 * 60

    func remaining(for family: RankedFamily, at date: Date = Date()) -> Int {
        max(0, Self.matchLimit - recentStarts(for: family, at: date).count)
    }

    func nextSlot(for family: RankedFamily, at date: Date = Date()) -> Date? {
        guard remaining(for: family, at: date) == 0 else { return nil }
        return recentStarts(for: family, at: date).min()?.addingTimeInterval(Self.window)
    }

    @discardableResult
    func startRound(for family: RankedFamily, at date: Date = Date()) -> Bool {
        let recent = recentStarts(for: family, at: date)
        guard recent.count < Self.matchLimit else { return false }
        starts[family.rawValue] = recent + [date]
        return true
    }

    func record(_ match: RankedPreviewMatch) {
        if let index = matches.firstIndex(where: { $0.id == match.id }) {
            matches[index] = match
        } else {
            matches.insert(match, at: 0)
        }
    }

    private func recentStarts(for family: RankedFamily, at date: Date) -> [Date] {
        (starts[family.rawValue] ?? []).filter { date.timeIntervalSince($0) < Self.window }
    }
}
