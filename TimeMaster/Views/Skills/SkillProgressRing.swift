import SwiftUI

/// Small ring showing how much of a skill is done; a check mark once all of it is. Frame it where it is used.
struct SkillProgressRing: View {
    let fraction: Double
    var tint: Color = Theme.toolbarOrange
    var lineWidth: CGFloat = 4

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let clamped = min(1, max(0, fraction.isFinite ? fraction : 0))
        ZStack {
            Circle()
                .stroke(Color.white.opacity(0.10), lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: CGFloat(clamped))
                .stroke(tint, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .opacity(clamped > 0 ? 1 : 0)
            if clamped >= 1 {
                Image(systemName: "checkmark")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(tint)
                    .transition(.opacity)
            }
        }
        .animation(reduceMotion ? nil : .easeOut(duration: 0.35), value: clamped)
        .accessibilityHidden(true)
    }
}
