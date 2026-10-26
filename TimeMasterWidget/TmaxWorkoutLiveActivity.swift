import ActivityKit
import AppIntents
import SwiftUI
import WidgetKit

@available(iOS 16.2, *)
struct TmaxWorkoutLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: WorkoutActivityAttributes.self) { context in
            TmaxLiveLockScreenView(context: context)
                .activityBackgroundTint(Color(widgetHex: "0A0A0A"))
                .activitySystemActionForegroundColor(.white)
                .widgetURL(URL(string: "timemaster://open"))
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    TmaxLiveExpandedLeading(context: context)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    TmaxLiveExpandedTrailing(context: context)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    TmaxLiveExpandedBottom(context: context)
                }
            } compactLeading: {
                TmaxLiveCompactLeading(context: context)
            } compactTrailing: {
                TmaxLiveCompactTrailing(context: context)
            } minimal: {
                TmaxLiveMinimal(context: context)
            }
            .keylineTint(Color(widgetHex: context.attributes.colorHex))
            .widgetURL(URL(string: "timemaster://open"))
        }
    }
}

@available(iOS 16.2, *)
private enum TmaxLiveStyle {
    static let secondary = Color.white.opacity(0.62)
    static let dimmed = 0.45

    static func timerFont(size: CGFloat) -> Font {
        .system(size: size, weight: .bold, design: .rounded).monospacedDigit()
    }
}

@available(iOS 16.2, *)
private extension WorkoutActivityAttributes.ContentState {
    var progressLength: Int {
        max(phaseDuration, remainingSeconds)
    }

    var runningInterval: ClosedRange<Date>? {
        guard !isPaused, let end = phaseEndDate, progressLength > 0 else { return nil }
        return end.addingTimeInterval(-TimeInterval(progressLength))...end
    }

    var elapsedFraction: Double {
        guard progressLength > 0 else { return 0 }
        return min(1, max(0, 1 - Double(remainingSeconds) / Double(progressLength)))
    }

    var symbolName: String {
        if phase == .completed { return "checkmark.circle.fill" }
        if isPaused { return "pause.fill" }
        switch phase {
        case .warmUp: return "flame.fill"
        case .prepare: return "hourglass"
        case .active: return "bolt.fill"
        case .setRest, .sectionRest: return "drop.fill"
        case .completed: return "checkmark.circle.fill"
        }
    }

    var phaseDescription: String {
        if phase == .completed { return "Workout complete" }
        if isPaused { return "Workout paused" }
        switch phase {
        case .warmUp: return "Warm up"
        case .prepare: return "Get ready"
        case .active: return title
        case .setRest, .sectionRest: return "Rest"
        case .completed: return "Workout complete"
        }
    }

    func countdownWidth(fontSize: CGFloat, showsHours: Bool) -> CGFloat {
        let emWidth: CGFloat
        if showsHours && progressLength >= 3600 {
            emWidth = 3.7
        } else if !showsHours && progressLength >= 6000 {
            emWidth = 3.5
        } else {
            emWidth = 2.8
        }
        return (fontSize * emWidth).rounded(.up)
    }
}

@available(iOS 16.2, *)
private struct TmaxLiveCountdown: View {
    let state: WorkoutActivityAttributes.ContentState
    var showsHours = true

    var body: some View {
        if let endDate = state.phaseEndDate, !state.isPaused {
            let now = Date.now
            Text(timerInterval: now...max(now, endDate), countsDown: true, showsHours: showsHours)
        } else {
            Text(Self.clock(seconds: state.remainingSeconds, showsHours: showsHours))
                .accessibilityLabel(Self.spoken(seconds: state.remainingSeconds))
        }
    }

    static func clock(seconds: Int, showsHours: Bool) -> String {
        let total = max(0, seconds)
        if showsHours && total >= 3600 {
            return String(format: "%d:%02d:%02d", total / 3600, (total % 3600) / 60, total % 60)
        }
        return String(format: "%d:%02d", total / 60, total % 60)
    }

    private static func spoken(seconds: Int) -> String {
        let formatter = DateComponentsFormatter()
        formatter.unitsStyle = .full
        formatter.allowedUnits = [.hour, .minute, .second]
        formatter.zeroFormattingBehavior = .dropAll
        let duration = formatter.string(from: TimeInterval(max(0, seconds))) ?? ""
        return "\(duration) remaining"
    }
}

