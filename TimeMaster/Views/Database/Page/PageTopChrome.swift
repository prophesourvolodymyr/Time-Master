import SwiftUI
import TimeMasterCore

/// Whether a page has scrolled under its top chrome. The page keeps it in `@State` without observing it and only
/// `PageTopChrome` observes it, so a change redraws the fade and never the page.
final class PageScrollEdge: ObservableObject {
    /// The coordinate space a page's root names; its scroll content sits at 0 in it while the page rests.
    static let space = "page-scroll"
    /// How far the content moves up before the fade shows.
    static let threshold: CGFloat = 6

    @Published private(set) var isScrolled = false

    func update(_ scrolled: Bool) {
        guard scrolled != isScrolled else { return }
        isScrolled = scrolled
    }
}

extension View {
    /// Names the page's scroll space on its root, the view its scroll view fills.
    @ViewBuilder
    func pageScrollSpace() -> some View {
        if #available(iOS 17.0, macOS 14.0, *) {
            coordinateSpace(.named(PageScrollEdge.space))
        } else {
            coordinateSpace(name: PageScrollEdge.space)
        }
    }

    /// Tells `edge` whether this scroll content has moved up past the threshold; it acts only when that flips.
    func pageScrollEdgeProbe(_ edge: PageScrollEdge) -> some View {
        onGeometryChange(for: Bool.self) { proxy in
            proxy.frame(in: .named(PageScrollEdge.space)).minY < -PageScrollEdge.threshold
        } action: { scrolled in
            edge.update(scrolled)
        }
    }
}

/// A page's top chrome over its scroll view: the soft fade its content scrolls under (solid from the window's top edge
/// behind the toolbar, thinning out below it), shown once the page has moved, and with `breadcrumbs` the path to the
/// page on its own glass capsule, pinned just below the back button. With `siblings` the row also holds the page's
/// Previous and Next once it knows its siblings (`pageSiblingNavigation`).
struct PageTopChrome: View {
    @ObservedObject var edge: PageScrollEdge
    var page: ExercisePage?
    var breadcrumbs: [ExercisePage] = []
    var siblings: PageSiblingNavigator?

    /// Height of the row the path sits in.
    static let pathRowHeight: CGFloat = SkillMetrics.s1 + SkillMetrics.touch
    /// Room kept free at the end of the path row for the cover's own chip.
    fileprivate static let trailingReserve: CGFloat = 104

    /// How far below the page's top a part revealed by a scroll lands, clear of the pinned path and most of the fade.
    static func revealInset(showsPath: Bool) -> CGFloat {
        (showsPath ? pathRowHeight : 0) + ScrollingChromeFade.defaultHeight * 0.75
    }

    static func showsPath(_ breadcrumbs: [ExercisePage]) -> Bool { breadcrumbs.count > 1 }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let siblings {
                PageTopRow(page: page, breadcrumbs: breadcrumbs, siblings: siblings)
            } else if let page, Self.showsPath(breadcrumbs) {
                PageBreadcrumbBar(page: page, breadcrumbs: breadcrumbs)
                    .pageTopRowFrame()
            }
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .background(alignment: .top) {
            GeometryReader { proxy in
                ScrollingChromeFade(
                    height: proxy.size.height + ScrollingChromeFade.defaultHeight,
                    solidHeight: proxy.safeAreaInsets.top
                )
                .offset(y: -proxy.safeAreaInsets.top)
            }
            .opacity(edge.isScrolled ? 1 : 0)
            .animation(.easeOut(duration: 0.2), value: edge.isScrolled)
        }
        .frame(maxHeight: .infinity, alignment: .top)
    }
}

/// The row under the back button: the path to the page, then the page's Previous and Next once it knows its siblings.
/// Only this row follows the siblings, so they never redraw the page.
private struct PageTopRow: View {
    let page: ExercisePage?
    let breadcrumbs: [ExercisePage]
    @ObservedObject var siblings: PageSiblingNavigator

    var body: some View {
        let path = PageTopChrome.showsPath(breadcrumbs) ? page : nil
        if path != nil || siblings.isShown {
            HStack(spacing: SkillMetrics.s1) {
                if let path {
                    PageBreadcrumbBar(page: path, breadcrumbs: breadcrumbs)
                }
                PageSiblingBar(navigator: siblings)
                    .fixedSize()
                    .layoutPriority(1)
            }
            .pageTopRowFrame()
        }
    }
}

private extension View {
    /// Where the row under the back button sits: a touch tall, clear of the cover's chip, on the page's width.
    func pageTopRowFrame() -> some View {
        frame(minHeight: SkillMetrics.touch)
            .padding(.trailing, PageTopChrome.trailingReserve)
            .frame(maxWidth: .infinity, alignment: .leading)
            .skillsContained()
            .padding(.top, SkillMetrics.s1)
    }
}

/// The path to a page on its own glass capsule: every page above it opens on a click or a tap, the page itself ends
/// the path, dimmer. A path longer than the room scrolls sideways inside the capsule.
struct PageBreadcrumbBar: View {
    let page: ExercisePage
    let breadcrumbs: [ExercisePage]

    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    private static let height: CGFloat = 32

    var body: some View {
        let shape = Capsule(style: .continuous)
        ViewThatFits(in: .horizontal) {
            path
            ScrollView(.horizontal, showsIndicators: false) {
                path
            }
        }
        .background(shape.fill(glass))
        .overlay(shape.strokeBorder(Color.white.opacity(0.18), lineWidth: 1).allowsHitTesting(false))
        .clipShape(shape)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Path")
    }

    private var path: some View {
        HStack(spacing: 6) {
            ForEach(Array(breadcrumbs.enumerated()), id: \.offset) { index, crumb in
                if index > 0 {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(Color.white.opacity(0.5))
                        .accessibilityHidden(true)
                }
                if crumb.id != page.id {
                    NavigationLink(value: DatabasePageRoute(pageID: crumb.manifest.id)) {
                        crumbLabel(crumb.title, opacity: 0.88)
                    }
                    .keyNavPlainButtonStyle(shape: .capsule)
                } else {
                    crumbLabel(crumb.title, opacity: 0.6)
                }
            }
        }
        .padding(.horizontal, SkillMetrics.s3)
        .frame(height: Self.height)
    }

    private func crumbLabel(_ title: String, opacity: Double) -> some View {
        Text(title)
            .font(TimeMasterFont.black(12, relativeTo: .caption))
            .foregroundStyle(Color.white.opacity(opacity))
            .lineLimit(1)
            .fixedSize()
            .frame(minHeight: Self.height)
            .contentShape(Rectangle())
    }

    private var glass: AnyShapeStyle {
        reduceTransparency ? AnyShapeStyle(Theme.surface2) : AnyShapeStyle(.ultraThinMaterial)
    }
}
