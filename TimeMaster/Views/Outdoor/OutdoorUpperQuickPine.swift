#if os(iOS)
import SwiftUI

struct OutdoorUpperQuickPine: View {
    let feature: OutdoorUpperQuickFeature
    let namespace: Namespace.ID
    let mapMode: OutdoorMapMode
    let activeMapMode: OutdoorMapMode
    let mapCapabilities: [OutdoorMapMode: OutdoorMapCapability]
    @ObservedObject var preferences: OutdoorRecordingPreferencesStore
    let offlineCapabilities: [OutdoorMapCapability]
    let onMapMode: (OutdoorMapMode) -> Void
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
        Button(action: onDismiss) {
            HStack(spacing: 8) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 17, weight: .semibold))

                Text(feature.title)
                    .font(.headline.weight(.semibold))
                    .lineLimit(1)

                Spacer(minLength: 0)
            }
            .foregroundStyle(Theme.textPrimary)
            .padding(.leading, 12)
            .padding(.trailing, 12)
            .frame(height: 54)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Close \(feature.title) quick pane")
        .accessibilityHint("Returns focus to the map quick controls.")
    }



    @ViewBuilder
    private var content: some View {
        switch feature {
        case .map:
            OutdoorMapModePicker(
                selectedMode: mapMode,
                activeMode: activeMapMode,
                capabilities: mapCapabilities,
                onSelect: onMapMode
            )
            .padding(.horizontal, 10)
            .padding(.bottom, 10)
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
