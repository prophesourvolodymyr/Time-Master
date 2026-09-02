#if os(iOS)
import SwiftUI

struct OutdoorMapModePicker: View {
    let selectedMode: OutdoorMapMode
    let activeMode: OutdoorMapMode
    let capabilities: [OutdoorMapMode: OutdoorMapCapability]
    let onSelect: (OutdoorMapMode) -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let tileWidth: CGFloat = 78
    private let tileHeight: CGFloat = 78

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHGrid(
                    rows: [
                        GridItem(.fixed(tileHeight)),
                        GridItem(.fixed(tileHeight))
                    ],
                    spacing: 8
                ) {
                    ForEach(OutdoorMapMode.allCases) { mode in
                        modeButton(mode)
                    }
                }
                .padding(.horizontal, 2)
                .padding(.vertical, 2)
            }
            .frame(height: tileHeight * 2 + 12)
            .scrollIndicators(.hidden)

            capabilitySummary
                .padding(.horizontal, 2)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private func modeButton(_ mode: OutdoorMapMode) -> some View {
        let capability = capabilities[mode] ?? OutdoorMapProviderConfiguration.main.capability(for: mode)
        let selected = mode == selectedMode
        let enabled = isModeEnabled(mode, capability: capability)

        return Button {
            guard enabled else { return }
            onSelect(mode)
        } label: {
            ZStack(alignment: .topTrailing) {
                VStack(spacing: 5) {
                    Image(systemName: mode.systemImageName)
                        .font(.system(size: 22, weight: .semibold))
                        .frame(height: 28)
                    Text(mode.displayName)
                        .font(.caption2.weight(.semibold))
                        .lineLimit(1)
                        .minimumScaleFactor(0.72)
                        .frame(maxWidth: .infinity)
                }
                .foregroundStyle(selected ? Theme.textPrimary : Theme.textSecondary)
                .frame(width: tileWidth, height: tileHeight)
                .background(
                    selected ? Theme.restAccent.opacity(0.18) : Theme.surface.opacity(0.72),
                    in: RoundedRectangle(cornerRadius: 14, style: .continuous)
                )
                .overlay {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .strokeBorder(
                            selected ? Theme.restAccent.opacity(0.68) : Color.white.opacity(0.12),
                            lineWidth: 1
                        )
                }

                Image(systemName: selected ? "checkmark.circle.fill" : enabled ? "circle" : "lock.fill")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(
                        selected
                            ? Theme.restAccent
                            : enabled ? Theme.textSecondary : Theme.textSecondary.opacity(0.7)
                    )
                    .padding(6)
            }
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
        .opacity(enabled ? 1 : 0.52)
        .accessibilityLabel("Map mode, \(mode.displayName)")
        .accessibilityValue(accessibilityValue(for: mode, capability: capability, selected: selected, enabled: enabled))
        .accessibilityHint(cardHint(for: mode, capability: capability, enabled: enabled))
        .animation(reduceMotion ? .none : .easeOut(duration: 0.18), value: selected)
    }

    private func isModeEnabled(_ mode: OutdoorMapMode, capability: OutdoorMapCapability) -> Bool {
        guard capability.isUsable else { return false }
        guard selectedMode == .terrain || selectedMode == .satellite else { return true }
        return mode == selectedMode || ![.threeD, .transit, .traffic, .cycling, .direction].contains(mode)
    }

    @ViewBuilder
    private var capabilitySummary: some View {
        let capability = capabilities[selectedMode] ?? OutdoorMapProviderConfiguration.main.capability(for: selectedMode)
        if capability.isUsable {
            VStack(alignment: .leading, spacing: 2) {
                Text("Active map: \(activeMode.displayName)")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Theme.textPrimary)
                Text(attributionText(for: capability))
                    .font(.caption2)
                    .foregroundStyle(Theme.textSecondary)
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)
            }
        } else {
            VStack(alignment: .leading, spacing: 2) {
                Text("\(selectedMode.displayName) unavailable")
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

    private func accessibilityValue(
        for mode: OutdoorMapMode,
        capability: OutdoorMapCapability,
        selected: Bool,
        enabled: Bool
    ) -> String {
        let state = selected ? "Selected" : enabled ? "Not selected" : "Unavailable with the current base map"
        let availability = capability.isUsable ? "Available" : statusText(capability.status)
        return "\(state), \(availability)"
    }

    private func cardHint(for mode: OutdoorMapMode, capability: OutdoorMapCapability, enabled: Bool) -> String {
        if !enabled, capability.isUsable {
            return "This layer requires a vector base map. Select Explore or Dark first."
        }
        return capability.reason ?? (capability.isUsable ? "Selects this presentation on the current map." : "Unavailable mode; shows its real requirement.")
    }

    private func attributionText(for capability: OutdoorMapCapability) -> String {
        let notices = capability.attribution.notices.joined(separator: " · ")
        if notices.isEmpty {
            return "Source: \(capability.attribution.providerName)"
        }
        return "Source: \(capability.attribution.providerName) · \(notices)"
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
