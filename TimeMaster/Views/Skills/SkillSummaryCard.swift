import SwiftUI
import TimeMasterCore

/// A skill as the Skills page shows it, in the app's card language (the Workouts page's cards): its icon, its title,
/// how many of its sub-skills are done and, once it is under way, its status. Tapping it opens the skill on the
/// surrounding navigation stack (`DatabaseNavigationState`); it is a button of its own, so give it no link around it.
/// `.row` is the list-mode row.
struct SkillSummaryCard: View {
    enum Style {
        case tile, row
    }

    static let tileCornerRadius: CGFloat = 22
    static let rowCornerRadius: CGFloat = 20
    /// Height of a tile at the default text size: the cover, the icon over its corner, two title lines (always kept, so
    /// every tile in a grid row is as tall as the others), the status chip and the progress strip.
    static let tileMinimumHeight: CGFloat = 220
    static let coverAspect: CGFloat = 1.75
    static let tileIconSize: CGFloat = 56
    static let rowIconSize: CGFloat = 48
    static let rowMinimumHeight: CGFloat = 72

    let page: ExercisePage
    let style: Style
    private let knownProgress: SkillProgress?
    private let knownCategory: SkillCategory?

    @EnvironmentObject private var store: DatabaseStore
    @EnvironmentObject private var navigationState: DatabaseNavigationState
    @ScaledMetric(relativeTo: .body) private var tileHeight = SkillSummaryCard.tileMinimumHeight
    @ScaledMetric(relativeTo: .body) private var rowHeight = SkillSummaryCard.rowMinimumHeight

    init(page: ExercisePage, style: Style = .tile) {
        self.page = page
        self.style = style
        knownProgress = nil
        knownCategory = nil
    }

    /// For lists that already read every skill's progress (and, for the Skills page, its category) in one pass.
    init(page: ExercisePage, style: Style, progress: SkillProgress, category: SkillCategory? = nil) {
        self.page = page
        self.style = style
        knownProgress = progress
        knownCategory = category
    }

    private var status: SkillStatus { page.manifest.skillStatus ?? .notStarted }
    private var cornerRadius: CGFloat { style == .tile ? Self.tileCornerRadius : Self.rowCornerRadius }

    var body: some View {
        let progress = knownProgress ?? store.skillProgress(of: page)
        let category = knownCategory ?? SkillCategory.of(page, in: store.index)
        Button(action: open) {
            switch style {
            case .tile: tile(progress, category: category)
            case .row: row(progress, category: category)
            }
        }
        .buttonStyle(SkillCardButtonStyle(cornerRadius: cornerRadius))
        .keyNavTarget(id: page.manifest.id, role: .primary, shape: .roundedRectangle(cornerRadius: cornerRadius), action: open)
        .accessibilityLabel(page.title)
        .accessibilityValue(progress.isEmpty ? status.title : "\(status.title), \(progress.summary)")
        .accessibilityHint(page.isTutorial ? "Opens this tutorial" : "Opens this skill")
    }

