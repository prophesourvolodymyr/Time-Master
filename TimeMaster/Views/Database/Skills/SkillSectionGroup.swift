import SwiftUI
import TimeMasterCore

// MARK: - Palette

/// The colours section groups wear. A section keeps the colour it was given (`SkillBoardSection.colorHex`); without one
/// it takes the palette colour of its position, so neighbouring groups never look alike.
enum SkillSectionPalette {
    struct Swatch: Identifiable, Equatable {
        /// `RRGGBB`, uppercase, no `#`.
        let hex: String
        /// Spoken by VoiceOver and shown as the tooltip.
        let name: String

        var id: String { hex }
    }

    /// The eight colours of `SkillColors.palette`, named.
    static let swatches: [Swatch] = zip(SkillColors.palette, ["Ice", "Violet", "Amber", "Rose", "Mint", "Coral", "Sky", "Orchid"])
        .map { Swatch(hex: $0.0, name: $0.1) }

    /// The strip of the skills outside every group: a quiet grey that belongs to no section.
    static let neutralHex = "8C8C8C"

    /// The palette colour for the section at `index`; wraps around.
    static func hex(forIndex index: Int) -> String {
        let count = swatches.count
        return swatches[((index % count) + count) % count].hex
    }

    /// `value` as `RRGGBB`, or nil when it is not a six-digit colour.
    static func usableHex(_ value: String?) -> String? {
        guard let hex = SkillColors.normalizedHex(value), hex.count == 6 else { return nil }
        return hex
    }

    /// A section's own colour when it has a usable one, else the palette colour for `index`.
    static func resolvedHex(explicit: String?, index: Int) -> String {
        usableHex(explicit) ?? hex(forIndex: index)
    }

    static func resolvedHex(for section: SkillBoardSection, index: Int) -> String {
        resolvedHex(explicit: section.colorHex, index: index)
    }

    /// The palette name of `hex` ("Ice"), nil for any other colour.
    static func name(of hex: String?) -> String? {
        guard let usable = usableHex(hex) else { return nil }
        return swatches.first { $0.hex == usable }?.name
    }
}

private struct SkillGroupTintKey: EnvironmentKey {
    static let defaultValue: String? = nil
}

extension EnvironmentValues {
    /// The colour (`RRGGBB`) of the group a view sits in when the group takes it from its picture, so the header
    /// inside wears the strip's colour.
    var skillGroupTintHex: String? {
        get { self[SkillGroupTintKey.self] }
        set { self[SkillGroupTintKey.self] = newValue }
    }
}

// MARK: - Group surface

/// A section drawn as a group: no card, only a thin line of its colour down the leading edge. While a sub-skill is
/// dragged over it, or right after the section was made, a faint wash and ring of that colour light it up. A section
/// with a picture shows it inside a slightly wider line, and the line and header take the picture's colours.
struct SkillSectionGroupSurface: ViewModifier {
    /// Line colour (`RRGGBB`); nil draws the neutral grey of the skills outside every group.
    let colorHex: String?
    var stripImageURL: URL? = nil
    var isDropTarget = false
    var isHighlighted = false
    var verticalPadding: CGFloat = SkillMetrics.s2

    static let cornerRadius: CGFloat = SkillMetrics.cardRadius
    static let stripWidth: CGFloat = 3
    static let pictureStripWidth: CGFloat = 8
    static let stripInset: CGFloat = 2
    static let pictureStripInset: CGFloat = 0
    static let stripEndInset: CGFloat = 6
    /// Where the content starts: past the line, with room to breathe.
    static let contentLeading: CGFloat = stripInset + stripWidth + SkillMetrics.s3
    static let contentTrailing: CGFloat = 0

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @StateObject private var picture = SkillStripImageModel()

    private var tintHex: String {
        (stripImageURL != nil ? picture.colors?.top : nil) ?? colorHex ?? SkillSectionPalette.neutralHex
    }

    func body(content: Content) -> some View {
        let color = Color(hex: tintHex)
        let shape = RoundedRectangle(cornerRadius: Self.cornerRadius, style: .continuous)
        let lit = isDropTarget || isHighlighted
        let animation: Animation? = reduceMotion ? nil : EverMotion.state
        content
            .environment(\.skillGroupTintHex, stripImageURL != nil ? tintHex : nil)
            .padding(.leading, Self.contentLeading)
            .padding(.trailing, Self.contentTrailing)
            .padding(.vertical, verticalPadding)
            .background {
                shape
                    .fill(color.opacity(lit ? 0.1 : 0))
                    .animation(animation, value: lit)
            }
            .overlay(alignment: .leading) {
                strip(color: color)
                    .padding(.vertical, Self.stripEndInset)
                    .padding(.leading, stripImageURL != nil ? Self.pictureStripInset : Self.stripInset)
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
            }
            .overlay {
                shape
                    .strokeBorder(color.opacity(isDropTarget ? 0.9 : 0.6), lineWidth: 1.5)
                    .opacity(lit ? 1 : 0)
                    .animation(animation, value: lit)
                    .allowsHitTesting(false)
            }
            .task(id: stripImageURL) { await picture.load(stripImageURL) }
    }

