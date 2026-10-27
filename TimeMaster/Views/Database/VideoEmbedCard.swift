import SwiftUI
import TimeMasterCore

struct VideoEmbedListView: View {
    let urls: [String]
    let metadata: [LinkMetadata]
    let onTapURL: (String) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Links")
                .font(TimeMasterFont.sectionTitle())
                .foregroundColor(Theme.textPrimary)

            ForEach(Array(urls.enumerated()), id: \.offset) { index, urlString in
                PageLinkRow(
                    info: PageLinkInfo(urlString: urlString, metadata: index < metadata.count ? metadata[index] : nil),
                    onOpen: { onTapURL(urlString) }
                )
            }
        }
    }
}

struct PageLinkRow: View {
    let info: PageLinkInfo
    var onOpen: (() -> Void)?

    var body: some View {
        if let onOpen {
            Button(action: onOpen) { row }
                .buttonStyle(TimeMasterCardButtonStyle())
                .accessibilityLabel("\(info.title), \(info.subtitle)")
                .accessibilityHint("Opens the link")
        } else {
            row
                .accessibilityElement(children: .combine)
        }
    }

    private var row: some View {
        HStack(spacing: 12) {
            PageLinkTile(platform: info.platform, thumbnailURL: info.thumbnailURL)

            VStack(alignment: .leading, spacing: 3) {
                Text(info.title)
                    .font(TimeMasterFont.rowTitle())
                    .foregroundStyle(Theme.textPrimary)
                    .lineLimit(2)
                Text(info.subtitle)
                    .font(TimeMasterFont.caption())
                    .foregroundStyle(Theme.textSecondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            if onOpen != nil {
                Image(systemName: "arrow.up.right")
                    .font(.system(size: 13, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)
                    .frame(width: 32, height: 32)
                    .background(Circle().fill(Theme.toolbarOrange))
                    .accessibilityHidden(true)
            }
        }
        .padding(10)
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.white.opacity(0.07), lineWidth: 1)
        )
        .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

struct PageLinkTile: View {
    let platform: LinkPlatform
    let thumbnailURL: URL?

    var body: some View {
        glyphTile
            .frame(width: 48, height: 48)
            .overlay {
                if let thumbnailURL {
                    AsyncImage(url: thumbnailURL) { phase in
                        if case .success(let image) = phase {
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                        }
                    }
                    .frame(width: 48, height: 48)
                    .clipped()
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .accessibilityHidden(true)
    }

    @ViewBuilder
    private var glyphTile: some View {
        switch platform {
        case .instagram:
            ZStack {
                LinearGradient(
                    colors: [Color(hex: "F58529"), Color(hex: "DD2A7B"), Color(hex: "8134AF")],
                    startPoint: .bottomLeading,
                    endPoint: .topTrailing
                )
                ZStack {
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .stroke(.white, lineWidth: 2.4)
                        .frame(width: 24, height: 24)
                    Circle()
                        .stroke(.white, lineWidth: 2.4)
                        .frame(width: 11, height: 11)
                    Circle()
                        .fill(.white)
                        .frame(width: 3.2, height: 3.2)
                        .offset(x: 7, y: -7)
                }
            }
        case .youtube:
            ZStack {
                Color(hex: "FF0033")
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(.white)
                    .frame(width: 28, height: 20)
                Image(systemName: "play.fill")
                    .font(.system(size: 9, weight: .black))
                    .foregroundStyle(Color(hex: "FF0033"))
            }
        case .tiktok:
            ZStack {
                Color.black
                Image(systemName: "music.note")
                    .font(.system(size: 22, weight: .black))
                    .foregroundStyle(Color(hex: "25F4EE"))
                    .offset(x: -1.5, y: 1)
                Image(systemName: "music.note")
                    .font(.system(size: 22, weight: .black))
                    .foregroundStyle(Color(hex: "FE2C55"))
                    .offset(x: 1.5, y: -1)
                Image(systemName: "music.note")
                    .font(.system(size: 22, weight: .black))
                    .foregroundStyle(.white)
            }
        case .facebook:
            ZStack {
                Color(hex: "1877F2")
                Text("f")
                    .font(.system(size: 30, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
                    .offset(y: 2)
            }
        case .web:
            ZStack {
                Theme.toolbarOrange.opacity(0.16)
                Image(systemName: "link")
                    .font(.system(size: 18, weight: .heavy, design: .rounded))
                    .foregroundStyle(Theme.toolbarOrange)
            }
        }
    }
}
