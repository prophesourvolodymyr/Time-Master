import SwiftUI

/// Sizes shared by every row of the workout builder, so controls, rails and text line up at every depth.
enum BuilderMetrics {
    #if os(macOS)
    static let pageInset: CGFloat = 20
    static let chip: CGFloat = 28
    #else
    static let pageInset: CGFloat = 12
    static let chip: CGFloat = 30
    #endif
    static let chipSpacing: CGFloat = 4
    static let valueWidth: CGFloat = 50
    static let columnWidth: CGFloat = EverLayout.maximumReadableWidth
    static let cardPadding: CGFloat = 12
    static let cardRadius: CGFloat = EverRadius.card
    static let groupSpacing: CGFloat = 10
    static let handleWidth: CGFloat = 12
    static let handleGap: CGFloat = 8
    static let root: CGFloat = 40
    static let rootGap: CGFloat = 10
    static let levelStep: CGFloat = 24
    static let rail: CGFloat = 1.5
    static let elbowRadius: CGFloat = 7
    static let headerVertical: CGFloat = 12

    /// The rail of a section runs under the centre of its cover, measured from the card's inner leading edge.
    static var railX: CGFloat { handleWidth + handleGap + root / 2 }

    static func nodeX(_ level: Int) -> CGFloat { railX + CGFloat(max(0, level - 1)) * levelStep }

    static func textX(_ level: Int) -> CGFloat {
        handleWidth + handleGap + root + rootGap + CGFloat(max(0, level - 1)) * levelStep
    }

    static func node(_ level: Int) -> CGFloat { level <= 1 ? 30 : (level == 2 ? 24 : 20) }

    static func rowVertical(_ level: Int) -> CGFloat { level <= 1 ? 9 : 7 }

    static func thumbnailRadius(_ size: CGFloat) -> CGFloat { min(10, size * 0.26) }
}

/// The two builder surfaces: the dark card of a section and the white head of a bundle.
enum BuilderTone {
    case dark
    case light

    var surface: Color { self == .dark ? Theme.surface : .white }
    var edge: Color? { self == .dark ? Theme.separator : nil }
    var rail: Color { self == .dark ? Color.white.opacity(0.16) : Color.black.opacity(0.16) }
    var hover: Color { self == .dark ? Color.white.opacity(0.035) : Color.black.opacity(0.035) }
    var ink: Color { self == .dark ? Theme.textPrimary : .black }
    var secondaryInk: Color { self == .dark ? Theme.textSecondary : Color.black.opacity(0.55) }
    fileprivate var chip: Color { self == .dark ? Color.white.opacity(0.06) : Color.black.opacity(0.06) }
    fileprivate var chipHover: Color { self == .dark ? Color.white.opacity(0.12) : Color.black.opacity(0.11) }
    fileprivate var chipPressed: Color { self == .dark ? Color.white.opacity(0.18) : Color.black.opacity(0.16) }
    fileprivate var glyph: Color { self == .dark ? Color.white.opacity(0.5) : Color.black.opacity(0.5) }
    fileprivate var glyphRowHover: Color { self == .dark ? Color.white.opacity(0.75) : Color.black.opacity(0.72) }
}

private struct BuilderRowHoveredKey: EnvironmentKey {
    static let defaultValue = false
}

extension EnvironmentValues {
    /// The pointer is over the builder row holding a control, so its controls step up in contrast.
    var builderRowHovered: Bool {
        get { self[BuilderRowHoveredKey.self] }
        set { self[BuilderRowHoveredKey.self] = newValue }
    }
}

extension View {
    /// Grows the touch area of a small control to 44 points on iPhone and iPad without changing its layout.
    func builderTouchTarget(width: CGFloat, height: CGFloat) -> some View {
        #if os(iOS)
        let dx = max(0, (EverLayout.minimumTouchTarget - width) / 2)
        let dy = max(0, (EverLayout.minimumTouchTarget - height) / 2)
        return padding(.horizontal, dx)
            .padding(.vertical, dy)
            .contentShape(Rectangle())
            .padding(.horizontal, -dx)
            .padding(.vertical, -dy)
        #else
        return self
        #endif
    }

