import SwiftUI

/// The debossed face Skillmax draws its tracks, tiles and chips with, in Tmax surfaces: a darker inner edge at the top
/// left, a lighter one at the bottom right and a hairline rim. `isLit` brightens it for press and hover.
struct SkillDebossedBackground: View {
    var cornerRadius: CGFloat
    var isLit = false

    @Environment(\.colorSchemeContrast) private var contrast

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        ZStack {
            shape.fill(LinearGradient(colors: [Theme.surface2, Theme.surface], startPoint: .topLeading, endPoint: .bottomTrailing))
            shape.strokeBorder(
                LinearGradient(
                    colors: [Color.black.opacity(0.6), Color.white.opacity(isLit ? 0.16 : 0.07)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                lineWidth: 2.5
            )
            if isLit {
                shape.fill(LinearGradient(colors: [Color.white.opacity(0.14), Color.white.opacity(0)], startPoint: .top, endPoint: .bottom))
            }
            shape.strokeBorder(contrast == .increased ? Color.white.opacity(0.5) : Color.white.opacity(0.09), lineWidth: 1)
        }
        .allowsHitTesting(false)
    }
}

/// The raised accent face of a selected segment or chip: Tmax orange with a soft light along its top.
struct SkillRaisedBackground: View {
    var cornerRadius: CGFloat
    var tint: Color = Theme.toolbarOrange
    var isLit = false

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        ZStack {
            shape.fill(LinearGradient(colors: [tint, tint.opacity(0.84)], startPoint: .top, endPoint: .bottom))
            shape.fill(LinearGradient(colors: [Color.white.opacity(isLit ? 0.34 : 0.22), Color.white.opacity(0)], startPoint: .top, endPoint: .center))
            shape.strokeBorder(Color.white.opacity(isLit ? 0.5 : 0.3), lineWidth: 1)
        }
        .shadow(color: tint.opacity(isLit ? 0.42 : 0.26), radius: 10, y: 3)
        .allowsHitTesting(false)
    }
}

extension View {
    /// The debossed tile behind a symbol (section headings, icon tiles of rows and cards).
    func skillTile(cornerRadius: CGFloat) -> some View {
        background { SkillDebossedBackground(cornerRadius: cornerRadius) }
    }
}

/// A plain tappable surface with Tmax's press feedback; a keyboard-navigation target on the Mac. Unlike
/// `EverPressButtonStyle` it does not measure itself for the floating bar, so a board of many rows stays light.
struct SkillPressButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .modifier(TimeMasterActionFeedback(isPressed: configuration.isPressed))
            .keyNavButtonSurface(.standard)
    }
}

// MARK: - Segmented track

/// Sizes of the slim segmented tracks (view mode, grouping). The Mac track is taller and its segments roomier.
enum SkillSegmentMetrics {
    #if os(macOS)
    static let trackHeight: CGFloat = 40
    static let labelInset: CGFloat = SkillMetrics.s4
    static let touchOutset: CGFloat = 0
    #else
    static let trackHeight: CGFloat = 36
    static let labelInset: CGFloat = SkillMetrics.s2
    /// Extra touch area above and below a segment so it still answers to 44 pt without taking more room.
    static let touchOutset: CGFloat = max(0, (SkillMetrics.touch - trackHeight) / 2)
    #endif
    /// Gap between the track's rim and the raised selection.
    static let inset: CGFloat = 3
    static let pillHeight: CGFloat = trackHeight - inset * 2
}

/// A segment of a slim debossed track: a quiet glyph when idle, a raised orange pill when selected. Segments that
/// share one `namespace` slide the pill between them.
struct SkillSegmentButtonStyle: ButtonStyle {
    var isSelected: Bool
    var namespace: Namespace.ID? = nil
    var fillsWidth = true

    func makeBody(configuration: Configuration) -> some View {
        SkillSegmentButtonBody(configuration: configuration, isSelected: isSelected, namespace: namespace, fillsWidth: fillsWidth)
    }
}

private struct SkillSegmentButtonBody: View {
    let configuration: ButtonStyleConfiguration
    let isSelected: Bool
    let namespace: Namespace.ID?
    let fillsWidth: Bool

    @Environment(\.isFocused) private var isFocused
    @State private var isHovering = false

    var body: some View {
        let radius = SkillSegmentMetrics.pillHeight / 2
        let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)
        configuration.label
            .foregroundStyle(foreground)
            .padding(.horizontal, SkillSegmentMetrics.labelInset)
            .frame(
                minWidth: SkillMetrics.touch - SkillSegmentMetrics.inset * 2,
                maxWidth: fillsWidth ? .infinity : nil,
                minHeight: SkillSegmentMetrics.pillHeight
            )
            .background { selection(radius: radius) }
            .keyNavButtonSurface(.capsule)
            .overlay {
                if isFocused {
                    shape.strokeBorder(Theme.textPrimary.opacity(0.75), lineWidth: 2)
                        .allowsHitTesting(false)
                }
            }
            .padding(SkillSegmentMetrics.inset)
            .padding(.vertical, SkillSegmentMetrics.touchOutset)
            .contentShape(Rectangle())
            .padding(.vertical, -SkillSegmentMetrics.touchOutset)
            .modifier(TimeMasterActionFeedback(isPressed: configuration.isPressed))
            .onHover { isHovering = $0 }
    }

    private var foreground: Color {
        if isSelected { return Theme.background }
        return isHovering || configuration.isPressed ? Theme.textPrimary : Theme.textSecondary
    }

    @ViewBuilder
    private func selection(radius: CGFloat) -> some View {
        if isSelected {
            if let namespace {
                SkillRaisedBackground(cornerRadius: radius, isLit: configuration.isPressed)
                    .matchedGeometryEffect(id: "selection", in: namespace)
            } else {
                SkillRaisedBackground(cornerRadius: radius, isLit: configuration.isPressed)
            }
        }
    }
}

extension View {
    /// The debossed track under a row of `SkillSegmentButtonStyle` segments.
    func skillSegmentTrack() -> some View {
        background { SkillDebossedBackground(cornerRadius: SkillSegmentMetrics.trackHeight / 2) }
    }
}

// MARK: - Choice chips

/// A filter chip: a debossed pill, or the raised orange one when it is the chosen filter.
struct SkillSelectionButtonStyle: ButtonStyle {
    var isSelected = false

    func makeBody(configuration: Configuration) -> some View {
        SkillSelectionButtonBody(configuration: configuration, isSelected: isSelected)
    }
}

private struct SkillSelectionButtonBody: View {
    let configuration: ButtonStyleConfiguration
    let isSelected: Bool

    @Environment(\.isFocused) private var isFocused

    var body: some View {
        let radius = Theme.controlCornerRadius
        let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)
        configuration.label
            .font(TimeMasterFont.rowTitle())
            .foregroundStyle(isSelected ? Theme.background : Theme.textPrimary)
            .padding(.horizontal, 14)
            .frame(minWidth: SkillMetrics.touch, minHeight: SkillMetrics.touch)
            .background {
                if isSelected {
                    SkillRaisedBackground(cornerRadius: radius, isLit: configuration.isPressed)
                } else {
                    SkillDebossedBackground(cornerRadius: radius, isLit: configuration.isPressed)
                }
            }
            .overlay {
                if isFocused {
                    shape.strokeBorder(Color.white.opacity(0.75), lineWidth: 2)
                        .allowsHitTesting(false)
                }
            }
            .contentShape(shape)
            .modifier(TimeMasterActionFeedback(isPressed: configuration.isPressed))
            .keyNavButtonSurface(.roundedRectangle(cornerRadius: radius))
    }
}
