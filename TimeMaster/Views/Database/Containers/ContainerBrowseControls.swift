import SwiftUI
import TimeMasterCore

// MARK: - Search field

/// The search field of a container: filters as you type; the clear button (or Escape on the Mac) empties it.
struct ContainerSearchField: View {
    @Binding var text: String
    let prompt: String
    var isFocused: FocusState<Bool>.Binding

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 16, style: .continuous)
        let isActive = isFocused.wrappedValue || !text.isEmpty
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(isActive ? Theme.toolbarOrange : Theme.textSecondary)
                .accessibilityHidden(true)
            TextField(prompt, text: $text)
                .textFieldStyle(.plain)
                .font(TimeMasterFont.body(16))
                .foregroundStyle(Theme.textPrimary)
                .autocorrectionDisabled()
                .submitLabel(.search)
                .focused(isFocused)
                .onSubmit { isFocused.wrappedValue = false }
                .accessibilityLabel(prompt)
            #if os(iOS)
                .textInputAutocapitalization(.never)
            #else
                .onExitCommand {
                    if text.isEmpty {
                        isFocused.wrappedValue = false
                    } else {
                        text = ""
                    }
                }
            #endif
            if !text.isEmpty {
                Button {
                    text = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(Theme.textSecondary)
                        .frame(minWidth: 44, minHeight: 44)
                        .contentShape(Rectangle())
                }
                .keyNavPlainButtonStyle(shape: .circle)
                .accessibilityLabel("Clear search")
                .transition(.opacity)
            }
        }
        .padding(.leading, 14)
        .padding(.trailing, text.isEmpty ? 14 : 2)
        .frame(minHeight: 48)
        .background(shape.fill(Theme.surface))
        .overlay {
            shape.strokeBorder(isFocused.wrappedValue ? Theme.toolbarOrange.opacity(0.6) : Theme.separator, lineWidth: 1)
                .allowsHitTesting(false)
        }
        .animation(reduceMotion ? nil : .easeOut(duration: 0.15), value: text.isEmpty)
        .animation(reduceMotion ? nil : .easeOut(duration: 0.15), value: isFocused.wrappedValue)
    }
}

// MARK: - Segmented track

/// Sizes of the slim segmented tracks of a container (its tabs, the layout switch). The Mac track is taller and its
/// segments roomier; the phone keeps a 44 pt touch area above and below a slimmer track.
enum ContainerSegmentMetrics {
    #if os(macOS)
    static let trackHeight: CGFloat = 40
    static let labelInset: CGFloat = 16
    static let touchOutset: CGFloat = 0
    #else
    static let trackHeight: CGFloat = 36
    static let labelInset: CGFloat = 8
    static let touchOutset: CGFloat = 4
    #endif
    /// Gap between the track's rim and the raised selection.
    static let inset: CGFloat = 3
    static let pillHeight: CGFloat = trackHeight - inset * 2
}

/// A segment of a slim track pressed into the page: a quiet label when idle, a raised orange pill when selected.
/// Give every segment of one track the same namespace and the pill slides between them.
struct ContainerSegmentButtonStyle: ButtonStyle {
    var isSelected: Bool
    var namespace: Namespace.ID? = nil
    var fillsWidth = true

    func makeBody(configuration: Configuration) -> some View {
        ContainerSegmentButtonBody(
            configuration: configuration,
            isSelected: isSelected,
            namespace: namespace,
            fillsWidth: fillsWidth
        )
    }
}

private struct ContainerSegmentButtonBody: View {
    let configuration: ButtonStyleConfiguration
    let isSelected: Bool
    let namespace: Namespace.ID?
    let fillsWidth: Bool

    @Environment(\.isFocused) private var isFocused
    @State private var isHovering = false

    var body: some View {
        let shape = Capsule(style: .continuous)
        configuration.label
            .foregroundStyle(foreground)
            .padding(.horizontal, ContainerSegmentMetrics.labelInset)
            .frame(
                minWidth: 44 - ContainerSegmentMetrics.inset * 2,
                maxWidth: fillsWidth ? .infinity : nil,
                minHeight: ContainerSegmentMetrics.pillHeight
            )
            .background { selection }
            .keyNavButtonSurface(.capsule)
            .overlay {
                if isFocused {
                    shape.strokeBorder(Theme.textPrimary.opacity(0.75), lineWidth: 2)
                        .allowsHitTesting(false)
                }
            }
            .padding(ContainerSegmentMetrics.inset)
            .padding(.vertical, ContainerSegmentMetrics.touchOutset)
            .contentShape(Rectangle())
            .padding(.vertical, -ContainerSegmentMetrics.touchOutset)
            .background(SlotNavigationContentClearanceReader())
            .modifier(TimeMasterActionFeedback(isPressed: configuration.isPressed))
            .onHover { isHovering = $0 }
    }