@available(iOS 16.2, *)
private struct TmaxLiveProgressBar: View {
    let state: WorkoutActivityAttributes.ContentState
    let tint: Color

    var body: some View {
        Group {
            if let interval = state.runningInterval {
                ProgressView(timerInterval: interval, countsDown: false) {
                    EmptyView()
                } currentValueLabel: {
                    EmptyView()
                }
            } else {
                ProgressView(value: state.elapsedFraction)
            }
        }
        .progressViewStyle(.linear)
        .tint(tint)
        .accessibilityHidden(true)
    }
}

@available(iOS 16.2, *)
private struct TmaxLiveProgressRing: View {
    let state: WorkoutActivityAttributes.ContentState
    let tint: Color

    var body: some View {
        Group {
            if let interval = state.runningInterval {
                ProgressView(timerInterval: interval, countsDown: false) {
                    EmptyView()
                } currentValueLabel: {
                    EmptyView()
                }
            } else {
                ProgressView(value: state.elapsedFraction)
            }
        }
        .progressViewStyle(.circular)
        .tint(tint)
        .accessibilityHidden(true)
    }
}

@available(iOS 16.2, *)
private struct TmaxLivePauseButton: View {
    let isPaused: Bool
    let tint: Color
    var diameter: CGFloat = 34

    var body: some View {
        if #available(iOS 17.0, *) {
            Button(intent: TogglePauseWorkoutIntent()) {
                Image(systemName: isPaused ? "play.fill" : "pause.fill")
                    .font(.system(size: diameter * 0.4, weight: .bold))
                    .foregroundStyle(tint)
                    .frame(width: diameter, height: diameter)
                    .background(tint.opacity(0.2), in: Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(isPaused ? "Resume workout" : "Pause workout")
        }
    }
}

@available(iOS 16.2, *)
private struct TmaxLiveFooter: View {
    let state: WorkoutActivityAttributes.ContentState
    let isStale: Bool

    var body: some View {
        if isStale {
            Label("Open Tmax to sync", systemImage: "arrow.triangle.2.circlepath")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(TmaxLiveStyle.secondary)
                .lineLimit(1)
        } else if let next = state.nextTitle {
            HStack(spacing: 5) {
                Text("Up next")
                    .foregroundStyle(TmaxLiveStyle.secondary)
                Text(next)
                    .lineLimit(1)
            }
            .font(.system(size: 13, weight: .semibold))
            .accessibilityElement(children: .combine)
        }
    }
}

@available(iOS 16.2, *)
private struct TmaxLiveLockScreenView: View {
    let context: ActivityViewContext<WorkoutActivityAttributes>
    @Environment(\.isLuminanceReduced) private var isLuminanceReduced

    private var state: WorkoutActivityAttributes.ContentState {
        context.state
    }

    private var accent: Color {
        Color(widgetHex: context.attributes.colorHex).opacity(isLuminanceReduced ? 0.7 : 1)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            header
            if state.phase == .completed {
                completedRow
            } else {
                liveRows
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .foregroundStyle(.white)
    }

    private var header: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(accent)
                .frame(width: 8, height: 8)
            Text(context.attributes.workoutName)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(TmaxLiveStyle.secondary)
                .lineLimit(1)
            Spacer(minLength: 8)
            if state.isPaused && state.phase != .completed {
                Label("Paused", systemImage: "pause.fill")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(accent)
            }
        }
        .accessibilityElement(children: .combine)
    }

    private var liveRows: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .center, spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(state.title)
                        .font(.system(size: 22, weight: .bold))
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                    if !state.subtitle.isEmpty {
                        Text(state.subtitle)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(TmaxLiveStyle.secondary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                TmaxLiveCountdown(state: state)
                    .font(TmaxLiveStyle.timerFont(size: 38))
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                    .frame(width: state.countdownWidth(fontSize: 38, showsHours: true), alignment: .trailing)
                    .opacity(context.isStale ? TmaxLiveStyle.dimmed : 1)
            }
            .accessibilityElement(children: .combine)

            TmaxLiveProgressBar(state: state, tint: accent)

            HStack(spacing: 10) {
                TmaxLiveFooter(state: state, isStale: context.isStale)
                    .frame(maxWidth: .infinity, alignment: .leading)
                TmaxLivePauseButton(isPaused: state.isPaused, tint: accent)
            }
        }
    }

    private var completedRow: some View {
        HStack(spacing: 12) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 36, weight: .semibold))
                .foregroundStyle(accent)
            VStack(alignment: .leading, spacing: 2) {
                Text("Workout complete")
                    .font(.system(size: 22, weight: .bold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                if state.elapsedSeconds > 0 {
                    Text("Total time \(TmaxLiveCountdown.clock(seconds: state.elapsedSeconds, showsHours: true))")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(TmaxLiveStyle.secondary)
                }
            }
            Spacer(minLength: 0)
        }
        .accessibilityElement(children: .combine)
    }
}

