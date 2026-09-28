#if os(iOS)
import SwiftUI

struct OutdoorLiveContent: View {
    @ObservedObject var recorder: OutdoorLocationRecorder
    @ObservedObject var preferences: OutdoorRecordingPreferencesStore
    let expansion: CGFloat
    let isDragging: Bool
    let onMusic: () -> Void
    let onFinish: () -> Void
    let onTogglePause: () -> Void
    let onRetry: () -> Void
    let onOpenSettings: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @ScaledMetric(relativeTo: .largeTitle) private var liveValueScale: CGFloat = 1
    @ScaledMetric(relativeTo: .caption) private var liveLabelScale: CGFloat = 1

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            if let message = recorder.errorMessage, recorder.state == .failed {
                ScrollView { recoveryMessage(message).padding(.vertical, 8) }
            } else {
                OutdoorAdaptivePane { _ in
                    VStack(spacing: 8) {
                        if let status = statusText {
                            statusPill(status).frame(maxWidth: .infinity)
                        }
                        GeometryReader { proxy in
                            metrics(at: context.date, in: proxy.size)
                        }
                        if let activity = recorder.activeActivity,
                           activity.tripDistanceMeters > activity.distanceMeters + 1 || recorder.isOnBus {
                            Text("Total incl. bus · \(outdoorDistanceText(activity.tripDistanceMeters, unitSystem: preferences.preferences.unitSystem, precision: true))")
                                .font(.caption)
                                .foregroundStyle(Theme.textSecondary)
                                .accessibilityIdentifier("trip.totalDistance")
                        }
                    }
                    .padding(.top, 4)
                } actions: { compact in
                    if compact {
                        LazyVGrid(columns: [GridItem(.fixed(44)), GridItem(.fixed(44))], spacing: 8) {
                            actionButtons(compact: true)
                        }
                    } else if dynamicTypeSize.isAccessibilitySize {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) { actionButtons(compact: false) }
                                .fixedSize(horizontal: true, vertical: false)
                        }
                        .fixedSize(horizontal: false, vertical: true)
                    } else {
                        HStack(spacing: 8) { actionButtons(compact: false) }
                    }
                }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Live \(recorder.kind.displayName) workout")
        .transaction { if isDragging { $0.animation = nil; $0.disablesAnimations = true } }
    }

    @ViewBuilder
    private func metrics(at date: Date, in size: CGSize) -> some View {
        let progress = min(1, max(0, expansion))
        let time = progress < 0.55 ? formattedCompactTime(at: date) : formattedTime(at: date)
        let speed = formattedSpeed
        let distance = formattedDistance
        let stacked = progress >= 0.74
        let labelSize = interpolate(10, 13, progress)
        let secondarySize = min(
            interpolate(16, 27, progress),
            max(1, (size.height / (stacked ? 5 : 1) - 1.25 * labelSize * liveLabelScale - 4) / (1.25 * liveValueScale))
        )
        let secondaryHeight = 1.25 * (labelSize * liveLabelScale + secondarySize * liveValueScale) + 4
        let speedHeight = stacked ? size.height - 2 * secondaryHeight - 32 : size.height
        let speedSize = min(
            interpolate(42, 92, progress),
            max(1, (speedHeight - 12.5 * liveLabelScale - 4) / (1.25 * liveValueScale + 0.375 * liveLabelScale))
        )

        if dynamicTypeSize.isAccessibilitySize {
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 12) {
                    accessibleMetric(title: "Speed", value: speed.value, unit: speed.unit, prominent: true)
                    accessibleMetric(title: "Time", value: time, unit: nil, prominent: false)
                    accessibleMetric(title: activeDistanceTitle, value: distance.value, unit: distance.unit, prominent: false)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
            }
        } else {
            let timeMetric = liveMetric(
                title: "Time",
                value: time,
                unit: nil,
                valueSize: secondarySize,
                labelSize: labelSize,
                alignment: .center
            )
            .frame(maxWidth: .infinity)
            .accessibilityLabel("Time \(time)")
            let speedMetric = liveMetric(
                title: nil,
                value: speed.value,
                unit: speed.unit,
                valueSize: speedSize,
                labelSize: labelSize,
                alignment: .center,
                unitBelow: true
            )
            .frame(maxWidth: .infinity)
            .accessibilityLabel("Speed \(speed.value) \(speed.unit)")
            let totalMetric = liveMetric(
                title: activeDistanceTitle,
                value: distance.value,
                unit: distance.unit,
                valueSize: secondarySize,
                labelSize: labelSize,
                alignment: .center
            )
            .frame(maxWidth: .infinity)
            .accessibilityLabel("\(activeDistanceTitle) \(distance.value) \(distance.unit)")

            Group {
                if stacked {
                    VStack(spacing: 8) {
                        timeMetric
                        Spacer(minLength: 0)
                        speedMetric
                        Spacer(minLength: 0)
                        totalMetric
                    }
                } else {
                    HStack(spacing: 8) {
                        totalMetric
                        speedMetric
                        timeMetric
                    }
                }
            }
            .frame(width: size.width, height: size.height)
            .transaction { $0.animation = nil }
        }
    }

    private func accessibleMetric(
        title: String,
        value: String,
        unit: String?,
        prominent: Bool
    ) -> some View {
        VStack(spacing: 3) {
            Text(title)
                .font(.headline.weight(.semibold))
                .foregroundStyle(Theme.textPrimary.opacity(0.72))
            VStack(spacing: 3) {
                Text(value)
                    .font((prominent ? Font.largeTitle : Font.title2).weight(.semibold))
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                if let unit {
                    Text(unit)
                        .font(.headline)
                        .foregroundStyle(Theme.textPrimary.opacity(0.62))
                }
            }
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title) \(value)\(unit.map { " \($0)" } ?? "")")
    }

    private func statusPill(_ status: String) -> some View {
        Text(status)
            .font(.caption.weight(.semibold))
            .foregroundStyle(Theme.textPrimary.opacity(0.88))
            .padding(.horizontal, 11)
            .frame(minHeight: 28)
            .background(reduceTransparency ? Theme.surface2 : Color.black.opacity(0.36), in: Capsule())
            .overlay {
                Capsule().strokeBorder(Theme.restAccent.opacity(0.38), lineWidth: 1)
            }
            .accessibilityLabel(status)
    }

    private func liveMetric(
        title: String?,
        value: String,
        unit: String?,
        valueSize: CGFloat,
        labelSize: CGFloat,
        alignment: HorizontalAlignment,
        unitBelow: Bool = false
    ) -> some View {
        VStack(alignment: alignment, spacing: 4) {
            if let title {
                Text(title)
                    .font(.system(size: labelSize * liveLabelScale, weight: .semibold))
                    .foregroundStyle(Theme.textPrimary.opacity(0.72))
            }
            if unitBelow, let unit {
                VStack(alignment: alignment, spacing: 2) {
                    metricValueText(value, size: valueSize)
                    Text(unit)
                        .font(.system(size: max(10, valueSize * 0.30) * liveLabelScale, weight: .medium))
                        .foregroundStyle(Theme.textPrimary.opacity(0.62))
                }
            } else {
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    metricValueText(value, size: valueSize)
                    if let unit {
                        Text(unit)
                            .font(.system(size: max(9, valueSize * 0.42) * liveLabelScale, weight: .medium))
                            .foregroundStyle(Theme.textPrimary.opacity(0.62))
                    }
                }
            }
        }
        .lineLimit(1)
        .minimumScaleFactor(0.5)
        .fixedSize(horizontal: false, vertical: true)
    }

    @ViewBuilder
    private func metricValueText(_ value: String, size: CGFloat) -> some View {
        if #available(iOS 17.0, *) {
            Text(value)
                .font(.system(size: size * liveValueScale, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .contentTransition(.numericText())
                .animation(reduceMotion ? .none : .snappy, value: value)
        } else {
            Text(value)
                .font(.system(size: size * liveValueScale, weight: .semibold, design: .rounded))
                .monospacedDigit()
        }
    }
    @ViewBuilder
    private func actionButtons(compact: Bool) -> some View {
        Button(action: onMusic) {
            OutdoorPaneActionLabel(title: "Music", systemImage: "music.note", compact: compact)
        }
        .buttonStyle(OutdoorPineButtonStyle(circular: compact))
        .accessibilityLabel("Music")

        Button(action: onFinish) {
            OutdoorPaneActionLabel(title: "Finish", systemImage: "stop.fill", compact: compact)
        }
        .buttonStyle(OutdoorPineButtonStyle(prominent: true, circular: compact))
        .accessibilityLabel("Finish workout")

        Button(action: onTogglePause) {
            OutdoorPaneActionLabel(title: isPaused ? "Resume" : "Pause", systemImage: isPaused ? "play.fill" : "pause.fill", compact: compact)
        }
        .buttonStyle(OutdoorPineButtonStyle(circular: compact))
        .accessibilityLabel(isPaused ? "Resume workout" : "Stop workout")

        Button(action: recorder.toggleBusTransfer) {
            OutdoorPaneActionLabel(title: recorder.isOnBus ? "Resume riding" : "Board bus", systemImage: recorder.isOnBus ? recorder.kind.iconName : "bus", compact: compact)
        }
        .buttonStyle(OutdoorPineButtonStyle(circular: compact))
        .accessibilityLabel(recorder.isOnBus ? "End bus transfer and resume active distance" : "Board bus and pause active distance")
        .accessibilityIdentifier("trip.busToggle")
    }

    private func recoveryMessage(_ message: String) -> some View {
        VStack(spacing: 10) {
            Image(systemName: "location.slash")
                .font(.title2)
            Text(message)
                .font(.subheadline.weight(.semibold))
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: 280)
            Button("Try Again", action: onRetry)
                .buttonStyle(OutdoorPineButtonStyle(prominent: true))
            if recorder.requiresLocationSettingsRecovery {
                Button("Open Settings", action: onOpenSettings)
                    .buttonStyle(OutdoorPineButtonStyle())
            }
            if recorder.activeActivity != nil {
                Button("Finish saved workout", action: onFinish)
                    .buttonStyle(OutdoorPineButtonStyle())
            }
        }
        .padding(16)
        .foregroundStyle(Theme.textPrimary)
        .background(reduceTransparency ? Theme.surface2 : Color.black.opacity(0.42), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private var isPaused: Bool {
        recorder.state == .manualPaused || recorder.state == .autoPaused
    }

    private var statusText: String? {
        if recorder.isOnBus, recorder.state == .recording { return "On bus · riding metrics paused" }
        return switch recorder.state {
        case .requestingAuthorization: "Waiting for location access"
        case .manualPaused: "Stopped"
        case .autoPaused: "Auto-paused"
        case .recording where recorder.gpsUnavailable: "Waiting for GPS"
        case .recording: nil
        case .failed: "Needs attention"
        case .finished: "Finished"
        case .idle: "Ready"
        }
    }

    private func formattedTime(at date: Date) -> String {
        let seconds = max(0, recorder.elapsedSeconds(at: date))
        return String(format: "%02d:%02d:%02d", seconds / 3600, (seconds % 3600) / 60, seconds % 60)
    }
    private func formattedCompactTime(at date: Date) -> String {
        let seconds = max(0, recorder.elapsedSeconds(at: date))
        return String(format: "%02d:%02d", seconds / 3600, (seconds % 3600) / 60)
    }

    private var activeDistanceTitle: String { recorder.kind == .bike ? "Riding" : "On foot" }

    private var formattedDistance: (value: String, unit: String) {
        let meters = max(0, recorder.activeActivity?.distanceMeters ?? 0)
        switch preferences.preferences.unitSystem {
        case .metric:
            return (meters >= 1_000 ? String(format: "%.2f", meters / 1_000) : String(format: "%.0f", meters), meters >= 1_000 ? "km" : "m")
        case .imperial:
            let miles = meters / 1_609.344
            return (miles >= 0.1 ? String(format: "%.2f", miles) : String(format: "%.0f", meters * 3.28084), miles >= 0.1 ? "mi" : "ft")
        }
    }

    private var formattedSpeed: (value: String, unit: String) {
        let metersPerSecond = max(0, recorder.smoothedLiveSpeedMetersPerSecond ?? recorder.liveSpeedMetersPerSecond ?? 0)
        if recorder.kind != .bike {
            guard metersPerSecond > 0.2 else { return ("—", preferences.preferences.unitSystem == .metric ? "min/km" : "min/mi") }
            let seconds = Int((preferences.preferences.unitSystem == .metric ? 1_000.0 : 1_609.344) / metersPerSecond)
            return (String(format: "%d:%02d", seconds / 60, seconds % 60), preferences.preferences.unitSystem == .metric ? "min/km" : "min/mi")
        }
        switch preferences.preferences.unitSystem {
        case .metric: return (String(format: "%.1f", metersPerSecond * 3.6), "km/h")
        case .imperial: return (String(format: "%.1f", metersPerSecond * 2.23694), "mph")
        }
    }

    private func interpolate(_ start: CGFloat, _ end: CGFloat, _ progress: CGFloat) -> CGFloat {
        start + (end - start) * progress
    }
}
#endif