    private func tile(_ progress: SkillProgress, category: SkillCategory) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            tileCover(category: category)
                .overlay(alignment: .bottomLeading) {
                    tileIcon(category: category)
                        .padding(.leading, 12)
                        .offset(y: Self.tileIconSize / 2)
                }
            VStack(alignment: .leading, spacing: 0) {
                title(font: TimeMasterFont.black(17, relativeTo: .headline), reservesSpace: true)
                if status != .notStarted {
                    statusChip
                        .padding(.top, 7)
                }
                if !progress.isEmpty {
                    Spacer(minLength: 10)
                    progressStrip(progress)
                }
            }
            .padding(.horizontal, 14)
            .padding(.top, Self.tileIconSize / 2 + 12)
            .padding(.bottom, 14)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .frame(maxWidth: .infinity, minHeight: tileHeight, alignment: .topLeading)
        .clipShape(RoundedRectangle(cornerRadius: Self.tileCornerRadius, style: .continuous))
    }

    private func tileCover(category: SkillCategory) -> some View {
        Color.clear
            .aspectRatio(Self.coverAspect, contentMode: .fit)
            .overlay { coverArt(category: category) }
            .clipped()
            .accessibilityHidden(true)
    }

    @ViewBuilder
    private func coverArt(category: SkillCategory) -> some View {
        if let url = page.galleryCoverURL {
            GeometryReader { proxy in
                AsyncCoverImage(url: url, height: proxy.size.height, contentMode: .fill, overlayGradient: false)
                    .frame(width: proxy.size.width, height: proxy.size.height)
                    .clipped()
            }
        } else {
            ZStack {
                LinearGradient(
                    colors: [Theme.toolbarOrange.opacity(0.2), Theme.surface2],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                placeholderGlyph(category: category)
                    .opacity(0.3)
            }
        }
    }

    @ViewBuilder
    private func placeholderGlyph(category: SkillCategory) -> some View {
        if let name = page.manifest.iconName, !name.isEmpty {
            SkillIconView(iconName: name, iconType: page.manifest.iconType ?? .emoji, size: 44)
        } else {
            Image(systemName: category.systemImage)
                .font(.system(size: 40, weight: .semibold))
                .foregroundStyle(Theme.toolbarOrange)
        }
    }

    private func tileIcon(category: SkillCategory) -> some View {
        let size = Self.tileIconSize
        return SkillCardIcon(page: page, category: category, size: size)
            .padding(3)
            .background(Theme.surface, in: RoundedRectangle(cornerRadius: size * 0.28 + 3, style: .continuous))
    }

    private func row(_ progress: SkillProgress, category: SkillCategory) -> some View {
        HStack(spacing: 12) {
            SkillCardIcon(page: page, category: category, size: Self.rowIconSize)
            VStack(alignment: .leading, spacing: 5) {
                title(font: TimeMasterFont.label(), reservesSpace: false)
                if !progress.isEmpty || status != .notStarted {
                    HStack(spacing: 8) {
                        if !progress.isEmpty {
                            progressLine(progress)
                        }
                        if status != .notStarted {
                            statusChip
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            TimeMasterDisclosureIndicator()
        }
        .padding(12)
        .frame(maxWidth: .infinity, minHeight: rowHeight, alignment: .leading)
    }

    private func title(font: Font, reservesSpace: Bool) -> some View {
        Text(page.title)
            .font(font)
            .foregroundStyle(Theme.textPrimary.opacity(status.titleOpacity))
            .lineLimit(2, reservesSpace: reservesSpace)
            .multilineTextAlignment(.leading)
    }

    /// "3 of 12 done" with its orange symbol.
    private func progressLine(_ progress: SkillProgress) -> some View {
        HStack(spacing: 6) {
            Image(systemName: progress.total > 0 ? "checkmark.circle.fill" : "xmark.circle")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(Theme.toolbarOrange)
            Text(progress.summary)
                .font(TimeMasterFont.black(13, relativeTo: .caption))
                .monospacedDigit()
                .foregroundStyle(Theme.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
    }

    /// The progress line centred on a strip, like the Workouts cards' metric strip, filled in faint orange as far as
    /// the skill is done. The fill is scaled, not measured.
    private func progressStrip(_ progress: SkillProgress) -> some View {
        progressLine(progress)
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 8)
            .padding(.vertical, 8)
            .background(alignment: .leading) {
                Rectangle()
                    .fill(Theme.toolbarOrange.opacity(0.16))
                    .scaleEffect(x: CGFloat(min(1, max(0, progress.fraction))), y: 1, anchor: .leading)
            }
            .background(Theme.surface2.opacity(0.75))
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    /// The status, slim, once the skill is under way; a skill not started yet shows none.
    private var statusChip: some View {
        HStack(spacing: 4) {
            Image(systemName: status.symbolName)
                .font(.system(size: 9, weight: .bold))
            Text(status.title)
                .lineLimit(1)
        }
        .font(TimeMasterFont.black(11, relativeTo: .caption2))
        .foregroundStyle(status.color)
        .padding(.horizontal, 7)
        .padding(.vertical, 3)
        .background(status.tint, in: Capsule())
        .fixedSize()
    }

    private func open() {
        EverHaptic.selection()
        navigationState.path.append(DatabasePageRoute(pageID: page.manifest.id))
    }
}

/// Button style of the Skills page cards: the app's flat card surface, its rim lit orange while pressed or pointed at,
/// and the app's press feedback. The card registers its own keyboard target (with its id and action), and a card in a
/// scroll view never counts for the navigation clearance, so the style adds neither.
struct SkillCardButtonStyle: ButtonStyle {
    var cornerRadius: CGFloat = SkillSummaryCard.tileCornerRadius

    func makeBody(configuration: Configuration) -> some View {
        SkillCardButtonBody(configuration: configuration, cornerRadius: cornerRadius)
    }
}

private struct SkillCardButtonBody: View {
    let configuration: ButtonStyleConfiguration
    let cornerRadius: CGFloat

    @State private var isHovering = false

    var body: some View {
        configuration.label
            .modifier(TimeMasterCardSurface(
                cornerRadius: cornerRadius,
                emphasized: configuration.isPressed || isHovering,
                flat: true
            ))
            .contentShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .modifier(TimeMasterActionFeedback(isPressed: configuration.isPressed))
            .animation(EverMotion.opacityOnly, value: isHovering)
            .onHover { isHovering = $0 }
    }
}

/// Press feedback and the keyboard ring for the Skills page's other buttons in its scroll view, without the
/// navigation clearance probe `TimeMasterCardButtonStyle` carries: a control in a scroll view never counts for it.
struct SkillsPressStyle: ButtonStyle {
    var cornerRadius: CGFloat = 20

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .modifier(TimeMasterActionFeedback(isPressed: configuration.isPressed))
            .keyNavButtonSurface(.roundedRectangle(cornerRadius: cornerRadius))
    }
}
