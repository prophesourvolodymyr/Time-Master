import SwiftUI

struct RankedRulesView: View {
    let variation: RankedVariation
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: ProfileStyle.inset) {
                    VStack(alignment: .leading, spacing: ProfileStyle.spacing) {
                        RankedMovementArt(variation: variation)
                            .frame(maxWidth: .infinity)
                            .frame(height: 180)
                        Text(variation.fullTitle).font(TimeMasterFont.title())
                            .accessibilityAddTraits(.isHeader)
                        Label(variation.battleRule, systemImage: variation.isTimedHold ? "timer" : "repeat")
                            .font(TimeMasterFont.secondary())
                            .foregroundStyle(Theme.toolbarOrange)
                        Text(variation.cue).font(TimeMasterFont.body())
                    }
                    .padding(ProfileStyle.inset)
                    .modifier(TimeMasterCardSurface(flat: true))

                    Text("MOVEMENT GUIDE").font(TimeMasterFont.sectionTitle())
                        .accessibilityAddTraits(.isHeader)
                    VStack(spacing: 0) {
                        guideStep(1, title: "Set your position", symbol: "figure.stand", detail: setup)
                        Divider().overlay(Theme.surface2).padding(.leading, 64)
                        guideStep(2, title: variation.isTimedHold ? "Hold your line" : "Move with control", symbol: variation.isTimedHold ? "pause.circle" : "arrow.down.circle", detail: movement)
                        Divider().overlay(Theme.surface2).padding(.leading, 64)
                        guideStep(3, title: variation.isTimedHold ? "Finish the hold" : "Complete the rep", symbol: variation.isTimedHold ? "stop.circle" : "arrow.up.circle", detail: finish)
                    }
                    .modifier(TimeMasterCardSurface(flat: true))

                    cameraGuide
                    ruleCard(title: variation.isTimedHold ? "What the timer measures" : "What counts as one rep", symbol: variation.isTimedHold ? "stopwatch" : "checkmark.circle", detail: variation.isTimedHold ? "The proposed round is 60 seconds. Your score is the longest continuous valid hold, in seconds, within that round—not the sum of separate attempts. Leaving the position ends that hold." : "The proposed round is 60 seconds. One full return from the starting position, through the required range and back, counts as one rep. Partial movements and bouncing do not count.")
                    ruleCard(title: "Keep the variation exact", symbol: "scope", detail: variationRule)
                    ruleCard(title: variation.isTimedHold ? "Breaks in form" : "Invalid reps", symbol: "xmark.circle", detail: invalidRule)
                    ruleCard(title: "Assistance & safety", symbol: "hand.raised", detail: assistanceRule)
                    Label("Live movement verification is not connected. This guide explains the intended rules; the camera does not currently certify reps, holds, or advanced poses.", systemImage: "camera.badge.ellipsis")
                        .font(TimeMasterFont.secondary())
                        .foregroundStyle(ProfileStyle.secondary)
                        .padding(ProfileStyle.inset)
                        .modifier(TimeMasterCardSurface(flat: true))
                }
                .fixedSize(horizontal: false, vertical: true)
                .padding(ProfileStyle.inset)
                .frame(maxWidth: ProfileStyle.readableWidth)
                .frame(maxWidth: .infinity)
            }
            .scrollIndicators(.hidden)
            .background(Theme.background.ignoresSafeArea())
            .foregroundStyle(.white)
            .navigationTitle("Movement rules")
