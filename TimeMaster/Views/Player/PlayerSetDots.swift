import SwiftUI

struct PlayerSetDots: View {
    let count: Int
    let current: Int
    var noun = "Set"

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Group {
            if count <= 12 {
                HStack(spacing: 7) {
                    ForEach(0..<max(count, 0), id: \.self) { index in
                        Capsule()
                            .fill(color(for: index))
                            .frame(width: index == current ? 28 : 9, height: 9)
                    }
                }
            } else {
                Capsule()
                    .fill(.white.opacity(0.2))
                    .frame(width: 140, height: 9)
                    .overlay(alignment: .leading) {
                        Capsule()
                            .fill(.white)
                            .frame(width: 140 * min(1, Double(current + 1) / Double(count)), height: 9)
                    }
            }
        }
        .animation(reduceMotion ? nil : .spring(response: 0.35, dampingFraction: 0.8), value: current)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(noun) \(min(current + 1, count)) of \(count)")
    }

    private func color(for index: Int) -> Color {
        if index == current { return .white }
        return index < current ? .white.opacity(0.55) : .white.opacity(0.22)
    }
}

struct PlayerSectionBadge: View {
    let current: Int
    let count: Int

    var body: some View {
        Text("\(min(current + 1, max(count, 1))) / \(max(count, 1))")
            .font(TimeMasterFont.black(13, relativeTo: .footnote).monospacedDigit())
            .foregroundColor(.white)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(Color.white.opacity(0.18))
            .cornerRadius(10)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Section \(min(current + 1, max(count, 1))) of \(max(count, 1))")
    }
}
