#if os(iOS)
import SwiftUI

struct OutdoorMapControls: View, Animatable {
    let weatherState: OutdoorWeatherState
    let weatherInfoEnabled: Bool
    let followsUser: Bool
    let mapAttribution: OutdoorMapAttribution
    let onDownload: () -> Void
    let onFocusLocation: () -> Void
    var onFitRoute: (() -> Void)?
    var onNorth: (() -> Void)?
    var geometry: OutdoorMapUtilityGeometry?
    var attributionOpacity: CGFloat = 1
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    var animatableData: AnimatablePair<CGFloat, CGFloat> {
        get { AnimatablePair(geometry?.rowProgress ?? 0, geometry?.columnTop ?? 0) }
        set {
            geometry?.rowProgress = newValue.first
            geometry?.columnTop = newValue.second
        }
    }

    var body: some View {
        if let geometry {
            ZStack(alignment: .topLeading) {
                downloadButton.position(geometry.position(at: 0, trailing: true))
                focusButton.position(geometry.position(at: 1, trailing: true))
                if weatherInfoEnabled {
                    weatherInformation
                        .position(geometry.position(at: 2, trailing: true))
                }
                mapAttributionView
                    .frame(width: 182)
                    .position(
                        x: geometry.width - 99,
                        y: geometry.position(at: weatherInfoEnabled ? 2 : 1, trailing: true).y + 42 + (weatherInfoEnabled ? 20 : 0)
                    )
                    .opacity(attributionOpacity)
                    .allowsHitTesting(attributionOpacity > 0.05)
                    .accessibilityHidden(attributionOpacity <= 0.05)
            }
        } else {
        VStack(alignment: .trailing, spacing: 8) {
            downloadButton

            if let onFitRoute {
                Menu {
                    Button("Fit trip", systemImage: "arrow.up.left.and.arrow.down.right", action: onFitRoute)
                    if let onNorth { Button("North up", systemImage: "location.north.line", action: onNorth) }
                } label: {
                    Image(systemName: "point.topleft.down.curvedto.point.bottomright.up")
                        .font(.system(size: 17, weight: .semibold))
                }
                .buttonStyle(OutdoorPineButtonStyle(circular: true, minimumSize: 44))
                .accessibilityLabel("Trip map controls")
            }

            focusButton
            if weatherInfoEnabled { weatherInformation }

            mapAttributionView
        }
        }
    }

    private var downloadButton: some View {
        Button(action: onDownload) {
            Image(systemName: "arrow.down.circle")
                .font(.system(size: 17, weight: .semibold))
        }
        .buttonStyle(OutdoorPineButtonStyle(circular: true, minimumSize: 44))
        .accessibilityLabel("Offline map area")
        .accessibilityHint("Manages installed maps, routing, and places for offline use.")
    }

    private var focusButton: some View {
        Button(action: onFocusLocation) {
            Image(systemName: followsUser ? "location.fill" : "location")
                .font(.system(size: 17, weight: .semibold))
        }
        .buttonStyle(OutdoorPineButtonStyle(circular: true, minimumSize: 44))
        .accessibilityLabel("Focus current location")
        .accessibilityValue(followsUser ? "Following" : "Not following")
        .accessibilityHint("Centers the map on your current position and follows it.")
    }

    private var weatherInformation: some View {
        weatherView
            .overlay(alignment: .bottomTrailing) {
                if let presentation = weatherState.presentation {
                    weatherAttributionView(presentation.attribution)
                        .offset(y: 20)
                }
            }
    }

