import SwiftUI
import TimeMasterCore

/// The menu of a page card: open it, add it to a workout, set a skill's status, edit it, add a page inside it,
/// duplicate, move or delete it. Each item shows only when the screen showing the card hands over its action.
struct PageCardMenu: View {
    let page: ExercisePage
    var onOpen: (() -> Void)? = nil
    var onAddToWorkout: (() -> Void)? = nil
    var onSetStatus: ((SkillStatus) -> Void)? = nil
    var onEdit: (() -> Void)? = nil
    var onAddChild: (() -> Void)? = nil
    var onDuplicate: (() -> Void)? = nil
    var onMove: (() -> Void)? = nil
    var onDelete: (() -> Void)? = nil

    var body: some View {
        if let onOpen {
            Button(action: onOpen) {
                Label("Open", systemImage: "arrow.up.forward.square")
            }
        }
        if page.isWorkoutAddable, let onAddToWorkout {
            Button(action: onAddToWorkout) {
                Label("Add to Workout", systemImage: "figure.strengthtraining.traditional")
            }
        }
        if SkillLibrary.isSkill(page), let onSetStatus {
            let current = page.manifest.skillStatus ?? .notStarted
            Menu {
                ForEach(SkillStatus.boardOrder, id: \.self) { status in
                    Button {
                        onSetStatus(status)
                    } label: {
                        Label(status.title, systemImage: status == current ? "checkmark" : status.symbolName)
                    }
                }
            } label: {
                Label("Status: \(current.title)", systemImage: current.symbolName)
            }
        }
        if let onEdit {
            Button(action: onEdit) {
                Label("Edit", systemImage: "pencil")
            }
        }
        if page.isContainer, let onAddChild {
            Button(action: onAddChild) {
                Label("Add Child Page", systemImage: "doc.badge.plus")
            }
        }
        if let onDuplicate {
            Button(action: onDuplicate) {
                Label("Duplicate", systemImage: "doc.on.doc")
            }
        }
        if let onMove {
            Button(action: onMove) {
                Label("Move to…", systemImage: "folder")
            }
        }
        if let onDelete {
            Divider()
            Button(role: .destructive, action: onDelete) {
                Label("Delete", systemImage: "trash")
            }
        }
    }
}

/// What the cards of a page list can do with a page. `ContainerPageActionHost` builds it and shows what it asks for.
struct ContainerPageActions {
    let open: (ExercisePage) -> Void
    /// A click on the page's cover: its clips in the stack's viewer (`PageCoverOpening`); a page without a clip opens.
    let openFromCover: (ExercisePage) -> Void
    let addToWorkout: (ExercisePage) -> Void
    let setStatus: (ExercisePage, SkillStatus) -> Void
    let edit: (ExercisePage) -> Void
    let addInside: (ExercisePage) -> Void
    let duplicate: (ExercisePage) -> Void
    let move: (ExercisePage) -> Void
    let delete: (ExercisePage) -> Void
    /// Moves the page with this id (dropped on a container's card) inside that container.
    let moveInside: (String, ExercisePage) -> Void
    /// Puts the page with this id right before the target page (right after it with `true`) in their parent's order;
    /// a page from another place stays where it is.
    let place: (String, ExercisePage, Bool) -> Void

    /// What a page dropped on `target`'s card does (`PageCardDragDrop`).
    func drop(_ id: String, _ placement: PageDropPlacement, on target: ExercisePage) {
        switch placement {
        case .inside: moveInside(id, target)
        case .before, .after: place(id, target, placement == .after)
        }
    }

    /// The full menu of `page`.
    func menu(for page: ExercisePage) -> PageCardMenu {
        PageCardMenu(
            page: page,
            onOpen: { open(page) },
            onAddToWorkout: { addToWorkout(page) },
            onSetStatus: { setStatus(page, $0) },
            onEdit: { edit(page) },
            onAddChild: { addInside(page) },
            onDuplicate: { duplicate(page) },
            onMove: { move(page) },
            onDelete: { delete(page) }
        )
    }
}

/// Shows what the page menu asks for over a list of page cards (the editor, a new page inside, the workout picker, the
/// move picker, the delete confirmation) and hands the cards the actions.
struct ContainerPageActionHost<Content: View>: View {
    @EnvironmentObject private var store: DatabaseStore
    @EnvironmentObject private var workoutStore: WorkoutStore
    @EnvironmentObject private var navigationState: DatabaseNavigationState
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @ViewBuilder let content: (ContainerPageActions) -> Content

