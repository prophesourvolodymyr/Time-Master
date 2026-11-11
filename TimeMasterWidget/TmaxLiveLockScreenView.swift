import ActivityKit
import SwiftUI
import WidgetKit

struct TmaxLiveLockScreenView: View {
    let state: WorkoutActivityAttributes.ContentState
    let workoutName: String
    let colorHex: String
    let isStale: Bool

    var body: some View {
        TmaxLiveLockScreenContent(state: state, workoutName: workoutName, colorHex: colorHex, isStale: isStale)
            .dynamicTypeSize(...DynamicTypeSize.xLarge)
    }
}

private struct TmaxLiveLockScreenContent: View {
    let state: WorkoutActivityAttributes.ContentState
    let workoutName: String
    let colorHex: String
    let isStale: Bool

    @Environment(\.isLuminanceReduced) private var isLuminanceReduced
    @ScaledMetric(relativeTo: .title) private var tileSize: CGFloat = 48
    @ScaledMetric(relativeTo: .title) private var timerSize: CGFloat = 36
    @ScaledMetric(relativeTo: .body) private var buttonSize: CGFloat = 34
    @ScaledMetric(relativeTo: .body) private var nextSize: CGFloat = 30

    private var tone: Color {
        state.tone(workout: Color(widgetHex: colorHex)).opacity(isLuminanceReduced ? 0.75 : 1)
    }

    var body: some View {
        Group {
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

    private var liveRows: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .center, spacing: 12) {
                TmaxLiveTile(state: state, tone: tone, size: tileSize)
                VStack(alignment: .leading, spacing: 1) {
                    TmaxLiveCountdown(state: state)
                        .font(TmaxLiveStyle.timerFont(size: timerSize))
                        .lineLimit(1)
                        .minimumScaleFactor(0.55)
                        .frame(width: state.countdownWidth(fontSize: timerSize, showsHours: true) * 0.93, alignment: .leading)
                        .opacity(isStale ? TmaxLiveStyle.dimmed : 1)
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
                        accent: Color(widgetHex: colorHex),
                        size: state.isRest ? nextSize * 1.2 : nextSize * 0.86,
                        maxNameWidth: state.isRest ? 70 : 62
                    )
                    .fixedSize()
                }
            }
            HStack(spacing: 10) {
                indicator
                Spacer(minLength: 0)
                TmaxLiveControls(state: state, tone: tone, diameter: buttonSize)
            }
            VStack(spacing: 4) {
                TmaxLivePhaseBar(state: state, tint: tone)
                if let fraction = state.workoutFraction {
                    TmaxLiveFillBar(fraction: fraction, tint: Color.white.opacity(0.55), height: 2)
                }
            }
        }
    }

    @ViewBuilder
    private var indicator: some View {
        if isStale {
            TmaxLiveStaleMark()
        } else if let position = state.position {
            TmaxLivePositionView(position: position, isBundle: state.isBundle, tint: tone)
        }
    }

    private var completedRow: some View {
        HStack(spacing: 12) {
            TmaxLiveTile(state: state, tone: tone, size: tileSize)
            VStack(alignment: .leading, spacing: 1) {
                if state.elapsedSeconds > 0 {
                    Text(WorkoutActivityAttributes.ContentState.clock(seconds: state.elapsedSeconds, showsHours: true))
                        .font(TmaxLiveStyle.timerFont(size: timerSize))
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                        .accessibilityLabel("Total time \(WorkoutActivityAttributes.ContentState.spokenDuration(state.elapsedSeconds))")
                }
                Text(state.title)
                    .font(.system(size: 15, weight: .semibold))
                    .lineLimit(1)
                Text(workoutName)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(TmaxLiveStyle.secondary)
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
        }
        .accessibilityElement(children: .combine)
    }
}
