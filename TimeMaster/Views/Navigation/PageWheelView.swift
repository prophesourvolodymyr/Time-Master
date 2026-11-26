// PageWheelView.swift
//
// The page wheel on screen: a dark disk cut into a slice per page with the page's icon and name, Tmax's square logo on
// the hub, an orange pointer over the slice at the top, the light of the finger on the glass and the slices around the
// finger magnified. Below it sits the liquid search field; above it (beside it on wide windows) the thinking bubble
// with what the search found below the pages, as a tree.

import SwiftUI
#if os(macOS)
import AppKit
#endif

struct PageWheelOverlay: View {
    @ObservedObject var wheel: PageWheelController
    let badges: SlotNavigationBadges
    let theme: SlotNavigationTheme

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @FocusState private var fieldFocused: Bool
    @State private var dragStart: CGPoint?
    @State private var dragStartedOnWheel = false
    @State private var dragTravel: CGFloat = 0

    static let space = "page-wheel"

    var body: some View {
        let layout = wheel.layout
        let progress = wheel.progress
        ZStack {
            if wheel.phase != .closed {
                scrim(progress: progress)
                PageWheelFace(
                    progress: progress,
                    stretch: wheel.stretch,
                    center: layout.center,
                    radius: layout.radius,
                    rotation: wheel.rotation,
                    hovered: wheel.hovered,
                    touch: wheel.touch,
                    light: wheel.light,
                    glow: wheel.glow,
                    items: wheel.items,
                    arc: wheel.arc,
                    badges: badges,
                    theme: theme,
                    reduceMotion: reduceMotion
                )
                .allowsHitTesting(false)
                .accessibilityHidden(true)

                gestureLayer(layout: layout)

                accessibilitySlices(layout: layout)

                PageWheelSearchField(wheel: wheel, focused: $fieldFocused)
                    .frame(width: layout.searchBar.width, height: layout.searchBar.height)
                    .position(x: layout.searchBar.midX, y: layout.searchBar.midY)
                    .opacity(searchOpacity(progress))
                    .offset(y: reduceMotion ? 0 : -18 * (1 - searchOpacity(progress)))
                    .allowsHitTesting(wheel.phase == .open)

                if wheel.phase == .open, !wheel.query.isEmpty, !wheel.results.tree.isEmpty || wheel.results.isEmpty {
                    PageWheelBubble(wheel: wheel, layout: layout)
                        .transition(reduceMotion ? .opacity : .scale(scale: 0.6, anchor: layout.bubbleOnSide ? .leading : .top)
                            .combined(with: .opacity))
                }
            }
        }
        .coordinateSpace(name: Self.space)
        .animation(reduceMotion ? nil : .spring(response: 0.42, dampingFraction: 0.84), value: layout)
        .animation(reduceMotion ? nil : .spring(response: 0.36, dampingFraction: 0.78), value: wheel.query.isEmpty)
        .onChange(of: wheel.searchFocused) { focused in
            if fieldFocused != focused { fieldFocused = focused }
        }
        .onChange(of: fieldFocused) { focused in
            if wheel.searchFocused != focused { wheel.searchFocused = focused }
        }
        #if os(macOS)
        .background {
            if wheel.phase == .open {
                PageWheelMacInput(wheel: wheel)
            }
        }
        #endif
    }

    /// The search field arrives once the wheel has mostly formed, sliding down a little as it fades in.
    private func searchOpacity(_ progress: CGFloat) -> CGFloat {
        let amount = min(1, max(0, (progress - 0.5) / 0.5))
        return amount * amount * (3 - 2 * amount)
    }

