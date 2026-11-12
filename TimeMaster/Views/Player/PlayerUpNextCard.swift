import SwiftUI

struct PlayerUpNextCard: View {
    let item: PlayerQueueItem
    var label = "Up next"
    let onOpen: () -> Void

    var body: some View {
        Button(action: onOpen) {
            HStack(spacing: 14) {
                PlayerCoverImage(url: item.coverURL, symbol: item.symbol, height: 76)
                    .frame(width: 76, height: 76)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .overlay(alignment: .topLeading) {
                        Image(systemName: "forward.fill")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(.black)
                            .frame(width: 24, height: 20)
                            .background(Color.white, in: Capsule())
                            .padding(5)
                            .accessibilityHidden(true)
                    }
                VStack(alignment: .leading, spacing: 4) {
                    Text("UP NEXT")
                        .font(TimeMasterFont.black(10, relativeTo: .caption2))
                        .tracking(3)
                        .foregroundColor(.white.opacity(0.5))
                    Text(item.name)
                        .font(TimeMasterFont.black(17, relativeTo: .headline))
                        .foregroundColor(.white)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                    PlayerItemFacts(item: item)
                }
                Spacer(minLength: 0)
                if item.canPreview {
                    Image(systemName: "book.pages")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.white.opacity(0.5))
                        .accessibilityHidden(true)
                }
            }
            .padding(8)
            .padding(.trailing, 8)
            .frame(maxWidth: 360)
            .background(Color.white.opacity(0.12), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 24, style: .continuous).strokeBorder(.white.opacity(0.14), lineWidth: 1)
            }
            .contentShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        }
        .keyNavPlainButtonStyle(shape: .roundedRectangle(cornerRadius: 24))
        .disabled(!item.canPreview)
        .accessibilityLabel("\(label), \(item.name), \(PlayerTime.spoken(item.duration))")
        .accessibilityHint(!item.canPreview ? "" : "Opens a preview")
    }
}

struct PlayerNextTile: View {
    let item: PlayerQueueItem
    let size: CGSize
    let onOpen: () -> Void

    var body: some View {
        Button(action: onOpen) {
            ZStack(alignment: .bottomLeading) {
                PlayerCoverImage(url: item.coverURL, symbol: item.symbol, height: size.height)
                LinearGradient(colors: [.clear, .black.opacity(0.82)], startPoint: .center, endPoint: .bottom)
                VStack(alignment: .leading, spacing: 5) {
                    Text(item.name)
                        .font(TimeMasterFont.black(14, relativeTo: .subheadline))
                        .foregroundStyle(.white)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                    PlayerItemFacts(item: item)
                }
                .padding(10)
            }
            .frame(width: size.width, height: size.height)
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay(alignment: .topLeading) {
                Image(systemName: "forward.fill")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(.black)
                    .frame(width: 30, height: 26)
                    .background(Color.white, in: Capsule())
                    .padding(8)
                    .accessibilityHidden(true)
            }
            .overlay {
                RoundedRectangle(cornerRadius: 20, style: .continuous).strokeBorder(.white.opacity(0.16), lineWidth: 1)
            }
            .contentShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        }
        .keyNavPlainButtonStyle(shape: .roundedRectangle(cornerRadius: 20))
        .disabled(!item.canPreview)
        .accessibilityLabel("Up next, \(item.name), \(PlayerTime.spoken(item.duration))")
        .accessibilityHint(!item.canPreview ? "" : "Opens a preview")
    }
}

struct PlayerItemFacts: View {
    let item: PlayerQueueItem

    var showsDuration = true

    var body: some View {
        HStack(spacing: 8) {
            if showsDuration { Label(PlayerTime.clock(item.duration), systemImage: "timer") }
            if let reps = item.repCount {
                Label("\(reps)", systemImage: "repeat")
            }
            if item.isDrop {
                Image(systemName: "arrow.down.right")
            }
        }
        .labelStyle(PlayerFactLabelStyle())
        .font(.system(size: 11, weight: .bold, design: .rounded).monospacedDigit())
        .foregroundStyle(.white.opacity(0.85))
    }
}

struct PlayerFactLabelStyle: LabelStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: 3) {
            configuration.icon.imageScale(.small)
            configuration.title
        }
    }
}

struct PlayerNextPill: View {
    let item: PlayerQueueItem
    let onOpen: () -> Void

    var body: some View {
        Button(action: onOpen) {
            HStack(spacing: 10) {
                PlayerCoverImage(url: item.coverURL, symbol: item.symbol, height: 38)
                    .frame(width: 38, height: 38)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                Text(item.name)
                    .font(TimeMasterFont.black(14, relativeTo: .subheadline))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                Image(systemName: "forward.fill")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(.white.opacity(0.7))
                    .accessibilityHidden(true)
            }
            .padding(.leading, 6)
            .padding(.trailing, 14)
            .frame(height: 50)
            .background(.white.opacity(0.12), in: Capsule())
            .contentShape(Capsule())
        }
        .keyNavPlainButtonStyle(shape: .capsule)
        .disabled(!item.canPreview)
        .accessibilityLabel("Up next, \(item.name)")
        .accessibilityHint(!item.canPreview ? "" : "Opens a preview")
    }
}
