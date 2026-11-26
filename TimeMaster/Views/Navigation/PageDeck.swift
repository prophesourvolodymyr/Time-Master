// PageDeck.swift
//
// Page switching that answers at once. Two places on screen hold the page being left and the page coming in; while a
// finger scrubs the bar, drags from an edge or hovers the wheel they follow it as page shells, which cost nothing to
// draw. When a page is chosen its real content is built behind its shell once the slide is half done, and fades in
// over the shell as soon as it has been laid out. Only the page being shown and the one leaving it are ever built.

import SwiftUI

/// The pages that exist as real views. Changes only when a page is built or let go, so the views that build pages
/// observe this and nothing that moves every frame.
@MainActor
final class PageDeckRoster: ObservableObject {
    @Published fileprivate(set) var live: [String]

    init(page: String) {
        live = [page]
    }
}

@MainActor
final class PageDeck: ObservableObject {
    /// The page on the left of the pair on screen and the one on its right; at rest only `left`.
    @Published private(set) var left: String
    @Published private(set) var right: String?
    /// 0 shows `left` in full and 1 shows `right`; past either end of the bar the page leans like a rubber band.
    @Published private(set) var split: CGFloat = 0
    /// Real pages that have been laid out and show over their shells.
    @Published private(set) var revealed: Set<String>
    /// The page the deck rests on or is going to: its preferences count and it takes touches once the deck rests.
    @Published private(set) var target: String
    @Published private(set) var isResting = true

    let roster: PageDeckRoster
    var reduceMotion = false
    /// Told whenever the deck comes to rest on a page.
    var onRest: (String) -> Void = { _ in }

    private var settleTask: Task<Void, Never>?
    private var mountTask: Task<Void, Never>?
    private var dragDirection: CGFloat = 0
    private var dragOrigin: String?

    static let duration: Double = 0.34
    static let curve = Animation.timingCurve(0.18, 0.84, 0.22, 1, duration: duration)
    /// The share of the slide after which the real page starts being built.
    static let buildPoint: Double = 0.45

    init(page: String) {
        left = page
        target = page
        revealed = [page]
        roster = PageDeckRoster(page: page)
    }

    /// Where the page `id` sits, as a share of the width from its resting place; nil when it is not on screen.
    func place(of id: String) -> CGFloat? {
        if id == left { return -split }
        if id == right { return 1 - split }
        return nil
    }

    var visiblePages: [String] {
        [left] + (right.map { [$0] } ?? [])
    }

    // MARK: Following a finger

    /// The bar's strip is being dragged: `position` is the fractional place along `order` under the bar's centre.
    func scrub(to position: CGFloat, order: [String]) {
        guard !order.isEmpty, position.isFinite else { return }
        cancelMotion()
        dragOrigin = nil
        let last = CGFloat(order.count - 1)
        withoutAnimation {
            isResting = false
            if position < 0 {
                assign(left: order[0], right: nil, split: position * 0.3)
            } else if position > last {
                assign(left: order[order.count - 1], right: nil, split: (position - last) * 0.3)
            } else {
                let index = min(Int(position.rounded(.down)), order.count - 1)
                let fraction = position - CGFloat(index)
                assign(left: order[index], right: index + 1 < order.count ? order[index + 1] : nil, split: fraction)
            }
            let nearest = order[min(max(Int(position.rounded()), 0), order.count - 1)]
            if target != nearest { target = nearest }
        }
    }

    /// A finger starts dragging `neighbour` in from one side of the page at rest: +1 from the right, -1 from the left.
    func beginDrag(to neighbour: String, direction: CGFloat) {
        cancelMotion()
        let origin = target
        dragOrigin = origin
        dragDirection = direction < 0 ? -1 : 1
        withoutAnimation {
            isResting = false
            if dragDirection > 0 {
                assign(left: origin, right: neighbour, split: 0)
            } else {
                assign(left: neighbour, right: origin, split: 1)
            }
        }
    }

    /// How far the neighbour has come in, from 0 to 1.
    func drag(fraction: CGFloat) {
        guard dragOrigin != nil, fraction.isFinite else { return }
        let amount = fraction > 1 ? 1 + (fraction - 1) * 0.2 : max(0, fraction)
        withoutAnimation {
            split = dragDirection > 0 ? amount : 1 - amount
        }
    }

    /// The drag ended without changing the page: the page it started from slides back.
    func cancelDrag() {
        guard let origin = dragOrigin else { return }
        dragOrigin = nil
        go(to: origin)
    }

    // MARK: Going to a page

    /// Slides from what is on screen now to `id`, builds it half way and rests on it.
    func go(to id: String, order: [String] = []) {
        dragOrigin = nil
        cancelMotion()
        if !roster.live.contains(id) { revealed.remove(id) }
        target = id
        isResting = false

        if left == id, right == nil, abs(split) < 0.001 {
            finish(on: id)
            return
        }

        if reduceMotion {
            withoutAnimation { assign(left: id, right: nil, split: 0) }
            scheduleBuild(id, after: 0)
            settle(on: id, after: 0.02)
            return
        }

        if left != id, right != id {
            let visible = split < 0.5 ? left : (right ?? left)
            let forward = Self.index(of: id, in: order).flatMap { next in
                Self.index(of: visible, in: order).map { next > $0 }
            } ?? true
            withoutAnimation {
                if forward {
                    assign(left: visible, right: id, split: 0)
                } else {
                    assign(left: id, right: visible, split: 1)
                }
            }
        }

        let goal: CGFloat = left == id ? 0 : 1
        let distance = min(1, max(0.2, abs(goal - split)))
        let duration = Self.duration * Double(distance)
        withAnimation(Self.curve.speed(1 / distance)) {
            split = goal
        }
        scheduleBuild(id, after: duration * Self.buildPoint)
        settle(on: id, after: duration + 0.02)
    }

