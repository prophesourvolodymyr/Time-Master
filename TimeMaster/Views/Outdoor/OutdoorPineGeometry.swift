#if os(iOS)
import SwiftUI

enum OutdoorRouteFeature: String, CaseIterable, Identifiable {
    case type
    case music
    case rate
    case route
    case library

    var id: String { rawValue }

    var title: String {
        switch self {
        case .rate: "Heart"
        case .route: "Routes"
        default: rawValue.capitalized
        }
    }

    var systemImage: String {
        switch self {
        case .type: "circle.grid.2x2"
        case .music: "music.note"
        case .rate: "heart"
        case .route: "point.topleft.down.curvedto.point.bottomright.up"
        case .library: "square.grid.2x2"
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
    private var minimumInteractivePaneHeight: CGFloat { 48 + 44 * 2 + 8 + 12 + 6 }

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
        mainMaximumHeight * 0.95
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

    var fullscreenPrimaryHeight: CGFloat {
        mainMaximumHeight * 0.30
    }

    var fullscreenFeatureFrame: CGRect {
        CGRect(
            x: mainMaximumFrame.minX,
            y: mainMaximumFrame.minY + fullscreenPrimaryHeight,
            width: mainMaximumFrame.width,
            height: mainMaximumHeight - fullscreenPrimaryHeight
        )
    }

    var fullscreenDragTravel: CGFloat {
        max(44, mainMaximumHeight - mainFullHeight)
    }

    func clampedMainHeight(_ proposed: CGFloat, featureHeight: CGFloat? = nil) -> CGFloat {
        let minimum = featureHeight == nil ? mainCompactHeight : mainMinimumWithFeature
        let maximum = featureHeight.map {
            max(minimum, min(mainFullHeight, size.height - lowerInset - $0 - safeAreaTop - 8))
        } ?? mainFullHeight
        return min(maximum, max(minimum, proposed))
    }

    func actionLabelProgress(for height: CGFloat) -> CGFloat {
        let value = min(1, max(0, (height / mainMaximumHeight - 0.60) / 0.08))
        return value * value * (3 - 2 * value)
    }

    func utilityOpacity(for height: CGFloat) -> CGFloat {
        min(1, max(0, (mainMaximumHeight - height) / (mainMaximumHeight * 0.05)))
    }

    func utilityRowProgress(for height: CGFloat) -> CGFloat {
        let value = min(1, max(0, (height / mainMaximumHeight - 0.50) / 0.30))
        return value * value * (3 - 2 * value)
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
        let available = size.height - safeAreaTop - lowerInset - 8 - mainMinimumWithFeature
        return max(1, min(music ? musicMaximumHeight : featureExpandedHeight, available))
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
        case .max: fullscreenFeatureFrame.height
        }
    }

    func mainTop(mainHeight: CGFloat, featureHeight: CGFloat?, gap: CGFloat = 8) -> CGFloat {
        if let featureHeight {
            return max(safeAreaTop, size.height - lowerInset - featureHeight - gap - mainHeight)
        }
        let progress = min(1, max(0, (mainHeight - mainMediumHeight) / max(1, mainFullHeight - mainMediumHeight)))
        let normalBottom = size.height - lowerInset
        let expandedBottom = mainMaximumFrame.maxY - 10
        let bottom = normalBottom + (expandedBottom - normalBottom) * progress
        return max(mainMaximumFrame.minY, bottom - mainHeight)
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

}

struct OutdoorMapUtilityGeometry: Equatable {
    var width: CGFloat
    var columnTop: CGFloat
    var rowTop: CGFloat
    var rowProgress: CGFloat
    var opacity: CGFloat

    func position(at index: Int, trailing: Bool = false) -> CGPoint {
        let edge: CGFloat = 33
        let spacing: CGFloat = 52
        let columnX = trailing ? width - edge : edge
        let rowY = rowTop + 22
        let p = min(1, max(0, rowProgress))
        let inverse = 1 - p
        let horizontal = sin(p * .pi / 2)
        let vertical = cos(p * .pi / 2)
        let h2 = horizontal * horizontal
        let v2 = vertical * vertical
        let h4 = h2 * h2
        let v4 = v2 * v2
        let stride = spacing / sqrt(sqrt(sqrt(h4 * h4 + v4 * v4)))
        return CGPoint(
            x: columnX + CGFloat(index) * stride * horizontal * (trailing ? -1 : 1),
            y: rowY + (columnTop - rowTop) * inverse * inverse * inverse + CGFloat(index) * stride * vertical
        )
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