    /// The page behind dims and blurs gently at first and fully only as the wheel forms.
    private func scrim(progress: CGFloat) -> some View {
        let amount = Double(min(max(progress, 0), 1))
        let eased = amount * amount * (3 - 2 * amount)
        return ZStack {
            if !reduceTransparency {
                Rectangle().fill(.ultraThinMaterial).opacity(eased * 0.9)
            }
            Color.black.opacity(eased * (reduceTransparency ? 0.82 : 0.5))
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }

    private func gestureLayer(layout: PageWheelLayout) -> some View {
        Color.clear
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0, coordinateSpace: .named(Self.space))
                    .onChanged { value in
                        if dragStart == nil {
                            dragStart = value.startLocation
                            dragTravel = 0
                            let geometry = wheel.geometry(at: 1)
                            dragStartedOnWheel = geometry.distance(to: value.startLocation) <= geometry.radius * 1.1
                            if dragStartedOnWheel { wheel.touchBegan(at: value.startLocation) }
                        }
                        dragTravel = max(dragTravel, hypot(value.translation.width, value.translation.height))
                        if dragStartedOnWheel {
                            wheel.touchMoved(to: value.location, from: value.startLocation)
                        }
                    }
                    .onEnded { value in
                        defer {
                            dragStart = nil
                            dragStartedOnWheel = false
                        }
                        if dragStartedOnWheel {
                            wheel.touchEnded(at: value.location, travelled: dragTravel)
                            return
                        }
                        let downward = value.translation.height > 70
                            && value.translation.height > abs(value.translation.width) * 1.2
                        if wheel.searchFocused, !downward {
                            wheel.searchFocused = false
                        } else if dragTravel < 12 || downward {
                            wheel.dismiss()
                        }
                    }
            )
            #if os(macOS)
            .onContinuousHover(coordinateSpace: .named(Self.space)) { phase in
                switch phase {
                case .active(let location): wheel.hover(at: location)
                case .ended: wheel.hover(at: nil)
                }
            }
            #endif
            .allowsHitTesting(wheel.phase == .open)
            .accessibilityHidden(true)
    }

    /// One accessible button per slice where the slice is drawn, so VoiceOver and UI tests find the pages.
    private func accessibilitySlices(layout: PageWheelLayout) -> some View {
        let geometry = wheel.geometry(at: 1)
        let distance = layout.morph(count: wheel.items.count, arc: wheel.arc).itemDistance(in: geometry, progress: 1)
        let top = wheel.top
        return ZStack {
            ForEach(Array(wheel.items.enumerated()), id: \.element.id) { index, item in
                let point = geometry.point(angle: geometry.angle(of: index, rotation: wheel.rotation), distance: distance)
                Color.clear
                    .frame(width: 52, height: 52)
                    .position(point)
                    .accessibilityElement()
                    .accessibilityLabel(item.title)
                    .accessibilityValue([
                        index == top ? "Selected" : nil,
                        SlotNavigationBadge.accessibilityText(badges.count(for: item.id))
                    ].compactMap { $0 }.joined(separator: ", "))
                    .accessibilityHint(item.accessibilityHint)
                    .accessibilityAddTraits(index == top ? [.isButton, .isSelected] : .isButton)
                    .accessibilityIdentifier("page-wheel-slice-\(item.id)")
                    .accessibilityAction { wheel.commit(index) }
            }
            Color.clear
                .frame(width: geometry.hubRadius * 1.6, height: geometry.hubRadius * 1.6)
                .position(geometry.center)
                .accessibilityElement()
                .accessibilityLabel("Open \(wheel.items.indices.contains(top) ? wheel.items[top].title : "page")")
                .accessibilityAddTraits(.isButton)
                .accessibilityIdentifier("page-wheel-hub")
                .accessibilityAction { wheel.commit(top) }
                .accessibilityAdjustableAction { direction in
                    switch direction {
                    case .increment: wheel.turn(by: 1)
                    case .decrement: wheel.turn(by: -1)
                    @unknown default: break
                    }
                }
        }
        .allowsHitTesting(false)
        .opacity(wheel.phase == .open ? 1 : 0)
        .accessibilityHidden(wheel.phase != .open)
    }
}

// MARK: - Face

