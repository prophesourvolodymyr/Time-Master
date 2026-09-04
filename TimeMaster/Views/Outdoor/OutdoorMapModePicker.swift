#if os(iOS)
import SwiftUI

struct OutdoorMapModePicker: View {
    let baseMode: OutdoorMapMode
    let enabledOverlays: Set<OutdoorMapMode>
    let activeMode: OutdoorMapMode
    let capabilities: [OutdoorMapMode: OutdoorMapCapability]
    let onBaseSelect: (OutdoorMapMode) -> Void
    let onToggleOverlay: (OutdoorMapMode) -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let baseTileHeight: CGFloat = 76
    private let overlayTileWidth: CGFloat = 58
    private let overlayTileHeight: CGFloat = 66

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            sectionTitle("Map view")
            HStack(spacing: 7) {
                ForEach(OutdoorMapMode.baseModes) { mode in
                    modeButton(mode, isBase: true)
                        .frame(maxWidth: .infinity)
                }
            }
            .frame(height: baseTileHeight)

            sectionTitle("Map overlays")
            HStack(spacing: 5) {
                ForEach(OutdoorMapMode.overlayModes) { mode in
                    modeButton(mode, isBase: false)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: overlayTileHeight)

            capabilitySummary
                .padding(.horizontal, 2)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private func sectionTitle(_ title: String) -> some View {
        Text(title)
            .font(.caption.weight(.semibold))
            .foregroundStyle(Theme.textPrimary.opacity(0.78))
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func modeButton(_ mode: OutdoorMapMode, isBase: Bool) -> some View {
        let capability = capabilities[mode] ?? OutdoorMapProviderConfiguration.main.capability(for: mode)
        let selected = isBase ? mode == baseMode : enabledOverlays.contains(mode)
        let enabled = capability.isUsable
        let tileHeight = isBase ? baseTileHeight : overlayTileHeight

        return Button {
            guard enabled else { return }
            if isBase {
                onBaseSelect(mode)
            } else {
                onToggleOverlay(mode)
            }
        } label: {
            ZStack(alignment: .topTrailing) {
                VStack(spacing: 4) {
                    Image(systemName: mode.systemImageName)
                        .font(.system(size: isBase ? 21 : 19, weight: .semibold))
                        .frame(height: isBase ? 28 : 24)
                    Text(mode.displayName)
                        .font(.caption2.weight(.semibold))
                        .lineLimit(1)
                        .minimumScaleFactor(0.68)
                        .frame(maxWidth: .infinity)
                }
                .foregroundStyle(selected ? Theme.textPrimary : Theme.textSecondary)
                .frame(
                    minWidth: isBase ? 0 : overlayTileWidth,
                    maxWidth: isBase ? .infinity : overlayTileWidth,
                    minHeight: tileHeight,
                    maxHeight: tileHeight
                )
                .overlay {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .strokeBorder(
                            selected ? Theme.restAccent.opacity(0.68) : Color.white.opacity(0.12),
                            lineWidth: 1
                        )
                }

                Image(systemName: selected ? "checkmark.circle.fill" : enabled ? "circle" : "lock.fill")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(
                        selected
                            ? Theme.restAccent
                            : enabled ? Theme.textSecondary : Theme.textSecondary.opacity(0.7)
                    )
                    .padding(5)
            }
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
        .opacity(enabled ? 1 : 0.52)
        .accessibilityLabel("Map mode, \(mode.displayName)")
        .accessibilityValue(accessibilityValue(for: mode, capability: capability, selected: selected, enabled: enabled, isBase: isBase))
        .accessibilityHint(cardHint(for: mode, capability: capability, enabled: enabled, isBase: isBase))
        .animation(reduceMotion ? .none : .easeOut(duration: 0.18), value: selected)
    }

    @ViewBuilder
    private var capabilitySummary: some View {
        let capability = capabilities[baseMode] ?? OutdoorMapProviderConfiguration.main.capability(for: baseMode)
        if capability.isUsable {
            VStack(alignment: .leading, spacing: 2) {
                Text("Base map: \(activeMode.displayName)")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Theme.textPrimary)
                Text(enabledOverlaySummary)
                    .font(.caption2)
                    .foregroundStyle(Theme.textSecondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
        } else {
            VStack(alignment: .leading, spacing: 2) {
                Text("\(baseMode.displayName) unavailable")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.yellow)
                Text(capability.reason ?? statusText(capability.status))
                    .font(.caption2)
                    .foregroundStyle(Theme.textSecondary)
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)
            }
        }
    }

    private var enabledOverlaySummary: String {
        let names = OutdoorMapMode.overlayModes
            .filter(enabledOverlays.contains)
            .map(\.displayName)
        return names.isEmpty ? "Overlays: None" : "Overlays: \(names.joined(separator: ", "))"
    }

    private func accessibilityValue(
        for mode: OutdoorMapMode,
        capability: OutdoorMapCapability,
        selected: Bool,
        enabled: Bool,
        isBase: Bool
    ) -> String {
        let state: String
        if isBase {
            state = selected ? "Selected base view" : "Not selected base view"
        } else {
            state = selected ? "Selected, On" : "Not selected, Off"
        }
        let availability = enabled ? "Available" : statusText(capability.status)
        return "\(state), \(availability)"
    }

    private func cardHint(
        for mode: OutdoorMapMode,
        capability: OutdoorMapCapability,
        enabled: Bool,
        isBase: Bool
    ) -> String {
        if !enabled {
            return capability.reason ?? "This map option is unavailable."
        }
        return isBase
            ? "Changes the base map view."
            : "Toggles this overlay without changing the base map view."
    }

    private func statusText(_ status: OutdoorMapCapabilityStatus) -> String {
        switch status {
        case .available: "Available"
        case .missingCredential: "Credential required"
        case .missingEndpoint: "Provider endpoint required"
        case .unsupported: "Unsupported by this provider"
        case .limitedCoverage: "Limited regional coverage"
        case .networkRequired: "Network required"
        case .providerError: "Provider error"
        }
    }
}


#endif
