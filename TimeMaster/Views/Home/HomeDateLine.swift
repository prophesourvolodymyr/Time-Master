import SwiftUI

/// The date under Home's greeting, "Sunday, November 1", a little larger than caption text, followed by a small flame, the
/// one from the Schedule page, with the current streak in it: lit, and hotter the longer the streak, or an empty outline
/// holding 0 when there is none. Now and then a soft glint glides across the text. Reduce Motion keeps everything still.
struct HomeDateLine: View {
    let date: Date
    let streak: Int

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase

    /// One glint every nine seconds, two and a half seconds to cross the line.
    static let glintCycle: TimeInterval = 9
    static let glintDuration: TimeInterval = 2.5

    /// The flame tier (the Schedule page's 1...7 scale, see `ScheduleFlame.accent`) a streak burns at: yellow for the first
    /// days, then orange, red, purple and, from a month, the pale violet of the hottest flame. nil without a streak, which
    /// is an empty flame.
    static func flameTier(forStreak days: Int) -> Int? {
        switch days {
        case ..<1: return nil
        case 1...2: return 3
        case 3...6: return 4
        case 7...13: return 5
        case 14...29: return 6
        default: return 7
        }
    }

    /// Where the glint is across the line (0 is the left edge, 1 the right) at `time`; nil between two glints.
    static func glint(at time: TimeInterval) -> Double? {
        let local = time.truncatingRemainder(dividingBy: glintCycle)
        return local < glintDuration ? local / glintDuration : nil
    }

    static func streakDescription(_ streak: Int) -> String {
        switch streak {
        case ...0: "no streak"
        case 1: "1 day streak"
        default: "\(streak) day streak"
        }
    }

    var body: some View {
        if reduceMotion || scenePhase != .active {
            HomeDateRow(date: date, streak: streak, glint: nil)
        } else {
            TimelineView(GlintSchedule()) { timeline in
                HomeDateRow(date: date, streak: streak, glint: Self.glint(at: timeline.date.timeIntervalSinceReferenceDate))
            }
        }
    }
}

/// Frames only while the glint crosses the line, then one at the start of the next pass, so the line costs nothing in
/// between.
struct GlintSchedule: TimelineSchedule {
    static let framesPerSecond = 24.0

    func entries(from start: Date, mode: TimelineScheduleMode) -> UnfoldSequence<Date, TimeInterval> {
        sequence(state: start.timeIntervalSinceReferenceDate) { next in
            let now = next
            let local = now.truncatingRemainder(dividingBy: HomeDateLine.glintCycle)
            // The frame after the nearest one on the grid, so ticks never repeat and never drift.
            let following = ((local * GlintSchedule.framesPerSecond).rounded() + 1) / GlintSchedule.framesPerSecond
            next = following < HomeDateLine.glintDuration - 1e-9
                ? now - local + following
                : now - local + HomeDateLine.glintCycle
            return Date(timeIntervalSinceReferenceDate: now)
        }
    }
}

/// The date line drawn for one moment; `glint` is where the glint is across it (nil for none).
struct HomeDateRow: View {
    let date: Date
    let streak: Int
    var glint: Double?

    @ScaledMetric(relativeTo: .subheadline) private var flameSize: CGFloat = 30

    private var dateText: String {
        date.formatted(.dateTime.weekday(.wide).month(.wide).day())
    }

    var body: some View {
        textRow(flame: true)
            .overlay { glintLayer }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("\(dateText), \(HomeDateLine.streakDescription(streak))")
    }

    private func textRow(flame: Bool) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 0) {
            Text(dateText)
            streakNumber(flame: flame)
        }
        .font(TimeMasterFont.black(15, relativeTo: .subheadline))
        .foregroundStyle(Theme.textSecondary)
        .lineLimit(1)
    }

    @ViewBuilder
    private func streakNumber(flame: Bool) -> some View {
        let days = max(0, streak)
        let tier = HomeDateLine.flameTier(forStreak: days)
        let digits = String(days).count
        let side = flameSize * (digits > 2 ? 1.3 : digits > 1 ? 1.12 : 1)
        Text("\(days)")
            .monospacedDigit()
            .foregroundStyle(tier == nil ? Theme.textSecondary : Theme.textPrimary)
            .padding(.horizontal, 8)
            .background {
                if flame {
                    ScheduleFlame(difficulty: tier ?? 1, isBurning: tier != nil, showsCore: false)
                        .frame(width: side, height: side)
                        .offset(y: -3.5)
                }
            }
            .padding(.leading, 8)
    }

    private static func clamped(_ value: Double) -> Double { min(1, max(0, value)) }

    /// A soft band of light over the letters (and only the letters) that moves from the left edge to the right.
    @ViewBuilder
    private var glintLayer: some View {
        if let glint {
            let half = 0.2
            let centre = -half + glint * (1 + 2 * half)
            LinearGradient(stops: [
                .init(color: Theme.textPrimary.opacity(0), location: Self.clamped(centre - half)),
                .init(color: Theme.textPrimary.opacity(0.85), location: Self.clamped(centre)),
                .init(color: Theme.textPrimary.opacity(0), location: Self.clamped(centre + half)),
            ], startPoint: .leading, endPoint: .trailing)
            .mask { textRow(flame: false) }
            .allowsHitTesting(false)
        }
    }
}