/// Everything the wheel draws, as one animatable view: the arc-to-wheel morph, the stretch past it and the wheel's
/// place (which moves when the search opens) interpolate together.
private struct PageWheelFace: View, Animatable {
    var progress: CGFloat
    var stretch: CGFloat
    var center: CGPoint
    var radius: CGFloat
    let rotation: CGFloat
    let hovered: Int?
    let touch: CGPoint?
    let light: CGPoint?
    let glow: CGFloat
    let items: [SlotNavigationItem]
    let arc: PageWheelArc
    let badges: SlotNavigationBadges
    let theme: SlotNavigationTheme
    let reduceMotion: Bool

    var animatableData: AnimatablePair<AnimatablePair<CGFloat, CGFloat>, AnimatablePair<CGFloat, AnimatablePair<CGFloat, CGFloat>>> {
        get { AnimatablePair(AnimatablePair(progress, stretch), AnimatablePair(radius, AnimatablePair(center.x, center.y))) }
        set {
            progress = newValue.first.first
            stretch = newValue.first.second
            radius = newValue.second.first
            center = CGPoint(x: newValue.second.second.first, y: newValue.second.second.second)
        }
    }

    var body: some View {
        let circle = PageWheelMorph.arcCircle(width: max(arc.width, 1), peak: arc.peak, sag: arc.sag)
        let morph = PageWheelMorph(
            count: items.count,
            arcCenter: circle.center,
            arcRadius: circle.radius,
            arcPitch: arc.pitch,
            arcInset: arc.inset,
            wheelCenter: center,
            wheelRadius: radius
        )
        let amount = min(max(progress, 0), 1)
        let geometry = Self.swollen(morph.geometry(at: amount), by: 1 + max(0, stretch) * 0.1)
        let distance = morph.itemDistance(in: geometry, progress: amount)
        let top = geometry.top(rotation: rotation)
        let formed = min(1, max(0, (amount - 0.25) / 0.6))

        ZStack {
            PageWheelDisk(geometry: geometry, rotation: rotation, formed: formed, theme: theme)

            if let light {
                PageWheelTouchLight(geometry: geometry, point: light, glow: glow)
            }

            if geometry.hubRadius > 6 {
                PageWheelHub(side: geometry.hubRadius * 1.08, isPressed: touch.map { geometry.distance(to: $0) <= geometry.hubRadius } ?? false)
                    .position(geometry.center)
                    .opacity(Double(formed))
            }

            ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                let angle = geometry.angle(of: index, rotation: rotation)
                let point = geometry.point(angle: angle, distance: distance)
                let place = abs(geometry.offset(of: index, rotation: rotation))
                let barFocus = max(0, 1 - min(place / 0.9, 1))
                let lens = touch.map { finger in
                    max(0, 1 - hypot(finger.x - point.x, finger.y - point.y) / 96)
                } ?? 0
                let isTop = index == top
                let isHovered = index == hovered
                let barSize = 24 + 8 * barFocus
                let wheelSize: CGFloat = isTop ? 27 : 22
                let size = (barSize + (wheelSize - barSize) * amount) * (1 + (reduceMotion ? 0 : 0.22 * lens * lens) + (isHovered ? 0.1 : 0))
                let barLabel = barFocus * barFocus
                PageWheelItem(
                    item: item,
                    size: size,
                    lit: isTop || isHovered ? 1 : max(barFocus * (1 - amount), lens * 0.8),
                    labelOpacity: barLabel + (1 - barLabel) * amount,
                    emphasized: isTop || isHovered,
                    badge: badges,
                    theme: theme
                )
                .position(point)
                .opacity(item.isPending ? 0.4 : 1)
                .zIndex(isTop || isHovered ? 2 : 1)
            }
        }
    }

    private static func swollen(_ geometry: PageWheelGeometry, by swell: CGFloat) -> PageWheelGeometry {
        var result = geometry
        result.radius *= swell
        result.hubRadius *= swell
        return result
    }
}