    /// The real page `id` has been added to the screen; it shows over its shell once it has been laid out.
    func pageAppeared(_ id: String) {
        guard !revealed.contains(id) else { return }
        DispatchQueue.main.async { [weak self] in
            guard let self, self.roster.live.contains(id), !self.revealed.contains(id) else { return }
            withAnimation(self.reduceMotion ? nil : .easeOut(duration: 0.2)) {
                _ = self.revealed.insert(id)
            }
        }
    }

    /// Builds `id` now, for a page the wheel is about to open.
    func build(_ id: String) {
        guard !roster.live.contains(id) else { return }
        revealed.remove(id)
        roster.live.append(id)
    }

    // MARK: Internals

    private func withoutAnimation(_ change: () -> Void) {
        var transaction = Transaction(animation: nil)
        transaction.disablesAnimations = true
        withTransaction(transaction, change)
    }

    private func assign(left: String, right: String?, split: CGFloat) {
        if self.left != left { self.left = left }
        if self.right != right { self.right = right }
        if self.split != split { self.split = split }
    }

    private func scheduleBuild(_ id: String, after delay: Double) {
        mountTask?.cancel()
        guard !roster.live.contains(id) else { return }
        mountTask = Task { @MainActor [weak self] in
            if delay > 0 { try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000)) }
            guard !Task.isCancelled, let self, self.target == id else { return }
            self.build(id)
        }
    }

    private func settle(on id: String, after delay: Double) {
        settleTask = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            guard !Task.isCancelled else { return }
            self?.finish(on: id)
        }
    }

    private func finish(on id: String) {
        settleTask = nil
        withoutAnimation {
            assign(left: id, right: nil, split: 0)
            isResting = true
        }
        if !roster.live.contains(id) { build(id) }
        let keep = roster.live.filter { $0 == id }
        if keep != roster.live { roster.live = keep }
        revealed = revealed.intersection(keep)
        onRest(id)
    }

    private func cancelMotion() {
        settleTask?.cancel()
        settleTask = nil
    }

    private static func index(of id: String, in order: [String]) -> Int? {
        order.firstIndex(of: id)
    }
}

/// The pages of the deck: each real page built once, placed and faded by the deck, and only the page the deck goes to
/// passes its preferences on and takes touches.
struct PageDeckPages<Page: View>: View {
    @ObservedObject var roster: PageDeckRoster
    let deck: PageDeck
    let order: [String]
    let page: (String) -> Page

    var body: some View {
        ZStack(alignment: .top) {
            ForEach(roster.live, id: \.self) { id in
                page(id)
                    .everPageTravel(scope: id, order: order.firstIndex(of: id) ?? 0)
                    .modifier(PageDeckPlacement(deck: deck, id: id))
                    .onAppear { deck.pageAppeared(id) }
            }
        }
    }
}

private struct PageDeckPlacement: ViewModifier {
    @ObservedObject var deck: PageDeck
    let id: String

    func body(content: Content) -> some View {
        let place = deck.place(of: id)
        let primary = deck.target == id
        let shown = deck.revealed.contains(id)
        let interactive = primary && shown && deck.isResting
        content
            .transformPreference(SlotNavigationPresentationPreferenceKey.self) { if !primary { $0 = nil } }
            .transformPreference(SlotNavigationInteractionDisabledPreferenceKey.self) { if !primary { $0 = false } }
            .transformPreference(SlotNavigationStripPreferenceKey.self) { if !primary { $0 = false } }
            .transformPreference(SlotNavigationEditingPreferenceKey.self) { if !primary { $0 = false } }
            .transformPreference(ReachabilityActivePreferenceKey.self) { if !primary { $0 = false } }
            #if os(macOS)
            .transformPreference(MacWindowTitlePreferenceKey.self) { if !primary { $0 = nil } }
            .transformPreference(EverPageBackStackKey.self) { if !primary { $0 = nil } }
            .transformPreference(EverEscapeClaimKey.self) { if !primary { $0 = nil } }
            #endif
            .modifier(PageDeckOffset(place: place ?? 0))
            .opacity(place == nil || !shown ? 0 : 1)
            .allowsHitTesting(interactive)
            .accessibilityHidden(!primary)
    }
}

/// The slide of one page: its place as a share of its width.
private struct PageDeckOffset: GeometryEffect {
    var place: CGFloat

    var animatableData: CGFloat {
        get { place }
        set { place = newValue }
    }

    func effectValue(size: CGSize) -> ProjectionTransform {
        ProjectionTransform(CGAffineTransform(translationX: size.width * place, y: 0))
    }
}

/// The shells of the pages on screen that have no real page showing yet.
struct PageDeckShells: View {
    @ObservedObject var deck: PageDeck

    var body: some View {
        ZStack(alignment: .top) {
            ForEach(deck.visiblePages.filter { !deck.revealed.contains($0) }, id: \.self) { id in
                if let destination = SlotNavigationDestination(rawValue: id) {
                    PageShell(destination: destination)
                        .modifier(PageDeckOffset(place: deck.place(of: id) ?? 0))
                        .transition(.opacity.animation(.easeOut(duration: 0.2)))
                }
            }
        }
        .allowsHitTesting(false)
    }
}
