import SwiftUI
import TimeMasterCore

/// The Table view of a board: every sub-skill at any depth on one row (done check, status, title with where it lives,
/// section, type, files, links and how much of what is inside it is done). Wide windows get column headers that sort;
/// phones get two-line rows and a sort menu. A row opens its sub-skill; its section and type change in place.
struct SkillTableView: View {
    let snapshot: SkillBoardSnapshot
    /// Already filtered by status; in board order.
    let items: [SkillBoardItem]
    /// The status filter above the table: a new sub-skill joins it, so it does not vanish the moment it exists.
    var statusFilter: SkillStatus?
    let actions: SkillBoardActions

    @EnvironmentObject private var store: DatabaseStore
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    #if os(iOS)
    @Environment(\.horizontalSizeClass) private var sizeClass
    #endif

    @State private var sortKey: SkillTableSortKey = .status
    @State private var ascending = true

    private var isWide: Bool {
        #if os(macOS)
        return true
        #else
        return sizeClass == .regular
        #endif
    }

    var body: some View {
        let rows = sortKey.sorted(items, ascending: ascending)
        let showsSection = snapshot.hasSections
        VStack(alignment: .leading, spacing: SkillMetrics.s3) {
            if !isWide { sortBar(count: rows.count) }
            if !rows.isEmpty {
                VStack(spacing: 0) {
                    if isWide { headerRow(showsSection: showsSection) }
                    LazyVStack(spacing: 0) {
                        ForEach(rows) { item in
                            SkillTableRow(
                                item: item,
                                isWide: isWide,
                                showsSection: showsSection,
                                moveTargets: snapshot.moveTargets,
                                actions: actions
                            )
                            if item.id != rows.last?.id { separator }
                        }
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: SkillMetrics.cardRadius, style: .continuous))
                .modifier(TimeMasterCardSurface(cornerRadius: SkillMetrics.cardRadius, flat: true))
            }
            SkillQuickAddRow(placeholder: "Add a sub-skill…") { title in
                let added = SkillErrorCenter.shared.attempt("Add the sub-skill") {
                    try store.createBoardSkill(title: title, on: snapshot.scope.boardID, sectionID: nil, status: statusFilter ?? .notStarted)
                }
                if added { EverHaptic.selection() }
                return added
            }
        }
    }

    // MARK: Header (wide)

    private func headerRow(showsSection: Bool) -> some View {
        VStack(spacing: 0) {
            HStack(spacing: SkillMetrics.s3) {
                Color.clear.frame(width: SkillMetrics.touch, height: 1).accessibilityHidden(true)
                headerCell(.status, width: SkillTableLayout.statusWidth)
                headerCell(.title, width: nil)
                if showsSection { headerCell(.section, width: SkillTableLayout.sectionWidth) }
                headerCell(.type, width: SkillTableLayout.typeWidth)
                headerCell(.files, width: SkillTableLayout.countWidth, trailing: true, symbol: "paperclip")
                headerCell(.links, width: SkillTableLayout.countWidth, trailing: true, symbol: "link")
                headerCell(.inside, width: SkillTableLayout.insideWidth, trailing: true)
            }
            .font(TimeMasterFont.black(12, relativeTo: .caption))
            .foregroundStyle(Theme.textSecondary)
            .padding(.horizontal, SkillMetrics.s4)
            .frame(height: 40)
            separator
        }
    }

    private func headerCell(_ key: SkillTableSortKey, width: CGFloat?, trailing: Bool = false, symbol: String? = nil) -> some View {
        let isActive = sortKey == key
        return Button {
            tap(key)
        } label: {
            HStack(spacing: 4) {
                if trailing { Spacer(minLength: 0) }
                if let symbol {
                    Image(systemName: symbol)
                        .accessibilityLabel(key.label)
                } else {
                    Text(key.label)
                        .lineLimit(1)
                }
                if isActive {
                    Image(systemName: ascending ? "chevron.up" : "chevron.down")
                        .font(.system(size: 9, weight: .semibold))
                }
                if !trailing { Spacer(minLength: 0) }
            }
            .foregroundStyle(isActive ? Theme.textPrimary : Theme.textSecondary)
            .frame(height: 40)
            .contentShape(Rectangle())
        }
        .buttonStyle(SkillPressButtonStyle())
        .frame(width: width)
        .frame(maxWidth: width == nil ? .infinity : nil)
        .accessibilityLabel("Sort by \(key.label)")
        .accessibilityValue(isActive ? (ascending ? "Ascending" : "Descending") : "")
        .accessibilityAddTraits(isActive ? .isSelected : [])
    }