#if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
#endif
            .toolbar {
                AppToolbar.item(placement: .cancellationAction) { Button("Close") { dismiss() } }
            }
        }
        .tint(Theme.toolbarOrange)
    }

    private var cameraGuide: some View {
        VStack(alignment: .leading, spacing: ProfileStyle.spacing) {
            Label("Keep the whole movement in frame", systemImage: "viewfinder")
                .font(TimeMasterFont.sectionTitle())
                .accessibilityAddTraits(.isHeader)
            ZStack {
                RoundedRectangle(cornerRadius: ProfileStyle.corner)
                    .strokeBorder(Theme.toolbarOrange, style: StrokeStyle(lineWidth: 2, dash: [8, 6]))
                HStack(spacing: ProfileStyle.spacing) {
                    Image(systemName: "camera.fill").font(.title2)
                    Image(systemName: "arrow.left.and.right").foregroundStyle(ProfileStyle.secondary)
                    RankedMovementArt(variation: variation)
                        .frame(maxWidth: 180)
                        .padding(ProfileStyle.spacing)
                }
                .padding(ProfileStyle.inset)
            }
            .frame(height: 150)
            .accessibilityHidden(true)
            Text(variation.family == .squats ? "Use a stable side or three-quarter view. Keep your head, hips, knees and feet visible, with room above and below the full squat." : "Use a stable side or three-quarter view. Keep your head, hands, hips and feet visible throughout; include the floor and leave space around your body.")
                .font(TimeMasterFont.secondary())
                .foregroundStyle(ProfileStyle.secondary)
            Text("Bright, even light · Unobstructed view · Stable phone")
                .font(TimeMasterFont.caption())
        }
        .padding(ProfileStyle.inset)
        .modifier(TimeMasterCardSurface(flat: true))
    }

    private func guideStep(_ number: Int, title: String, symbol: String, detail: String) -> some View {
        HStack(alignment: .top, spacing: ProfileStyle.spacing) {
            VStack(spacing: 8) {
                Text(number.formatted()).font(TimeMasterFont.heading())
                Image(systemName: symbol).font(.title2)
            }
            .foregroundStyle(Theme.toolbarOrange)
            .frame(width: ProfileStyle.touchTarget)
            .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 6) {
                Text("\(number). \(title)").font(TimeMasterFont.rowTitle())
                Text(detail).font(TimeMasterFont.secondary()).foregroundStyle(ProfileStyle.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(ProfileStyle.inset)
        .accessibilityElement(children: .combine)
    }

    private func ruleCard(title: String, symbol: String, detail: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(title, systemImage: symbol).font(TimeMasterFont.rowTitle())
            Text(detail).font(TimeMasterFont.secondary()).foregroundStyle(ProfileStyle.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(ProfileStyle.inset)
        .modifier(TimeMasterCardSurface(flat: true))
    }

    private var setup: String {
        if variation.isAdvanced {
            return "Use only a progression you can already perform safely. Establish a stable, controlled starting position before attempting a rep."
        }
        if variation.isTimedHold { return variation.cue }
        return variation.family == .squats ? "Stand tall in this variation’s stance. Keep both feet grounded and your balance centered." : "Begin at the top with arms extended. Brace your torso; use knees only for the knee variation."
    }

    private var movement: String {
        if variation.isTimedHold { return "Brace and breathe normally. Maintain the same support points and a straight, steady body line." }
        if variation.isAdvanced { return "Lower under control through the range you can safely own. Keep the prescribed support points throughout." }
        return variation.family == .squats ? "Bend your knees and hips together. Lower until your thighs are approximately parallel to the floor, without lifting your heels." : "Lower your chest toward the floor with a stable torso until your upper arms are approximately parallel to the floor."
    }

    private var finish: String {
        if variation.isTimedHold { return "Lower safely when your alignment or support changes. A new attempt starts a separate hold, not a continuation." }
        return variation.family == .squats ? "Stand fully upright again with control. Finish extending your hips and knees before the next rep." : "Press back to the starting height with arms extended. Finish the full return before beginning the next rep."
    }

    private var variationRule: String {
        switch variation {
        case .standardPushUp: "Hands beneath or just outside the shoulders; toes stay grounded. Keep shoulders, hips and ankles aligned."
        case .widePushUp: "Keep hands wider than shoulder width for the whole set. A wider grip does not replace the full range of motion."
        case .closePushUp: "Keep hands close beneath the chest and elbows controlled. Do not switch to a standard grip during a rep."
        case .kneePushUp: "Knees are the intended support. Maintain a straight line from shoulders through hips to knees; do not hinge at the hips."
        case .pausedPushUp: "Come to a clear, controlled stop at the bottom before pressing up. Bouncing straight out of the bottom is not a paused rep."
        case .tempoPushUp: "Use a visibly slow, controlled lowering phase, then return with control. Rushing the descent changes the variation."
        case .diamondPushUp: "Keep thumbs and index fingers close in a diamond beneath your chest. Maintain that hand position and a braced body throughout."
        case .wallHandstandPushUp: "Wall contact is the named variation’s intended support. Maintain a controlled inverted position and return to straight arms. Do not kick or bounce to complete a rep."
        case .freestandingHandstandPushUp: "Balance without a wall, spotter or other support. Lower and press under control, returning to a stable freestanding handstand."
        case .planchePushUp: "Keep feet off the floor and the body supported by the hands throughout. Lower and return under control without adding foot or knee support."
        case .standardSquat: "Use a shoulder-width stance. Keep knees tracking with toes and heels grounded through the full movement."
        case .wideSquat: "Keep a wider-than-shoulder stance with knees tracking in the same direction as your toes. Do not shorten the depth."
        case .narrowSquat: "Keep feet closer together while maintaining balance, grounded heels and the full controlled squat."
        case .pausedSquat: "Stop under control at the bottom before standing. A continuous bounce is not a paused squat."
        case .forearmPlank: "Support yourself on forearms and toes, elbows under shoulders. Keep shoulders, hips and ankles in one line."
        case .highPlank: "Support yourself on hands and toes with straight arms. Keep hands under shoulders and hips level."
        case .leftSidePlank: "Use the left forearm and left foot as supports. Stack the feet and shoulders; keep hips lifted. Right-side time is a different variation."
        case .rightSidePlank: "Use the right forearm and right foot as supports. Stack the feet and shoulders; keep hips lifted. Left-side time is a different variation."
        }
    }

    private var invalidRule: String {
        if variation.isTimedHold { return "Dropping or lifting the hips out of alignment, resting a knee, changing sides or adding a support ends the valid hold. Moving outside the frame prevents assessment." }
        if variation.isAdvanced { return "Partial returns, momentum-assisted reps, loss of the prescribed position or extra support do not meet the intended movement. A camera view alone cannot establish that a difficult pose is unassisted." }
        return variation.family == .squats ? "Incomplete depth, a partial stand, bouncing or changing stance do not count as complete reps. Keep the entire movement visible." : "Incomplete depth, a partial return, sagging or sharply lifted hips, and changing support points do not count. Knee support is valid only in knee push-ups."
    }

    private var assistanceRule: String {
        if variation.isAdvanced { return "Advanced and inverted movements require appropriate training and a safe space. Do not attempt an unfamiliar pose for a preview. Bands, hidden supports or a spotter can change the movement, and this app cannot currently detect them. Wall contact is allowed only for the wall variation. Stop if you feel pain or lose control." }
        return "Do not use bands, a spotter or furniture to assist a scored movement unless the variation explicitly calls for support. This app cannot currently detect hidden assistance. Choose a movement you can perform safely and stop if you feel pain or lose control."
    }
}
