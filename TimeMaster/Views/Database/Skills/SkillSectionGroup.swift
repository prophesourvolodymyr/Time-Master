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

/// A section drawn as a group: one rounded card with a colour strip down its leading edge, tinted with that colour.
/// While a sub-skill is dragged over it, or right after the section was made, the whole card lights up. A section with
/// a picture shows it inside a wider strip, and the strip, card and header take the picture's colours.
struct SkillSectionGroupSurface: ViewModifier {
    /// Strip colour (`RRGGBB`); nil draws the neutral grey of the skills outside every group.
    let colorHex: String?
    var stripImageURL: URL? = nil
    var isDropTarget = false
    var isHighlighted = false
    var verticalPadding: CGFloat = SkillMetrics.s2

    static let cornerRadius: CGFloat = SkillMetrics.cardRadius
    static let stripWidth: CGFloat = 5
    static let pictureStripWidth: CGFloat = 12
    static let stripInset: CGFloat = 9
    static let pictureStripInset: CGFloat = 6
    static let stripEndInset: CGFloat = 11
    /// Where the content starts: past the strip, with room to breathe.
    static let contentLeading: CGFloat = stripInset + stripWidth + SkillMetrics.s3
    static let contentTrailing: CGFloat = SkillMetrics.s3

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
                    .fill(
                        LinearGradient(
                            colors: [color.opacity(lit ? 0.24 : 0.10), color.opacity(lit ? 0.12 : 0.03)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .animation(animation, value: lit)
            }
            .modifier(TimeMasterCardSurface(cornerRadius: Self.cornerRadius, accent: color, flat: true))
            .overlay(alignment: .leading) {
                strip(color: color)
                    .padding(.vertical, Self.stripEndInset)
                    .padding(.leading, stripImageURL != nil ? Self.pictureStripInset : Self.stripInset)
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
            }
            .overlay {
                shape
                    .strokeBorder(color.opacity(isDropTarget ? 0.95 : 0.7), lineWidth: 2)
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
            .overlay(Capsule(style: .continuous).strokeBorder(Color.white.opacity(0.18), lineWidth: 1))
            .shadow(color: color.opacity(0.4), radius: 4)
        } else {
            Capsule(style: .continuous)
                .fill(color)
                .frame(width: Self.stripWidth)
                .shadow(color: color.opacity(0.4), radius: 4)
        }
    }
}

extension View {
    /// Draws this stack as one section group: rounded card, colour strip on the leading edge, drop-target glow.
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

/// Header of a section group: collapse chevron, icon in the section colour, name, count pill and a menu. With
/// `onOpen` the chevron collapses the group and the rest of the row opens it as a page; without it the whole row
/// collapses, as it does for the skills outside every group.
struct SkillBoardSectionHeader<MenuContent: View>: View {
    let title: String
    let iconName: String?
    let iconType: SkillBoardIconType?
    /// Section colour (`RRGGBB`) for the icon and the count; nil = the neutral grey.
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
                        .frame(width: 28, height: SkillMetrics.row)
                        .contentShape(Rectangle())
                }
                .buttonStyle(SkillPressButtonStyle())
                .accessibilityLabel(isCollapsed ? "Expand \(title)" : "Collapse \(title)")
                .help(isCollapsed ? "Expand" : "Collapse")
                Button(action: onOpen) {
                    HStack(spacing: SkillMetrics.s3) {
                        iconAndTitle
                        Spacer(minLength: SkillMetrics.s2)
                        countPill
                    }
                    .frame(minHeight: SkillMetrics.row)
                    .contentShape(Rectangle())
                }
                .buttonStyle(SkillPressButtonStyle())
                .accessibilityLabel("Open \(title), \(count) \(count == 1 ? "item" : "items")")
                .accessibilityAddTraits(.isHeader)
                .help("Open \(title) as a page")
            } else {
                Button(action: onToggle) {
                    HStack(spacing: SkillMetrics.s3) {
                        chevron
                            .frame(width: 16)
                        iconAndTitle
                        Spacer(minLength: SkillMetrics.s2)
                        countPill
                    }
                    .frame(minHeight: SkillMetrics.row)
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
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(Theme.textSecondary)
            .rotationEffect(.degrees(isCollapsed ? 0 : 90))
            .animation(reduceMotion ? nil : EverMotion.disclosure, value: isCollapsed)
    }

    private var iconAndTitle: some View {
        HStack(spacing: SkillMetrics.s3) {
            SkillIconView(
                iconName: iconName ?? "square.grid.2x2",
                iconType: iconName == nil ? SkillBoardIconType.system : iconType,
                colorHex: tintHex,
                size: 20
            )
            .frame(width: 28)
            Text(title)
                .font(TimeMasterFont.heading())
                .foregroundStyle(Theme.textPrimary)
                .lineLimit(2)
                .multilineTextAlignment(.leading)
        }
    }

    private var countPill: some View {
        let tint = Color(hex: tintHex)
        return Text("\(count)")
            .font(TimeMasterFont.black(13, relativeTo: .footnote).monospacedDigit())
            .foregroundStyle(Theme.textPrimary)
            .padding(.horizontal, SkillMetrics.s2)
            .frame(minWidth: 28, minHeight: 26)
            .background(Capsule(style: .continuous).fill(tint.opacity(0.18)))
            .overlay(Capsule(style: .continuous).strokeBorder(tint.opacity(0.4), lineWidth: 1))
            .accessibilityHidden(true)
    }
}

// MARK: - Page section heading

/// The title row of one section of a skill page (Skills, Exercises & notes, …): a debossed tile with the section's
/// glyph, the title and, when there is something to count, the count.
struct SkillSectionHeading: View {
    let symbol: String
    let title: String
    var count: Int?

    var body: some View {
        HStack(spacing: SkillMetrics.s2) {
            SkillSectionIcon(symbol: symbol)
            Text(title)
                .font(TimeMasterFont.sectionTitle())
                .foregroundStyle(Theme.textPrimary)
                .lineLimit(1)
            if let count, count > 0 {
                Text("\(count)")
                    .font(TimeMasterFont.technical())
                    .foregroundStyle(Theme.textSecondary)
            }
            Spacer(minLength: 0)
        }
        .frame(minHeight: SkillMetrics.touch)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isHeader)
    }
}

/// The small debossed tile with an orange glyph that opens a section heading. Decorative.
struct SkillSectionIcon: View {
    let symbol: String

    var body: some View {
        Image(systemName: symbol)
            .font(.system(size: Self.glyphSize, weight: .semibold))
            .foregroundStyle(Theme.toolbarOrange)
            .frame(width: Self.side, height: Self.side)
            .skillTile(cornerRadius: Self.side * 0.32)
            .accessibilityHidden(true)
    }

    private static var side: CGFloat {
        #if os(macOS)
        return 32
        #else
        return 30
        #endif
    }

    private static var glyphSize: CGFloat {
        #if os(macOS)
        return 16
        #else
        return 15
        #endif
    }
}
