import SwiftUI
import TimeMasterCore

/// A skill page's milestones: big cards in a grid (a cover across the top, an icon hanging over it, the title, a few
/// lines of note, pictures, links and the sub-milestones inside), cut into parts by section dividers that span the
/// grid. Tap a card to edit it; the check on its cover marks it reached.
struct SkillMilestonesSection: View {
    let pageID: String

    @EnvironmentObject private var store: DatabaseStore
    @EnvironmentObject private var workoutStore: WorkoutStore
    @EnvironmentObject private var navigationState: DatabaseNavigationState
    @Environment(\.openURL) private var openURL

    @AppStorage("tm.milestones.hidesReached") private var hidesReached = false
    @State private var editor: ChecklistEditorRoute?
    @State private var pendingDelete: Milestone?
    @State private var renamingSectionID: String?
    @State private var errorMessage: String?
    @State private var gallerySelection: URL?

    var body: some View {
        let list = store.checklist(Milestone.self, of: pageID)
        VStack(alignment: .leading, spacing: 14) {
            ChecklistSectionHeader(
                symbol: "flag.checkered", title: "Milestones", done: list.progressDone, total: list.progressTotal,
                addLabel: "New milestone", onAdd: { editor = .create(parentID: nil, index: nil) }
            ) {
                Toggle(isOn: $hidesReached) { Label("Hide what's reached", systemImage: "eye.slash") }
                Button { addSection(at: nil) } label: { Label("Add a section", systemImage: "text.badge.plus") }
            }
            if let errorMessage {
                ChecklistErrorBanner(message: errorMessage) { self.errorMessage = nil }
            }
            if list.isEmpty {
                stateLine(symbol: "flag.checkered", text: "No milestones yet")
            } else if hidesReached, list.progressTotal > 0, list.openCount == 0 {
                stateLine(symbol: "checkmark.seal.fill", text: "Every milestone reached")
            }
            ForEach(list.parts) { part in
                if let section = part.section {
                    divider(section, in: list)
                }
                let shown = hidesReached ? part.entries.filter { !$0.isDone } : part.entries
                if !shown.isEmpty {
                    LazyVGrid(
                        columns: [GridItem(.adaptive(minimum: 300, maximum: 560), spacing: 16, alignment: .top)],
                        alignment: .leading,
                        spacing: 16
                    ) {
                        ForEach(shown) { milestone in
                            MilestoneCardView(pageID: pageID, milestone: milestone, actions: actions)
                        }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .sheet(item: $editor) { route in
            ChecklistEditorSheet<Milestone>(pageID: pageID, route: route, existing: existing(for: route))
                .environmentObject(store)
                .environmentObject(workoutStore)
        }
        .confirmationDialog(
            "Delete this milestone?",
            isPresented: Binding(get: { pendingDelete != nil }, set: { if !$0 { pendingDelete = nil } }),
            titleVisibility: .visible,
            presenting: pendingDelete
        ) { item in
            Button("Delete", role: .destructive) { remove(item.id) }
            Button("Cancel", role: .cancel) {}
        } message: { item in
            let inside = item.children.flattened().count
            Text(inside == 0 ? "“\(item.title)”" : "“\(item.title)” and \(inside) inside")
        }
        .checklistGallery(pageID: pageID, selection: $gallerySelection)
    }

    private func stateLine(symbol: String, text: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: symbol)
                .foregroundStyle(Theme.toolbarOrange)
            Text(text)
                .font(TimeMasterFont.secondary())
                .foregroundStyle(Theme.textSecondary)
        }
        .padding(.vertical, 6)
    }

    private func divider(_ section: Milestone, in list: [Milestone]) -> some View {
        let index = list.firstIndex { $0.id == section.id } ?? 0
        return ChecklistSectionDivider(
            title: section.title,
            iconName: section.iconName,
            iconType: section.iconType,
            colorHex: section.colorHex,
            canMoveUp: index > 0,
            canMoveDown: index < list.count - 1,
            renamesOnAppear: renamingSectionID == section.id,
            onRename: { title in
                perform { try store.updateChecklistEntry(Milestone.self, section.id, in: pageID) { $0.title = title } }
            },
            onMove: { delta in perform { try store.stepChecklistEntry(Milestone.self, section.id, by: delta, in: pageID) } },
            onEdit: { editor = .edit(section.id) },
            onDelete: { remove(section.id) }
        )
        .onAppear {
            guard renamingSectionID == section.id else { return }
            DispatchQueue.main.async { renamingSectionID = nil }
        }
    }

    // MARK: Actions

    private var actions: MilestoneActions {
        MilestoneActions(
            toggle: { milestone in
                perform { try store.setChecklistEntry(Milestone.self, milestone.id, done: !milestone.isDone, in: pageID) }
                if milestone.isDone { EverHaptic.selection() } else { EverHaptic.success() }
            },
            edit: { editor = .edit($0.id) },
            addChild: { editor = .create(parentID: $0.id, index: nil) },
            move: { milestone, delta in perform { try store.stepChecklistEntry(Milestone.self, milestone.id, by: delta, in: pageID) } },
            delete: { pendingDelete = $0 },
            openLink: { _, target in
                ChecklistLinkOpener.open(target, navigation: navigationState, openURL: openURL) { gallerySelection = $0 }
            },
            playWorkout: ChecklistLinkOpener.start,
            removeLink: { milestone, link in
                perform { try store.updateChecklistEntry(Milestone.self, milestone.id, in: pageID) { $0.links.removeAll { $0.id == link.id } } }
            },
            openPicture: { gallerySelection = $0 }
        )
    }

    private func addSection(at index: Int?) {
        perform {
            let section: Milestone = try store.addChecklistSection(Milestone.self, title: "New section", to: pageID, at: index)
            renamingSectionID = section.id
        }
    }

    private func remove(_ id: String) {
        perform { try store.removeChecklistEntry(Milestone.self, id, from: pageID) }
    }

    private func existing(for route: ChecklistEditorRoute) -> Milestone? {
        guard case .edit(let id) = route else { return nil }
        return store.checklist(Milestone.self, of: pageID).entry(id)
    }

    private func perform(_ change: () throws -> Void) {
        do {
            try change()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
