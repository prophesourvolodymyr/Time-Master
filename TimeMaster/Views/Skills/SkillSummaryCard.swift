import SwiftUI
import TimeMasterCore

/// A skill as the Skills page shows it: its icon, a ring of the sub-skills done, the title, "22 of 113 done" and its
/// status, on a card pressed into the page. Tapping it opens the skill on the surrounding navigation stack
/// (`DatabaseNavigationState`); it is a button of its own, so give it no link around it. `.row` is the list-mode row.
struct SkillSummaryCard: View {
    enum Style {
        case tile, row
    }

    static let tileCornerRadius: CGFloat = 22
    static let rowCornerRadius: CGFloat = 20
    /// Height of a tile at the default text size (the title always keeps two lines, so every tile in a grid row is
    /// as tall as the others); the Skills page sizes its "New skill" tile with it too.
    static let tileMinimumHeight: CGFloat = 184
    static let rowMinimumHeight: CGFloat = 72

    let page: ExercisePage
    let style: Style
    private let knownProgress: SkillProgress?

    @EnvironmentObject private var store: DatabaseStore
    @EnvironmentObject private var navigationState: DatabaseNavigationState
    @ScaledMetric(relativeTo: .body) private var tileHeight = SkillSummaryCard.tileMinimumHeight
    @ScaledMetric(relativeTo: .body) private var rowHeight = SkillSummaryCard.rowMinimumHeight

    init(page: ExercisePage, style: Style = .tile) {
        self.page = page
        self.style = style
        knownProgress = nil
    }

    /// For lists that already read every skill's progress in one pass over the library.
    init(page: ExercisePage, style: Style, progress: SkillProgress) {
        self.page = page
        self.style = style
        knownProgress = progress
    }

    private var status: SkillStatus { page.manifest.skillStatus ?? .notStarted }
    private var cornerRadius: CGFloat { style == .tile ? Self.tileCornerRadius : Self.rowCornerRadius }

    var body: some View {
        let progress = knownProgress ?? store.skillProgress(of: page)
        Button(action: open) {
            switch style {
            case .tile: tile(progress)
            case .row: row(progress)
            }
        }
        .buttonStyle(SkillCardButtonStyle(cornerRadius: cornerRadius, depth: style == .tile ? 1 : 0.55))
        .keyNavRole(.excluded)
        .keyNavTarget(id: page.manifest.id, role: .primary, shape: .roundedRectangle(cornerRadius: cornerRadius), action: open)
        .accessibilityLabel(page.title)
        .accessibilityValue("\(status.title), \(progress.summary)")
        .accessibilityHint(page.isTutorial ? "Opens this tutorial" : "Opens this skill")
    }

    private func tile(_ progress: SkillProgress) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top, spacing: 8) {
                SkillPageIconTile(page: page, size: 44)
                Spacer(minLength: 0)
                SkillProgressRing(fraction: progress.fraction, lineWidth: 4)
                    .frame(width: 32, height: 32)
            }
            Spacer(minLength: 12)
            VStack(alignment: .leading, spacing: 4) {
                Text(page.title)
                    .font(TimeMasterFont.heading())
                    .foregroundStyle(Theme.textPrimary.opacity(status.titleOpacity))
                    .lineLimit(2, reservesSpace: true)
                    .multilineTextAlignment(.leading)
                Text(progress.summary)
                    .font(TimeMasterFont.caption())
                    .foregroundStyle(Theme.textSecondary)
                    .lineLimit(1)
                statusPill
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, minHeight: tileHeight, alignment: .topLeading)
    }

    private func row(_ progress: SkillProgress) -> some View {
        HStack(spacing: 12) {
            SkillPageIconTile(page: page, size: 36)
                .frame(width: 48, height: 48)
                .background(Color.black.opacity(0.22), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .strokeBorder(Theme.separator, lineWidth: 1)
                }
            VStack(alignment: .leading, spacing: 3) {
                Text(page.title)
                    .font(TimeMasterFont.label())
                    .foregroundStyle(Theme.textPrimary.opacity(status.titleOpacity))
                    .lineLimit(1)
                HStack(spacing: 5) {
                    Image(systemName: status.symbolName)
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(status.color)
                    Text("\(status.title) · \(progress.summary)")
                        .lineLimit(1)
                }
                .font(TimeMasterFont.caption())
                .foregroundStyle(Theme.textSecondary)
            }
            Spacer(minLength: 8)
            SkillProgressRing(fraction: progress.fraction, lineWidth: 3.5)
                .frame(width: 28, height: 28)
        }
        .padding(.leading, 12)
        .padding(.trailing, 16)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, minHeight: rowHeight, alignment: .leading)
    }

    private var statusPill: some View {
        HStack(spacing: 5) {
            Image(systemName: status.symbolName)
                .font(.system(size: 10, weight: .bold))
            Text(status.title)
                .lineLimit(1)
        }
        .font(TimeMasterFont.black(11, relativeTo: .caption2))
        .foregroundStyle(status.color)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(status.color.opacity(0.14), in: Capsule())
    }

    private func open() {
        EverHaptic.selection()
        navigationState.path.append(DatabasePageRoute(pageID: page.manifest.id))
    }
}

