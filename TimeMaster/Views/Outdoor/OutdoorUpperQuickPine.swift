#if os(iOS)
import SwiftUI

struct OutdoorUpperQuickPine: View {
    let feature: OutdoorUpperQuickFeature
    let namespace: Namespace.ID
    let mapMode: OutdoorMapMode
    let enabledOverlays: Set<OutdoorMapMode>
    let mapCapabilities: [OutdoorMapMode: OutdoorMapCapability]
    @ObservedObject var preferences: OutdoorRecordingPreferencesStore
    let offlineCapabilities: [OutdoorMapCapability]
    let onMapMode: (OutdoorMapMode) -> Void
    let onToggleOverlay: (OutdoorMapMode) -> Void
    let onManageMusic: () -> Void
    let onDismiss: () -> Void
    let height: CGFloat

    var body: some View {
        OutdoorPineGlassSurface(
            identity: "route-upper-quick-pine",
            namespace: namespace,
            cornerRadius: 25,
            interactive: true
        ) {
            VStack(spacing: 0) {
                header
                content
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
        .frame(maxWidth: .infinity)
        .frame(height: height)
        .padding(.horizontal, 8)
    }
    private var header: some View {
        HStack(spacing: 8) {
            Text(feature == .map ? "Map" : feature.title)
                .font(.headline.weight(.semibold))
                .lineLimit(1)
                .foregroundStyle(Theme.textPrimary)

            Spacer(minLength: 0)

            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .font(.system(size: 17, weight: .semibold))
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .foregroundStyle(Theme.textPrimary.opacity(0.86))
            .accessibilityLabel("Close \(feature.title) quick pane")
            .accessibilityHint("Returns focus to the map quick controls.")
        }
        .padding(.leading, 16)
        .padding(.trailing, 6)
        .frame(height: 44)
    }



    @ViewBuilder
    private var content: some View {
        switch feature {
        case .map:
            OutdoorMapModePicker(
                baseMode: mapMode,
                enabledOverlays: enabledOverlays,
                capabilities: mapCapabilities,
                onBaseSelect: onMapMode,
                onToggleOverlay: onToggleOverlay
            )
        case .trophy:
            Color.clear
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .accessibilityHidden(true)
        case .settings:
            OutdoorQuickSettingsPine(
                preferences: preferences,
                offlineCapabilities: offlineCapabilities,
                onManageMusic: onManageMusic
            )
        }
    }
}
private extension OutdoorUpperQuickFeature {
    var title: String {
        switch self {
        case .map: "Map"
        case .trophy: "Trophy"
        case .settings: "Settings"
        }
    }
}
#endif
