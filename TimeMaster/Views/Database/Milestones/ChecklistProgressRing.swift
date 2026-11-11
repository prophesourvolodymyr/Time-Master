import SwiftUI

/// A small progress ring with a symbol inside: how much of a list is done, at a glance.
struct ChecklistProgressRing: View {
    let fraction: Double
    let symbol: String
    var size: CGFloat = 30

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            Circle().stroke(Color.white.opacity(0.1), lineWidth: 3)
            Circle()
                .trim(from: 0, to: max(0, min(1, fraction)))
                .stroke(Theme.toolbarOrange, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(reduceMotion ? nil : .easeOut(duration: 0.35), value: fraction)
            Image(systemName: symbol)
                .font(.system(size: size * 0.4, weight: .bold))
                .foregroundStyle(fraction >= 1 ? Theme.toolbarOrange : Theme.textPrimary)
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}
