import SwiftUI

struct RankedDuelPlayerView: View {
    let variation: RankedVariation
    let mode: RankedMode
    let frame: RankedDuelFrame
    let onLeave: () -> Void
    let onFeedback: (RankedMovementFeedback) -> Void
    let onFinish: () -> Void

    @EnvironmentObject private var profileStore: LocalProfileStore
    @Environment(\.dynamicTypeSize) private var typeSize
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var showsFeedbackControls = false

    private var remaining: Int { max(0, frame.remaining) }
    private var timerText: String {
        String(format: "%d:%02d", remaining / 60, remaining % 60)
    }
    private var scoreUnit: String { variation.isTimedHold ? "seconds" : "reps" }
    private var yourShare: Double {
        let yours = Double(max(0, frame.yourScore))
        let theirs = Double(max(0, frame.opponentScore))
        return yours + theirs == 0 ? 0.5 : yours / (yours + theirs)
    }
    private var leadText: String {
        let difference = frame.yourScore - frame.opponentScore
        if difference == 0 { return "Tied" }
        return difference > 0
            ? "+\(difference) · You lead"
            : "+\(-difference) · Alex leads"
    }
    private var feedbackDetail: String {
        switch frame.feedback {
        case .ready:
            "Full body in view. Start in position."
        case .accepted:
            variation.isTimedHold ? "An example of a valid hold." : "An example of a complete repetition."
        case .incomplete:
            variation.isTimedHold ? "Reset your alignment before holding." : "Complete the full range of motion."
        case .outOfFrame:
            "Step back so your whole body fits."
        case .reposition:
            "Move to a clear side-on view."
        case .connectionLost:
            "Disconnect example. No live connection is active."
        }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: ProfileStyle.inset) {
                header
                scoreboard
                movementIllustration
                feedback
                Button(action: onFinish) {
                    Label("Finish demo", systemImage: "flag.checkered")
                        .font(TimeMasterFont.sectionTitle())
                        .frame(maxWidth: .infinity, minHeight: ProfileStyle.touchTarget)
                }
                .buttonStyle(TimeMasterToolbarWideButtonStyle())
                .accessibilityHint("Ends this UI preview. No competitive result is recorded.")
                .accessibilityIdentifier("ranked-duel-finish")
                feedbackControls
            }
            .padding(ProfileStyle.inset)
            .frame(maxWidth: ProfileStyle.readableWidth)
            .frame(maxWidth: .infinity)
        }
        .font(TimeMasterFont.body())
        .foregroundStyle(.white)
        .background(Theme.background.ignoresSafeArea())
        .tint(Theme.toolbarOrange)
        .preferredColorScheme(.dark)
        .accessibilityIdentifier("ranked-duel-player")
    }

    private var header: some View {
        VStack(spacing: ProfileStyle.spacing) {
            HStack(spacing: ProfileStyle.spacing) {
                Button(action: onLeave) {
                    Label("Leave", systemImage: "xmark")
                        .font(TimeMasterFont.rowTitle())
                }
                .buttonStyle(TimeMasterToolbarWideButtonStyle())
                .accessibilityHint("Opens the leave-preview confirmation.")
                .accessibilityIdentifier("ranked-duel-leave")
                Spacer(minLength: 0)
                Text("UI PREVIEW")
                    .font(TimeMasterFont.rowTitle())
                    .foregroundStyle(Theme.toolbarOrange)
                    .fixedSize(horizontal: false, vertical: true)
            }
            VStack(spacing: 6) {
                Text(mode == .practice ? "Practice preview" : "Duel preview")
                    .font(TimeMasterFont.caption())
                    .foregroundStyle(ProfileStyle.secondary)
                Text(variation.fullTitle)
                    .font(TimeMasterFont.heading())
                    .accessibilityAddTraits(.isHeader)
                Text("Scores are examples · No Elo change")
                    .font(TimeMasterFont.caption())
                    .foregroundStyle(ProfileStyle.secondary)
            }
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var scoreboard: some View {
        VStack(spacing: ProfileStyle.spacing) {
            if mode == .practice {
                timer
                soloScore
            } else if typeSize.isAccessibilitySize {
                timer
                scoreSide(isYou: true)
                scoreSide(isYou: false)
                leadBar
            } else {
                ViewThatFits(in: .horizontal) {
                    HStack(alignment: .top, spacing: 8) {
                        scoreSide(isYou: true)
                            .frame(minWidth: 68, maxWidth: .infinity)
                        timer
                            .fixedSize(horizontal: true, vertical: false)
                        scoreSide(isYou: false)
                            .frame(minWidth: 68, maxWidth: .infinity)
                    }
                    VStack(spacing: ProfileStyle.spacing) {
                        timer
                        HStack(alignment: .top, spacing: ProfileStyle.inset) {
                            scoreSide(isYou: true)
                                .frame(maxWidth: .infinity)
                            scoreSide(isYou: false)
                                .frame(maxWidth: .infinity)
                        }
                    }
                }
                leadBar
            }
        }
        .padding(ProfileStyle.inset)
        .frame(maxWidth: .infinity)
        .modifier(TimeMasterCardSurface(flat: true))
    }

    private var timer: some View {
        VStack(spacing: 2) {
            Text("TIME LEFT")
                .font(TimeMasterFont.micro())
                .foregroundStyle(ProfileStyle.secondary)
            Text(timerText)
                .font(typeSize.isAccessibilitySize
                      ? TimeMasterFont.display()
                      : .custom("Inter-Black", size: 64, relativeTo: .largeTitle))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.75)
                .foregroundStyle(.white)
                .accessibilityIdentifier("ranked-duel-timer")
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Time remaining")
        .accessibilityValue("\(remaining) seconds")
    }

    private var soloScore: some View {
        HStack(spacing: ProfileStyle.spacing) {
            ProfileAvatar(profile: profileStore.profile, size: 36)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text("Your example score")
                    .font(TimeMasterFont.caption())
                    .foregroundStyle(ProfileStyle.secondary)
                Text("\(frame.yourScore) \(scoreUnit)")
                    .font(TimeMasterFont.title())
                    .monospacedDigit()
                    .foregroundStyle(Theme.toolbarOrange)
            }
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
    }

    private func scoreSide(isYou: Bool) -> some View {
        VStack(spacing: 6) {
            Text((isYou ? frame.yourScore : frame.opponentScore).formatted())
                .font(typeSize.isAccessibilitySize
                      ? TimeMasterFont.title()
                      : .custom("Inter-Black", size: 36, relativeTo: .title))
                .monospacedDigit()
                .foregroundStyle(isYou ? Theme.toolbarOrange : .white)
            Text(scoreUnit)
                .font(TimeMasterFont.micro())
                .foregroundStyle(ProfileStyle.secondary)
            Group {
                if isYou {
                    ProfileAvatar(profile: profileStore.profile, size: 32)
                } else {
                    Image(systemName: "person.fill")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(ProfileStyle.secondary)
                        .frame(width: 32, height: 32)
                        .background(Theme.surface2, in: Circle())
                }
            }
            .accessibilityHidden(true)
            Text(isYou ? "You" : "Alex")
                .font(TimeMasterFont.rowTitle())
            Text(isYou ? "Your example score" : "Example opponent")
                .font(TimeMasterFont.micro())
                .foregroundStyle(ProfileStyle.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .multilineTextAlignment(.center)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(isYou ? "Your example score" : "Alex, example opponent")
        .accessibilityValue("\(isYou ? frame.yourScore : frame.opponentScore) \(scoreUnit)")
    }

    private var leadBar: some View {
        VStack(spacing: 8) {
            GeometryReader { geometry in
                HStack(spacing: 3) {
                    Rectangle()
                        .fill(Theme.toolbarOrange)
                        .frame(width: max(0, geometry.size.width - 3) * yourShare)
                    Rectangle()
                        .fill(ProfileStyle.secondary)
                }
                .clipShape(Capsule())
            }
            .frame(height: 8)
            .animation(reduceMotion ? nil : .easeOut(duration: 0.25), value: yourShare)
            .accessibilityHidden(true)
            Text(leadText)
                .font(TimeMasterFont.caption())
                .foregroundStyle(ProfileStyle.secondary)
                .multilineTextAlignment(.center)
                .accessibilityLabel("Example scores: \(leadText)")
        }
    }

    private var movementIllustration: some View {
        VStack(spacing: ProfileStyle.spacing) {
            ZStack {
                RoundedRectangle(cornerRadius: ProfileStyle.corner, style: .continuous)
                    .fill(Theme.surface)
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(ProfileStyle.secondary.opacity(0.5), style: StrokeStyle(lineWidth: 1, dash: [8, 6]))
                    .padding(ProfileStyle.inset)
                RankedMovementArt(variation: variation)
                    .padding(28)
            }
            .frame(height: typeSize.isAccessibilitySize ? 200 : 228)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Movement illustration for \(variation.fullTitle). Not a camera feed.")
            Label("Illustration · Camera not connected", systemImage: "video.slash")
                .font(TimeMasterFont.caption())
                .foregroundStyle(ProfileStyle.secondary)
                .multilineTextAlignment(.center)
            Text(variation.cue)
                .font(TimeMasterFont.secondary())
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var feedback: some View {
        HStack(alignment: .top, spacing: ProfileStyle.spacing) {
            Image(systemName: frame.feedback.symbol)
                .font(.title3.weight(.semibold))
                .foregroundStyle(Theme.toolbarOrange)
                .frame(width: ProfileStyle.touchTarget, height: ProfileStyle.touchTarget)
                .background(Theme.surface2, in: Circle())
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 4) {
                Text("EXAMPLE FEEDBACK")
                    .font(TimeMasterFont.micro())
                    .foregroundStyle(ProfileStyle.secondary)
                Text(frame.feedback.title)
                    .font(TimeMasterFont.rowTitle())
                Text(feedbackDetail)
                    .font(TimeMasterFont.secondary())
                    .foregroundStyle(ProfileStyle.secondary)
            }
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(ProfileStyle.spacing)
        .modifier(TimeMasterCardSurface(flat: true))
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("ranked-duel-feedback")
    }

    private var feedbackControls: some View {
        DisclosureGroup(isExpanded: $showsFeedbackControls) {
            VStack(alignment: .leading, spacing: ProfileStyle.spacing) {
                Text("Change the example feedback only. Scores are not affected.")
                    .font(TimeMasterFont.caption())
                    .foregroundStyle(ProfileStyle.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                LazyVGrid(columns: typeSize.isAccessibilitySize
                          ? [GridItem(.flexible())]
                          : [GridItem(.adaptive(minimum: 135))], spacing: 8) {
                    ForEach(RankedMovementFeedback.allCases) { state in
                        Button {
                            onFeedback(state)
                        } label: {
                            HStack(spacing: 6) {
                                Label(state.title, systemImage: state.symbol)
                                    .fixedSize(horizontal: false, vertical: true)
                                Spacer(minLength: 0)
                                if frame.feedback == state {
                                    Image(systemName: "checkmark")
                                        .accessibilityHidden(true)
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .buttonStyle(TimeMasterSelectionButtonStyle(isSelected: frame.feedback == state))
                        .accessibilityLabel("Preview \(state.title)")
                        .accessibilityAddTraits(frame.feedback == state ? .isSelected : [])
                        .accessibilityIdentifier("ranked-feedback-\(state.rawValue)")
                    }
                }
            }
            .padding(.top, ProfileStyle.spacing)
        } label: {
            Label("Preview feedback", systemImage: "slider.horizontal.3")
                .font(TimeMasterFont.rowTitle())
                .frame(minHeight: ProfileStyle.touchTarget)
        }
        .padding(.horizontal, 4)
        .accessibilityIdentifier("ranked-feedback-controls")
    }
}