    /// Draws a `Menu` as a builder chip: no menu indicator, the same face as the buttons beside it.
    func builderChipMenu(tone: BuilderTone = .dark) -> some View {
        menuStyle(.button)
            .menuIndicator(.hidden)
            .buttonStyle(BuilderChipButtonStyle(tone: tone))
            .fixedSize()
    }

    /// A right-click menu on the Mac. On iPhone and iPad a long press stays free for reordering; the same actions sit
    /// in the row's menus and swipe actions there.
    @ViewBuilder
    func builderContextMenu<MenuItems: View>(@ViewBuilder _ items: () -> MenuItems) -> some View {
        #if os(macOS)
        contextMenu(menuItems: items)
        #else
        self
        #endif
    }

    /// Places content in the page's centred column with the page margins.
    func builderColumn() -> some View {
        frame(maxWidth: BuilderMetrics.columnWidth)
            .frame(maxWidth: .infinity)
            .padding(.horizontal, BuilderMetrics.pageInset)
    }

    /// A row in the page's column, drawn as a plain list row on iPhone and iPad.
    func builderPageRow() -> some View {
        builderColumn()
            .listRowInsets(EdgeInsets())
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)
    }

    /// A row of a section's card. On iPhone and iPad every row is its own list row and so takes the page column
    /// itself; on the Mac the section's card is one view that does it once.
    @ViewBuilder
    func builderGroupedRow() -> some View {
        #if os(macOS)
        self
        #else
        builderPageRow()
        #endif
    }

    /// The card of one section on the Mac, where the section's rows share one view and so one continuous surface.
    func builderGroupSurface() -> some View {
        background(BuilderSurface(slice: .single))
            .clipShape(RoundedRectangle(cornerRadius: BuilderMetrics.cardRadius, style: .continuous))
    }
}

/// The one control of the builder rows: a quiet filled circle that brightens on hover and gives under a press.
struct BuilderChipButtonStyle: ButtonStyle {
    var tone: BuilderTone = .dark

    func makeBody(configuration: Configuration) -> some View {
        BuilderChipFace(label: configuration.label, isPressed: configuration.isPressed, tone: tone)
    }
}

private struct BuilderChipFace<Label: View>: View {
    let label: Label
    let isPressed: Bool
    let tone: BuilderTone
    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.builderRowHovered) private var rowHovered
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorSchemeContrast) private var contrast
    @State private var hovered = false

    var body: some View {
        let lit = hovered || isPressed
        label
            .font(.system(size: 12, weight: .bold))
            .foregroundStyle(lit ? tone.ink : (rowHovered ? tone.glyphRowHover : tone.glyph))
            .frame(width: BuilderMetrics.chip, height: BuilderMetrics.chip)
            .background(Circle().fill(isPressed ? tone.chipPressed : (hovered ? tone.chipHover : tone.chip)))
            .overlay {
                if contrast == .increased {
                    Circle().strokeBorder(tone.ink.opacity(0.45), lineWidth: 1)
                }
            }
            .contentShape(Circle())
            .opacity(isEnabled ? 1 : 0.35)
            .animation(reduceMotion ? nil : (isPressed ? EverMotion.press : EverMotion.release), value: isPressed)
            .everBounce(isPressed && isEnabled, in: Circle(), kind: .lift(EverBounceMotion.compactLift), pops: true)
            .animation(reduceMotion ? nil : .easeOut(duration: 0.12), value: hovered)
            .keyNavButtonSurface(.circle)
            .onHover { hovered = $0 }
            .builderTouchTarget(width: BuilderMetrics.chip, height: BuilderMetrics.chip)
    }
}

