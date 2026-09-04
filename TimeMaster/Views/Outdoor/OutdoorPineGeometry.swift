#if os(iOS)
import SwiftUI

enum OutdoorRouteFeature: String, CaseIterable, Identifiable {
    case type
    case music
    case rate
    case route

    var id: String { rawValue }

    var title: String {
        rawValue.capitalized
    }

    var systemImage: String {
        switch self {
        case .type: "circle.grid.2x2"
        case .music: "music.note"
        case .rate: "heart"
        case .route: "point.topleft.down.curvedto.point.bottomright.up"
        }
    }
}

enum OutdoorPineDetent: String, CaseIterable, Identifiable {
    case compact
    case medium
    case expanded
    case max

    var id: String { rawValue }

    var accessibilityName: String {
        switch self {
        case .compact: "Compact"
        case .medium: "Medium"
        case .expanded: "Full"
        case .max: "Maximum"
        }
    }
}

struct OutdoorPineGeometry: Equatable {
    var size: CGSize
    var safeAreaTop: CGFloat
    var safeAreaBottom: CGFloat
    var playerReserve: CGFloat
    static let quickStackHeight: CGFloat = 148

    var usableHeight: CGFloat {
        max(1, size.height - safeAreaTop - safeAreaBottom)
    }

    var lowerInset: CGFloat {
        (playerReserve > 0 ? safeAreaBottom : 0) + 10 + playerReserve
    }

    var mainCompactHeight: CGFloat {
        usableHeight * 0.30
    }

    var mainMediumHeight: CGFloat {
        usableHeight * 0.60
    }

    var mainFullHeight: CGFloat {
        max(mainMediumHeight, usableHeight - 12)
    }

    var featureCompactHeight: CGFloat {
        usableHeight * 0.30
    }

    var musicCompactHeight: CGFloat {
        usableHeight * 0.14
    }

    var musicMediumHeight: CGFloat {
        usableHeight * 0.17
    }

    var featureMediumHeight: CGFloat {
        usableHeight * 0.53
    }

    var featureExpandedHeight: CGFloat {
        usableHeight * 0.70
    }

    var musicFitHeight: CGFloat {
        usableHeight * 0.20
    }

    var musicMaximumHeight: CGFloat {
        usableHeight * 0.20
    }

    var compactPlayerReserve: CGFloat {
        94
    }

    var featureCloseThreshold: CGFloat {
        usableHeight * 0.12
    }

    var mainMinimumWithFeature: CGFloat {
        usableHeight * 0.22
    }

    func mainHeight(for detent: OutdoorPineDetent) -> CGFloat {
        switch detent {
        case .compact: mainCompactHeight
        case .medium: mainMediumHeight
        case .expanded: mainFullHeight
        case .max: usableHeight
        }
    }
    var libraryHeight: CGFloat {
        min(mainFullHeight, max(mainMediumHeight, usableHeight * 0.67))
    }

    func featureHeight(for detent: OutdoorPineDetent, music: Bool = false) -> CGFloat {
        switch detent {
        case .compact: music ? musicCompactHeight : featureCompactHeight
        case .medium: music ? musicMediumHeight : featureMediumHeight
        case .expanded: music ? musicFitHeight : featureExpandedHeight
        case .max: usableHeight * 0.31
        }
    }

    func mainTop(mainHeight: CGFloat, featureHeight: CGFloat?, gap: CGFloat = 8) -> CGFloat {
        let featureTop = featureHeight.map { size.height - lowerInset - $0 } ?? (size.height - lowerInset)
        let bottom = featureHeight == nil ? size.height - lowerInset : featureTop - gap
        return max(safeAreaTop, bottom - mainHeight)
    }

    func quickStackTop(mainTop: CGFloat, preferred: CGFloat = 112, stackHeight: CGFloat = Self.quickStackHeight) -> CGFloat {
        return max(safeAreaTop + 8, min(preferred, mainTop - 12 - stackHeight))
    }

    func quickStackOpacity(mainTop: CGFloat, stackHeight: CGFloat = Self.quickStackHeight) -> CGFloat {
        let available = mainTop - 12 - safeAreaTop
        return max(0, min(1, (available - stackHeight + 34) / 34))
    }
}

struct OutdoorPineDragState: Equatable {
    var isDragging = false
    var startValue: CGFloat = 0
    var lastTranslation: CGFloat = 0

    mutating func begin(at value: CGFloat) {
        isDragging = true
        startValue = value
        lastTranslation = 0
    }

    mutating func update(translation: CGFloat) {
        lastTranslation = translation
    }

    mutating func end() {
        isDragging = false
        lastTranslation = 0
    }
}

extension OutdoorActivityKind {
    static var newRecordingChoices: [OutdoorActivityKind] {
        [.run, .bike, .walk]
    }
}
#endif