/// The wheel's dark glass. While the arc is still rising it keeps the bar's own surface and shadow, so the moment the
/// bar becomes the wheel nothing jumps; the wheel's soft highlight and its dividers come in as it forms.
private struct PageWheelDisk: View {
    let geometry: PageWheelGeometry
    let rotation: CGFloat
    let formed: CGFloat
    let theme: SlotNavigationTheme

    var body: some View {
        Canvas { context, _ in
            let center = geometry.center
            let radius = geometry.radius
            let disk = Path(ellipseIn: CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2))

            var shadowed = context
            shadowed.addFilter(.shadow(
                color: .black.opacity(0.5 + 0.05 * formed), radius: 12 + 10 * formed, x: 0, y: -8 + 18 * formed
            ))
            shadowed.fill(disk, with: .color(theme.surface))

            if formed > 0 {
                var lit = context
                lit.opacity = formed
                lit.fill(disk, with: .radialGradient(
                    Gradient(colors: [Color(hex: "1E1E20"), Color(hex: "121213"), Color(hex: "0A0A0A")]),
                    center: CGPoint(x: center.x, y: center.y - radius * 0.35), startRadius: 0, endRadius: radius * 1.25
                ))
            }

            if geometry.count > 0, formed > 0 {
                let half = geometry.spacing / 2
                var separators = Path()
                for index in 0..<geometry.count {
                    let angle = geometry.angle(of: index, rotation: rotation) + half
                    separators.move(to: geometry.point(angle: angle, distance: geometry.hubRadius + 4))
                    separators.addLine(to: geometry.point(angle: angle, distance: radius - 6))
                }
                context.stroke(separators, with: .color(.white.opacity(0.07 * formed)), lineWidth: 1)
            }

            context.stroke(disk, with: .color(theme.rim), lineWidth: 1)
        }
    }
}

/// The orange light under the finger: a warm glow on the glass around the touch and the rim catching it nearby. It
/// comes up softly, follows the finger and fades where the finger lifted.
private struct PageWheelTouchLight: View, Animatable {
    let geometry: PageWheelGeometry
    let point: CGPoint
    var glow: CGFloat

    var animatableData: CGFloat {
        get { glow }
        set { glow = newValue }
    }

    var body: some View {
        Canvas { context, _ in
            guard glow > 0.001 else { return }
            let center = geometry.center
            let radius = geometry.radius
            let disk = Path(ellipseIn: CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2))
            let orange = Theme.toolbarOrange
            let reach = min(150, max(70, radius * 0.72))
            var lit = context
            lit.clip(to: disk)
            lit.blendMode = .plusLighter
            lit.fill(disk, with: .radialGradient(
                Gradient(stops: [
                    .init(color: orange.opacity(0.42 * glow), location: 0),
                    .init(color: orange.opacity(0.16 * glow), location: 0.45),
                    .init(color: orange.opacity(0), location: 1)
                ]),
                center: point, startRadius: 0, endRadius: reach
            ))
            context.stroke(disk, with: .radialGradient(
                Gradient(colors: [orange.opacity(0.95 * glow), orange.opacity(0)]),
                center: point, startRadius: 0, endRadius: reach * 1.1
            ), lineWidth: 1.6)
        }
        .allowsHitTesting(false)
    }
}

private struct PageWheelItem: View {
    let item: SlotNavigationItem
    let size: CGFloat
    let lit: CGFloat
    let labelOpacity: CGFloat
    let emphasized: Bool
    @ObservedObject var badge: SlotNavigationBadges
    let theme: SlotNavigationTheme