/// A tappable value of a builder row (a duration): a quiet capsule in the language of the chips.
struct BuilderValueButtonStyle: ButtonStyle {
    var tone: BuilderTone = .dark

    func makeBody(configuration: Configuration) -> some View {
        BuilderValueFace(label: configuration.label, isPressed: configuration.isPressed, tone: tone)
    }
}

private struct BuilderValueFace<Label: View>: View {
    let label: Label
    let isPressed: Bool
    let tone: BuilderTone
    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var hovered = false

    var body: some View {
        label
            .font(TimeMasterFont.black(12, relativeTo: .caption).monospacedDigit())
            .foregroundStyle(tone.ink.opacity(hovered || isPressed ? 1 : 0.88))
            .lineLimit(1)
            .padding(.horizontal, 9)
            .frame(minWidth: BuilderMetrics.valueWidth, minHeight: 24)
            .background(Capsule().fill(isPressed ? tone.chipPressed : (hovered ? tone.chipHover : tone.chip)))
            .contentShape(Capsule())
            .opacity(isEnabled ? 1 : 0.35)
            .animation(reduceMotion ? nil : (isPressed ? EverMotion.press : EverMotion.release), value: isPressed)
            .everBounce(isPressed && isEnabled, in: Capsule(), kind: .lift(EverBounceMotion.compactLift), pops: true)
            .animation(reduceMotion ? nil : .easeOut(duration: 0.12), value: hovered)
            .keyNavButtonSurface(.capsule)
            .onHover { hovered = $0 }
            .builderTouchTarget(width: BuilderMetrics.valueWidth, height: 24)
    }
}

/// A value of a builder row that is not edited in place, set in the column of the tappable ones.
struct BuilderValueText: View {
    let text: String
    var tone: BuilderTone = .dark

    var body: some View {
        Text(text)
            .font(TimeMasterFont.black(12, relativeTo: .caption).monospacedDigit())
            .foregroundStyle(tone.secondaryInk)
            .lineLimit(1)
            .frame(minWidth: BuilderMetrics.valueWidth)
    }
}

/// The expand and collapse control: the chevron turns with the expansion.
struct BuilderDisclosureChip: View {
    let isExpanded: Bool
    var tone: BuilderTone = .dark
    let expandLabel: String
    let collapseLabel: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "chevron.down")
                .rotationEffect(.degrees(isExpanded ? 180 : 0))
        }
        .buttonStyle(BuilderChipButtonStyle(tone: tone))
        .accessibilityLabel(isExpanded ? collapseLabel : expandLabel)
        .accessibilityValue(isExpanded ? "Expanded" : "Collapsed")
    }
}

/// A row's controls in three fixed slots (add, more, expand), so a control sits in the same column on every row of a
/// section; an empty slot keeps its room.
struct BuilderCluster<Lead: View, Middle: View, Last: View>: View {
    let lead: Lead
    let middle: Middle
    let last: Last

    init(
        @ViewBuilder lead: () -> Lead,
        @ViewBuilder middle: () -> Middle,
        @ViewBuilder last: () -> Last
    ) {
        self.lead = lead()
        self.middle = middle()
        self.last = last()
    }

    var body: some View {
        HStack(spacing: BuilderMetrics.chipSpacing) {
            slot(lead)
            slot(middle)
            slot(last)
        }
    }

    private func slot<Content: View>(_ content: Content) -> some View {
        ZStack {
            Color.clear
            content
        }
        .frame(width: BuilderMetrics.chip, height: BuilderMetrics.chip)
    }
}

/// One child row of a section: its node on the rail, its title, then its value and controls at the trailing edge.
struct BuilderTimelineRow<Node: View, Title: View, Trailing: View>: View {
    let level: Int
    let node: Node
    let title: Title
    let trailing: Trailing

    init(
        level: Int,
        @ViewBuilder node: () -> Node,
        @ViewBuilder title: () -> Title,
        @ViewBuilder trailing: () -> Trailing
    ) {
        self.level = level
        self.node = node()
        self.title = title()
        self.trailing = trailing()
    }