    private var separator: some View {
        Rectangle()
            .fill(Theme.separator)
            .frame(height: 1)
    }

    // MARK: Sort (phone)

    private func sortBar(count: Int) -> some View {
        HStack(spacing: SkillMetrics.s2) {
            Text("\(count)")
                .font(TimeMasterFont.technical())
                .foregroundStyle(Theme.textSecondary)
            Spacer(minLength: 0)
            TmaxMenu {
                ForEach(SkillTableSortKey.allCases) { key in
                    Button {
                        tap(key)
                    } label: {
                        if key == sortKey {
                            Label(key.label, systemImage: ascending ? "chevron.up" : "chevron.down")
                        } else {
                            Text(key.label)
                        }
                    }
                }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "arrow.up.arrow.down")
                        .font(.system(size: 12, weight: .semibold))
                    Text(sortKey.label)
                        .font(TimeMasterFont.black(13, relativeTo: .footnote))
                    Image(systemName: ascending ? "chevron.up" : "chevron.down")
                        .font(.system(size: 9, weight: .semibold))
                }
                .foregroundStyle(Theme.textPrimary)
                .padding(.horizontal, SkillMetrics.s3)
                .frame(minHeight: SkillMetrics.touch)
                .contentShape(Rectangle())
            }
            .menuStyle(.button)
            .buttonStyle(SkillPressButtonStyle())
            .menuIndicator(.hidden)
            .fixedSize()
            .accessibilityLabel("Sort by \(sortKey.label)")
            .accessibilityValue(ascending ? "Ascending" : "Descending")
        }
    }

    /// The same column again flips the direction; a new column starts ascending (counts start with the largest).
    private func tap(_ key: SkillTableSortKey) {
        withAnimation(reduceMotion ? nil : EverMotion.state) {
            if sortKey == key {
                ascending.toggle()
            } else {
                sortKey = key
                ascending = !key.startsDescending
            }
        }
        EverHaptic.selection()
    }
}

// MARK: - Column widths

private enum SkillTableLayout {
    static let statusWidth: CGFloat = 132
    static let sectionWidth: CGFloat = 150
    static let typeWidth: CGFloat = 140
    static let countWidth: CGFloat = 44
    static let insideWidth: CGFloat = 72
}

// MARK: - Sorting

/// The columns a table sorts by.
enum SkillTableSortKey: String, CaseIterable, Identifiable {
    case title, status, section, type, files, links, inside

    var id: String { rawValue }

    var label: String {
        switch self {
        case .title: return "Title"
        case .status: return "Status"
        case .section: return "Section"
        case .type: return "Type"
        case .files: return "Files"
        case .links: return "Links"
        case .inside: return "Inside"
        }
    }

    /// Counts sort from the largest when picked.
    var startsDescending: Bool {
        switch self {
        case .files, .links, .inside: return true
        case .title, .status, .section, .type: return false
        }
    }

    /// A sorted copy; ties keep board order.
    func sorted(_ items: [SkillBoardItem], ascending: Bool) -> [SkillBoardItem] {
        items.enumerated()
            .sorted { lhs, rhs in
                let result = compare(lhs.element, rhs.element)
                if result == .orderedSame { return lhs.offset < rhs.offset }
                return ascending ? result == .orderedAscending : result == .orderedDescending
            }
            .map(\.element)
    }