    var body: some View {
        VStack(spacing: 3) {
            SlotNavigationIconImage(icon: item.icon, size: size, lit: lit)
                .foregroundStyle(theme.textPrimary)
                .frame(width: size * 1.2, height: size * 1.2)
                .overlay(alignment: .topTrailing) {
                    let count = badge.count(for: item.id)
                    if count > 0 {
                        SlotNavigationBadge(count: count, ring: Color(hex: "121213"), size: 19)
                            .offset(x: 8, y: -6)
                    }
                }
            Text(item.title.uppercased())
                .font(TimeMasterFont.black(emphasized ? 10.5 : 9.5, relativeTo: .caption2))
                .dynamicTypeSize(.large)
                .tracking(1.1)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .foregroundStyle(emphasized ? theme.textPrimary : theme.textPrimary.opacity(0.72))
                .opacity(Double(labelOpacity))
                .frame(width: 84)
        }
        .fixedSize()
    }
}

/// The square Tmax logo on the hub: the white mark on a black tile with the orange glow rising from its bottom, like the
/// app's icon. It presses in under a finger.
private struct PageWheelHub: View {
    let side: CGFloat
    let isPressed: Bool

    var body: some View {
        let tile = RoundedRectangle(cornerRadius: side * 0.26, style: .continuous)
        tile
            .fill(LinearGradient(colors: [Color(hex: "070505"), Color(hex: "120604")], startPoint: .top, endPoint: .bottom))
            .overlay {
                RadialGradient(
                    colors: [Color(hex: "FF7A2E").opacity(0.95), Color(hex: "FF5A1F").opacity(0.45), .clear],
                    center: UnitPoint(x: 0.5, y: 1.08), startRadius: 0, endRadius: side * 0.62
                )
                .clipShape(tile)
            }
            .overlay {
                TmaxMark()
                    .fill(LinearGradient(colors: [.white, Color(hex: "FFE2D0")], startPoint: .top, endPoint: .bottom))
                    .aspectRatio(TmaxMark.aspectRatio, contentMode: .fit)
                    .frame(width: side * 0.62)
                    .offset(y: -side * 0.03)
            }
            .overlay(tile.strokeBorder(Color(hex: "4A1408").opacity(0.9), lineWidth: 1))
            .frame(width: side, height: side)
            .shadow(color: Color(hex: "FF5A1F").opacity(isPressed ? 0.55 : 0.28), radius: isPressed ? 14 : 8)
            .scaleEffect(isPressed ? 0.93 : 1)
            .animation(isPressed ? EverBounceMotion.squeezeOn : EverBounceMotion.liftOff, value: isPressed)
    }
}

// MARK: - Search field

/// The liquid glass field at the top of the wheel. Focusing it zooms into it; on the iPhone the wheel then grows right
/// under it, its lower half going under the keyboard.
struct PageWheelSearchField: View {
    @ObservedObject var wheel: PageWheelController
    var focused: FocusState<Bool>.Binding

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    var body: some View {
        let isFocused = wheel.searchFocused
        let shape = Capsule(style: .continuous)
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 17, weight: .bold))
                .foregroundStyle(isFocused ? Theme.toolbarOrange : Theme.textSecondary)
            TextField("Search pages, workouts, exercises", text: $wheel.query)
                .textFieldStyle(.plain)
                .font(TimeMasterFont.body(17))
                .foregroundStyle(Theme.textPrimary)
                .autocorrectionDisabled()
                .submitLabel(.go)
                .focused(focused)
                .onSubmit { wheel.submit() }
                .accessibilityIdentifier("page-wheel-search")
                #if os(iOS)
                .textInputAutocapitalization(.never)
                #endif
            if !wheel.query.isEmpty {
                Button {
                    wheel.query = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(Theme.textSecondary)
                        .frame(width: 36, height: 36)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Clear search")
                .transition(.scale.combined(with: .opacity))
            }
        }
        .padding(.leading, 18)
        .padding(.trailing, wheel.query.isEmpty ? 18 : 8)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background { glass(shape) }
        .overlay {
            shape.strokeBorder(
                LinearGradient(
                    colors: isFocused ? [Theme.toolbarOrange.opacity(0.9), Theme.toolbarOrange.opacity(0.25)]
                        : [Color.white.opacity(0.32), Color.white.opacity(0.08)],
                    startPoint: .top, endPoint: .bottom
                ),
                lineWidth: isFocused ? 1.5 : 1
            )
            .allowsHitTesting(false)
        }
        .shadow(color: isFocused ? Theme.toolbarOrange.opacity(0.35) : .black.opacity(0.35), radius: isFocused ? 18 : 12, y: 6)
        .animation(reduceMotion ? nil : .spring(response: 0.34, dampingFraction: 0.7), value: isFocused)
        .contentShape(shape)
        .onTapGesture { wheel.searchFocused = true }
        .everBounce(isFocused, in: shape, kind: .lift(EverBounceMotion.lift), lights: true)
    }

    @ViewBuilder
    private func glass(_ shape: Capsule) -> some View {
        if reduceTransparency {
            shape.fill(Theme.surface2)
        } else if #available(iOS 26.0, macOS 26.0, *) {
            shape.fill(Color.black.opacity(0.18))
                .glassEffect(.regular.interactive(), in: shape)
        } else {
            #if os(iOS)
            TimeMasterFrostedGlassBackground()
                .clipShape(shape)
                .overlay(shape.fill(Color.white.opacity(0.04)))
            #else
            shape.fill(.regularMaterial)
            #endif
        }
    }
}