    var body: some View {
        HStack(spacing: 0) {
            node
                .frame(width: BuilderMetrics.node(level), height: BuilderMetrics.node(level))
                .padding(.leading, BuilderMetrics.nodeX(level) - BuilderMetrics.node(level) / 2)
                .frame(width: BuilderMetrics.textX(level), alignment: .leading)
            title
                .frame(maxWidth: .infinity, alignment: .leading)
            HStack(spacing: 8) {
                trailing
            }
            .padding(.leading, 8)
        }
    }
}

/// Title and optional caption of a builder row.
struct BuilderRowTitle: View {
    let title: String
    var subtitle: String?
    var level: Int

    init(_ title: String, subtitle: String? = nil, level: Int = 1) {
        self.title = title
        self.subtitle = subtitle
        self.level = level
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(title)
                .font(TimeMasterFont.black(level <= 1 ? 15 : 14, relativeTo: .subheadline))
                .foregroundStyle(Theme.textPrimary)
                .lineLimit(1)
            if let subtitle {
                Text(subtitle)
                    .font(TimeMasterFont.micro())
                    .foregroundStyle(Theme.textSecondary)
                    .lineLimit(1)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
    }
}

/// A rail node drawn as a glyph on a small disc (preparation, rests, notes), or on a rounded square for a section
/// without a cover.
struct BuilderGlyphNode: View {
    let systemImage: String
    var size: CGFloat = BuilderMetrics.node(1)
    var tint: Color = Theme.textSecondary
    var square = false
    var progress: Double?

    var body: some View {
        Image(systemName: systemImage)
            .font(.system(size: max(9, size * 0.36), weight: .bold))
            .foregroundStyle(tint)
            .accessibilityHidden(true)
            .frame(width: size, height: size)
            .background {
                if square {
                    RoundedRectangle(cornerRadius: BuilderMetrics.thumbnailRadius(size), style: .continuous)
                        .fill(Theme.surface2)
                } else {
                    Circle().fill(Theme.surface2)
                }
            }
            .overlay {
                if square {
                    RoundedRectangle(cornerRadius: BuilderMetrics.thumbnailRadius(size), style: .continuous)
                        .strokeBorder(Color.white.opacity(0.1), lineWidth: 1)
                } else {
                    Circle().strokeBorder(Color.white.opacity(0.1), lineWidth: 1)
                }
            }
            .overlay {
                if let progress {
                    BuilderProgressRing(
                        progress: progress,
                        cornerRadius: square ? BuilderMetrics.thumbnailRadius(size) : nil
                    )
                }
            }
    }
}

/// Live progress around a rail node: the orange stroke fills while the step plays.
struct BuilderProgressRing: View {
    let progress: Double
    /// Corner radius of a square node (a cover); `nil` for a round node.
    var cornerRadius: CGFloat?

    var body: some View {
        let value = min(1, max(0, progress))
        ZStack {
            if let cornerRadius {
                RoundedRectangle(cornerRadius: cornerRadius + 3, style: .continuous)
                    .stroke(Color.gray.opacity(0.4), lineWidth: 2)
                RoundedRectangle(cornerRadius: cornerRadius + 3, style: .continuous)
                    .trim(from: 0, to: value)
                    .stroke(Theme.toolbarOrange, style: StrokeStyle(lineWidth: 2, lineCap: .round))
            } else {
                Circle()
                    .stroke(Color.gray.opacity(0.4), lineWidth: 2)
                Circle()
                    .trim(from: 0, to: value)
                    .stroke(Theme.toolbarOrange, style: StrokeStyle(lineWidth: 2, lineCap: .round))
                    .rotationEffect(.degrees(-90))
            }
        }
        .padding(-3)
        .allowsHitTesting(false)
        .accessibilityElement()
        .accessibilityLabel("Progress")
        .accessibilityValue("\(Int(value * 100)) percent")
    }
}

/// The reorder grip of a section: drag it on the Mac, long-press the row on iPhone and iPad.
struct BuilderHandle: View {
    var tone: BuilderTone = .dark

