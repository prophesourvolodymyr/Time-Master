import SwiftUI
import TimeMasterCore

struct PlayerComboStage: View {
    let section: Section
    let items: [PlayerQueueItem]
    let currentIndex: Int

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var current: PlayerQueueItem? {
        items.indices.contains(currentIndex) ? items[currentIndex] : nil
    }

    private var upcoming: [PlayerQueueItem] {
        Array(items.dropFirst(currentIndex + 1).prefix(3))
    }

    var body: some View {
        let tokens = ComboCall.tokens(in: current?.name ?? "")
        ZStack(alignment: .topTrailing) {
            VStack(spacing: 16) {
                Text(section.name.uppercased())
                    .font(TimeMasterFont.black(12, relativeTo: .caption))
                    .tracking(1.4)
                    .foregroundStyle(.white.opacity(0.8))
                    .lineLimit(1)
                    .padding(.horizontal, 56)
                tiles(tokens)
                    .id(current?.id)
                    .transition(reduceMotion ? .opacity : .opacity.combined(with: .scale(scale: 0.94)))
                Text(ComboCall.spoken(tokens).capitalized)
                    .font(TimeMasterFont.black(18, relativeTo: .title3))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                if !upcoming.isEmpty {
                    ViewThatFits(in: .horizontal) {
                        nextRow(upcoming)
                        nextRow(Array(upcoming.prefix(2)))
                        nextRow(Array(upcoming.prefix(1)))
                    }
                    .padding(.top, 2)
                }
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 24)
            .frame(maxWidth: .infinity)

            ComboCornerIcon(iconName: section.iconName, iconType: section.iconType, size: 40)
                .padding(14)
        }
        .background(ComboStyle.gradient, in: RoundedRectangle(cornerRadius: 30, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 30, style: .continuous).strokeBorder(Color.white.opacity(0.18), lineWidth: 1))
        .shadow(color: ComboStyle.bright.opacity(0.35), radius: 24, y: 10)
        .animation(reduceMotion ? nil : .spring(response: 0.34, dampingFraction: 0.82), value: current?.id)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Combo, \(ComboCall.spoken(tokens))")
    }

    private func nextRow(_ items: [PlayerQueueItem]) -> some View {
        HStack(spacing: 8) {
            Text("Next")
                .font(TimeMasterFont.black(12, relativeTo: .caption))
                .foregroundStyle(.white.opacity(0.75))
            ForEach(items) { item in
                ComboCallChip(tokens: ComboCall.tokens(in: item.name), compact: true)
                    .opacity(0.85)
            }
        }
    }

    private func tiles(_ tokens: [String]) -> some View {
        let count = max(tokens.count, 1)
        let digit: CGFloat = count <= 3 ? 56 : (count <= 5 ? 44 : 32)
        return HStack(spacing: count > 4 ? 6 : 10) {
            ForEach(Array(tokens.enumerated()), id: \.offset) { _, token in
                let move = ComboMoves.move(for: token)
                VStack(spacing: 4) {
                    Image(systemName: move?.symbol ?? "waveform")
                        .font(.system(size: count <= 5 ? 24 : 18, weight: .bold))
                    Text(token.count <= 1 ? token : token.capitalized)
                        .font(TimeMasterFont.black(token.count <= 1 ? digit : digit * 0.5, relativeTo: .largeTitle))
                        .minimumScaleFactor(0.4)
                        .lineLimit(1)
                    if count <= 4 {
                        Text(move?.title ?? "")
                            .font(TimeMasterFont.caption())
                            .opacity(0.85)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                    }
                }
                .foregroundStyle(.white)
                .frame(maxWidth: 110)
                .padding(.vertical, 14)
                .padding(.horizontal, 6)
                .background(Color.white.opacity(0.18), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).strokeBorder(Color.white.opacity(0.28), lineWidth: 1))
            }
        }
        .frame(maxWidth: .infinity)
    }
}
