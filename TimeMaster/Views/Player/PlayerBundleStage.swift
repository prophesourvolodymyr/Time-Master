import SwiftUI

struct PlayerBundleStage: View {
    let items: [PlayerQueueItem]
    let currentIndex: Int
    let setStarts: Set<Int>
    let isRandom: Bool
    let next: PlayerQueueItem?
    let isFinal: Bool
    let onOpen: (PlayerQueueItem) -> Void
    let onJump: (Int) -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var current: PlayerQueueItem? { items.indices.contains(currentIndex) ? items[currentIndex] : nil }

    var body: some View {
        VStack(spacing: 16) {
            HStack(alignment: .top, spacing: 14) {
                if let current {
                    PlayerNowCard(item: current, onOpen: { onOpen(current) })
                        .id(current.id)
                        .transition(reduceMotion ? .opacity : .asymmetric(
                            insertion: .move(edge: .trailing).combined(with: .opacity),
                            removal: .move(edge: .leading).combined(with: .opacity)
                        ))
                }
                nextCard
            }
            .frame(height: 236)
            .animation(reduceMotion ? .easeOut(duration: 0.15) : .spring(response: 0.42, dampingFraction: 0.82), value: currentIndex)
            PlayerQueueStrip(
                items: items, currentIndex: currentIndex, setStarts: setStarts, isRandom: isRandom,
                onJump: onJump, onOpen: onOpen
            )
        }
    }

    @ViewBuilder
    private var nextCard: some View {
        if let next {
            PlayerNextTile(item: next, size: CGSize(width: 116, height: 236)) { onOpen(next) }
                .id(next.id)
                .transition(.opacity)
        } else if isFinal {
            Image(systemName: "flag.checkered")
                .font(.system(size: 30, weight: .bold))
                .foregroundStyle(.white.opacity(0.7))
                .frame(width: 116, height: 236)
                .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                .accessibilityLabel("Last exercise of the workout")
        }
    }
}

struct PlayerNowCard: View {
    let item: PlayerQueueItem
    let onOpen: () -> Void

    var body: some View {
        Button(action: onOpen) {
            ZStack(alignment: .bottomLeading) {
                PlayerCoverImage(url: item.coverURL, symbol: item.symbol, height: 236)
                LinearGradient(colors: [.clear, .black.opacity(0.85)], startPoint: .center, endPoint: .bottom)
                VStack(alignment: .leading, spacing: 8) {
                    Text(item.name)
                        .font(TimeMasterFont.black(26, relativeTo: .title2))
                        .foregroundStyle(.white)
                        .lineLimit(2)
                        .minimumScaleFactor(0.75)
                        .multilineTextAlignment(.leading)
                    PlayerItemFacts(item: item)
                }
                .padding(16)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 236)
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            .overlay(alignment: .topLeading) {
                Image(systemName: "play.fill")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(.black)
                    .frame(width: 34, height: 28)
                    .background(Color.white, in: Capsule())
                    .padding(10)
                    .accessibilityHidden(true)
            }
            .overlay {
                RoundedRectangle(cornerRadius: 24, style: .continuous).strokeBorder(.white.opacity(0.9), lineWidth: 2)
            }
            .contentShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        }
        .keyNavPlainButtonStyle(shape: .roundedRectangle(cornerRadius: 24))
        .disabled(!item.canPreview)
        .accessibilityLabel("Now playing, \(item.name), \(PlayerTime.spoken(item.duration))")
        .accessibilityHint(!item.canPreview ? "" : "Opens the exercise page")
    }
}

struct PlayerQueueStrip: View {
    let items: [PlayerQueueItem]
    let currentIndex: Int
    let setStarts: Set<Int>
    let isRandom: Bool
    let onJump: (Int) -> Void
    let onOpen: (PlayerQueueItem) -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: .center, spacing: 8) {
                    if isRandom {
                        Image(systemName: "shuffle")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(.white.opacity(0.7))
                            .frame(width: 28)
                            .accessibilityLabel("Shuffled order")
                    }
                    ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                        if setStarts.contains(index), index > 0 {
                            Capsule().fill(.white.opacity(0.22)).frame(width: 3, height: 34)
                                .padding(.horizontal, 4)
                                .accessibilityHidden(true)
                        }
                        cell(item, index: index).id(item.id)
                    }
                }
                .padding(.horizontal, 2)
                .padding(.vertical, 4)
            }
            .onChange(of: currentIndex) { index in
                guard items.indices.contains(index) else { return }
                withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.3)) {
                    proxy.scrollTo(items[index].id, anchor: .center)
                }
            }
            .onAppear {
                if items.indices.contains(currentIndex) { proxy.scrollTo(items[currentIndex].id, anchor: .center) }
            }
        }
    }

    private func cell(_ item: PlayerQueueItem, index: Int) -> some View {
        let isCurrent = index == currentIndex
        let isDone = index < currentIndex
        return Button {
            if isCurrent { onOpen(item) } else { onJump(index) }
        } label: {
            PlayerCoverImage(url: item.coverURL, symbol: item.symbol, height: 58)
                .frame(width: 58, height: 58)
                .clipShape(RoundedRectangle(cornerRadius: 15, style: .continuous))
                .opacity(isDone ? 0.45 : 1)
                .overlay {
                    if isCurrent {
                        RoundedRectangle(cornerRadius: 15, style: .continuous).strokeBorder(.white, lineWidth: 3)
                    } else if isDone {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 20))
                            .foregroundStyle(.white, .black.opacity(0.6))
                    }
                }
                .scaleEffect(isCurrent ? 1.08 : 1)
        }
        .keyNavPlainButtonStyle(shape: .roundedRectangle(cornerRadius: 15))
        .contextMenu {
            if item.canPreview {
                Button("Preview", systemImage: "book.pages") { onOpen(item) }
            }
        }
        .accessibilityLabel("\(item.name), \(PlayerTime.spoken(item.duration))")
        .accessibilityValue(isCurrent ? "Now" : isDone ? "Done" : "Upcoming")
        .accessibilityHint(isCurrent ? "Opens the exercise page" : "Jumps to this exercise")
    }
}