    var body: some View {
        Image(systemName: "line.3.horizontal")
            .font(.system(size: 11, weight: .bold))
            .foregroundStyle(tone.secondaryInk.opacity(0.8))
            .frame(width: BuilderMetrics.handleWidth, height: BuilderMetrics.root)
            .accessibilityHidden(true)
    }
}

/// Where a row sits in its section's card: the rows of one section share one surface, rounded only at its ends.
enum BuilderSlice {
    case top
    case middle
    case bottom
    case single

    var roundsTop: Bool { self == .top || self == .single }
    var roundsBottom: Bool { self == .bottom || self == .single }
}

/// The section card behind a row: a slice of one rounded surface, with the hairline only on its outer edges.
struct BuilderSurface: View {
    let slice: BuilderSlice
    var tone: BuilderTone = .dark
    var highlighted = false
    @Environment(\.colorSchemeContrast) private var contrast

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: BuilderMetrics.cardRadius, style: .continuous)
        let overflow = BuilderMetrics.cardRadius * 2
        ZStack {
            shape.fill(tone.surface)
            if highlighted {
                shape.fill(tone.hover)
            }
            if let edge = tone.edge {
                shape.strokeBorder(contrast == .increased ? Color.white.opacity(0.5) : edge, lineWidth: 1)
            }
        }
        .padding(.top, slice.roundsTop ? 0 : -overflow)
        .padding(.bottom, slice.roundsBottom ? 0 : -overflow)
        .clipped()
        .allowsHitTesting(false)
    }
}

/// The line that ties a section's children to its cover: through the node of every step, with rounded elbows into
/// nested rows, so an expanded section reads as one unit. While a workout plays, the finished part turns orange.
struct BuilderRail: Equatable {
    /// 0 for the section head, 1 for its steps, 2 and 3 for rows nested under a step.
    var level = 0
    /// The rail goes on below this row's node (more steps, or rows nested under this one, follow).
    var continuesBelow = false
    /// Columns of outer levels that cross this row from top to bottom.
    var passes: [Int] = []
    /// The column this nested row branches from goes on below its elbow.
    var branchContinues = false
    /// A row that interrupts the rail (an inline editor spanning the card): no line runs through or into it.
    var breaksRail = false
    /// A step's line comes down from the row above (not after an interruption).
    var railAbove = true
    var live = false
    /// The line arriving at this step is complete.
    var enteredDone = false
    /// Played share of this step.
    var fill: Double = 0
    /// The step this nested row belongs to is complete.
    var passesDone = false

    /// Rails for a section's rows below its head, in order.
    static func thread(
        levels: [Int],
        progress: [Double],
        crossing: [Bool],
        rootProgress: Double,
        live: Bool
    ) -> [BuilderRail] {
        func continues(_ column: Int, after index: Int) -> Bool {
            for level in levels[(index + 1)...] {
                if column == 1 {
                    if level <= 2 { return true }
                } else if level == column + 1 {
                    return true
                } else if level <= column {
                    return false
                }
            }
            return false
        }

        var rails: [BuilderRail] = []
        var reached = live && rootProgress > 0
        var stepDone = false
        var afterBreak = false
        for index in levels.indices {
            let level = max(1, levels[index])
            var rail = BuilderRail(level: level, live: live)
            rail.continuesBelow = continues(level, after: index)
                && !(index + 1 < crossing.count && crossing[index + 1])
            rail.breaksRail = crossing[index]
            rail.railAbove = !afterBreak
            afterBreak = crossing[index]
            if level == 1 {
                rail.enteredDone = reached
                rail.fill = live ? progress[index] : 0
                stepDone = live && progress[index] >= 1
                reached = stepDone
            } else {
                rail.passes = (1..<(level - 1)).filter { continues($0, after: index) }
                rail.branchContinues = continues(level - 1, after: index)
                rail.passesDone = stepDone
            }
            rails.append(rail)
        }
        return rails
    }
}

