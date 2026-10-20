#if os(iOS)
import SwiftUI

struct OutdoorMapQuickStack: View, Animatable {
    var geometry: OutdoorMapUtilityGeometry
    let onSelect: (OutdoorUpperQuickFeature) -> Void


    var animatableData: AnimatablePair<CGFloat, CGFloat> {
        get { AnimatablePair(geometry.rowProgress, geometry.columnTop) }
        set {
            geometry.rowProgress = newValue.first
            geometry.columnTop = newValue.second
        }
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            quickButton(.map, systemImage: "map", label: "Open map quick pane")
                .position(geometry.position(at: 0))
            quickButton(.trophy, systemImage: "trophy", label: "Open trophy quick pane")
                .position(geometry.position(at: 1))
            quickButton(.settings, systemImage: "gearshape", label: "Open settings quick pane")
                .position(geometry.position(at: 2))
        }
        .opacity(geometry.opacity)
        .allowsHitTesting(geometry.opacity > 0.05)
        .accessibilityHidden(geometry.opacity <= 0.05)
    }

    private func quickButton(_ feature: OutdoorUpperQuickFeature, systemImage: String, label: String) -> some View {
        Button {
            onSelect(feature)
        } label: {
            Image(systemName: systemImage)
                .font(.system(size: 17, weight: .semibold))
        }
        .buttonStyle(TimeMasterActionButtonStyle(circular: true))
        .accessibilityLabel(label)
        .accessibilityHint("Opens the shared upper quick pane from this control.")
    }

}

#endif