    @ViewBuilder
    private func strip(color: Color) -> some View {
        if stripImageURL != nil {
            let top = Color(hex: picture.colors?.top ?? tintHex)
            let bottom = Color(hex: picture.colors?.bottom ?? tintHex)
            ZStack {
                LinearGradient(colors: [top, bottom], startPoint: .top, endPoint: .bottom)
                if let image = picture.image {
                    Image(decorative: image, scale: 1)
                        .resizable()
                        .scaledToFill()
                }
            }
            .frame(width: Self.pictureStripWidth)
            .clipShape(Capsule(style: .continuous))
        } else {
            Capsule(style: .continuous)
                .fill(color)
                .frame(width: Self.stripWidth)
        }
    }
}

extension View {
    /// Draws this stack as one section group: a thin line of the section's colour on the leading edge, drop-target glow.
    func skillSectionGroup(
        colorHex: String?,
        stripImageURL: URL? = nil,
        isDropTarget: Bool = false,
        isHighlighted: Bool = false,
        verticalPadding: CGFloat = SkillMetrics.s2
    ) -> some View {
        modifier(
            SkillSectionGroupSurface(
                colorHex: colorHex,
                stripImageURL: stripImageURL,
                isDropTarget: isDropTarget,
                isHighlighted: isHighlighted,
                verticalPadding: verticalPadding
            )
        )
    }
}

// MARK: - Section header

/// Header of a section group, bare: a small chevron, the section's own symbol or emoji when it has one, the name and a
/// quiet count, then a menu. With `onOpen` the chevron collapses the group and the rest of the row opens it as a page;
/// without it the whole row collapses, as it does for the skills outside every group. The colour lives in the line the
/// group surface draws beside it.
struct SkillBoardSectionHeader<MenuContent: View>: View {
    let title: String
    let iconName: String?
    let iconType: SkillBoardIconType?
    /// Section colour (`RRGGBB`) for the symbol; nil = the neutral grey.
    let colorHex: String?
    let count: Int
    let isCollapsed: Bool
    let showsMenu: Bool
    let onToggle: () -> Void
    var onOpen: (() -> Void)? = nil
    @ViewBuilder let menu: () -> MenuContent

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.skillGroupTintHex) private var groupTintHex

    private var tintHex: String { groupTintHex ?? colorHex ?? SkillSectionPalette.neutralHex }

    var body: some View {
        HStack(spacing: SkillMetrics.s1) {
            if let onOpen {
                Button(action: onToggle) {
                    chevron
                        .frame(width: 24, height: SkillMetrics.touch)
                        .contentShape(Rectangle())
                }
                .buttonStyle(SkillPressButtonStyle())
                .accessibilityLabel(isCollapsed ? "Expand \(title)" : "Collapse \(title)")
                .help(isCollapsed ? "Expand" : "Collapse")
                Button(action: onOpen) {
                    HStack(spacing: SkillMetrics.s2) {
                        iconTitleAndCount
                        Spacer(minLength: SkillMetrics.s2)
                    }
                    .frame(minHeight: SkillMetrics.touch)
                    .contentShape(Rectangle())
                }
                .buttonStyle(SkillPressButtonStyle())
                .accessibilityLabel("Open \(title), \(count) \(count == 1 ? "item" : "items")")
                .accessibilityAddTraits(.isHeader)
                .help("Open \(title) as a page")
            } else {
                Button(action: onToggle) {
                    HStack(spacing: SkillMetrics.s2) {
                        chevron
                            .frame(width: 16)
                        iconTitleAndCount
                        Spacer(minLength: SkillMetrics.s2)
                    }
                    .frame(minHeight: SkillMetrics.touch)
                    .contentShape(Rectangle())
                }
                .buttonStyle(SkillPressButtonStyle())
                .accessibilityLabel("\(title), \(count) \(count == 1 ? "item" : "items")")
                .accessibilityValue(isCollapsed ? "Collapsed" : "Expanded")
                .accessibilityAddTraits(.isHeader)
            }

            if showsMenu {
                Menu {
                    menu()
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(Theme.textSecondary)
                        .frame(width: SkillMetrics.touch, height: SkillMetrics.touch)
                        .contentShape(Rectangle())
                }
                .menuIndicator(.hidden)
                .menuStyle(.button)
                .buttonStyle(SkillPressButtonStyle())
                #if os(macOS)
                .fixedSize()
                #endif
                .accessibilityLabel("\(title) section options")
                .help("Section options")
            }
        }
        .keyNavTarget(role: .primary, shape: .roundedRectangle(cornerRadius: SkillMetrics.fieldRadius), action: onOpen ?? onToggle)
    }

    private var chevron: some View {
        Image(systemName: "chevron.right")
            .font(.system(size: 10, weight: .bold))
            .foregroundStyle(Theme.textSecondary)
            .rotationEffect(.degrees(isCollapsed ? 0 : 90))
            .animation(reduceMotion ? nil : EverMotion.disclosure, value: isCollapsed)
    }

    private var iconTitleAndCount: some View {
        HStack(spacing: SkillMetrics.s2) {
            if let iconName, !iconName.isEmpty {
                SkillIconView(iconName: iconName, iconType: iconType, colorHex: tintHex, size: 15)
            }
            Text(title)
                .font(TimeMasterFont.heading())
                .foregroundStyle(Theme.textPrimary)
                .lineLimit(2)
                .multilineTextAlignment(.leading)
            Text("\(count)")
                .font(TimeMasterFont.body(15, relativeTo: .subheadline).monospacedDigit())
                .foregroundStyle(Theme.textSecondary)
                .accessibilityHidden(true)
        }
    }
}
