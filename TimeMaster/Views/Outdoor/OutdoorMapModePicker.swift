#if os(iOS)
import SwiftUI

struct OutdoorMapModePicker: View {
    let baseMode: OutdoorMapMode
    let enabledOverlays: Set<OutdoorMapMode>
    let capabilities: [OutdoorMapMode: OutdoorMapCapability]
    let onBaseSelect: (OutdoorMapMode) -> Void
    let onToggleOverlay: (OutdoorMapMode) -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        GeometryReader { proxy in
            let spacing: CGFloat = 6
            let availableHeight = max(0, proxy.size.height - spacing)
            let baseHeight = availableHeight * 0.54
            let overlayHeight = availableHeight - baseHeight

            VStack(spacing: spacing) {
                HStack(spacing: spacing) {
                    ForEach(OutdoorMapMode.baseModes) { mode in
                        modeButton(mode, isBase: true, height: baseHeight)
                    }
                }

                HStack(spacing: spacing) {
                    ForEach(OutdoorMapMode.overlayModes) { mode in
                        modeButton(mode, isBase: false, height: overlayHeight)
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
        .padding(.horizontal, 8)
        .padding(.bottom, 8)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    private func modeButton(_ mode: OutdoorMapMode, isBase: Bool, height: CGFloat) -> some View {
        let capability = capabilities[mode] ?? OutdoorMapProviderConfiguration.main.capability(for: mode)
        let selected = isBase ? mode == baseMode : enabledOverlays.contains(mode)
        let enabled = capability.isUsable

        return Button {
            guard enabled else { return }
            if isBase {
                onBaseSelect(mode)
            } else {
                onToggleOverlay(mode)
            }
        } label: {
            VStack(spacing: isBase ? 6 : 4) {
                Image(systemName: mode.systemImageName)
                    .font(.system(size: isBase ? 22 : 18, weight: .semibold))
                    .frame(height: isBase ? 28 : 22)
                Text(mode.displayName)
                    .font(
                        .custom(
                            isBase ? "Inter Black" : "Inter Light",
                            size: isBase ? 14 : 12,
                            relativeTo: .caption2
                        )
                    )
                    .lineLimit(1)
                    .minimumScaleFactor(0.68)
            }
            .foregroundStyle(selected ? Theme.textPrimary : Theme.textSecondary)
            .frame(maxWidth: .infinity, minHeight: height, maxHeight: height)
            .background {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(selected ? Theme.toolbarOrange.opacity(0.20) : Color.white.opacity(0.05))
            }
            .overlay {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(
                        selected ? Theme.toolbarOrange.opacity(0.78) : Color.white.opacity(0.12),
                        lineWidth: 1
                    )
            }
            .overlay(alignment: .topTrailing) {
                if selected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Theme.toolbarOrange)
                        .padding(6)
                } else if !enabled {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(Theme.textSecondary.opacity(0.7))
                        .padding(6)
                }
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
