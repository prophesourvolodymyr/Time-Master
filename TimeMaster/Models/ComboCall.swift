import Foundation

struct ComboMove: Identifiable, Hashable {
    let token: String
    let title: String
    let symbol: String
    let isPunch: Bool

    var id: String { token }
}

enum ComboMoves {
    static let all: [ComboMove] = [
        ComboMove(token: "1", title: "Jab", symbol: "arrow.right", isPunch: true),
        ComboMove(token: "2", title: "Cross", symbol: "arrow.right.to.line", isPunch: true),
        ComboMove(token: "3", title: "Lead hook", symbol: "arrow.turn.up.right", isPunch: true),
        ComboMove(token: "4", title: "Rear hook", symbol: "arrow.turn.up.left", isPunch: true),
        ComboMove(token: "5", title: "Lead uppercut", symbol: "arrow.up.right", isPunch: true),
        ComboMove(token: "6", title: "Rear uppercut", symbol: "arrow.up.left", isPunch: true),
        ComboMove(token: "slip", title: "Slip", symbol: "arrow.left.and.right", isPunch: false),
        ComboMove(token: "roll", title: "Roll", symbol: "arrow.triangle.2.circlepath", isPunch: false),
        ComboMove(token: "duck", title: "Duck", symbol: "arrow.down.to.line", isPunch: false),
        ComboMove(token: "block", title: "Block", symbol: "shield.fill", isPunch: false),
        ComboMove(token: "pivot", title: "Pivot", symbol: "arrow.uturn.right", isPunch: false),
        ComboMove(token: "reset", title: "Reset", symbol: "arrow.counterclockwise", isPunch: false),
    ]

    static func move(for token: String) -> ComboMove? {
        all.first { $0.token == token }
    }
}

enum ComboCall {
    private static let words: [String: String] = [
        "1": "one", "2": "two", "3": "three", "4": "four", "5": "five", "6": "six", "7": "seven", "8": "eight", "9": "nine",
    ]

    static func tokens(in text: String) -> [String] {
        var result: [String] = []
        var current = ""
        func flush() {
            guard !current.isEmpty else { return }
            if current.allSatisfy(\.isNumber) {
                result.append(contentsOf: current.map { String($0) })
            } else {
                result.append(current)
            }
            current = ""
        }
        for character in text.lowercased() {
            if character.isLetter || character.isNumber {
                current.append(character)
            } else {
                flush()
            }
        }
        flush()
        return result
    }

    static func name(for tokens: [String]) -> String {
        tokens.joined(separator: "-")
    }

    static func spoken(_ tokens: [String]) -> String {
        tokens.map { words[$0] ?? $0 }.joined(separator: ", ")
    }

    static func spoken(_ text: String) -> String {
        spoken(tokens(in: text))
    }

    static func moves(_ tokens: [String]) -> [ComboMove?] {
        tokens.map(ComboMoves.move(for:))
    }

    static let defaultCall = ["1", "2"]
}
