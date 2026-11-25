import SwiftUI
import TimeMasterCore

/// The sizes every page widget shares.
enum PageWidgetMetrics {
    static let tileHeight: CGFloat = 136
    static let cornerRadius: CGFloat = 22
    static let spacing: CGFloat = 12
    /// Space between a tile's edge and its content.
    static let inset: CGFloat = 14

    static var shape: RoundedRectangle { RoundedRectangle(cornerRadius: cornerRadius, style: .continuous) }
}

private struct PageWidgetRevealedKey: EnvironmentKey {
    static let defaultValue = true
}

extension EnvironmentValues {
    /// False while the page around a widget strip is still opening: the tiles draw their box only, and a clip waits to
    /// play.
    var pageWidgetRevealed: Bool {
        get { self[PageWidgetRevealedKey.self] }
        set { self[PageWidgetRevealedKey.self] = newValue }
    }
}

// MARK: - Tile

/// One tile of the strip: its surface, the light it takes on hover and press, the tap that opens `target`, and its
/// content. The content sits over a button that fills the tile, so a tap anywhere opens the target while a control in
/// the content (a to-do's tick) still answers on its own; the rest of the content is `allowsHitTesting(false)`. Until
/// the strip is revealed only the box is drawn.
struct PageWidgetTile<Content: View>: View {
    let kind: PageWidgetKind
    let target: PageWidgetTarget
    /// What VoiceOver says for the tile.
    let summary: String
    /// The content holds controls of its own, which VoiceOver then reaches one by one.
    let hasControls: Bool
    let tint: WidgetTint
    let art: WidgetArt?
    let artSpot: WidgetArtSpot
    let onOpen: (PageWidgetTarget) -> Void
    private let content: Content

    @Environment(\.pageWidgetRevealed) private var isRevealed
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isPressed = false
    @State private var isHovering = false

    init(
        kind: PageWidgetKind,
        target: PageWidgetTarget,
        summary: String,
        tint: WidgetTint = .graphite,
        art: WidgetArt? = nil,
        artSpot: WidgetArtSpot = .corner,
        hasControls: Bool = false,
        onOpen: @escaping (PageWidgetTarget) -> Void,
        @ViewBuilder content: () -> Content
    ) {
        self.kind = kind
        self.target = target
        self.summary = summary
        self.tint = art?.tint ?? tint
        self.art = art
        self.artSpot = artSpot
        self.hasControls = hasControls
        self.onOpen = onOpen
        self.content = content()
    }

    var body: some View {
        ZStack {
            Button(action: open) {
                PageWidgetSurface(tint: tint, art: isRevealed ? art : nil, spot: artSpot)
                    .contentShape(PageWidgetMetrics.shape)
            }
            .buttonStyle(PageWidgetPressStyle(isPressed: $isPressed))
            .accessibilityLabel(summary)
            .accessibilityHint(target.hint)
            if isRevealed {
                content
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    .environment(\.widgetTint, tint)
                    .foregroundStyle(tint.ink)
                    .transition(.opacity)
            }
        }
        .overlay { PageWidgetRim(isLit: isPressed || isHovering) }
        .clipShape(PageWidgetMetrics.shape)
        .contentShape(PageWidgetMetrics.shape)
        .scaleEffect(isPressed && !reduceMotion ? 0.97 : 1)
        .animation(reduceMotion ? nil : .spring(response: 0.26, dampingFraction: 0.82), value: isPressed)
        .animation(EverMotion.opacityOnly, value: isHovering)
        .onHover { isHovering = $0 }
        .keyNavTarget(
            id: "page-widget-\(kind.rawValue)",
            role: .primary,
            shape: .roundedRectangle(cornerRadius: PageWidgetMetrics.cornerRadius),
            action: open
        )
        .modifier(PageWidgetTileAccessibility(summary: summary, hint: target.hint, hasControls: hasControls, action: open))
    }

    private func open() {
        onOpen(target)
    }
}

/// Hands the pressed state of a tile's button to the tile, which lights and settles as a whole.
struct PageWidgetPressStyle: ButtonStyle {
    @Binding var isPressed: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .onChange(of: configuration.isPressed) { pressed in
                isPressed = pressed
            }
    }
}

