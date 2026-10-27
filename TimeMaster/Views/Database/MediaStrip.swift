import SwiftUI

enum PageMediaKind {
    private static let videoExtensions: Set<String> = ["mov", "mp4", "m4v", "avi", "mkv"]

    static func isVideo(_ url: URL) -> Bool {
        videoExtensions.contains(url.pathExtension.lowercased())
    }
}

struct MediaStrip: View {
    var title: String = "Media"
    let urls: [URL]
    var marksCover = true
    let comments: [URL: String]
    let onOpen: (Int) -> Void
    var onOpenNotes: ((Int) -> Void)? = nil
    @State private var containerWidth: CGFloat = 0
    @State private var focusedIndex: Int? = 0

    private var cardWidth: CGFloat {
        let available = containerWidth > 0 ? containerWidth : 340
        return min(max(available * 0.72, 220), 360)
    }

    private var cardHeight: CGFloat { cardWidth * 1.25 }

    var body: some View {
        ScrollViewReader { proxy in
            VStack(alignment: .leading, spacing: 10) {
                header(proxy)
                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(spacing: 12) {
                        ForEach(urls.indices, id: \.self) { index in
                            card(index: index)
                                .id(index)
                        }
                    }
                    .modifier(MediaStripTargetLayout())
                    .padding(.vertical, 2)
                }
                .modifier(MediaStripSnapping(position: $focusedIndex))
                .frame(height: cardHeight + 4)
            }
            .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { containerWidth = $0 }
        }
    }

    @ViewBuilder
    private func header(_ proxy: ScrollViewProxy) -> some View {
        if !title.isEmpty || urls.count > 1 {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                if !title.isEmpty {
                    Text(title)
                        .font(TimeMasterFont.sectionTitle())
                        .foregroundStyle(Theme.textPrimary)
                }
                Spacer()
                Text("\(min((focusedIndex ?? 0) + 1, urls.count)) / \(urls.count)")
                    .font(TimeMasterFont.caption().monospacedDigit())
                    .foregroundStyle(Theme.textSecondary)
                    .accessibilityLabel("Item \(min((focusedIndex ?? 0) + 1, urls.count)) of \(urls.count)")
                #if os(macOS)
                if urls.count > 1 {
                    stepButton("chevron.left", label: "Previous media", enabled: (focusedIndex ?? 0) > 0) {
                        scroll(proxy, to: (focusedIndex ?? 0) - 1)
                    }
                    stepButton("chevron.right", label: "Next media", enabled: (focusedIndex ?? 0) < urls.count - 1) {
                        scroll(proxy, to: (focusedIndex ?? 0) + 1)
                    }
                }
                #endif
            }
        }
    }

    #if os(macOS)
    private func stepButton(_ symbol: String, label: String, enabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 12, weight: .bold))
        }
        .buttonStyle(TimeMasterActionButtonStyle(circular: true, minimumSize: 30))
        .disabled(!enabled)
        .accessibilityLabel(label)
    }

    private func scroll(_ proxy: ScrollViewProxy, to index: Int) {
        let clamped = max(0, min(urls.count - 1, index))
        withAnimation(.easeInOut(duration: 0.25)) {
            proxy.scrollTo(clamped, anchor: .leading)
        }
        focusedIndex = clamped
    }
    #endif

    private func card(index: Int) -> some View {
        let url = urls[index]
        let isCover = marksCover && index == 0
        let isVideo = PageMediaKind.isVideo(url)
        let hasNote = comments[url] != nil
        let width = cardWidth
        let height = cardHeight

        return ZStack(alignment: .bottomLeading) {
            Button {
                onOpen(index)
            } label: {
                AsyncCoverImage(
                    url: url,
                    fallbackIcon: isVideo ? "play.rectangle.fill" : "photo",
                    fallbackColor: isVideo ? Theme.toolbarOrange : nil,
                    height: height,
                    contentMode: .fill,
                    overlayGradient: false
                )
                .frame(width: width, height: height)
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .strokeBorder(isCover ? Theme.toolbarOrange : Theme.separator, lineWidth: isCover ? 2 : 1)
                }
                .overlay(alignment: .topLeading) {
                    if isCover {
                        Label {
                            Text("Cover")
                                .font(TimeMasterFont.black(11, relativeTo: .caption2))
                        } icon: {
                            Image(systemName: "pin.fill")
                                .font(.caption2.weight(.semibold))
                        }
                        .foregroundStyle(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 5)
                        .background(.black.opacity(0.7), in: Capsule())
                        .padding(10)
                    }
                }
                .overlay(alignment: .topTrailing) {
                    if urls.count > 1 {
                        Text("\(index + 1)/\(urls.count)")
                            .font(TimeMasterFont.black(11, relativeTo: .caption2).monospacedDigit())
                            .foregroundStyle(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 5)
                            .background(.black.opacity(0.6), in: Capsule())
                            .padding(10)
                    }
                }
                .overlay {
                    if isVideo {
                        Image(systemName: "play.circle.fill")
                            .font(.system(size: 44))
                            .foregroundStyle(.white)
                            .shadow(color: .black.opacity(0.5), radius: 3)
                    }
                }
                .overlay(alignment: .bottomTrailing) {
                    if hasNote {
                        Image(systemName: "text.alignleft")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.white)
                            .padding(8)
                            .background(.black.opacity(0.65), in: Circle())
                            .padding(10)
                    }
                }
                .contentShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            }
            .buttonStyle(.plain)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("\(isCover ? "Cover, " : "")\(isVideo ? "Video" : "Photo") \(index + 1) of \(urls.count)")
            .accessibilityHint(hasNote ? "Opens the media viewer and its notes" : "Opens the media viewer")

            if let onOpenNotes {
                Button {
                    onOpenNotes(index)
                } label: {
                    Label {
                        Text(hasNote ? "Notes" : "Add notes")
                            .font(TimeMasterFont.black(12, relativeTo: .caption))
                    } icon: {
                        Image(systemName: "square.and.pencil")
                            .font(.caption.weight(.bold))
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 7)
                    .background(.black.opacity(0.65), in: Capsule())
                }
                .buttonStyle(.plain)
                .padding(10)
                .accessibilityLabel(hasNote ? "Open notes for media \(index + 1)" : "Add notes to media \(index + 1)")
            }
        }
        .frame(width: width, height: height)
    }
}

private struct MediaStripTargetLayout: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 17.0, macOS 14.0, *) {
            content.scrollTargetLayout()
        } else {
            content
        }
    }
}

private struct MediaStripSnapping: ViewModifier {
    @Binding var position: Int?

    func body(content: Content) -> some View {
        if #available(iOS 17.0, macOS 14.0, *) {
            content
                .scrollTargetBehavior(.viewAligned)
                .scrollPosition(id: $position)
        } else {
            content
        }
    }
}
