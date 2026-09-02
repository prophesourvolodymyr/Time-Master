#if os(iOS)
import SwiftUI

struct OutdoorMapModePicker: View {
    let selectedMode: OutdoorMapMode
    let activeMode: OutdoorMapMode
    let capabilities: [OutdoorMapMode: OutdoorMapCapability]
    let onSelect: (OutdoorMapMode) -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Namespace private var selectionNamespace
    @State private var gooeyProgress: CGFloat = 1

    private let baseModes: [OutdoorMapMode] = [.explore, .terrain, .satellite, .dark]
    private let detailModes: [OutdoorMapMode] = [.threeD, .transit, .traffic, .cycling, .direction]

    var body: some View {
        GeometryReader { proxy in
            let destinationRect = CGRect(
                x: 2,
                y: 2,
                width: max(1, proxy.size.width - 4),
                height: max(1, proxy.size.height - 4)
            )
            ZStack(alignment: .topLeading) {
                OutdoorGooeyMorphLayer(
                    progress: gooeyProgress,
                    sourceRect: CGRect(x: 6, y: 6, width: 44, height: 44),
                    destinationRect: destinationRect,
                    sourceRadius: 22,
                    destinationRadius: 18,
                    color: Theme.surface.opacity(0.74)
                )

                ScrollView(.vertical, showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 14) {
                        modeSection("Base Map", modes: baseModes)
                        modeSection("Map Layers", modes: detailModes)
                        capabilitySummary
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                    .padding(.bottom, 10)
                }
                .scrollIndicators(.hidden)
                .opacity(0.84 + (0.16 * gooeyProgress))
                .offset(y: (1 - gooeyProgress) * 8)
            }
            .onAppear(perform: startGooeyExpansion)
        }
    }

    private func startGooeyExpansion() {
        guard !reduceMotion else {
            gooeyProgress = 1
            return
        }
        gooeyProgress = 0
        withAnimation(.spring(response: 0.5, dampingFraction: 0.82)) {
            gooeyProgress = 1
        }
    }

    private func modeSection(_ title: String, modes: [OutdoorMapMode]) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(title.uppercased())
                .font(.caption2.weight(.bold))
                .tracking(0.7)
                .foregroundStyle(Theme.textSecondary)
                .padding(.leading, 4)

            VStack(spacing: 1) {
                ForEach(modes) { mode in
                    modeRow(mode)
                }
            }
            .padding(8)
            .background(Theme.surface.opacity(0.72), in: RoundedRectangle(cornerRadius: 17, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 17, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.11), lineWidth: 1)
            }
        }
    }

    private func modeRow(_ mode: OutdoorMapMode) -> some View {
        let capability = capabilities[mode] ?? OutdoorMapProviderConfiguration.main.capability(for: mode)
        let selected = mode == selectedMode
        let enabled = isModeEnabled(mode, capability: capability)
        return Button {
            guard enabled else { return }
            onSelect(mode)
        } label: {
            ZStack {
                if selected {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Theme.restAccent.opacity(0.22))
                        .matchedGeometryEffect(id: "selected-map-mode", in: selectionNamespace)
                        .blur(radius: 2)
                        .contrast(8)
                }

                HStack(spacing: 10) {
                    Image(systemName: mode.systemImageName)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(selected ? Theme.restAccent : Theme.textSecondary)
                        .frame(width: 24)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(mode.displayName)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(Theme.textPrimary)
                            .lineLimit(1)
                        Text(rowSubtitle(for: mode, capability: capability))
                            .font(.caption2)
                            .foregroundStyle(Theme.textSecondary)
                            .lineLimit(2)
                    }

                    Spacer(minLength: 6)

                    Image(systemName: selected ? "checkmark.circle.fill" : enabled ? "circle" : "lock.fill")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(
                            selected
                                ? Theme.restAccent
                                : enabled ? Theme.textSecondary : Theme.textSecondary.opacity(0.7)
                        )
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 8)
                .contentShape(Rectangle())
            }
            .frame(minHeight: 56)
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
        .opacity(enabled ? 1 : 0.52)
        .accessibilityLabel("Map mode, \(mode.displayName)")
        .accessibilityValue(accessibilityValue(for: mode, capability: capability, selected: selected, enabled: enabled))
        .accessibilityHint(rowHint(for: mode, capability: capability, enabled: enabled))
    }

    private func isModeEnabled(_ mode: OutdoorMapMode, capability: OutdoorMapCapability) -> Bool {
        guard capability.isUsable else { return false }
        guard selectedMode == .terrain || selectedMode == .satellite else { return true }
        return mode == selectedMode || !detailModes.contains(mode)
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

    private func rowSubtitle(for mode: OutdoorMapMode, capability: OutdoorMapCapability) -> String {
        if !capability.isUsable {
            return capability.reason ?? statusText(capability.status)
        }
        switch mode {
        case .explore: return "Vector streets, paths, and places"
        case .terrain: return "Elevation, hillshade, and contours"
        case .satellite: return "Aerial imagery"
        case .dark: return "Dark vector presentation"
        case .threeD: return "Building heights on vector maps"
        case .transit: return "Transit routes and stops"
        case .traffic: return "Current traffic flow"
        case .cycling: return "Cycleways and bicycle access"
        case .direction: return "Device heading and orientation"
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

    private func rowHint(for mode: OutdoorMapMode, capability: OutdoorMapCapability, enabled: Bool) -> String {
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

// Adapted from the MIT-licensed liquid-gooey silhouette/content architecture:
// https://github.com/Jakubantalik/Libraries/tree/main/packages/liquid-gooey
private struct OutdoorGooeyMorphLayer: View {
    let progress: CGFloat
    let sourceRect: CGRect
    let destinationRect: CGRect
    let sourceRadius: CGFloat
    let destinationRadius: CGFloat
    let color: Color

    var body: some View {
        Canvas { context, _ in
            var sourceContext = context
            sourceContext.opacity = Double(max(0, 1 - progress))
            sourceContext.fill(
                RoundedRectangle(cornerRadius: sourceRadius, style: .continuous).path(in: sourceRect),
                with: .color(color)
            )

            var destinationContext = context
            destinationContext.opacity = Double(progress)
            destinationContext.fill(
                RoundedRectangle(cornerRadius: destinationRadius, style: .continuous).path(in: destinationRect),
                with: .color(color)
            )
        }
        .blur(radius: 6)
        .contrast(18)
        .compositingGroup()
        .allowsHitTesting(false)
    }
}

#endif