/// A tile without controls is one button for VoiceOver; one with controls lets VoiceOver reach the tile's button and
/// each control on its own.
private struct PageWidgetTileAccessibility: ViewModifier {
    let summary: String
    let hint: String
    let hasControls: Bool
    let action: () -> Void

    @ViewBuilder
    func body(content: Content) -> some View {
        if hasControls {
            content.accessibilityElement(children: .contain)
        } else {
            content
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(summary)
                .accessibilityHint(hint)
                .accessibilityAddTraits(.isButton)
                .accessibilityAction { action() }
        }
    }
}

// MARK: - Surface

struct PageWidgetSurface: View {
    let tint: WidgetTint
    let art: WidgetArt?
    let spot: WidgetArtSpot

    var body: some View {
        Group {
            if let art {
                WidgetTintBackground(art: art, spot: spot)
            } else {
                WidgetTintBackground(tint: tint)
            }
        }
        .drawingGroup()
        .accessibilityHidden(true)
    }
}

/// The edge of a tile, drawn over its content: a hairline rim (brighter with Increase Contrast) and, while hover or a
/// press lights the tile, a soft wash from the top and a brighter rim.
struct PageWidgetRim: View {
    let isLit: Bool

    @Environment(\.colorSchemeContrast) private var contrast

    var body: some View {
        let shape = PageWidgetMetrics.shape
        ZStack {
            shape.fill(
                LinearGradient(colors: [Color.white.opacity(isLit ? 0.09 : 0), .clear], startPoint: .top, endPoint: .center)
            )
            shape.strokeBorder(
                contrast == .increased ? Color.white.opacity(0.5) : Color.white.opacity(isLit ? 0.24 : 0.07),
                lineWidth: 1
            )
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

// MARK: - Pieces

struct PageWidgetEmptyState: View {
    let systemImage: String?
    let title: String

    @Environment(\.widgetTint) private var tint

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if let systemImage {
                Image(systemName: systemImage)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(tint.accent)
            }
            WidgetTitle(text: title, size: 18, lines: 2)
                .frame(maxWidth: 140, alignment: .leading)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(PageWidgetMetrics.inset)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

/// A page file's picture (a photo, or a video's first frame) filling the frame it is given, cropped.
struct PageWidgetPoster: View {
    let url: URL
    var maxPixel: CGFloat = 640

    @State private var image: PhotoPlatformImage?

    var body: some View {
        GeometryReader { proxy in
            if let image {
                platformImage(image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: proxy.size.width, height: proxy.size.height)
                    .clipped()
                    .transition(.opacity)
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
        .task(id: url) {
            let loaded = await PhotoManager.shared.asyncLoadImage(from: url, maxPixelSize: maxPixel)
            guard !Task.isCancelled else { return }
            withAnimation(.easeOut(duration: 0.2)) { image = loaded }
        }
    }
}

/// Text the widgets share.
enum PageWidgetFormat {
    /// "Trained today", "Trained yesterday", "Trained 4 days ago", "Trained 3 Mar"; "Not trained yet" without a date.
    static func trained(_ date: Date?, now: Date = Date(), calendar: Calendar = .current) -> String {
        guard let date else { return "Not trained yet" }
        return "Trained \(when(date, now: now, calendar: calendar, capitalized: false))"
    }

    static func when(_ date: Date, now: Date = Date(), calendar: Calendar = .current, capitalized: Bool = true) -> String {
        let days = calendar.dateComponents([.day], from: calendar.startOfDay(for: date), to: calendar.startOfDay(for: now)).day ?? 0
        switch days {
        case ..<1: return capitalized ? "Today" : "today"
        case 1: return capitalized ? "Yesterday" : "yesterday"
        case 2..<7: return "\(days) days ago"
        default:
            let style: Date.FormatStyle = calendar.isDate(date, equalTo: now, toGranularity: .year)
                ? .dateTime.day().month(.abbreviated)
                : .dateTime.day().month(.abbreviated).year()
            return date.formatted(style)
        }
    }
}
