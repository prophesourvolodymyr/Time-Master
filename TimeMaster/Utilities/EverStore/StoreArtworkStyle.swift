import SwiftUI

enum StoreArtworkStyle: String, CaseIterable, Identifiable, Hashable {
    case orbit, frame, tempo, grove, pixel, prism, paper, mono

    var id: String { rawValue }

    var color: Color {
        switch self {
        case .orbit: Color(red: 0.84, green: 0.94, blue: 0.55)
        case .frame: Color(red: 0.96, green: 0.58, blue: 0.39)
        case .tempo: Color(red: 0.64, green: 0.73, blue: 0.97)
        case .grove: Color(red: 0.55, green: 0.77, blue: 0.64)
        case .pixel: Color(red: 0.98, green: 0.76, blue: 0.39)
        case .prism: Color(red: 0.90, green: 0.59, blue: 0.66)
        case .paper: Color(red: 0.88, green: 0.84, blue: 0.74)
        case .mono: Color(white: 0.84)
        }
    }

    var ink: Color { Color(red: 0.08, green: 0.12, blue: 0.12) }
}