    private var foreground: Color {
        if isSelected { return EverColor.onAccent }
        return isHovering || configuration.isPressed ? Theme.textPrimary : EverColor.textSecondary
    }

    @ViewBuilder
    private var selection: some View {
        if isSelected {
            if let namespace {
                pill.matchedGeometryEffect(id: "selection", in: namespace)
            } else {
                pill
            }
        }
    }

    private var pill: some View {
        let shape = Capsule(style: .continuous)
        return shape
            .fill(
                LinearGradient(
                    colors: [Theme.toolbarOrange.opacity(0.88), Theme.toolbarOrange],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .overlay { shape.strokeBorder(Color.white.opacity(0.3), lineWidth: 1) }
            .shadow(color: Theme.toolbarOrange.opacity(configuration.isPressed ? 0.42 : 0.26), radius: 10, y: 3)
    }
}

extension View {
    /// The track pressed into the page under a row of `ContainerSegmentButtonStyle` segments.
    func containerSegmentTrack() -> some View {
        background { ContainerTrackSurface() }
    }
}

/// A capsule pressed into the page: the card surface with a shade inside its top-left rim and a hairline edge.
private struct ContainerTrackSurface: View {
    @Environment(\.colorSchemeContrast) private var contrast

    var body: some View {
        let shape = Capsule(style: .continuous)
        ZStack {
            shape.fill(Theme.surface)
            shape.stroke(Color.black.opacity(0.6), lineWidth: 6)
                .blur(radius: 4)
                .offset(x: 2, y: 2)
                .clipShape(shape)
            shape.strokeBorder(contrast == .increased ? Color.white.opacity(0.45) : Color.white.opacity(0.08), lineWidth: 1)
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

/// Gallery · List (· Board) as a slim track of glyphs; the names show as tooltips and are read by VoiceOver.
struct ContainerLayoutPicker: View {
    @Binding var selection: ContainerBrowseLayout
    let options: [ContainerBrowseLayout]

    @Namespace private var namespace

    var body: some View {
        HStack(spacing: 0) {
            ForEach(options) { option in
                Button {
                    selection = option
                } label: {
                    Image(systemName: option.symbolName)
                        .font(.system(size: 14, weight: .semibold))
                }
                .buttonStyle(ContainerSegmentButtonStyle(isSelected: selection == option, namespace: namespace, fillsWidth: false))
                .accessibilityLabel(option.title)
                .accessibilityAddTraits(selection == option ? .isSelected : [])
                .help(option.title)
            }
        }
        .containerSegmentTrack()
        .fixedSize()
    }
}

// MARK: - Status filter

/// All plus the four statuses as scrolling capsules, each with its count. Tapping the active one shows everything again.
struct ContainerStatusFilterBar: View {
    @Binding var selection: SkillStatus?
    let counts: [SkillStatus: Int]

    private var total: Int { SkillStatus.boardOrder.reduce(0) { $0 + (counts[$1] ?? 0) } }

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                chip("All", count: total, symbol: nil, tint: Theme.textPrimary, isSelected: selection == nil) {
                    selection = nil
                }
                ForEach(SkillStatus.boardOrder, id: \.self) { status in
                    chip(
                        status.title,
                        count: counts[status] ?? 0,
                        symbol: status.symbolName,
                        tint: status.color,
                        isSelected: selection == status
                    ) {
                        selection = selection == status ? nil : status
                    }
                }
            }
            .padding(.horizontal, 1)
            .padding(.vertical, 2)
        }
    }

    private func chip(
        _ title: String,
        count: Int,
        symbol: String?,
        tint: Color,
        isSelected: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if let symbol {
                    Image(systemName: symbol)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(isSelected ? Theme.textPrimary : tint)
                }
                Text(title)
                    .lineLimit(1)
                Text("\(count)")
                    .font(TimeMasterFont.technical())
                    .opacity(isSelected ? 0.85 : 0.6)
            }
            .fixedSize()
        }
        .buttonStyle(TimeMasterSelectionButtonStyle(isSelected: isSelected))
        .accessibilityLabel("\(title), \(count)")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

// MARK: - Section header

/// The title row of one group of skills: a tinted icon tile, the title and the count; tapping it folds the group.
struct ContainerSectionHeader: View {
    let symbol: String
    let tint: Color
    let title: String
    let count: Int
    let isFolded: Bool
    let onToggle: () -> Void

    var body: some View {
        Button(action: onToggle) {
            HStack(spacing: 10) {
                Image(systemName: symbol)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(tint)
                    .frame(width: 30, height: 30)
                    .background(RoundedRectangle(cornerRadius: 9, style: .continuous).fill(tint.opacity(0.14)))
                Text(title)
                    .font(TimeMasterFont.sectionTitle())
                    .foregroundStyle(Theme.textPrimary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                Text("\(count)")
                    .font(TimeMasterFont.technical())
                    .foregroundStyle(Theme.textSecondary)
                Spacer(minLength: 8)
                Image(systemName: "chevron.down")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(Theme.textSecondary)
                    .rotationEffect(.degrees(isFolded ? -90 : 0))
            }
            .frame(minHeight: 44)
            .contentShape(Rectangle())
        }
        .keyNavPlainButtonStyle()
        .accessibilityLabel("\(title), \(count)")
        .accessibilityValue(isFolded ? "Folded" : "Open")
        .accessibilityHint(isFolded ? "Shows this group" : "Folds this group")
        .accessibilityAddTraits(.isHeader)
    }
}

// MARK: - Labels

/// Where a nested page sits below the container ("Footwork › Drills").
struct ContainerPathLabel: View {
    let path: String

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "folder")
                .font(.system(size: 10, weight: .semibold))
            Text(path)
                .lineLimit(1)
                .truncationMode(.middle)
        }
        .font(TimeMasterFont.caption())
        .foregroundStyle(Theme.textSecondary)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("In \(path)")
    }
}