// MARK: - Thinking bubble

/// What the search found below the wheel's pages, in a thought bubble whose small circles lead to the slice at the
/// top: a tree of the page, the places inside it and the matches. Any row opens; a place opens further in place.
struct PageWheelBubble: View {
    @ObservedObject var wheel: PageWheelController
    let layout: PageWheelLayout

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let tree = wheel.results.tree
        let frame = layout.bubble
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 8) {
                Image(systemName: "sparkle.magnifyingglass")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(Theme.toolbarOrange)
                Text(header(tree))
                    .font(TimeMasterFont.black(13, relativeTo: .subheadline))
                    .foregroundStyle(Theme.textPrimary)
                    .lineLimit(1)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 16)
            .padding(.top, 14)
            .padding(.bottom, 8)

            if tree.isEmpty {
                Text("Nothing in Tmax matches “\(wheel.query)”.")
                    .font(TimeMasterFont.secondary())
                    .foregroundStyle(Theme.textSecondary)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 14)
            } else {
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 2) {
                        ForEach(tree) { node in
                            PageWheelTreeRows(node: node, depth: 0, wheel: wheel)
                        }
                    }
                    .padding(.horizontal, 8)
                    .padding(.bottom, 10)
                }
                .frame(maxHeight: max(60, frame.height - 64))
                .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.leading, layout.bubbleOnSide ? 18 : 0)
        .padding(.bottom, layout.bubbleOnSide ? 0 : 20)
        .frame(width: frame.width, alignment: .leading)
        .background {
            PageWheelBubbleShape(tailOnSide: layout.bubbleOnSide)
                .fill(Color(hex: "161618").opacity(0.97))
                .overlay(PageWheelBubbleShape(tailOnSide: layout.bubbleOnSide).stroke(Color.white.opacity(0.14), lineWidth: 1))
                .shadow(color: .black.opacity(0.5), radius: 20, y: 8)
        }
        .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { height in
            if abs(wheel.bubbleHeight - height) > 0.5 { wheel.bubbleHeight = height }
        }
        .onDisappear { wheel.bubbleHeight = 0 }
        .frame(width: frame.width, height: frame.height, alignment: .topLeading)
        .position(x: frame.midX, y: frame.midY)
        .animation(reduceMotion ? nil : .spring(response: 0.34, dampingFraction: 0.82), value: wheel.results.query)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Search suggestions")
        .accessibilityIdentifier("page-wheel-bubble")
    }

    private func header(_ tree: [NavigationSearchNode]) -> String {
        if tree.isEmpty { return "No match" }
        let count = wheel.results.hits.filter { !$0.entry.isPage }.prefix(NavigationSearchIndex.treeLimit).count
        return "\(count) \(count == 1 ? "match" : "matches") for “\(wheel.query.trimmingCharacters(in: .whitespaces))”"
    }
}

