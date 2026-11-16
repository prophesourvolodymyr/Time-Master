import SwiftUI

/// Where each page cover of the builder sits on screen. Kept outside SwiftUI state, so scrolling never re-renders
/// anything; a page opened from a cover grows out of it and shrinks back into it.
final class WorkoutHeroSources {
    private var frames: [String: CGRect] = [:]
    private var tapped: String?

    func record(_ frame: CGRect, for key: String) { frames[key] = frame }
    func forget(_ key: String) { frames[key] = nil }
    func frame(for key: String?) -> CGRect? { key.flatMap { frames[$0] } }

    /// Marks the cover a row passes on to a callback that only carries the page.
    func markTapped(_ key: String) { tapped = key }

    func takeTapped() -> String? {
        defer { tapped = nil }
        return tapped
    }
}

private struct WorkoutHeroSourcesKey: EnvironmentKey {
    static let defaultValue: WorkoutHeroSources? = nil
}

extension EnvironmentValues {
    var workoutHeroSources: WorkoutHeroSources? {
        get { self[WorkoutHeroSourcesKey.self] }
        set { self[WorkoutHeroSourcesKey.self] = newValue }
    }
}

extension View {
    /// Reports where this cover sits, so a page opened from it can grow out of it (inside the workout builder only).
    func workoutHeroSource(_ key: String) -> some View {
        modifier(WorkoutHeroSourceModifier(key: key))
    }
}

private struct WorkoutHeroSourceModifier: ViewModifier {
    let key: String
    @Environment(\.workoutHeroSources) private var sources

    @ViewBuilder
    func body(content: Content) -> some View {
        if let sources {
            content
                .onGeometryChange(for: CGRect.self) { proxy in
                    proxy.frame(in: .global)
                } action: { frame in
                    sources.record(frame, for: key)
                }
                .onDisappear { sources.forget(key) }
        } else {
            content
        }
    }
}

/// A page to open over the builder, with the cover it grows from.
struct WorkoutPageHeroRequest: Identifiable, Equatable {
    let id = UUID()
    let pageID: UUID
    let sourceKey: String?
    let sourceFrame: CGRect?
    let fallbackIcon: String
}

struct WorkoutHeroCover {
    let url: URL?
    let fallbackIcon: String
    let fallbackColor: Color?
}

/// Opens a page inside the window: the tapped cover grows into a card that fills the page over a dimmed backdrop
/// while the cover cross-fades into the page; closing (the page's own close control, which also answers Escape on the
/// Mac, or a tap on the backdrop) shrinks the card back into the cover where it sits now. Without a known cover the
/// card rises from the middle; with Reduce Motion it only cross-fades.
struct WorkoutPageHero<Content: View>: View {
    let request: WorkoutPageHeroRequest
    let sources: WorkoutHeroSources
    let cover: WorkoutHeroCover
    let onFinished: () -> Void
    let content: (_ close: @escaping () -> Void) -> Content

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var expanded = false
    @State private var showsPage = false
    @State private var closing = false
    @State private var settled = false
    @State private var source: CGRect?

    #if os(macOS)
    private let inset: CGFloat = 16
    private let radius: CGFloat = 18
    #else
    private let inset: CGFloat = 10
    private let radius: CGFloat = 24
    #endif

    init(
        request: WorkoutPageHeroRequest,
        sources: WorkoutHeroSources,
        cover: WorkoutHeroCover,
        onFinished: @escaping () -> Void,
        @ViewBuilder content: @escaping (_ close: @escaping () -> Void) -> Content
    ) {
        self.request = request
        self.sources = sources
        self.cover = cover
        self.onFinished = onFinished
        self.content = content
        _source = State(initialValue: request.sourceFrame)
    }

    private var flight: Animation { .spring(response: 0.42, dampingFraction: 0.88) }

    var body: some View {
        GeometryReader { proxy in
            let space = proxy.frame(in: .global)
            let target = CGRect(origin: .zero, size: proxy.size).insetBy(dx: inset, dy: inset)
            let origin = source.map { $0.offsetBy(dx: -space.minX, dy: -space.minY) }
            let flies = !reduceMotion && origin != nil
            let frame = expanded || !flies ? target : (origin ?? target)
            let corner = expanded || !flies ? radius : BuilderMetrics.thumbnailRadius(min(frame.width, frame.height))

            ZStack(alignment: .topLeading) {
                Color.black
                    .opacity(expanded ? 0.55 : 0)
                    .contentShape(Rectangle())
                    .onTapGesture(perform: close)
                    .accessibilityElement()
                    .accessibilityLabel("Close page")
                    .accessibilityAddTraits(.isButton)
                    .accessibilityAction(.default, close)

                card(frame: frame, target: target, corner: corner)
                    .offset(x: frame.minX, y: frame.minY)
                    .opacity(flies || expanded ? 1 : 0)
                    .scaleEffect(!flies && !expanded && !reduceMotion ? 0.94 : 1)
            }
        }
        .accessibilityAddTraits(.isModal)
        .onAppear(perform: open)
    }

