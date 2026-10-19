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
        Group {
            if typeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: ProfileStyle.spacing) {
                    leaveButton
                    Text(variation.fullTitle).font(TimeMasterFont.caption())
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                HStack(spacing: ProfileStyle.spacing) {
                    leaveButton
                    Spacer(minLength: 0)
                    Text(variation.fullTitle).font(TimeMasterFont.caption()).multilineTextAlignment(.trailing)
                }
            }
        }
    }

    private var leaveButton: some View {
        Button(action: onLeave) { Label("Leave", systemImage: "xmark") }
            .buttonStyle(TimeMasterToolbarWideButtonStyle())
            .fixedSize()
            .accessibilityHint(mode == .duel ? "Leaving after Go forfeits the match." : "Ends this solo activity.")
            .accessibilityIdentifier("ranked-duel-leave")
    }

    private var feedback: some View {
        Group {
            if typeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: ProfileStyle.spacing) {
                    HStack { feedbackIcon; Spacer(minLength: 0); connection }
                    feedbackText
                }
            } else {
                HStack(alignment: .top, spacing: ProfileStyle.spacing) {
                    feedbackIcon
                    feedbackText
                    connection
                }
            }
        }
        .padding(ProfileStyle.spacing).frame(maxWidth: .infinity, alignment: .leading)
        .modifier(TimeMasterCardSurface(flat: true))
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("ranked-duel-feedback")
    }

    private var feedbackIcon: some View {
        Image(systemName: camera.tracking.usable ? "figure.strengthtraining.traditional" : "viewfinder")
            .foregroundStyle(Theme.toolbarOrange).accessibilityHidden(true)
    }

    private var feedbackText: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(frame.phase).font(TimeMasterFont.rowTitle())
            Text(frame.feedback).font(TimeMasterFont.caption()).foregroundStyle(ProfileStyle.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder private var connection: some View {
        if mode == .duel {
            Label(frame.connected ? "Live" : "Reconnecting", systemImage: frame.connected ? "wifi" : "wifi.exclamationmark")
                .font(TimeMasterFont.micro()).foregroundStyle(frame.connected ? ProfileStyle.secondary : Theme.toolbarOrange)
                .fixedSize(horizontal: true, vertical: false)
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
                        Label("Solo", systemImage: "figure.stand")
                            .font(TimeMasterFont.caption()).foregroundStyle(ProfileStyle.secondary).frame(maxWidth: .infinity)
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
                Text(lead).font(TimeMasterFont.micro()).foregroundStyle(ProfileStyle.secondary)
            } else {
                Text("Camera-tracked Practice · No Elo or allowance used")
                    .font(TimeMasterFont.micro()).foregroundStyle(ProfileStyle.secondary)
            }
        }
        .padding(ProfileStyle.spacing).frame(maxWidth: .infinity)
        .modifier(TimeMasterCardSurface(flat: true))
    }

    private var timer: some View {
        VStack(spacing: 2) {
            Text("TIME").font(TimeMasterFont.micro()).foregroundStyle(ProfileStyle.secondary)
            Text(timerText).font(.custom("Inter-Black", size: 40, relativeTo: .largeTitle).monospacedDigit())
                .accessibilityIdentifier("ranked-duel-timer")
        }
        .accessibilityElement(children: .ignore).accessibilityLabel("Time remaining").accessibilityValue("\(frame.remaining) seconds")
    }

    private func scoreSide(you: Bool) -> some View {
        VStack(spacing: 3) {
            HStack(spacing: 5) {
                if you { ProfileAvatar(profile: profileStore.profile, size: 22).accessibilityHidden(true) }
                else { Image(systemName: "person.crop.circle.fill").accessibilityHidden(true) }
                Text(you ? "You" : frame.opponentName).font(TimeMasterFont.micro()).lineLimit(1)
            }.foregroundStyle(ProfileStyle.secondary)
            Text(score(you ? frame.yourScore : frame.opponentScore))
                .font(.custom("Inter-Black", size: 34, relativeTo: .title).monospacedDigit())
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