private struct PageWheelTreeRows: View {
    let node: NavigationSearchNode
    let depth: Int
    @ObservedObject var wheel: PageWheelController

    var body: some View {
        let children = node.children + (wheel.expanded[node.id] ?? []).filter { child in
            !node.children.contains(where: { $0.id == child.id })
        }
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 0) {
                Button {
                    wheel.open(node.target)
                } label: {
                    HStack(spacing: 10) {
                        if depth > 0 {
                            PageWheelTreeGuide()
                                .frame(width: 10, height: 30)
                        }
                        Image(systemName: node.symbol)
                            .font(.system(size: depth == 0 ? 13 : 14, weight: .bold))
                            .foregroundStyle(node.isMatch || depth == 0 ? Theme.toolbarOrange : Theme.textSecondary)
                            .frame(width: 22)
                        VStack(alignment: .leading, spacing: 1) {
                            Text(depth == 0 ? node.title.uppercased() : node.title)
                                .font(depth == 0 ? TimeMasterFont.black(11, relativeTo: .caption) : TimeMasterFont.body(15, relativeTo: .subheadline))
                                .tracking(depth == 0 ? 1.2 : 0)
                                .foregroundStyle(node.isMatch || depth == 0 ? Theme.textPrimary : Theme.textPrimary.opacity(0.72))
                                .lineLimit(1)
                            if !node.detail.isEmpty, depth > 0 {
                                Text(node.detail)
                                    .font(TimeMasterFont.caption())
                                    .foregroundStyle(Theme.textSecondary)
                                    .lineLimit(1)
                            }
                        }
                        Spacer(minLength: 0)
                    }
                    .padding(.leading, CGFloat(max(0, depth - 1)) * 16 + 8)
                    .padding(.vertical, depth == 0 ? 6 : 5)
                    .contentShape(Rectangle())
                }
                .buttonStyle(PageWheelRowStyle())
                .accessibilityIdentifier("page-wheel-result-\(node.id)")
                .accessibilityHint(depth == 0 ? "Opens the page" : "Opens it")

                if node.canExpand {
                    Button {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) { wheel.toggle(node) }
                    } label: {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(Theme.textSecondary)
                            .rotationEffect(.degrees(wheel.expanded[node.id] != nil ? 90 : 0))
                            .frame(width: 40, height: 40)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(wheel.expanded[node.id] != nil ? "Show less of \(node.title)" : "Show what is in \(node.title)")
                }
            }
            ForEach(children) { child in
                PageWheelTreeRows(node: child, depth: depth + 1, wheel: wheel)
            }
        }
    }
}

private struct PageWheelRowStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.white.opacity(configuration.isPressed ? 0.1 : 0))
            )
            .everBounce(configuration.isPressed, in: RoundedRectangle(cornerRadius: 12, style: .continuous), kind: .squeeze, lights: false)
    }
}

private struct PageWheelTreeGuide: View {
    var body: some View {
        Canvas { context, size in
            var path = Path()
            path.move(to: CGPoint(x: 1, y: 0))
            path.addLine(to: CGPoint(x: 1, y: size.height / 2))
            path.addQuadCurve(to: CGPoint(x: size.width, y: size.height / 2 + 1), control: CGPoint(x: 1, y: size.height / 2 + 1))
            context.stroke(path, with: .color(.white.opacity(0.22)), lineWidth: 1.2)
        }
        .accessibilityHidden(true)
    }
}

/// A rounded thought bubble with two small circles trailing toward the wheel: below it, or to its left on wide windows.
private struct PageWheelBubbleShape: Shape {
    let tailOnSide: Bool

