import SwiftUI

enum CollectibleArtworkPalette {
    static let white = Color.white
    static let graphite = Color(red: 0.24, green: 0.27, blue: 0.31)

    static func variant(for item: CollectibleItem) -> Int {
        let remainder = item.variant % 3
        return remainder >= 0 ? remainder : remainder + 3
    }

    static func colors(for item: CollectibleItem) -> [Color] {
        switch item.category {
        case .avatar:
            switch variant(for: item) {
            case 0:
                return [Color(red: 0.78, green: 0.95, blue: 0.50), .white, Color(red: 0.33, green: 0.70, blue: 0.49)]
            case 1:
                return [Color(red: 0.20, green: 0.88, blue: 0.92), Color(red: 0.54, green: 0.38, blue: 0.98), Color(red: 0.98, green: 0.42, blue: 0.78)]
            default:
                return [Color(red: 1.0, green: 0.42, blue: 0.14), Color(red: 1.0, green: 0.82, blue: 0.25), .white]
            }
        case .name:
            switch variant(for: item) {
            case 0:
                return [.white, Color(red: 0.68, green: 0.74, blue: 0.82), Color(red: 0.35, green: 0.43, blue: 0.52)]
            case 1:
                return [Color(red: 0.27, green: 0.88, blue: 1.0), Color(red: 0.53, green: 0.43, blue: 1.0), Color(red: 1.0, green: 0.42, blue: 0.78)]
            default:
                return [Color(red: 1.0, green: 0.52, blue: 0.22), Color(red: 1.0, green: 0.82, blue: 0.28), Color(red: 0.98, green: 0.34, blue: 0.54)]
            }
        case .badge:
            switch variant(for: item) {
            case 0:
                return [.white, Color(red: 0.74, green: 0.80, blue: 0.88), Color(red: 0.35, green: 0.42, blue: 0.53)]
            case 1:
                return [Color(red: 0.29, green: 0.89, blue: 1.0), Color(red: 0.56, green: 0.40, blue: 1.0), Color(red: 1.0, green: 0.47, blue: 0.78)]
            default:
                return [Color(red: 0.99, green: 0.25, blue: 0.10), Color(red: 1.0, green: 0.64, blue: 0.18), Color(red: 1.0, green: 0.89, blue: 0.34)]
            }
        case .entrance:
            switch variant(for: item) {
            case 0:
                return [Color(red: 0.93, green: 0.95, blue: 1.0), Color(red: 0.51, green: 0.56, blue: 0.72), Color(red: 0.20, green: 0.23, blue: 0.38)]
            case 1:
                return [Color(red: 0.30, green: 0.89, blue: 1.0), Color(red: 0.57, green: 0.43, blue: 1.0), Color(red: 1.0, green: 0.45, blue: 0.77)]
            default:
                return [Color(red: 1.0, green: 0.75, blue: 0.22), Color(red: 1.0, green: 0.39, blue: 0.15), Color(red: 0.99, green: 0.89, blue: 0.47)]
            }
        }
    }

    static func smoothStep(_ value: Double) -> Double {
        let clamped = min(max(value, 0), 1)
        return clamped * clamped * (3 - 2 * clamped)
    }
}
