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
        hasControls: Bool = false,
        onOpen: @escaping (PageWidgetTarget) -> Void,
        @ViewBuilder content: () -> Content
    ) {
        self.kind = kind
        self.target = target
        self.summary = summary
        self.hasControls = hasControls
        self.onOpen = onOpen
        self.content = content()
    }

    var body: some View {
        ZStack {
            Button(action: open) {
                PageWidgetSurface()
                    .contentShape(PageWidgetMetrics.shape)
            }
            .buttonStyle(PageWidgetPressStyle(isPressed: $isPressed))
            .accessibilityLabel(summary)
            .accessibilityHint(target.hint)
            if isRevealed {
                content
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
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

/// The face of a tile behind its content: Skillmax's debossed tile in Tmax's greys. A diagonal gradient, a brushed
/// texture, a soft shadow inside the top-left edge and a faint light inside the bottom-right one.
struct PageWidgetSurface: View {
    var body: some View {
        let shape = PageWidgetMetrics.shape
        ZStack {
            shape.fill(
                LinearGradient(colors: [Theme.surface2, Theme.surface], startPoint: .topLeading, endPoint: .bottomTrailing)
            )
            PageWidgetBrushedTexture()
                .clipShape(shape)
            shape.stroke(Color.black.opacity(0.62), lineWidth: 6.6)
                .blur(radius: 5)
                .offset(x: 2.75, y: 2.75)
                .clipShape(shape)
            shape.stroke(Color.white.opacity(0.05), lineWidth: 5.5)
                .blur(radius: 4.4)
                .offset(x: -2.2, y: -2.2)
                .clipShape(shape)
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
                contrast == .increased ? Color.white.opacity(0.5) : Color.white.opacity(isLit ? 0.24 : 0.09),
                lineWidth: 1
            )
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

/// Diagonal hairlines: the brushed texture of the skill tiles.
struct PageWidgetBrushedTexture: View {
    var spacing: CGFloat = 3
    var opacity: Double = 0.035

    var body: some View {
        Canvas { context, size in
            var path = Path()
            var x = -size.height
            while x < size.width {
                path.move(to: CGPoint(x: x, y: size.height))
                path.addLine(to: CGPoint(x: x + size.height, y: 0))
                x += spacing
            }
            context.stroke(path, with: .color(.white.opacity(opacity)), lineWidth: 1)
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

// MARK: - Pieces

/// A tile's title: its symbol in orange, its name and, at the end, a figure or a badge.
struct PageWidgetHeader<Accessory: View>: View {
    let kind: PageWidgetKind
    /// Over a picture: brighter text with a soft shadow.
    let overPicture: Bool
    private let accessory: Accessory

    init(kind: PageWidgetKind, overPicture: Bool = false, @ViewBuilder accessory: () -> Accessory) {
        self.kind = kind
        self.overPicture = overPicture
        self.accessory = accessory()
    }

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: kind.systemImage)
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(Theme.toolbarOrange)
            Text(kind.title)
                .font(TimeMasterFont.black(12, relativeTo: .caption))
                .foregroundStyle(overPicture ? Color.white.opacity(0.88) : Theme.textSecondary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            Spacer(minLength: 4)
            accessory
        }
        .shadow(color: overPicture ? .black.opacity(0.5) : .clear, radius: 2, y: 1)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

extension PageWidgetHeader where Accessory == PageWidgetHeaderFigure {
    init(kind: PageWidgetKind, trailing: String? = nil, overPicture: Bool = false) {
        self.init(kind: kind, overPicture: overPicture) {
            PageWidgetHeaderFigure(text: trailing, overPicture: overPicture)
        }
    }
}

/// The figure at the end of a tile's title ("12", "3 of 8 done").
struct PageWidgetHeaderFigure: View {
    let text: String?
    let overPicture: Bool

    var body: some View {
        if let text {
            Text(text)
                .font(TimeMasterFont.black(12, relativeTo: .caption).monospacedDigit())
                .foregroundStyle(overPicture ? Color.white.opacity(0.88) : Theme.textSecondary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
    }
}

/// A tile with nothing to show yet: a symbol and a short line in the page-title face, at the foot of the tile.
struct PageWidgetEmptyState: View {
    let systemImage: String
    let title: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Image(systemName: systemImage)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(Theme.toolbarOrange)
            TimeMasterPageTitle(title, size: 22, relativeTo: .title3)
                .foregroundStyle(Theme.textPrimary)
                .lineLimit(2)
                .minimumScaleFactor(0.75)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

/// A thin progress bar.
struct PageWidgetBar: View {
    let fraction: Double
    var tint: Color = Theme.toolbarOrange

    var body: some View {
        let clamped = min(1, max(0, fraction.isFinite ? fraction : 0))
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule().fill(Color.white.opacity(0.14))
                Capsule()
                    .fill(tint)
                    .frame(width: clamped > 0 ? max(5, proxy.size.width * clamped) : 0)
            }
        }
        .frame(height: 5)
        .accessibilityHidden(true)
    }
}

/// How many are open, in an orange ring; a check when none are.
struct PageWidgetCountBadge: View {
    let count: Int

    var body: some View {
        ZStack {
            Circle().fill(Theme.toolbarOrange.opacity(0.2))
            Circle().strokeBorder(Theme.toolbarOrange.opacity(0.65), lineWidth: 1.2)
            if count == 0 {
                Image(systemName: "checkmark")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(Theme.toolbarOrange)
            } else {
                Text("\(count)")
                    .font(TimeMasterFont.black(12, relativeTo: .caption).monospacedDigit())
                    .foregroundStyle(Theme.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                    .padding(.horizontal, 3)
            }
        }
        .frame(width: 24, height: 24)
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
        let days = calendar.dateComponents([.day], from: calendar.startOfDay(for: date), to: calendar.startOfDay(for: now)).day ?? 0
        switch days {
        case ..<1: return "Trained today"
        case 1: return "Trained yesterday"
        case 2..<7: return "Trained \(days) days ago"
        default:
            let style: Date.FormatStyle = calendar.isDate(date, equalTo: now, toGranularity: .year)
                ? .dateTime.day().month(.abbreviated)
                : .dateTime.day().month(.abbreviated).year()
            return "Trained \(date.formatted(style))"
        }
    }
}
