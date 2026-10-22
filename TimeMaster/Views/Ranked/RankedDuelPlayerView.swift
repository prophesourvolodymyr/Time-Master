import SwiftUI

struct RankedDuelPlayerView: View {
    let variation: RankedVariation
    let mode: RankedMode
    let frame: RankedDuelFrame
    @ObservedObject var camera: RankedCamera
    let onLeave: () -> Void
    @EnvironmentObject private var profileStore: LocalProfileStore
    @Environment(\.dynamicTypeSize) private var typeSize
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var timerText: String { String(format: "%d:%02d", max(0, frame.remaining) / 60, max(0, frame.remaining) % 60) }
    private var unit: String { variation.isTimedHold ? "seconds" : "reps" }
    private var share: Double {
        let total = frame.yourScore + frame.opponentScore
        return total > 0 ? max(0, min(1, frame.yourScore / total)) : 0.5
    }
    private var lead: String {
        let difference = frame.yourScore - frame.opponentScore
        if abs(difference) < 0.1 { return "Tied · Provisional" }
        return "+\(score(abs(difference))) · \(difference > 0 ? "You lead" : "Opponent leads") · Provisional"
    }

    var body: some View {
        Group {
            if typeSize.isAccessibilitySize {
                ScrollView { content(cameraHeight: 260) }
            } else {
                content(cameraHeight: nil)
            }
        }
        .foregroundStyle(.white).background(Theme.background.ignoresSafeArea())
        .tint(Theme.toolbarOrange).preferredColorScheme(.dark)
        .accessibilityIdentifier("ranked-duel-player")
    }

    private func content(cameraHeight: CGFloat?) -> some View {
        VStack(spacing: ProfileStyle.spacing) {
            header
            scoreboard
            if let cameraHeight {
                RankedCameraPreview(camera: camera).frame(height: cameraHeight)
            } else {
                RankedCameraPreview(camera: camera).frame(minHeight: 160, maxHeight: .infinity)
            }
            feedback
        }
        .padding(ProfileStyle.inset)
        .frame(maxWidth: ProfileStyle.readableWidth).frame(maxWidth: .infinity)
    }

    private var header: some View {
        HStack(spacing: ProfileStyle.spacing) {
            leaveButton
            Spacer(minLength: 0)
            TimeMasterPageTitle(variation.fullTitle, size: 20, relativeTo: .subheadline)
                .multilineTextAlignment(.trailing)
            RankedMovementArt(variation: variation)
                .frame(width: ProfileStyle.touchTarget * 1.5, height: ProfileStyle.touchTarget)
                .accessibilityHidden(false)
                .accessibilityLabel(variation.fullTitle)
        }
    }

    private var leaveButton: some View {
        RankedIconAction(symbol: "xmark", label: "Leave", action: onLeave)
            .accessibilityHint(mode == .duel ? "Leaving after Go forfeits the match." : "Ends this solo activity.")
            .accessibilityIdentifier("ranked-duel-leave")
    }

    private var feedback: some View {
        HStack(spacing: ProfileStyle.spacing) {
            RankedInfoButton(label: frame.phase, message: frame.feedback, symbol: phaseSymbol)
            if variation.isTimedHold {
                RankedMetric(value: camera.tracking.currentHold.formatted(.number.precision(.fractionLength(1))), unit: "s")
                    .accessibilityLabel("Current continuous hold")
            }
            Spacer(minLength: 0)
            connection
        }
        .padding(EverSpacing.x2)
        .modifier(TimeMasterCardSurface(flat: true))
        .accessibilityIdentifier("ranked-duel-feedback")
    }

    private var phaseSymbol: String {
        guard camera.tracking.usable else { return "viewfinder" }
        switch frame.phase {
        case "Lower": return "arrow.down"
        case "Return to full extension": return "arrow.up"
        case "Holding": return "pause.fill"
        default: return "figure.stand"
        }
    }