    private func card(frame: CGRect, target: CGRect, corner: CGFloat) -> some View {
        let shape = RoundedRectangle(cornerRadius: corner, style: .continuous)
        return ZStack(alignment: .topLeading) {
            Theme.background
            content(close)
                .environment(\.everPageIsOpening, !settled)
                .frame(width: target.width, height: target.height)
                .scaleEffect(showsPage || reduceMotion ? 1 : 0.97, anchor: .top)
                .opacity(showsPage ? 1 : 0)
                .allowsHitTesting(showsPage && !closing)
                .accessibilityHidden(!showsPage)
            WorkoutHeroCoverImage(cover: cover)
                .frame(width: frame.width, height: frame.height)
                .opacity(showsPage ? 0 : 1)
                .allowsHitTesting(false)
                .accessibilityHidden(true)
        }
        .frame(width: frame.width, height: frame.height, alignment: .topLeading)
        .clipShape(shape)
        .overlay(shape.strokeBorder(Color.white.opacity(0.08), lineWidth: 1).allowsHitTesting(false))
    }

    private func open() {
        if reduceMotion {
            run(EverMotion.opacityOnly, duration: 0.15, {
                expanded = true
                showsPage = true
            }, completion: { settled = true })
            return
        }
        withAnimation(.easeOut(duration: 0.24).delay(0.1)) { showsPage = true }
        run(flight, duration: 0.45, { expanded = true }, completion: { settled = true })
    }

    private func close() {
        guard !closing else { return }
        closing = true
        let current = sources.frame(for: request.sourceKey)
        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction) { source = current }
        if reduceMotion {
            run(EverMotion.opacityOnly, duration: 0.15, {
                expanded = false
                showsPage = false
            }, completion: onFinished)
            return
        }
        withAnimation(.easeIn(duration: 0.14)) { showsPage = false }
        run(.spring(response: 0.38, dampingFraction: 0.9), duration: 0.4, { expanded = false }, completion: onFinished)
    }

    private func run(_ animation: Animation, duration: Double, _ changes: () -> Void, completion: @escaping () -> Void) {
        if #available(iOS 17.0, macOS 14.0, *) {
            withAnimation(animation, completionCriteria: .logicallyComplete, changes, completion: completion)
        } else {
            withAnimation(animation, changes)
            DispatchQueue.main.asyncAfter(deadline: .now() + duration, execute: completion)
        }
    }
}

/// A page the workout builder asks the Workouts page to open over itself.
struct WorkoutPageHeroPresentation {
    let request: WorkoutPageHeroRequest
    /// The window title the page below keeps while the page is open, so the Mac's page travel does not run.
    let windowTitle: String
    let sources: WorkoutHeroSources
    let cover: WorkoutHeroCover
    let content: (_ close: @escaping () -> Void) -> AnyView
    let onFinished: () -> Void
}

/// Holds the page a builder opened, so the Workouts page can draw it outside its navigation stack. A page browser
/// has a navigation stack of its own, and one inside a pushed destination of another stack makes SwiftUI rebuild
/// that destination and pop the builder.
final class WorkoutPageHeroPresenter: ObservableObject {
    @Published private(set) var presentation: WorkoutPageHeroPresentation?

    func present(_ presentation: WorkoutPageHeroPresentation) {
        guard self.presentation == nil else { return }
        PerfLog.event("page hero opened")
        self.presentation = presentation
    }

    func finish(_ requestID: UUID) {
        guard let current = presentation, current.request.id == requestID else { return }
        PerfLog.event("page hero closed")
        presentation = nil
        current.onFinished()
    }
}

private struct WorkoutPageHeroPresenterKey: EnvironmentKey {
    static let defaultValue: WorkoutPageHeroPresenter? = nil
}

extension EnvironmentValues {
    var workoutPageHeroPresenter: WorkoutPageHeroPresenter? {
        get { self[WorkoutPageHeroPresenterKey.self] }
        set { self[WorkoutPageHeroPresenterKey.self] = newValue }
    }
}

/// Draws the presenter's page over the Workouts page, above the room the navigation keeps for itself.
struct WorkoutPageHeroHost: View {
    @ObservedObject var presenter: WorkoutPageHeroPresenter
    @Environment(\.slotNavigationContentBounds) private var navigationBounds

    var body: some View {
        GeometryReader { proxy in
            if let presentation = presenter.presentation {
                let visibleHeight = navigationBounds.map {
                    min(proxy.size.height, max(0, $0.maxY - proxy.frame(in: .global).minY))
                } ?? proxy.size.height
                WorkoutPageHero(
                    request: presentation.request,
                    sources: presentation.sources,
                    cover: presentation.cover,
                    onFinished: { presenter.finish(presentation.request.id) },
                    content: presentation.content
                )
                .macWindowTitle(presentation.windowTitle)
                .id(presentation.request.id)
                .frame(width: proxy.size.width, height: visibleHeight)
            }
        }
        .slotNavigationInteractionDisabled(presenter.presentation != nil)
    }
}

/// The cover the hero card shows while it travels, loaded at the size the row thumbnail already cached.
private struct WorkoutHeroCoverImage: View {
    let cover: WorkoutHeroCover
    @State private var image: PhotoPlatformImage?

    var body: some View {
        Color.clear
            .overlay {
                if let image {
                    platformImage(image)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } else {
                    ZStack {
                        (cover.fallbackColor?.opacity(0.3) ?? Theme.surface2)
                        Image(systemName: cover.fallbackIcon)
                            .font(.system(size: 28, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.35))
                    }
                }
            }
            .clipped()
            .task(id: cover.url) {
                guard let url = cover.url else { return }
                image = await PhotoManager.shared.asyncLoadImage(from: url, maxPixelSize: PhotoManager.thumbnailPixelSize)
            }
    }
}
