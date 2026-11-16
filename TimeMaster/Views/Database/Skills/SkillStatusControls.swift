import SwiftUI
import TimeMasterCore

// MARK: - Chip

/// A small capsule saying where a page stands. Wrap it in a button to cycle the status, or in a `SkillStatusMenu`.
struct SkillStatusChip: View {
    let status: SkillStatus
    var showsLabel: Bool

    init(_ status: SkillStatus, showsLabel: Bool = true) {
        self.status = status
        self.showsLabel = showsLabel
    }

    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: status.symbolName)
                .font(.system(size: 11, weight: .semibold))
            if showsLabel {
                Text(status.title)
                    .font(TimeMasterFont.black(12, relativeTo: .caption))
                    .lineLimit(1)
            }
        }
        .foregroundStyle(status.color)
        .padding(.horizontal, showsLabel ? 10 : 7)
        .frame(minHeight: 28)
        .background(Capsule().fill(status.tint))
        .overlay(Capsule().strokeBorder(status.color.opacity(0.35), lineWidth: 1))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Status: \(status.title)")
    }
}

// MARK: - Menu

/// A menu of the four statuses with a check on the current one.
struct SkillStatusMenu<Label: View>: View {
    let status: SkillStatus
    let onChange: (SkillStatus) -> Void
    let label: Label

    init(status: SkillStatus, onChange: @escaping (SkillStatus) -> Void, @ViewBuilder label: () -> Label) {
        self.status = status
        self.onChange = onChange
        self.label = label()
    }

    var body: some View {
        Menu {
            ForEach(SkillStatus.boardOrder, id: \.self) { option in
                Button {
                    onChange(option)
                } label: {
                    SwiftUI.Label(option.title, systemImage: option == status ? "checkmark" : option.symbolName)
                }
            }
        } label: {
            label
        }
        .menuIndicator(.hidden)
        .keyNavTarget(shape: .capsule)
        .accessibilityLabel("Status: \(status.title)")
        .accessibilityHint("Pick a status")
    }
}

/// Context-menu buttons that move a page to every status but its own.
struct SkillStatusQuickActions: View {
    let status: SkillStatus
    let onChange: (SkillStatus) -> Void

    private static let order: [SkillStatus] = [.completed, .learning, .notStarted, .abandoned]

    var body: some View {
        ForEach(Self.order.filter { $0 != status }, id: \.self) { option in
            Button {
                onChange(option)
            } label: {
                Label(option.quickActionTitle, systemImage: option.symbolName)
            }
        }
    }
}

// MARK: - Filter bar

/// All plus the four statuses as chips, each with its glyph and count, in a row that scrolls sideways. Tapping the
/// chosen one again goes back to All.
struct SkillStatusFilterBar: View {
    @Binding var selection: SkillStatus?
    let counts: [SkillStatus: Int]

    private var allCount: Int { SkillStatus.boardOrder.reduce(0) { $0 + (counts[$1] ?? 0) } }

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: SkillMetrics.s2) {
                chip(title: "All", count: allCount, symbol: nil, tint: Theme.textPrimary, isSelected: selection == nil) {
                    select(nil)
                }
                ForEach(SkillStatus.boardOrder, id: \.self) { status in
                    chip(
                        title: status.title,
                        count: counts[status] ?? 0,
                        symbol: status.symbolName,
                        tint: status.color,
                        isSelected: selection == status
                    ) {
                        select(selection == status ? nil : status)
                    }
                }
            }
            .padding(.horizontal, 2)
            .padding(.vertical, 2)
        }
    }

    private func select(_ status: SkillStatus?) {
        guard selection != status else { return }
        selection = status
        EverHaptic.selection()
    }

    private func chip(
        title: String,
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
                    .opacity(isSelected ? 0.7 : 0.6)
            }
        }
        .buttonStyle(SkillSelectionButtonStyle(isSelected: isSelected))
        .accessibilityLabel("\(title), \(count)")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

// MARK: - Done check

/// Remembers what a page was before it was ticked off, so un-ticking restores it (In progress stays In progress).
enum SkillDoneMemory {
    /// The status one tap on the done check should set: Done when it is not done yet, else whatever it was before.
    static func toggled(pageID: String, current: SkillStatus) -> SkillStatus {
        let defaults = UserDefaults.standard
        var stored = defaults.dictionary(forKey: SkillSettings.statusBeforeDoneKey) as? [String: String] ?? [:]
        if current == .completed {
            let previous = stored[pageID].flatMap(SkillStatus.init(rawValue:))
            stored[pageID] = nil
            defaults.set(stored, forKey: SkillSettings.statusBeforeDoneKey)
            guard let previous, previous != .completed else { return .notStarted }
            return previous
        }
        stored[pageID] = current.rawValue
        defaults.set(stored, forKey: SkillSettings.statusBeforeDoneKey)
        return .completed
    }
}

/// A round check: one tap marks a sub-skill done, another puts it back. No confirmation.
struct SkillDoneButton: View {
    let title: String
    let status: SkillStatus
    let pageID: String
    /// Receives the status to set (already decided by `SkillDoneMemory`).
    let onSet: (SkillStatus) -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var isDone: Bool { status == .completed }

    var body: some View {
        Button {
            onSet(SkillDoneMemory.toggled(pageID: pageID, current: status))
        } label: {
            ZStack {
                if isDone {
                    Image(systemName: SkillStatus.completed.symbolName)
                        .font(.system(size: 26, weight: .semibold))
                        .foregroundStyle(SkillStatus.completed.color)
                        .transition(.scale(scale: 0.5).combined(with: .opacity))
                } else {
                    Circle()
                        .strokeBorder(SkillStatus.completed.color.opacity(0.55), lineWidth: 1.5)
                        .frame(width: 24, height: 24)
                        .transition(.opacity)
                }
            }
            .animation(reduceMotion ? nil : EverMotion.state, value: isDone)
            .frame(width: SkillMetrics.touch, height: SkillMetrics.touch)
            .contentShape(Rectangle())
        }
        .buttonStyle(SkillPressButtonStyle())
        .accessibilityLabel(isDone ? "Done: \(title)" : "Mark \(title) done")
        .accessibilityAddTraits(isDone ? .isSelected : [])
        .help(isDone ? "Done. Click to undo" : "Mark done")
    }
}