/// Button style of the Skills page cards: the pressed-in card surface, lit while pressed or hovered, the focus ring,
/// press feedback, the navigation clearance probe and a keyboard target on the visible face.
struct SkillCardButtonStyle: ButtonStyle {
    var cornerRadius: CGFloat = SkillSummaryCard.tileCornerRadius
    var depth: CGFloat = 1

    func makeBody(configuration: Configuration) -> some View {
        SkillCardButtonBody(configuration: configuration, cornerRadius: cornerRadius, depth: depth)
    }
}

private struct SkillCardButtonBody: View {
    let configuration: ButtonStyleConfiguration
    let cornerRadius: CGFloat
    let depth: CGFloat

    @State private var isHovering = false
    @Environment(\.isFocused) private var isFocused

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        configuration.label
            .background(SkillCardSurface(cornerRadius: cornerRadius, lit: configuration.isPressed || isHovering ? 1 : 0, depth: depth))
            .clipShape(shape)
            .overlay {
                if isFocused {
                    shape.strokeBorder(Color.white.opacity(0.75), lineWidth: 2)
                        .allowsHitTesting(false)
                }
            }
            .contentShape(shape)
            .background(SlotNavigationContentClearanceReader())
            .modifier(TimeMasterActionFeedback(isPressed: configuration.isPressed))
            .onHover { isHovering = $0 }
            .keyNavButtonSurface(.roundedRectangle(cornerRadius: cornerRadius))
    }
}

/// The card surface: Tmax's dark card pressed into the page (shade inside the top-left edge, light inside the
/// bottom-right one, a hairline rim). `lit` (0…1) fades in an orange wash and outline.
struct SkillCardSurface: View {
    let cornerRadius: CGFloat
    var lit: Double = 0
    var depth: CGFloat = 1

    @Environment(\.colorSchemeContrast) private var contrast
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        ZStack {
            shape.fill(
                LinearGradient(colors: [Theme.surface2, Theme.surface], startPoint: .topLeading, endPoint: .bottomTrailing)
            )
            shape.stroke(Color.black.opacity(0.62), lineWidth: 12 * depth)
                .blur(radius: 9 * depth)
                .offset(x: 5 * depth, y: 5 * depth)
                .clipShape(shape)
            shape.stroke(Color.white.opacity(0.05 + 0.03 * lit), lineWidth: 10 * depth)
                .blur(radius: 8 * depth)
                .offset(x: -4 * depth, y: -4 * depth)
                .clipShape(shape)
            shape.fill(
                LinearGradient(
                    colors: [Theme.toolbarOrange.opacity(0.18 * lit), Theme.toolbarOrange.opacity(0.03 * lit), .clear],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            shape.strokeBorder(contrast == .increased ? Color.white.opacity(0.5) : Color.white.opacity(0.1), lineWidth: 1.2)
            shape.strokeBorder(Theme.toolbarOrange.opacity(0.6 * lit), lineWidth: 2)
                .blur(radius: 1.2 * lit)
        }
        .animation(reduceMotion ? nil : .easeOut(duration: 0.15), value: lit)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}