    func path(in rect: CGRect) -> Path {
        var path = Path()
        if tailOnSide {
            let body = rect.insetBy(dx: 0, dy: 0).offsetBy(dx: 0, dy: 0)
            path.addRoundedRect(in: CGRect(x: body.minX + 18, y: body.minY, width: body.width - 18, height: body.height),
                                cornerSize: CGSize(width: 26, height: 26), style: .continuous)
            path.addEllipse(in: CGRect(x: body.minX + 4, y: body.minY + 36, width: 11, height: 11))
            path.addEllipse(in: CGRect(x: body.minX - 6, y: body.minY + 52, width: 6, height: 6))
        } else {
            path.addRoundedRect(in: CGRect(x: rect.minX, y: rect.minY, width: rect.width, height: rect.height - 20),
                                cornerSize: CGSize(width: 26, height: 26), style: .continuous)
            path.addEllipse(in: CGRect(x: rect.midX - 7, y: rect.maxY - 17, width: 12, height: 12))
            path.addEllipse(in: CGRect(x: rect.midX + 2, y: rect.maxY - 4, width: 6, height: 6))
        }
        return path
    }
}

// MARK: - Mac input

#if os(macOS)
/// While the wheel is open on the Mac: two-finger scrolls and the mouse wheel turn it, the arrow keys step it, Return
/// opens the slice at the top and Escape clears the search or closes the wheel.
private struct PageWheelMacInput: NSViewRepresentable {
    let wheel: PageWheelController

    func makeNSView(context: Context) -> InputView {
        let view = InputView()
        view.wheel = wheel
        return view
    }

    func updateNSView(_ view: InputView, context: Context) {
        view.wheel = wheel
    }

    static func dismantleNSView(_ view: InputView, coordinator: ()) {
        view.stop()
    }

    final class InputView: NSView {
        weak var wheel: PageWheelController?
        private var monitors: [Any] = []
        private var lastWheelStep: TimeInterval = 0

        override func hitTest(_ point: NSPoint) -> NSView? { nil }

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            stop()
            guard window != nil else { return }
            let scrolls = NSEvent.addLocalMonitorForEvents(matching: .scrollWheel) { [weak self] event in
                MainActor.assumeIsolated { self?.scroll(event) ?? false } ? nil : event
            }
            let keys = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
                MainActor.assumeIsolated { self?.key(event) ?? false } ? nil : event
            }
            monitors = [scrolls, keys].compactMap { $0 }
        }

        func stop() {
            monitors.forEach(NSEvent.removeMonitor)
            monitors.removeAll()
        }

        private func scroll(_ event: NSEvent) -> Bool {
            guard let wheel, event.window === window, wheel.phase == .open else { return false }
            let delta = event.scrollingDeltaY + event.scrollingDeltaX
            if event.phase.isEmpty, event.momentumPhase.isEmpty {
                guard delta != 0, event.timestamp - lastWheelStep > 0.06 else { return true }
                lastWheelStep = event.timestamp
                wheel.turn(by: delta > 0 ? -1 : 1)
                return true
            }
            if !event.momentumPhase.isEmpty { return true }
            let ended = event.phase.contains(.ended) || event.phase.contains(.cancelled)
            wheel.scroll(by: Double(-delta / 46), ended: ended)
            return true
        }

        private func key(_ event: NSEvent) -> Bool {
            guard let wheel, event.window === window, wheel.phase == .open else { return false }
            let typing = !wheel.query.isEmpty
            switch event.keyCode {
            case 53:
                if typing { wheel.query = "" } else { wheel.dismiss() }
                return true
            case 126:
                wheel.turn(by: -1)
                return true
            case 125:
                wheel.turn(by: 1)
                return true
            case 123 where !typing:
                wheel.turn(by: -1)
                return true
            case 124 where !typing:
                wheel.turn(by: 1)
                return true
            case 36, 76:
                guard !wheel.searchFocused else { return false }
                wheel.submit()
                return true
            default:
                return false
            }
        }
    }
}
#endif
