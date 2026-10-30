import SwiftUI

struct BundlePlaybackCards: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let slots: [SetSlot]
    let currentIndex: Int
    let isRandom: Bool
    let onOpen: (SetSlot) -> Void

    var body: some View {
        VStack(spacing: 18) {
            if slots.indices.contains(currentIndex) {
                ZStack {
                    ForEach(deck, id: \.slot.id) { entry in
                        deckCard(entry.slot, depth: entry.depth)
                            .zIndex(Double(-entry.depth))
                            .transition(reduceMotion ? .opacity : .asymmetric(
                                insertion: .opacity.combined(with: .scale(scale: 0.86)),
                                removal: .move(edge: .leading).combined(with: .opacity)
                            ))
                    }
                }
                .frame(maxWidth: .infinity, minHeight: 290)
                .animation(reduceMotion ? .easeOut(duration: 0.15) : .spring(response: 0.42, dampingFraction: 0.78), value: currentIndex)
            }
            HStack {
                Image(systemName: isRandom ? "shuffle" : "list.number")
                Text("\(min(currentIndex + 1, slots.count)) / \(slots.count)")
                    .monospacedDigit()
                Spacer()
            }
            .font(TimeMasterFont.caption())
            .foregroundStyle(.white.opacity(0.65))
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: .top, spacing: 10) {
                    ForEach(Array(slots.enumerated()), id: \.element.id) { index, slot in
                        Button { onOpen(slot) } label: {
                            VStack(spacing: 6) {
                                BundleExerciseThumbnail(slot: slot, size: 64)
                                    .overlay(alignment: .topTrailing) {
                                        if index == currentIndex {
                                            Image(systemName: "play.circle.fill")
                                                .foregroundStyle(.black, .white)
                                        } else if index < currentIndex {
                                            Image(systemName: "checkmark.circle.fill")
                                                .foregroundStyle(.white, .black)
                                        }
                                    }
                                Text(slot.displayName)
                                    .font(TimeMasterFont.caption())
                                    .lineLimit(2)
                                Text("\(slot.duration)s")
                                    .font(TimeMasterFont.micro().monospacedDigit())
                                    .opacity(0.6)
                            }
                            .frame(width: 78)
                            .padding(8)
                            .background(index == currentIndex ? .white.opacity(0.16) : .clear, in: RoundedRectangle(cornerRadius: 14))
                        }
                        .keyNavPlainButtonStyle(shape: .roundedRectangle(cornerRadius: 14))
                        .foregroundStyle(.white)
                        .disabled(slot.exercisePageID == nil)
                        .accessibilityLabel("\(slot.displayName), \(slot.duration) seconds\(index == currentIndex ? ", current" : index > currentIndex ? ", upcoming" : ", completed")")
                    }
                }
            }
        }
    }

    private var deck: [(slot: SetSlot, depth: Int)] {
        slots.enumerated().compactMap { index, slot in
            let depth = index - currentIndex
            return (0...3).contains(depth) ? (slot, depth) : nil
        }
    }

    private func deckCard(_ slot: SetSlot, depth: Int) -> some View {
        let tilt = reduceMotion ? 0 : Double(depth) * (depth.isMultiple(of: 2) ? -3.5 : 3.5)
        return Button { onOpen(slot) } label: {
            VStack(spacing: 14) {
                BundleExerciseThumbnail(slot: slot, size: depth == 0 ? 112 : 84)
                Text(slot.displayName)
                    .font(TimeMasterFont.black(depth == 0 ? 30 : 22, relativeTo: .title))
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                if depth == 0, slot.exercisePageID != nil {
                    Image(systemName: "book.pages")
                        .font(.title3)
                        .accessibilityHidden(true)
                }
            }
            .foregroundStyle(.black)
            .frame(maxWidth: .infinity, minHeight: 220)
            .padding(20)
            .background(.white.opacity(1 - Double(depth) * 0.16), in: RoundedRectangle(cornerRadius: 24))
            .overlay {
                RoundedRectangle(cornerRadius: 24)
                    .strokeBorder(.black.opacity(depth == 0 ? 0 : 0.12), lineWidth: 1)
            }
        }
        .keyNavPlainButtonStyle(shape: .roundedRectangle(cornerRadius: 24))
        .disabled(depth != 0 || slot.exercisePageID == nil)
        .allowsHitTesting(depth == 0)
        .scaleEffect(1 - CGFloat(depth) * 0.06)
        .rotationEffect(.degrees(tilt))
        .offset(y: CGFloat(-depth) * 18)
        .padding(.horizontal, 18)
        .accessibilityHidden(depth != 0)
        .accessibilityLabel("\(slot.displayName)\(slot.exercisePageID == nil ? "" : ", open page and media")")
    }
}
