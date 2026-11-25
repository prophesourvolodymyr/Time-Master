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
    fileprivate static let trailingReserve: CGFloat = 56

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

    @EnvironmentObject private var store: DatabaseStore
    @EnvironmentObject private var navigation: DatabaseNavigationState
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
            treeButton
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
                    .keyNavBounceButtonStyle(shape: .capsule, cornerRadius: Self.height / 2, lift: 5)
                } else {
                    crumbLabel(crumb.title, opacity: 0.6)
                }
            }
        }
        .padding(.trailing, SkillMetrics.s3)
        .frame(height: Self.height)
    }

    private var treeButton: some View {
        TmaxMenu(cornerRadius: Self.height / 2) {
            PageTreeRows(rows: treeRows) { id in
                navigation.path.append(DatabasePageRoute(pageID: id))
            }
        } label: {
            Image(systemName: "list.bullet.indent")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(Color.white.opacity(0.9))
                .frame(width: Self.height + 4, height: Self.height)
                .contentShape(Rectangle())
        }
        .keyNavBounceButtonStyle(shape: .circle, cornerRadius: Self.height / 2, lift: 5)
        .accessibilityLabel("Where you are")
        .accessibilityHint("Shows this page's place in the tree")
    }

    private var treeRows: [PageTreeRows.Row] {
        var rows = breadcrumbs.enumerated().map { index, crumb in
            PageTreeRows.Row(
                id: crumb.manifest.id,
                title: crumb.title,
                depth: index,
                isCurrent: crumb.id == page.id
            )
        }
        let below = breadcrumbs.count
        let children = store.children(ofManifestID: page.manifest.id)
        rows += children.prefix(12).map {
            PageTreeRows.Row(id: $0.manifest.id, title: $0.title, depth: below, isCurrent: false, isBelow: true)
        }
        if children.count > 12 {
            rows.append(PageTreeRows.Row(id: "", title: "+ \(children.count - 12) more", depth: below, isCurrent: false, isBelow: true))
        }
        return rows
    }

    private func crumbLabel(_ title: String, opacity: Double) -> some View {
        Text(title)
            .font(TimeMasterFont.black(12, relativeTo: .caption))
            .foregroundStyle(Color.white.opacity(opacity))
            .lineLimit(1)
            .fixedSize()
            .padding(.horizontal, 6)
            .frame(minHeight: Self.height)
            .contentShape(Rectangle())
    }

    private var glass: AnyShapeStyle {
        reduceTransparency ? AnyShapeStyle(Theme.surface2) : AnyShapeStyle(.ultraThinMaterial)
    }
}

struct PageTreeRows: View {
    struct Row: Identifiable {
        let id: String
        let title: String
        let depth: Int
        let isCurrent: Bool
        var isBelow = false
    }

    let rows: [Row]
    let onOpen: (String) -> Void

    var body: some View {
        Text("WHERE YOU ARE")
            .font(TimeMasterFont.black(11, relativeTo: .caption2))
            .foregroundStyle(Theme.textSecondary)
            .padding(.horizontal, 18)
            .padding(.top, 12)
            .padding(.bottom, 6)
        ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
            treeRow(row)
        }
    }

    @ViewBuilder
    private func treeRow(_ row: Row) -> some View {
        let face = HStack(spacing: 8) {
            Image(systemName: row.isCurrent ? "location.fill" : row.isBelow ? "arrow.turn.down.right" : "chevron.right")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(row.isCurrent ? Theme.toolbarOrange : Theme.textSecondary)
                .frame(width: 14)
            Text(row.title)
                .opacity(row.isBelow ? 0.7 : 1)
            Spacer(minLength: 0)
        }
        .padding(.leading, CGFloat(min(row.depth, 6)) * 14)
        if row.id.isEmpty {
            face
                .padding(.horizontal, 18)
                .frame(maxWidth: .infinity, minHeight: TmaxMenuMetrics.rowHeight, alignment: .leading)
        } else {
            Button {
                if !row.isCurrent { onOpen(row.id) }
            } label: {
                face
            }
            .background(Theme.toolbarOrange.opacity(row.isCurrent ? 0.22 : 0))
            .tmaxMenuCurrent(row.isCurrent)
        }
    }
}
