#if os(iOS)
import SwiftUI

struct OutdoorMapModePicker: View {
    let selectedMode: OutdoorMapMode
    let activeMode: OutdoorMapMode
    let capabilities: [OutdoorMapMode: OutdoorMapCapability]
    let onSelect: (OutdoorMapMode) -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 8) {
                    ForEach(OutdoorMapMode.allCases) { mode in
                        modeButton(mode)
                    }
                }
                .padding(.horizontal, 2)
                .padding(.vertical, 2)
            }
            .scrollClipDisabledIfAvailable()

            capabilitySummary
        }
    }

    private func modeButton(_ mode: OutdoorMapMode) -> some View {
        let capability = capabilities[mode] ?? OutdoorMapProviderConfiguration.main.capability(for: mode)
        let selected = mode == selectedMode
        return Button {
            onSelect(mode)
        } label: {
            VStack(spacing: 6) {
                Image(systemName: mode.systemImageName)
                    .font(.system(size: 18, weight: .semibold))
                    .frame(height: 22)
                Text(mode.displayName)
                    .font(.caption.weight(.semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.78)
                Image(systemName: capability.isUsable ? (selected ? "checkmark.circle.fill" : "circle") : "exclamationmark.circle")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(capability.isUsable ? (selected ? Theme.restAccent : Theme.textSecondary) : .yellow)
            }
            .foregroundStyle(selected ? Theme.textPrimary : Theme.textSecondary)
            .frame(width: 78, height: 82)
            .background(selected ? Theme.restAccent.opacity(0.18) : Theme.surface.opacity(0.72), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(selected ? Theme.restAccent.opacity(0.68) : Color.white.opacity(0.12), lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Map mode, \(mode.displayName)")
        .accessibilityValue(accessibilityValue(for: mode, capability: capability, selected: selected))
        .accessibilityHint(capability.reason ?? (capability.isUsable ? "Selects this presentation on the current map." : "Unavailable mode; shows its real requirement."))
        .animation(reduceMotion ? .none : .easeOut(duration: 0.18), value: selected)
    }

    @ViewBuilder
    private var capabilitySummary: some View {
        let capability = capabilities[selectedMode] ?? OutdoorMapProviderConfiguration.main.capability(for: selectedMode)
        if capability.isUsable {
            VStack(alignment: .leading, spacing: 3) {
                Text("Active map: \(activeMode.displayName)")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Theme.textPrimary)
                Text(attributionText(for: capability))
                    .font(.caption2)
                    .foregroundStyle(Theme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        } else {
            VStack(alignment: .leading, spacing: 3) {
                Text("\(selectedMode.displayName) unavailable")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.yellow)
                Text(capability.reason ?? statusText(capability.status))
                    .font(.caption2)
                    .foregroundStyle(Theme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                Text("Active map remains \(activeMode.displayName).")
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(Theme.textSecondary)
            }
        }
    }

    private func accessibilityValue(for mode: OutdoorMapMode, capability: OutdoorMapCapability, selected: Bool) -> String {
        let state = selected ? "Selected" : "Not selected"
        let availability = capability.isUsable ? "Available" : statusText(capability.status)
        return "\(state), \(availability)"
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

private extension View {
    @ViewBuilder
    func scrollClipDisabledIfAvailable() -> some View {
        if #available(iOS 17.0, *) {
            scrollClipDisabled()
        } else {
            self
        }
    }
}
#endif