    private func compare(_ a: SkillBoardItem, _ b: SkillBoardItem) -> ComparisonResult {
        switch self {
        case .title:
            return a.title.localizedCaseInsensitiveCompare(b.title)
        case .status:
            return Self.compare(Self.rank(a.status), Self.rank(b.status))
        case .section:
            return Self.compare(a.laneIndex == 0 ? Int.max : a.laneIndex, b.laneIndex == 0 ? Int.max : b.laneIndex)
        case .type:
            switch (a.type?.title, b.type?.title) {
            case (nil, nil): return .orderedSame
            case (nil, _): return .orderedDescending
            case (_, nil): return .orderedAscending
            case let (x?, y?): return x.localizedCaseInsensitiveCompare(y)
            }
        case .files:
            return Self.compare(a.mediaCount, b.mediaCount)
        case .links:
            return Self.compare(a.linkCount, b.linkCount)
        case .inside:
            return Self.compare(a.progress.total, b.progress.total)
        }
    }

    private static func rank(_ status: SkillStatus) -> Int {
        SkillStatus.boardOrder.firstIndex(of: status) ?? 0
    }

    private static func compare(_ x: Int, _ y: Int) -> ComparisonResult {
        x == y ? .orderedSame : (x < y ? .orderedAscending : .orderedDescending)
    }
}

// MARK: - Row

private struct SkillTableRow: View {
    let item: SkillBoardItem
    let isWide: Bool
    let showsSection: Bool
    let moveTargets: [SkillBoardLane]
    let actions: SkillBoardActions

    @State private var isHovering = false
    @State private var typeEditor: SkillTypeEditorRoute?
    @State private var showingTypeManager = false

    private var page: ExercisePage { item.page }
    private var status: SkillStatus { item.status }

