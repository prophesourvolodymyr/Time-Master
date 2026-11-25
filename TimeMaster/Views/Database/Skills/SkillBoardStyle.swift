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
/// share one `namespace` and `matchID` slide the pill between them; without a namespace the pill fills and empties in
/// place.
struct SkillSegmentButtonStyle: ButtonStyle {
    var isSelected: Bool
    var namespace: Namespace.ID? = nil
    var fillsWidth = true
    var matchID: AnyHashable = "selection"
    var isGrabbed = false
    var pillOffset: CGFloat = 0

    func makeBody(configuration: Configuration) -> some View {
        SkillSegmentButtonBody(
            configuration: configuration,
            isSelected: isSelected,
            namespace: namespace,
            fillsWidth: fillsWidth,
            matchID: matchID,
            isGrabbed: isGrabbed,
            pillOffset: pillOffset
        )
    }
}

private struct SkillSegmentButtonBody: View {
    let configuration: ButtonStyleConfiguration
    let isSelected: Bool
    let namespace: Namespace.ID?
    let fillsWidth: Bool
    let matchID: AnyHashable
    let isGrabbed: Bool
    let pillOffset: CGFloat

    @State private var isHovering = false

    private var isLit: Bool { configuration.isPressed || isGrabbed }

    var body: some View {
        let radius = SkillSegmentMetrics.pillHeight / 2
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
            .padding(SkillSegmentMetrics.inset)
            .padding(.vertical, SkillSegmentMetrics.touchOutset)
            .contentShape(Rectangle())
            .padding(.vertical, -SkillSegmentMetrics.touchOutset)
            .modifier(TimeMasterActionFeedback(isPressed: isLit, cornerRadius: SkillSegmentMetrics.pillHeight / 2 + SkillSegmentMetrics.inset, tracks: false))
            .onHover { isHovering = $0 }
    }

    private var foreground: Color {
        if isSelected { return Theme.background }
        return isHovering || isLit ? Theme.textPrimary : Theme.textSecondary
    }

    @ViewBuilder
    private func selection(radius: CGFloat) -> some View {
        if isSelected {
            if let namespace {
                SkillRaisedBackground(cornerRadius: radius, isLit: isLit)
                    .matchedGeometryEffect(id: matchID, in: namespace)
                    .offset(x: pillOffset)
            } else {
                SkillRaisedBackground(cornerRadius: radius, isLit: isLit)
                    .transition(.opacity.combined(with: .scale(scale: 0.9)))
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
