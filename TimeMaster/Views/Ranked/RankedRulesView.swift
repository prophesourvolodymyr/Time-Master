import SwiftUI

struct RankedRulesView: View {
    let variation: RankedVariation

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: ProfileStyle.inset) {
                    RankedMovementArt(variation: variation)
                        .frame(height: ProfileStyle.touchTarget * 4).frame(maxWidth: .infinity)
                    HStack {
                        RankedMetric(value: "60", unit: "s")
                        Spacer()
                        RankedInfoButton(label: variation.fullTitle, message: variation.cue, symbol: variation.isTimedHold ? "stopwatch" : "repeat")
                    }
                    HStack(spacing: ProfileStyle.spacing) {
                        guideStep(1, title: "Set your position", symbol: "figure.stand", detail: setup)
                        guideStep(2, title: variation.isTimedHold ? "Hold your line" : "Move with control", symbol: variation.isTimedHold ? "pause.fill" : "arrow.down", detail: movement)
                        guideStep(3, title: variation.isTimedHold ? "Finish the hold" : "Complete the rep", symbol: variation.isTimedHold ? "stop.fill" : "arrow.up", detail: finish)
                    }
                    cameraGuide
                    HStack(spacing: ProfileStyle.spacing) {
                        ruleCard(title: variation.isTimedHold ? "Longest continuous hold" : "One complete repetition", symbol: variation.isTimedHold ? "stopwatch" : "checkmark.circle", detail: variation.isTimedHold ? "The round lasts 60 seconds. Only the longest uninterrupted valid segment counts, to tenths of a second. A break or unusable observation ends the segment; fragments are never added together. Recalibrate after tracking loss." : "The round lasts 60 seconds. Establish full extension after Go, lower through the required depth, then return to full extension. A partial movement at either boundary does not score. Each endpoint must be observed steadily, not crossed by jitter.")
                        ruleCard(title: "Keep the variation exact", symbol: "scope", detail: variationRule)
                        ruleCard(title: variation.isTimedHold ? "Breaks in form" : "Invalid reps", symbol: "xmark.circle", detail: invalidRule)
                        ruleCard(title: "Assistance and safety", symbol: "hand.raised", detail: assistanceRule)
                    }
                    RankedInfoButton(label: "What tracking validates", message: variation.isAdvanced ? "Advanced Practice uses pose estimates. Rated verification is unavailable until real movement recordings and an appropriate hand/support validation method establish sufficient evidence." : "On-device joint estimates are checked again by the service. This validates observed movement, not the absence of hidden assistance or replay.", symbol: "checkmark.shield")
                }
                .fixedSize(horizontal: false, vertical: true)
                .padding(ProfileStyle.inset)
                .frame(maxWidth: ProfileStyle.readableWidth)
                .frame(maxWidth: .infinity)
            }
            .scrollIndicators(.hidden)
            .background(Theme.background.ignoresSafeArea())
            .foregroundStyle(.white)
            .toolbar {
                AppToolbar.iconItem(placement: .cancellationAction) { RankedCloseButton() }
            }
        }
        .tint(Theme.toolbarOrange)
    }

    private var cameraGuide: some View {
        VStack(spacing: ProfileStyle.spacing) {
            HStack(spacing: ProfileStyle.spacing) {
                Image(systemName: "camera.fill").font(.title2)
                Image(systemName: "arrow.left.and.right").foregroundStyle(ProfileStyle.secondary)
                RankedMovementArt(variation: variation).frame(maxWidth: .infinity)
            }
            .padding(ProfileStyle.inset)
            .frame(height: ProfileStyle.touchTarget * 3)
            .overlay {
                RoundedRectangle(cornerRadius: ProfileStyle.corner)
                    .strokeBorder(Theme.toolbarOrange, style: StrokeStyle(lineWidth: 2, dash: [8, 6]))
            }
            HStack {
                RankedInfoButton(label: "Full-body framing", message: "Use a stable three-quarter view with both shoulders and support points visible. Include your head, hands, hips, knees and feet, the floor and space around the full movement. Moving or rotating the camera requires recalibration.", symbol: "viewfinder")
                Spacer()
                RankedInfoButton(label: "Lighting", message: "Use bright, even lighting and keep your whole body unobstructed.", symbol: "sun.max")
                Spacer()
                RankedInfoButton(label: "Stable camera", message: "Keep the phone fixed throughout calibration and the round. Recalibrate after moving or rotating it.", symbol: "iphone.gen3.radiowaves.left.and.right")
            }
        }
    }

    private func guideStep(_ number: Int, title: String, symbol: String, detail: String) -> some View {
        VStack(spacing: EverSpacing.x2) {
            Text(number.formatted()).font(TimeMasterFont.heading()).monospacedDigit()
            RankedInfoButton(label: "\(number). \(title)", message: detail, symbol: symbol)
        }
        .padding(ProfileStyle.spacing).frame(maxWidth: .infinity)
        .modifier(TimeMasterCardSurface(flat: true))
    }

    private func ruleCard(title: String, symbol: String, detail: String) -> some View {
        RankedInfoButton(label: title, message: detail, symbol: symbol)
            .frame(maxWidth: .infinity)
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
        return variation.family == .squats ? "Lower until both knee angles reach full depth, with hips approximately at knee height. Keep the selected stance throughout." : "Lower with a straight body until both elbow angles reach full depth, then return without shortening the range."
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
        case .pausedPushUp: "Hold the bottom continuously for at least one second before returning. Rebounding or briefly touching the bottom does not satisfy the pause."
        case .tempoPushUp: "Take at least three seconds from leaving full extension to reaching the bottom, then return through the full range."
        case .diamondPushUp: "Keep thumbs and index fingers close in a diamond beneath your chest. Maintain that hand position and a braced body throughout."
        case .wallHandstandPushUp: "Wall contact is the named variation’s intended support. Maintain a controlled inverted position and return to straight arms. Do not kick or bounce to complete a rep."
        case .freestandingHandstandPushUp: "Balance without a wall, spotter or other support. Lower and press under control, returning to a stable freestanding handstand."
        case .planchePushUp: "Keep feet off the floor and the body supported by the hands throughout. Lower and return under control without adding foot or knee support."
        case .standardSquat: "Use a shoulder-width stance. Keep knees tracking with toes and heels grounded through the full movement."
        case .wideSquat: "Keep a wider-than-shoulder stance with knees tracking in the same direction as your toes. Do not shorten the depth."
        case .narrowSquat: "Keep feet closer together while maintaining balance, grounded heels and the full controlled squat."
        case .pausedSquat: "Hold the bottom continuously for at least one second before standing. Separate fragments of a pause are not combined."
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
        if variation.isAdvanced { return "Use only an advanced progression you already control. Stop if you feel pain or lose balance. Body joints alone cannot prove finger contact, wall independence, feet clear of the floor, or absence of bands and hidden supports. Diamond uses additional hand observations; inverted detection also checks a rotated image. Those estimates are not a rated support-verification method." }
        return "Use only a movement you can perform safely, and stop if you feel pain or lose control. Bands, a spotter and furniture can alter the attempt. The camera cannot rule out hidden or off-camera support, or a replay. Only derived joints—not images or video—leave this device for competition; Practice stays local."
    }
}