    var body: some View {
        Group {
            if isWide { wideRow } else { compactRow }
        }
        .background(Color.white.opacity(isHovering ? 0.04 : 0))
        .skillTypeBase(item.type, cornerRadius: 0)
        .contentShape(Rectangle())
        .keyNavTarget(id: item.id, role: .primary, shape: .roundedRectangle(cornerRadius: 8), action: open)
        .onHover { isHovering = $0 }
        .onTapGesture(perform: open)
        .skillTypeSheets(for: item.id, editor: $typeEditor, showingManager: $showingTypeManager)
        .contextMenu {
            SkillPageMenuItems(
                item: item,
                actions: actions,
                moveTargets: moveTargets,
                statusAsMenu: true,
                typeEditor: $typeEditor,
                showingTypeManager: $showingTypeManager
            )
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(item.spokenSummary)
        .accessibilityAction(named: "Open", open)
    }

    private func open() {
        actions.open(page)
    }

    // MARK: Wide

    private var wideRow: some View {
        HStack(spacing: SkillMetrics.s3) {
            SkillDoneButton(title: item.title, status: status, pageID: item.id) { actions.setStatus(page, $0) }
            statusMenu(showsLabel: true)
                .frame(width: SkillTableLayout.statusWidth, alignment: .leading)
            HStack(spacing: SkillMetrics.s2) {
                SkillPageIconTile(page: page, size: 26)
                VStack(alignment: .leading, spacing: 2) {
                    title
                    if !item.path.isEmpty {
                        Text(item.path)
                            .font(TimeMasterFont.caption())
                            .foregroundStyle(Theme.textSecondary)
                            .lineLimit(1)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            if showsSection {
                sectionCell
                    .frame(width: SkillTableLayout.sectionWidth, alignment: .leading)
            }
            SkillTypePicker(pageID: item.id) {
                Group {
                    if let type = item.type {
                        SkillTypeChip(type: type, showsChevron: true)
                    } else {
                        SkillAddTypeChip()
                    }
                }
                .frame(width: SkillTableLayout.typeWidth, height: 32, alignment: .leading)
                .contentShape(Rectangle())
            }
            count(item.mediaCount)
            count(item.linkCount)
            Text(item.progress.total > 0 ? "\(item.progress.completed)/\(item.progress.total)" : "—")
                .font(TimeMasterFont.technical())
                .foregroundStyle(item.progress.total > 0 ? Theme.textPrimary : Theme.textSecondary)
                .frame(width: SkillTableLayout.insideWidth, alignment: .trailing)
        }
        .padding(.horizontal, SkillMetrics.s4)
        .frame(minHeight: 52)
    }

    /// Where the sub-skill sits: a menu that moves a direct sub-skill to another section, plain text for nested ones.
    @ViewBuilder
    private var sectionCell: some View {
        let label = HStack(spacing: SkillMetrics.s2) {
            if let hex = item.sectionColorHex {
                Capsule(style: .continuous)
                    .fill(Color(hex: hex))
                    .frame(width: 4, height: 18)
                    .accessibilityHidden(true)
            }
            Text(item.sectionTitle ?? "—")
                .font(TimeMasterFont.secondary())
                .foregroundStyle(item.sectionTitle == nil ? Theme.textSecondary : Theme.textPrimary)
                .lineLimit(1)
        }
        if item.isDirect && !moveTargets.isEmpty {
            TmaxMenu {
                ForEach(moveTargets) { lane in
                    Button {
                        actions.moveToSection(page, lane.sectionID)
                    } label: {
                        Label(lane.title, systemImage: lane.key == item.laneKey ? "checkmark" : lane.symbolName)
                    }
                }
            } label: {
                label
                    .frame(height: 32)
                    .contentShape(Rectangle())
            }
            .menuStyle(.button)
            .buttonStyle(SkillPressButtonStyle())
            .menuIndicator(.hidden)
            .accessibilityLabel("Section: \(item.sectionTitle ?? "none")")
        } else {
            label
        }
    }

    private func count(_ value: Int) -> some View {
        Text(value > 0 ? "\(value)" : "—")
            .font(TimeMasterFont.technical())
            .foregroundStyle(value > 0 ? Theme.textPrimary : Theme.textSecondary)
            .frame(width: SkillTableLayout.countWidth, alignment: .trailing)
    }

    // MARK: Compact

    private var compactRow: some View {
        HStack(spacing: SkillMetrics.s2) {
            SkillDoneButton(title: item.title, status: status, pageID: item.id) { actions.setStatus(page, $0) }
            statusMenu(showsLabel: false)
            VStack(alignment: .leading, spacing: 3) {
                title
                metaLine
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            Image(systemName: "chevron.right")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(Theme.textSecondary)
                .accessibilityHidden(true)
        }
        .padding(.leading, SkillMetrics.s2)
        .padding(.trailing, SkillMetrics.s4)
        .padding(.vertical, SkillMetrics.s1)
        .frame(minHeight: 60)
    }

    private var metaLine: some View {
        HStack(spacing: SkillMetrics.s3) {
            if let place = item.path.isEmpty ? item.sectionTitle : item.path {
                HStack(spacing: 5) {
                    if item.path.isEmpty, let hex = item.sectionColorHex {
                        Circle()
                            .fill(Color(hex: hex))
                            .frame(width: 8, height: 8)
                            .accessibilityHidden(true)
                    }
                    Text(place)
                        .lineLimit(1)
                }
                .layoutPriority(-1)
            }
            if let type = item.type { SkillTypeChip(type: type) }
            if item.mediaCount > 0 { badge("paperclip", "\(item.mediaCount)") }
            if item.linkCount > 0 { badge("link", "\(item.linkCount)") }
            if item.progress.total > 0 { badge("arrow.turn.down.right", "\(item.progress.completed)/\(item.progress.total)") }
        }
        .font(TimeMasterFont.caption())
        .foregroundStyle(Theme.textSecondary)
    }

    private func badge(_ symbol: String, _ text: String) -> some View {
        HStack(spacing: 3) {
            Image(systemName: symbol)
                .font(.system(size: 10, weight: .semibold))
            Text(text)
                .font(TimeMasterFont.technical())
                .lineLimit(1)
        }
        .fixedSize()
    }

    // MARK: Shared

    private var title: some View {
        SkillEditableTitle(
            pageID: item.id,
            title: item.title,
            font: TimeMasterFont.rowTitle(),
            color: Theme.textPrimary.opacity(status.titleOpacity),
            lineLimit: 1,
            onOpen: open
        )
    }

    private func statusMenu(showsLabel: Bool) -> some View {
        SkillStatusMenu(status: status, onChange: { actions.setStatus(page, $0) }) {
            SkillStatusChip(status, showsLabel: showsLabel)
                .frame(minHeight: SkillMetrics.touch)
                .padding(.horizontal, showsLabel ? 0 : 4)
                .contentShape(Rectangle())
        }
        .menuStyle(.button)
        .buttonStyle(SkillPressButtonStyle())
        .fixedSize()
    }
}