    @State private var editing: ExercisePage?
    @State private var addingInside: ExercisePage?
    @State private var addingToWorkout: ExercisePage?
    @State private var moving: ExercisePage?
    @State private var deleting: ExercisePage?

    var body: some View {
        content(actions)
            .sheet(item: $editing) { page in
                PageCreationSheet(page: page) { manifest, parentID in
                    try store.updatePage(id: page.manifest.id, manifest: manifest, newParentID: parentID)
                }
                .environmentObject(workoutStore)
                .environmentObject(store)
            }
            .sheet(item: $addingInside) { parent in
                PageCreationSheet(
                    parentID: parent.manifest.id,
                    initialPageType: parent.isSkillLike ? .skill : .exercise
                ) { manifest, parentID in
                    try store.createPage(manifest: manifest, parentID: parentID)
                } onSaveWithMedia: { manifest, parentID, coverData, mediaData in
                    try store.createPageWithMedia(
                        manifest: manifest,
                        parentID: parentID,
                        coverData: coverData,
                        mediaData: mediaData
                    )
                }
                .environmentObject(workoutStore)
                .environmentObject(store)
            }
            .sheet(item: $addingToWorkout) { page in
                WorkoutPickerSheet(page: page)
                    .environmentObject(workoutStore)
            }
            .sheet(item: $moving) { page in
                ContainerMoveSheet(page: page)
                    .environmentObject(store)
            }
            .confirmationDialog(
                deleting.map { "Delete “\($0.title)”?" } ?? "Delete this page?",
                isPresented: Binding(get: { deleting != nil }, set: { if !$0 { deleting = nil } }),
                titleVisibility: .visible,
                presenting: deleting
            ) { page in
                Button("Delete", role: .destructive) { delete(page) }
                Button("Cancel", role: .cancel) {}
            } message: { page in
                Text(page.isContainer ? "Everything inside it goes with it." : "Its notes and media go with it.")
            }
    }

    private var actions: ContainerPageActions {
        ContainerPageActions(
            open: { page in
                navigationState.path.append(DatabasePageRoute(pageID: page.manifest.id))
            },
            openFromCover: { page in
                PageCoverOpening.open(page, in: navigationState)
            },
            addToWorkout: { addingToWorkout = $0 },
            setStatus: { page, status in setStatus(status, of: page) },
            edit: { editing = $0 },
            addInside: { addingInside = $0 },
            duplicate: { page in duplicate(page) },
            move: { moving = $0 },
            delete: { deleting = $0 },
            moveInside: { id, target in moveInside(id, target) },
            place: { id, target, after in place(id, nextTo: target, after: after) }
        )
    }

    private func setStatus(_ status: SkillStatus, of page: ExercisePage) {
        guard (page.manifest.skillStatus ?? .notStarted) != status else { return }
        let changed = SkillErrorCenter.shared.attempt("Change the status") {
            try store.setSkillStatus(status, for: page.manifest.id)
        }
        if changed { EverHaptic.success() }
    }

    private func duplicate(_ page: ExercisePage) {
        let duplicated = SkillErrorCenter.shared.attempt("Duplicate the page") {
            try store.duplicatePage(page)
        }
        if duplicated { EverHaptic.success() }
    }

    private func delete(_ page: ExercisePage) {
        let deleted = SkillErrorCenter.shared.attempt("Delete the page") {
            try store.deletePage(id: page.manifest.id)
        }
        if deleted { EverHaptic.success() }
    }

    private func moveInside(_ id: String, _ target: ExercisePage) {
        guard id != target.manifest.id,
              store.page(manifestID: id)?.manifest.parentID != target.manifest.id,
              !store.breadcrumbs(for: target.id).contains(where: { $0.manifest.id == id }) else { return }
        let moved = SkillErrorCenter.shared.attempt("Move the page") {
            try store.movePageToEnd(id: id, parentID: target.manifest.id)
        }
        if moved { EverHaptic.success() }
    }

    private func place(_ id: String, nextTo target: ExercisePage, after: Bool) {
        guard id != target.manifest.id, store.page(manifestID: id)?.manifest.parentID == target.manifest.parentID else { return }
        let placed = SkillErrorCenter.shared.attempt("Move the page") {
            try withAnimation(reduceMotion ? nil : .spring(response: 0.34, dampingFraction: 0.86)) {
                try store.placePage(id, nextTo: target.manifest.id, after: after)
            }
        }
        if placed { EverHaptic.selection() }
    }
}