/// Draws a row's part of the rail; rows touch, so the parts join into one line.
struct BuilderRailCanvas: View {
    let rail: BuilderRail
    var tone: BuilderTone = .dark

    var body: some View {
        Canvas { context, size in
            draw(in: &context, size: size)
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private func draw(in context: inout GraphicsContext, size: CGSize) {
        let base = tone.rail
        let done = Theme.toolbarOrange
        let width = BuilderMetrics.rail
        let mid = size.height / 2

        func x(_ column: Int) -> CGFloat {
            BuilderMetrics.cardPadding + BuilderMetrics.nodeX(column)
        }

        func line(_ column: Int, from top: CGFloat, to bottom: CGFloat, _ color: Color) {
            guard bottom > top else { return }
            context.fill(
                Path(CGRect(x: x(column) - width / 2, y: top, width: width, height: bottom - top)),
                with: .color(color)
            )
        }

        switch rail.level {
        case 0:
            guard rail.continuesBelow else { return }
            let top = BuilderMetrics.headerVertical + BuilderMetrics.root + 3
            line(1, from: top, to: size.height, rail.live && rail.fill > 0 ? done : base)
        case 1:
            guard !rail.breaksRail else { return }
            if rail.railAbove {
                line(1, from: 0, to: mid, rail.enteredDone ? done : base)
            }
            if rail.continuesBelow {
                line(1, from: mid, to: size.height, base)
                if rail.fill > 0 {
                    line(1, from: mid, to: mid + (size.height - mid) * min(1, rail.fill), done)
                }
            }
        default:
            for column in rail.passes {
                line(column, from: 0, to: size.height, column == 1 && rail.passesDone ? done : base)
            }
            let elbow = rail.level - 1
            let elbowX = x(elbow)
            let radius = BuilderMetrics.elbowRadius
            let color = elbow == 1 && rail.passesDone ? done : base
            var path = Path()
            path.move(to: CGPoint(x: elbowX, y: 0))
            path.addLine(to: CGPoint(x: elbowX, y: mid - radius))
            path.addQuadCurve(to: CGPoint(x: elbowX + radius, y: mid), control: CGPoint(x: elbowX, y: mid))
            path.addLine(to: CGPoint(x: x(rail.level) - BuilderMetrics.node(rail.level) / 2, y: mid))
            context.stroke(path, with: .color(color), style: StrokeStyle(lineWidth: width, lineJoin: .round))
            if rail.branchContinues {
                line(elbow, from: mid - radius, to: size.height, color)
            }
            if rail.continuesBelow {
                line(rail.level, from: mid, to: size.height, base)
            }
        }
    }
}

/// Wraps a builder row: the card padding, the section surface (a slice of it where every row is its own list row),
/// the rail behind the content and a hover tint on the Mac.
struct BuilderRowChrome: ViewModifier {
    let rail: BuilderRail?
    let slice: BuilderSlice?
    var tone: BuilderTone = .dark
    var vertical: CGFloat = BuilderMetrics.rowVertical(1)
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var hovered = false

    func body(content: Content) -> some View {
        content
            .padding(.horizontal, BuilderMetrics.cardPadding)
            .padding(.vertical, vertical)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background {
                if let rail {
                    BuilderRailCanvas(rail: rail, tone: tone)
                }
            }
            .background {
                if let slice {
                    BuilderSurface(slice: slice, tone: tone, highlighted: hovered)
                } else if hovered {
                    tone.hover.allowsHitTesting(false)
                }
            }
            .contentShape(Rectangle())
            .environment(\.builderRowHovered, hovered)
            .onHover { hovering in
                withAnimation(reduceMotion ? nil : .easeOut(duration: 0.12)) { hovered = hovering }
            }
    }
}
