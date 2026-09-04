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
    let onHeart: () -> Void
    let onRetry: () -> Void
    let onOpenSettings: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @ScaledMetric(relativeTo: .largeTitle) private var liveValueScale: CGFloat = 1
    @ScaledMetric(relativeTo: .caption) private var liveLabelScale: CGFloat = 1

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            GeometryReader { proxy in
                let contentWidth = max(1, proxy.size.width - 24)
                let actionHeight = min(58, max(48, proxy.size.height * 0.13))
                let actionReserve = actionHeight + 7
                let statusInset: CGFloat = statusText == nil ? 34 : 52
                let metricRegionHeight = max(1, proxy.size.height - actionReserve)
                let metricHeight = max(1, metricRegionHeight - statusInset)

                ZStack {
                    VStack(spacing: 0) {
                        ZStack(alignment: .top) {
                            metrics(
                                at: context.date,
                                in: CGSize(width: contentWidth, height: metricHeight)
                            )
                            .frame(width: contentWidth, height: metricHeight)
                            .padding(.top, statusInset)

                            if let status = statusText {
                                statusPill(status)
                                    .frame(maxWidth: .infinity)
                                    .padding(.top, 4)
                            }
                        }
                        .frame(maxWidth: .infinity, maxHeight: metricRegionHeight)

                        actionBar(height: actionHeight)
                            .padding(.horizontal, 7)
                            .padding(.bottom, 7)
                            .frame(height: actionReserve)
                    }

                    if let message = recorder.errorMessage, recorder.state == .failed {
                        recoveryMessage(message)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .padding(18)
                    }
                }
                .padding(.horizontal, 12)
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Live \(recorder.kind.displayName) workout")
        .transaction { transaction in
            if isDragging {
                transaction.animation = nil
            }
        }
    }

    @ViewBuilder
    private func metrics(at date: Date, in size: CGSize) -> some View {
        let progress = min(1, max(0, expansion))
        let time = progress < 0.55 ? formattedCompactTime(at: date) : formattedTime(at: date)
        let speed = formattedSpeed
        let distance = formattedDistance
        let reflow = min(1, max(0, (progress - 0.62) / 0.24))
        let timeX = interpolate(0.80, 0.50, reflow) * size.width
        let timeY = interpolate(0.50, 0.24, reflow) * size.height
        let speedY = 0.50 * size.height
        let totalX = interpolate(0.20, 0.50, reflow) * size.width
        let totalY = interpolate(0.50, 0.74, reflow) * size.height
        let speedSize = interpolate(42, 92, progress)
        let secondarySize = interpolate(16, 27, progress)
        let labelSize = interpolate(10, 13, progress)
        let speedUnitBelow = reflow > 0.72

        if dynamicTypeSize.isAccessibilitySize {
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 12) {
                    accessibleMetric(title: "Speed", value: speed.value, unit: speed.unit, prominent: true)
                    HStack(alignment: .top, spacing: 18) {
                        accessibleMetric(title: "Time", value: time, unit: nil, prominent: false)
                        accessibleMetric(title: "Total", value: distance.value, unit: distance.unit, prominent: false)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
            }
        } else {
            ZStack {
                liveMetric(
                    title: "Time",
                    value: time,
                    unit: nil,
                    valueSize: secondarySize,
                    labelSize: labelSize,
                    alignment: .center
                )
                .position(x: timeX, y: timeY)
                .accessibilityLabel("Time \(time)")

                liveMetric(
                    title: nil,
                    value: speed.value,
                    unit: speed.unit,
                    valueSize: speedSize,
                    labelSize: labelSize,
                    alignment: .center,
                    unitBelow: speedUnitBelow
                )
                .position(x: size.width * 0.5, y: speedY)
                .accessibilityLabel("Speed \(speed.value) \(speed.unit)")

                liveMetric(
                    title: "Total",
                    value: distance.value,
                    unit: distance.unit,
                    valueSize: secondarySize,
                    labelSize: labelSize,
                    alignment: .center
                )
                .position(x: totalX, y: totalY)
                .accessibilityLabel("Total \(distance.value) \(distance.unit)")
            }
            .animation(isDragging || reduceMotion ? .none : .spring(response: 0.35, dampingFraction: 0.9), value: progress)
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
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(value)
                    .font((prominent ? Font.largeTitle : Font.title2).weight(.semibold))
                    .monospacedDigit()
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
        .fixedSize()
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
    private func actionBar(height: CGFloat) -> some View {
        if dynamicTypeSize.isAccessibilitySize || dynamicTypeSize == .xxLarge || dynamicTypeSize == .xxxLarge {
            ScrollView(.horizontal, showsIndicators: false) {
                actionButtons(height: height, fillsWidth: false)
                    .fixedSize(horizontal: true, vertical: false)
            }
        } else {
            actionButtons(height: height, fillsWidth: true)
        }
    }

    private func actionButtons(height: CGFloat, fillsWidth: Bool) -> some View {
        HStack(spacing: 6) {
            Button(action: onMusic) {
                Image(systemName: "music.note")
                    .font(.system(size: interpolate(21, 26, expansion), weight: .semibold))
                    .frame(maxWidth: .infinity)
            }
            .frame(minWidth: 44, maxWidth: fillsWidth ? .infinity : nil, minHeight: height)
            .buttonStyle(OutdoorPineButtonStyle())
            .accessibilityLabel("Music")
            .accessibilityHint("Open the shared Music editor")

            Button(action: onFinish) {
                Text("Finish")
                    .font(.system(size: interpolate(12, 14, expansion), weight: .bold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                    .frame(maxWidth: .infinity)
            }
            .frame(minWidth: 58, maxWidth: fillsWidth ? .infinity : nil, minHeight: height)
            .buttonStyle(OutdoorPineButtonStyle(prominent: true))
            .accessibilityLabel("Finish workout")

            Button(action: onTogglePause) {
                Text(isPaused ? "Resume" : "Stop")
                    .font(.system(size: interpolate(12, 14, expansion), weight: .semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .frame(maxWidth: .infinity)
            }
            .frame(minWidth: 62, maxWidth: fillsWidth ? .infinity : nil, minHeight: height)
            .buttonStyle(OutdoorPineButtonStyle())
            .accessibilityLabel(isPaused ? "Resume workout" : "Stop workout")
            .accessibilityValue(isPaused ? "Stopped" : "Recording")

            Button(action: onHeart) {
                Image(systemName: "heart")
                    .font(.system(size: interpolate(21, 26, expansion), weight: .semibold))
                    .frame(maxWidth: .infinity)
            }
            .frame(minWidth: 44, maxWidth: fillsWidth ? .infinity : nil, minHeight: height)
            .buttonStyle(OutdoorPineButtonStyle())
            .accessibilityLabel("Heart rate")
            .accessibilityHint("Heart rate action is not available yet")
        }
        .frame(maxWidth: fillsWidth ? .infinity : nil, minHeight: height)
    }

    private func recoveryMessage(_ message: String) -> some View {
        VStack(spacing: 10) {
            Image(systemName: "location.slash")
                .font(.title2)
            Text(message)
                .font(.subheadline.weight(.semibold))
                .multilineTextAlignment(.center)
                .frame(maxWidth: 280)
            Button("Try Again", action: onRetry)
                .buttonStyle(OutdoorPineButtonStyle(prominent: true))
            if recorder.requiresLocationSettingsRecovery {
                Button("Open Settings", action: onOpenSettings)
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
        switch recorder.state {
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
