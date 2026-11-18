import SwiftUI
import TimeMasterCore

/// The Board layout of a folder's Exercises tab: every exercise and note below the folder, at any depth, in one column
/// per tag of the folder's top page (Untagged first), the way a Notion board groups by a Select property. A card opens
/// its page, its cover does what a gallery cover does, the page menu's writes go through the folder's page actions, and
/// a column's New row opens the page editor for an exercise already wearing that column's tag. The board tells the
/// navigation its reading order, so Previous and Next on an opened page walk the board.
struct ContainerTypeBoard: View {
    /// The folder, with its page tree (`ContainerBrowseModel.container`).
    let folder: ExercisePage
    let actions: ContainerPageActions

    @EnvironmentObject private var store: DatabaseStore
    @EnvironmentObject private var workoutStore: WorkoutStore
    @EnvironmentObject private var navigationState: DatabaseNavigationState
    @Environment(\.openURL) private var openURL

    @State private var creation: ContainerTypedCreation?
    /// `path.count` of the screen the board sits on, read when it appears.
    @State private var depth = 0

    var body: some View {
        let snapshot = PageTypeBoardSnapshot(folder: folder, store: store)
        PageTypeBoardView(
            snapshot: snapshot,
            actions: boardActions,
            newPage: .editor(title: "New exercise", open: { type in creation = ContainerTypedCreation(typeID: type?.id) })
        )
        .onAppear {
            depth = navigationState.path.count
            offer(snapshot.readingOrder)
        }
        .onChange(of: snapshot.readingOrder) { offer($0) }
        .sheet(item: $creation) { request in
            PageCreationSheet(parentID: folder.manifest.id, initialPageType: .exercise) { manifest, parentID in
                try store.createPage(manifest: request.tagged(manifest), parentID: parentID)
            } onSaveWithMedia: { manifest, parentID, coverData, mediaData in
                try store.createPageWithMedia(
                    manifest: request.tagged(manifest),
                    parentID: parentID,
                    coverData: coverData,
                    mediaData: mediaData
                )
            }
            .environmentObject(workoutStore)
            .environmentObject(store)
        }
    }

    private var boardActions: PageTypeBoardActions {
        PageTypeBoardActions(
            open: actions.open,
            openFromCover: actions.openFromCover,
            setType: { page, type in setType(page, type) },
            setStatus: actions.setStatus,
            changeIcon: nil,
            addToWorkout: actions.addToWorkout,
            edit: actions.edit,
            moveTo: actions.move,
            requestDelete: actions.delete,
            openLink: { openURL($0) }
        )
    }

    private func setType(_ page: ExercisePage, _ type: SkillType?) {
        guard page.manifest.typeID != type?.id else { return }
        if SkillErrorCenter.shared.attempt("Change the tag", { try store.setSkillType(type?.id, for: page.manifest.id) }) {
            EverHaptic.selection()
        }
    }

    private func offer(_ ids: [String]) {
        navigationState.offerSiblings(ids, containerID: folder.manifest.id, surface: "board", depth: depth)
    }
}

/// What a column's New row asks the page editor for: an exercise wearing the column's tag (nil = Untagged).
private struct ContainerTypedCreation: Identifiable {
    let id = UUID()
    let typeID: String?

    /// The manifest the editor made, wearing the tag.
    func tagged(_ manifest: ExercisePageManifest) -> ExercisePageManifest {
        var tagged = manifest
        tagged.typeID = typeID
        return tagged
    }
}