    @ViewBuilder private var connection: some View {
        if mode == .duel {
            RankedInfoButton(label: frame.connected ? "Live connection" : "Reconnecting", message: frame.connected ? "Scores are provisional until the service verifies the round." : "Connection interrupted. The shared round clock continues; the last opponent score is not a live update.", symbol: frame.connected ? "wifi" : "wifi.exclamationmark")
        }
    }

    private var scoreboard: some View {
        VStack(spacing: ProfileStyle.spacing) {
            if typeSize.isAccessibilitySize {
                timer
                HStack { scoreSide(you: true); if mode == .duel { scoreSide(you: false) } }
            } else {
                HStack(alignment: .center, spacing: ProfileStyle.spacing) {
                    scoreSide(you: true).frame(maxWidth: .infinity)
                    timer.fixedSize(horizontal: true, vertical: false)
                    if mode == .duel { scoreSide(you: false).frame(maxWidth: .infinity) }
                    else {
                        Label("Solo", systemImage: "person.fill")
                            .font(TimeMasterFont.caption())
                            .foregroundStyle(ProfileStyle.secondary).frame(maxWidth: .infinity)
                    }
                }
            }
            if mode == .duel {
                GeometryReader { geometry in
                    HStack(spacing: 3) {
                        Rectangle().fill(Theme.toolbarOrange).frame(width: max(0, geometry.size.width - 3) * share)
                        Rectangle().fill(ProfileStyle.secondary.opacity(0.65))
                    }.clipShape(Capsule())
                }
                .frame(height: 6).accessibilityHidden(true)
                .animation(reduceMotion ? nil : .easeOut(duration: 0.2), value: share)
                HStack(spacing: EverSpacing.x1) {
                    Image(systemName: frame.yourScore == frame.opponentScore ? "equal" : frame.yourScore > frame.opponentScore ? "arrow.up.right" : "arrow.down.right")
                    Text("\(frame.yourScore >= frame.opponentScore ? "+" : "−")\(score(abs(frame.yourScore - frame.opponentScore))) \(unit)")
                        .monospacedDigit()
                }
                .font(TimeMasterFont.micro()).foregroundStyle(ProfileStyle.secondary)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(lead)
            }
        }
        .padding(ProfileStyle.spacing).frame(maxWidth: .infinity)
        .modifier(TimeMasterCardSurface(flat: true))
    }

    private var timer: some View {
        VStack(spacing: 2) {
            Text("Time left").font(TimeMasterFont.micro()).foregroundStyle(ProfileStyle.secondary)
            Text(timerText).font(TimeMasterFont.black(40, relativeTo: .largeTitle).monospacedDigit())
                .accessibilityIdentifier("ranked-duel-timer")
        }
        .accessibilityElement(children: .ignore).accessibilityLabel("Time remaining").accessibilityValue("\(frame.remaining) seconds")
    }

    private func scoreSide(you: Bool) -> some View {
        VStack(spacing: 3) {
            HStack(spacing: 5) {
                if you { ProfileAvatar(profile: profileStore.profile, size: 22).accessibilityHidden(true) }
                else { Image(systemName: "person.crop.circle.fill").accessibilityHidden(true) }
                Text(you ? profileStore.profile.displayName : frame.opponentName).font(TimeMasterFont.micro()).lineLimit(1)
            }.foregroundStyle(ProfileStyle.secondary)
            Text(score(you ? frame.yourScore : frame.opponentScore))
                .font(TimeMasterFont.black(34, relativeTo: .title).monospacedDigit())
                .foregroundStyle(you ? Theme.toolbarOrange : .white)
            Text(unit).font(TimeMasterFont.micro()).foregroundStyle(ProfileStyle.secondary)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(you ? "Your provisional score" : "\(frame.opponentName), provisional score")
        .accessibilityValue("\(score(you ? frame.yourScore : frame.opponentScore)) \(unit)")
    }

    private func score(_ value: Double) -> String {
        variation.isTimedHold ? value.formatted(.number.precision(.fractionLength(1))) : Int(value).formatted()
    }
}
