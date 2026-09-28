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
    var fullscreenBounds: CGRect? = nil
    static let quickStackHeight: CGFloat = 148
    private var minimumInteractivePaneHeight: CGFloat { 48 + 44 * 2 + 8 + 12 }

    var usableHeight: CGFloat {
        max(1, size.height - safeAreaTop - safeAreaBottom)
    }

    var lowerInset: CGFloat {
        safeAreaBottom + 10 + playerReserve
    }

    var mainCompactHeight: CGFloat {
        min(mainFullHeight, max(minimumInteractivePaneHeight, usableHeight * 0.35))
    }

    var mainMediumHeight: CGFloat {
        min(mainFullHeight, usableHeight * 0.60)
    }

    var mainFullHeight: CGFloat {
        max(1, size.height - safeAreaTop - lowerInset - 8)
    }

    var mainMaximumFrame: CGRect {
        fullscreenBounds ?? CGRect(
            x: 0,
            y: -safeAreaTop,
            width: size.width,
            height: size.height + safeAreaTop + safeAreaBottom
        )
    }

    var mainMaximumHeight: CGFloat {
        mainMaximumFrame.height
    }

    var mainMaximumBottomPadding: CGFloat {
        max(0, mainMaximumFrame.maxY - size.height) + lowerInset
    }

    var fullscreenDragTravel: CGFloat {
        max(44, mainTop(mainHeight: mainFullHeight, featureHeight: nil) - mainMaximumFrame.minY)
    }

    func fullscreenProgress(forProposedHeight height: CGFloat) -> CGFloat {
        min(1, max(0, (height - mainFullHeight) / fullscreenDragTravel))
    }

    var featureCompactHeight: CGFloat {
        usableHeight * 0.30
    }

    var musicCompactHeight: CGFloat {
        usableHeight * 0.28
    }

    var musicMediumHeight: CGFloat {
        usableHeight * 0.48
    }

    var featureMediumHeight: CGFloat {
        usableHeight * 0.53
    }

    var featureExpandedHeight: CGFloat {
        usableHeight * 0.70
    }

    var musicFitHeight: CGFloat {
        usableHeight * 0.62
    }

    var musicMaximumHeight: CGFloat {
        usableHeight * 0.70
    }

    var compactPlayerReserve: CGFloat {
        94
    }

    var featureCloseThreshold: CGFloat {
        usableHeight * 0.12
    }

    var mainMinimumWithFeature: CGFloat {
        min(mainFullHeight, max(minimumInteractivePaneHeight, usableHeight * 0.28))
    }

    func maximumFeatureHeight(music: Bool) -> CGFloat {
        max(1, min(music ? musicMaximumHeight : featureExpandedHeight, mainFullHeight - mainMinimumWithFeature))
    }

    func featureDragLayout(proposedHeight: CGFloat, music: Bool, allowsDismissal: Bool) -> (height: CGFloat, offset: CGFloat) {
        let maximum = maximumFeatureHeight(music: music)
        let minimum = min(maximum, music ? musicCompactHeight : featureCompactHeight)
        return (
            height: min(maximum, max(minimum, proposedHeight)),
            offset: allowsDismissal ? max(0, minimum - proposedHeight) : 0
        )
    }

    func mainHeight(for detent: OutdoorPineDetent) -> CGFloat {
        switch detent {
        case .compact: mainCompactHeight
        case .medium: mainMediumHeight
        case .expanded: mainFullHeight
        case .max: mainMaximumHeight
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
        case .max: music ? musicMaximumHeight : usableHeight * 0.31
        }
    }

    func mainTop(mainHeight: CGFloat, featureHeight: CGFloat?, gap: CGFloat = 8) -> CGFloat {
        let featureTop = featureHeight.map { size.height - lowerInset - $0 } ?? (size.height - lowerInset)
        let bottom = featureHeight == nil ? size.height - lowerInset : featureTop - gap
        return max(safeAreaTop, bottom - mainHeight)
    }

    func mainFrame(mainHeight: CGFloat, featureHeight: CGFloat?, fullscreenProgress: CGFloat) -> CGRect {
        let progress = min(1, max(0, fullscreenProgress))
        let inset: CGFloat = 10
        let top = mainTop(mainHeight: mainHeight, featureHeight: featureHeight)
        let maximum = mainMaximumFrame
        return CGRect(
            x: inset + (maximum.minX - inset) * progress,
            y: top + (maximum.minY - top) * progress,
            width: size.width - inset * 2 + (maximum.width - size.width + inset * 2) * progress,
            height: mainHeight + (maximum.height - mainHeight) * progress
        )
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
    var horizontalTranslation: CGFloat = 0

    var handleBend: CGFloat {
        guard isDragging else { return 0 }
        return 6 * lastTranslation / (abs(lastTranslation) + 48)
    }

    var handleBias: CGFloat {
        guard isDragging else { return 0 }
        return 8 * horizontalTranslation / (abs(horizontalTranslation) + 48)
    }

    mutating func begin(at value: CGFloat) {
        isDragging = true
        startValue = value
        lastTranslation = 0
        horizontalTranslation = 0
    }

    mutating func update(translation: CGFloat, horizontal: CGFloat = 0) {
        lastTranslation = translation
        horizontalTranslation = horizontal
    }

    mutating func end() {
        isDragging = false
        lastTranslation = 0
        horizontalTranslation = 0
    }
}

extension OutdoorActivityKind {
    static var newRecordingChoices: [OutdoorActivityKind] {
        [.run, .bike, .walk]
    }
}
#endif