    private var mapAttributionView: some View {
        let noticeText = mapAttribution.notices.joined(separator: " · ")
        return VStack(alignment: .trailing, spacing: 1) {
            if let URL = mapAttribution.URLs.first {
                Link(mapAttribution.providerName, destination: URL)
            } else {
                Text(mapAttribution.providerName)
            }
            if !noticeText.isEmpty {
                Text(noticeText)
                    .font(.caption2.weight(.regular))
            }
        }
        .font(.caption2.weight(.semibold))
        .foregroundStyle(Theme.textSecondary)
        .lineLimit(1)
        .minimumScaleFactor(0.8)
        .font(.custom("Inter Light", size: 11, relativeTo: .caption2))
        .fixedSize(horizontal: false, vertical: true)
        .frame(maxWidth: 170, alignment: .trailing)
        .padding(.horizontal, 6)
        .padding(.vertical, 3)
        .background(reduceTransparency ? Theme.surface : Theme.surface.opacity(0.78), in: Capsule())
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Map data attribution")
        .accessibilityValue([mapAttribution.providerName, noticeText].filter { !$0.isEmpty }.joined(separator: ", "))
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
            weatherStatusCapsule(title: "Weather updating", systemImage: "cloud.sun", value: "—")
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
                    .font(.custom("Inter Black", size: 12, relativeTo: .caption2))
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
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.14), lineWidth: 1)
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

struct OutdoorRouteExitControl: View {
    let onExit: () -> Void

    var body: some View {
        Button(action: onExit) {
            Image(systemName: "rectangle.portrait.and.arrow.right")
                .font(.system(size: 15, weight: .semibold))
        }
        .buttonStyle(OutdoorPineButtonStyle(circular: true, minimumSize: 38))
        .padding(3)
        .accessibilityLabel("Return to app")
        .accessibilityHint("Leaves the map while keeping the active workout running.")
    }
}

struct OutdoorLiveWorkoutStatusWidget: View {
    @ObservedObject var recorder: OutdoorLocationRecorder
    @ObservedObject var preferences: OutdoorRecordingPreferencesStore
    let onOpenMap: () -> Void

    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    var body: some View {
        if recorder.isLiveSession {
            Button(action: onOpenMap) {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 6) {
                        Circle()
                            .fill(recorder.state == .recording ? Color.green : Theme.toolbarOrange)
                            .frame(width: 7, height: 7)
                        Text(recorder.state == .recording ? "LIVE" : "PAUSED")
                            .font(.caption2.weight(.bold))
                            .tracking(0.8)
                            .foregroundStyle(Theme.textSecondary)
                        Spacer(minLength: 4)
                        Image(systemName: "map")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(Theme.textSecondary)
                    }

                    HStack(spacing: 14) {
                        metric(value: speedText, label: isMetric ? "km/h" : "mph")
                        metric(value: distanceText, label: isMetric ? "km" : "mi")
                    }
                }
                .padding(.horizontal, 13)
                .padding(.vertical, 11)
                .frame(width: 174, alignment: .leading)
                .background {
                    if reduceTransparency {
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(Theme.surface)
                    } else {
                        OutdoorFrostedGlassBackground(style: .systemMaterialDark)
                            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(Theme.surface.opacity(0.28))
                    }
                }
                .overlay {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.16), lineWidth: 1)
                }
            }
            .buttonStyle(.plain)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Live \(recorder.activeActivity?.kind.displayName ?? "workout")")
            .accessibilityValue("\(speedText) \(isMetric ? "kilometres" : "miles") per hour, \(distanceText) \(isMetric ? "kilometres" : "miles")")
            .accessibilityHint("Opens the active workout map.")
        }
    }
    private var isMetric: Bool { preferences.preferences.unitSystem == .metric }


    private var speedText: String {
        let metersPerSecond = recorder.smoothedLiveSpeedMetersPerSecond
            ?? recorder.liveSpeedMetersPerSecond
            ?? 0
        return String(format: "%.1f", max(0, metersPerSecond * (isMetric ? 3.6 : 2.23694)))
    }

    private var distanceText: String {
        String(format: "%.2f", max(0, (recorder.activeActivity?.distanceMeters ?? 0) / (isMetric ? 1_000 : 1_609.344)))
    }

    private func metric(value: String, label: String) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(value)
                .font(.system(size: 21, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(Theme.textPrimary)
            Text(label)
                .font(.caption2.weight(.medium))
                .foregroundStyle(Theme.textSecondary)
        }
    }
}
#endif