@available(iOS 16.2, *)
private struct TmaxLiveExpandedLeading: View {
    let context: ActivityViewContext<WorkoutActivityAttributes>

    var body: some View {
        let state = context.state
        VStack(alignment: .leading, spacing: 2) {
            Text(state.phase == .completed ? "Workout complete" : state.title)
                .font(.system(size: 18, weight: .bold))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(state.subtitle.isEmpty ? context.attributes.workoutName : state.subtitle)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(TmaxLiveStyle.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }
}

@available(iOS 16.2, *)
private struct TmaxLiveExpandedTrailing: View {
    let context: ActivityViewContext<WorkoutActivityAttributes>

    var body: some View {
        let state = context.state
        if state.phase == .completed {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 30, weight: .semibold))
                .foregroundStyle(Color(widgetHex: context.attributes.colorHex))
                .accessibilityHidden(true)
        } else {
            TmaxLiveCountdown(state: state)
                .font(TmaxLiveStyle.timerFont(size: 32))
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .frame(width: state.countdownWidth(fontSize: 32, showsHours: true), alignment: .trailing)
                .opacity(context.isStale ? TmaxLiveStyle.dimmed : 1)
        }
    }
}

@available(iOS 16.2, *)
private struct TmaxLiveExpandedBottom: View {
    let context: ActivityViewContext<WorkoutActivityAttributes>

    var body: some View {
        let state = context.state
        let accent = Color(widgetHex: context.attributes.colorHex)
        if state.phase == .completed {
            if state.elapsedSeconds > 0 {
                Text("Total time \(TmaxLiveCountdown.clock(seconds: state.elapsedSeconds, showsHours: true))")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(TmaxLiveStyle.secondary)
            }
        } else {
            VStack(spacing: 8) {
                TmaxLiveProgressBar(state: state, tint: accent)
                HStack(spacing: 10) {
                    TmaxLiveFooter(state: state, isStale: context.isStale)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    TmaxLivePauseButton(isPaused: state.isPaused, tint: accent)
                }
            }
        }
    }
}

@available(iOS 16.2, *)
private struct TmaxLiveCompactLeading: View {
    let context: ActivityViewContext<WorkoutActivityAttributes>

    var body: some View {
        Image(systemName: context.state.symbolName)
            .font(.system(size: 14, weight: .bold))
            .foregroundStyle(Color(widgetHex: context.attributes.colorHex))
            .accessibilityLabel(context.state.phaseDescription)
    }
}

@available(iOS 16.2, *)
private struct TmaxLiveCompactTrailing: View {
    let context: ActivityViewContext<WorkoutActivityAttributes>

    var body: some View {
        let state = context.state
        if state.phase == .completed {
            Text("Done")
                .font(.system(size: 13, weight: .bold))
                .lineLimit(1)
        } else {
            TmaxLiveCountdown(state: state, showsHours: false)
                .font(TmaxLiveStyle.timerFont(size: 14))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .frame(width: state.countdownWidth(fontSize: 14, showsHours: false), alignment: .trailing)
                .opacity(context.isStale ? TmaxLiveStyle.dimmed : 1)
        }
    }
}

@available(iOS 16.2, *)
private struct TmaxLiveMinimal: View {
    let context: ActivityViewContext<WorkoutActivityAttributes>

    var body: some View {
        let state = context.state
        let accent = Color(widgetHex: context.attributes.colorHex)
        ZStack {
            if state.phase != .completed {
                TmaxLiveProgressRing(state: state, tint: accent)
            }
            Image(systemName: state.symbolName)
                .font(.system(size: state.phase == .completed ? 14 : 10, weight: .bold))
                .foregroundStyle(accent)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(state.phaseDescription)
    }
}
