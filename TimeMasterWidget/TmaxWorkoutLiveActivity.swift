import ActivityKit
import SwiftUI
import WidgetKit

struct TmaxWorkoutLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: WorkoutActivityAttributes.self) { context in
            TmaxLiveLockScreenView(
                state: context.state,
                workoutName: context.attributes.workoutName,
                colorHex: context.attributes.colorHex,
                isStale: context.isStale
            )
            .activityBackgroundTint(TmaxLiveStyle.background)
            .activitySystemActionForegroundColor(.white)
            .widgetURL(URL(string: "timemaster://open"))
        } dynamicIsland: { context in
            let state = context.state
            let accent = Color(widgetHex: context.attributes.colorHex)
            let name = context.attributes.workoutName
            return DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    TmaxLiveExpandedLeading(state: state, accent: accent)
                        .dynamicTypeSize(...DynamicTypeSize.xLarge)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    TmaxLiveExpandedTrailing(state: state, isStale: context.isStale)
                        .dynamicTypeSize(...DynamicTypeSize.xLarge)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    TmaxLiveExpandedBottom(state: state, accent: accent, workoutName: name, isStale: context.isStale)
                        .dynamicTypeSize(...DynamicTypeSize.xLarge)
                }
            } compactLeading: {
                TmaxLiveCompactLeading(state: state, accent: accent, workoutName: name)
            } compactTrailing: {
                TmaxLiveCompactTrailing(state: state, isStale: context.isStale)
            } minimal: {
                TmaxLiveMinimal(state: state, accent: accent, workoutName: name)
            }
            .keylineTint(state.tone(workout: accent))
            .widgetURL(URL(string: "timemaster://open"))
        }
    }
}

struct TmaxLiveExpandedLeading: View {
    let state: WorkoutActivityAttributes.ContentState
    let accent: Color
    @ScaledMetric(relativeTo: .title) private var tileSize: CGFloat = 34

    var body: some View {
        TmaxLiveTile(state: state, tone: state.tone(workout: accent), size: tileSize)
    }
}

struct TmaxLiveExpandedTrailing: View {
    let state: WorkoutActivityAttributes.ContentState
    let isStale: Bool
    @ScaledMetric(relativeTo: .title) private var timerSize: CGFloat = 32

    var body: some View {
        if state.phase == .completed {
            Text(WorkoutActivityAttributes.ContentState.clock(seconds: state.elapsedSeconds, showsHours: true))
                .font(TmaxLiveStyle.timerFont(size: timerSize))
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .accessibilityLabel("Total time \(WorkoutActivityAttributes.ContentState.spokenDuration(state.elapsedSeconds))")
        } else {
            TmaxLiveCountdown(state: state)
                .font(TmaxLiveStyle.timerFont(size: timerSize))
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .frame(width: state.countdownWidth(fontSize: timerSize, showsHours: true) * 0.93, alignment: .trailing)
                .opacity(isStale ? TmaxLiveStyle.dimmed : 1)
        }
    }
}

struct TmaxLiveExpandedBottom: View {
    let state: WorkoutActivityAttributes.ContentState
    let accent: Color
    let workoutName: String
    let isStale: Bool
    @ScaledMetric(relativeTo: .body) private var buttonSize: CGFloat = 30
    @ScaledMetric(relativeTo: .body) private var nextSize: CGFloat = 26

    private var tone: Color {
        state.tone(workout: accent)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .center, spacing: 10) {
                VStack(alignment: .leading, spacing: 0) {
                    Text(state.title)
                        .font(.system(size: 15, weight: .semibold))
                        .lineLimit(1)
                        .accessibilityLabel(state.spokenSummary(workoutName: workoutName))
                    Text(workoutName)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(TmaxLiveStyle.secondary)
                        .lineLimit(1)
                        .accessibilityHidden(true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                if state.hasNext {
                    TmaxLiveNextCard(
                        state: state,
                        accent: accent,
                        size: state.isRest ? nextSize : nextSize * 0.86,
                        maxNameWidth: state.isRest ? 92 : 64
                    )
                    .fixedSize()
                }
            }
            if state.phase != .completed {
                HStack(spacing: 10) {
                    if isStale {
                        TmaxLiveStaleMark()
                    } else if let position = state.position {
                        TmaxLivePositionView(position: position, isBundle: state.isBundle, tint: tone)
                    }
                    Spacer(minLength: 0)
                    TmaxLiveControls(state: state, tone: tone, diameter: buttonSize)
                }
                TmaxLivePhaseBar(state: state, tint: tone)
            }
        }
        .foregroundStyle(.white)
        .dynamicTypeSize(...DynamicTypeSize.xLarge)
    }
}

struct TmaxLiveCompactLeading: View {
    let state: WorkoutActivityAttributes.ContentState
    let accent: Color
    let workoutName: String

    var body: some View {
        TmaxLiveBadge(state: state, tone: state.tone(workout: accent), size: 22)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(state.spokenSummary(workoutName: workoutName))
    }
}

struct TmaxLiveCompactTrailing: View {
    let state: WorkoutActivityAttributes.ContentState
    let isStale: Bool

    var body: some View {
        if state.phase == .completed {
            Text(WorkoutActivityAttributes.ContentState.clock(seconds: state.elapsedSeconds, showsHours: true))
                .font(TmaxLiveStyle.timerFont(size: 13))
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .frame(maxWidth: 52, alignment: .trailing)
                .accessibilityLabel("Total time \(WorkoutActivityAttributes.ContentState.spokenDuration(state.elapsedSeconds))")
        } else {
            TmaxLiveCountdown(state: state, showsHours: false)
                .font(TmaxLiveStyle.timerFont(size: 14))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .frame(width: state.countdownWidth(fontSize: 14, showsHours: false), alignment: .trailing)
                .opacity(isStale ? TmaxLiveStyle.dimmed : 1)
        }
    }
}

struct TmaxLiveMinimal: View {
    let state: WorkoutActivityAttributes.ContentState
    let accent: Color
    let workoutName: String

    var body: some View {
        let tone = state.tone(workout: accent)
        ZStack {
            TmaxLiveRing(state: state, tint: tone)
            TmaxLiveBadge(state: state, tone: tone, size: 14, isCircle: true)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(state.spokenSummary(workoutName: workoutName))
    }
}
