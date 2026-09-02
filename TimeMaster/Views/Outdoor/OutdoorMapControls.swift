#if os(iOS)
import SwiftUI

struct OutdoorMapControls: View {
    let weatherState: OutdoorWeatherState
    let weatherInfoEnabled: Bool
    let followsUser: Bool
    let mapAttribution: OutdoorMapAttribution
    let onDownload: () -> Void
    let onFocusLocation: () -> Void
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    var body: some View {
        VStack(alignment: .trailing, spacing: 1) {
            Button(action: onDownload) {
                Image(systemName: "arrow.down.circle")
                    .font(.system(size: 17, weight: .semibold))
            }
            .buttonStyle(OutdoorPineButtonStyle(circular: true, minimumSize: 44))
            .accessibilityLabel("Offline map area")
            .accessibilityHint("Shows a city-scale map view for offline area planning.")

            Button(action: onFocusLocation) {
                Image(systemName: followsUser ? "location.fill" : "location")
                    .font(.system(size: 17, weight: .semibold))
            }
            .buttonStyle(OutdoorPineButtonStyle(circular: true, minimumSize: 44))
            .accessibilityLabel("Focus current location")
            .accessibilityValue(followsUser ? "Following" : "Not following")
            .accessibilityHint("Centers the map on your current position and follows it.")

            if weatherInfoEnabled {
                weatherView
            }
            mapAttributionView
            if let presentation = weatherState.presentation {
                weatherAttributionView(presentation.attribution)
            }
        }
    }

    private var mapAttributionView: some View {
        let text = ([mapAttribution.providerName] + mapAttribution.notices).joined(separator: " · ")
        return Group {
            if let URL = mapAttribution.URLs.first {
                Link(text, destination: URL)
            } else {
                Text(text)
            }
        }
        .font(.caption2.weight(.medium))
        .foregroundStyle(Theme.textSecondary)
        .lineLimit(2)
        .multilineTextAlignment(.trailing)
        .fixedSize(horizontal: false, vertical: true)
        .padding(.horizontal, 6)
        .padding(.vertical, 3)
        .background(reduceTransparency ? Theme.surface : Theme.surface.opacity(0.78), in: Capsule())
        .accessibilityLabel("Map data attribution")
        .accessibilityValue(text)
    }

    private func weatherAttributionView(_ attribution: OutdoorWeatherAttribution) -> some View {
        Link(destination: attribution.legalPageURL) {
            AsyncImage(url: attribution.combinedMarkLightURL) { phase in
                if let image = phase.image {
                    image
                        .resizable()
                        .scaledToFit()
                        .frame(width: 68, height: 16)
                } else {
                    Text(attribution.serviceName)
                        .font(.caption2.weight(.semibold))
                        .lineLimit(2)
                        .multilineTextAlignment(.trailing)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: 120, alignment: .trailing)
                }
            }
        }
        .accessibilityLabel("\(attribution.serviceName) weather attribution")
        .accessibilityHint("Opens the weather provider legal page.")
    }

    @ViewBuilder
    private var weatherView: some View {
        switch weatherState {
        case .disabled:
            EmptyView()
        case .loading(let previous):
            if let previous {
                weatherCapsule(previous, status: "Updating")
            } else {
                weatherStatusCapsule(title: "Weather updating", systemImage: "cloud.sun", value: "—")
            }
        case .fresh(let presentation):
            weatherCapsule(presentation, status: nil)
        case .cached(let presentation):
            weatherCapsule(presentation, status: "Cached")
        case .unavailable:
            weatherStatusCapsule(title: "Weather unavailable", systemImage: "cloud.slash", value: "—")
        }
    }

    private func weatherCapsule(_ presentation: OutdoorWeatherPresentation, status: String?) -> some View {
        weatherSurface(
            VStack(spacing: 0) {
                Image(systemName: presentation.symbolName)
                    .font(.body.weight(.medium))
                Text(presentation.temperatureText)
                    .font(.caption2.weight(.semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .foregroundStyle(Theme.textPrimary)
            .padding(.horizontal, 8)
            .frame(minWidth: 44, minHeight: 44)
            .fixedSize(horizontal: true, vertical: false)
        )
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Weather information")
        .accessibilityValue([presentation.temperatureText, presentation.conditionText, status].compactMap { $0 }.joined(separator: ", "))
        .accessibilityAddTraits(.isStaticText)
    }

    private func weatherStatusCapsule(title: String, systemImage: String, value: String) -> some View {
        weatherSurface(
            VStack(spacing: 0) {
                Image(systemName: systemImage)
                    .font(.body.weight(.medium))
                Text(value)
                    .font(.caption2.weight(.semibold))
            }
            .foregroundStyle(Theme.textSecondary)
            .padding(.horizontal, 8)
            .frame(minWidth: 44, minHeight: 44)
            .fixedSize(horizontal: true, vertical: false)
        )
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(title)
        .accessibilityAddTraits(.isStaticText)
    }

    @ViewBuilder
    private func weatherSurface<Content: View>(_ content: Content) -> some View {
        if reduceTransparency {
            content.background(Theme.surface, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        } else if #available(iOS 26.0, *) {
            content.glassEffect(.regular, in: .rect(cornerRadius: 20))
        } else {
            content
                .background {
                    OutdoorFrostedGlassBackground()
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(Theme.surface.opacity(0.20))
                }
        }
    }
}


struct OutdoorRouteNotification: View {
    let message: String
    let systemImage: String
    let onDismiss: (() -> Void)?

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    var body: some View {
        HStack(alignment: .center, spacing: 10) {
            Image(systemName: systemImage)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(Theme.restAccent)
                .frame(width: 24, height: 24)
                .accessibilityHidden(true)

            Text(message)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Theme.textPrimary)
                .multilineTextAlignment(.leading)
                .lineLimit(3)
                .minimumScaleFactor(0.86)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)

            if let onDismiss {
                Button(action: onDismiss) {
                    Image(systemName: "xmark")
                        .font(.system(size: 12, weight: .bold))
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .foregroundStyle(Theme.textSecondary)
                .accessibilityLabel("Dismiss notification")
            }
        }
        .padding(.leading, 12)
        .padding(.trailing, onDismiss == nil ? 12 : 2)
        .padding(.vertical, 2)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(reduceTransparency ? Theme.surface : Theme.surface.opacity(0.92))
        }
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(Color.white.opacity(0.16), lineWidth: 1)
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(message)
        .transition(
            reduceMotion
                ? .opacity
                : .move(edge: .top).combined(with: .opacity)
        )
    }
}

struct OutdoorRouteIdleCloseControl: View {
    let onDismiss: () -> Void

    var body: some View {
        Button(action: onDismiss) {
            Image(systemName: "xmark")
                .font(.system(size: 15, weight: .bold))
        }
        .buttonStyle(OutdoorPineButtonStyle(circular: true, minimumSize: 38))
        .padding(3)
        .accessibilityLabel("Close route")
        .accessibilityHint("Returns to the app surface that opened the route feature.")
    }
}
#endif