/// Why a search showed a page whose title did not match.
struct ContainerMatchLabel: View {
    let reason: ContainerMatchReason

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 5) {
            Image(systemName: reason.systemImage)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(Theme.toolbarOrange)
            Text(reason.text)
                .lineLimit(2)
        }
        .font(TimeMasterFont.caption())
        .foregroundStyle(Theme.textSecondary)
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Card button style

/// Press and hover light-up for the cards of a container (Skillmax's tile feel in Tmax orange), the focus ring, the
/// navigation clearance probe and a keyboard target on the card's face.
struct ContainerTileButtonStyle: ButtonStyle {
    var cornerRadius: CGFloat = 20

    func makeBody(configuration: Configuration) -> some View {
        ContainerTileButtonBody(configuration: configuration, cornerRadius: cornerRadius)
    }
}

private struct ContainerTileButtonBody: View {
    let configuration: ButtonStyleConfiguration
    let cornerRadius: CGFloat

    @State private var isHovering = false
    @Environment(\.isFocused) private var isFocused
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        let isLit = configuration.isPressed || isHovering
        configuration.label
            .overlay {
                shape.fill(Theme.toolbarOrange.opacity(configuration.isPressed ? 0.12 : (isHovering ? 0.06 : 0)))
                    .allowsHitTesting(false)
            }
            .overlay {
                shape.strokeBorder(Theme.toolbarOrange.opacity(isLit ? 0.55 : 0), lineWidth: 1.5)
                    .allowsHitTesting(false)
            }
            .overlay {
                if isFocused {
                    shape.strokeBorder(Color.white.opacity(0.75), lineWidth: 2)
                        .allowsHitTesting(false)
                }
            }
            .contentShape(shape)
            .scaleEffect(reduceMotion || !configuration.isPressed ? 1 : 0.97)
            .animation(reduceMotion ? nil : .spring(response: 0.26, dampingFraction: 0.82), value: configuration.isPressed)
            .animation(reduceMotion ? nil : .easeOut(duration: 0.15), value: isHovering)
            .background(SlotNavigationContentClearanceReader())
            .onHover { isHovering = $0 }
            .keyNavButtonSurface(.roundedRectangle(cornerRadius: cornerRadius))
    }
}
