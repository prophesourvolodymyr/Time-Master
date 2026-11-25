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

// MARK: - Layout

/// Gallery · List (· Board) as a slim track of glyphs, a `TmaxTabBar`; the names show as tooltips and are read by
/// VoiceOver.
struct ContainerLayoutPicker: View {
    @Binding var selection: ContainerBrowseLayout
    let options: [ContainerBrowseLayout]

    var body: some View {
        TmaxTabBar(
            options.map { TmaxTab($0, title: $0.title, symbol: $0.symbolName, showsTitle: false) },
            selection: $selection,
            fillsWidth: false,
            accessibilityLabel: "Layout"
        )
        .fixedSize()
    }
}

// MARK: - Status filter

/// All plus the four statuses as scrolling chips, each with its count; one pill swooshes to the chosen one. Tapping the
/// chosen status again shows everything.
struct ContainerStatusFilterBar: View {
    @Binding var selection: SkillStatus?
    let counts: [SkillStatus: Int]

    @Namespace private var namespace

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
                        .foregroundStyle(isSelected ? Theme.background : tint)
                }
                Text(title)
                    .lineLimit(1)
                Text("\(count)")
                    .font(TimeMasterFont.technical())
                    .opacity(isSelected ? 0.85 : 0.6)
            }
            .fixedSize()
        }
        .buttonStyle(TmaxChipButtonStyle(isSelected: isSelected, namespace: namespace))
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
            .animation(reduceMotion ? nil : .spring(response: 0.26, dampingFraction: 0.82), value: configuration.isPressed)
            .animation(reduceMotion ? nil : .easeOut(duration: 0.15), value: isHovering)
            .everBounce(configuration.isPressed, in: shape, kind: .squeeze, lights: false)
            .background(SlotNavigationContentClearanceReader())
            .onHover { isHovering = $0 }
            .keyNavButtonSurface(.roundedRectangle(cornerRadius: cornerRadius))
    }
}
