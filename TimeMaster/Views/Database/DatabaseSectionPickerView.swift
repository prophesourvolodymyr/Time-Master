import SwiftUI

// MARK: - DatabaseSectionPickerView

struct DatabaseSectionPickerView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var store: DatabaseStore

    let onSelect: (Section) -> Void

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.background.ignoresSafeArea()
                PickerFolderLevel(
                    folders:   store.rootFolders,
                    exercises: [],
                    onSelect: { section in
                        onSelect(section)
                        dismiss()
                    }
                )
            }
            .timeMasterNavigationTitle("Exercise Database")
            #if os(iOS)
#if os(iOS)
#if os(iOS)
.navigationBarTitleDisplayMode(.large)
#endif
#endif
#endif
            .toolbar {
                AppToolbar.item(placement: .cancellationAction) { Button("Cancel") { dismiss() }
                                 }
            }
        }
    }
}

// MARK: - PickerFolderLevel

struct PickerFolderLevel: View {
    let folders:   [ExerciseFolder]
    let exercises: [Exercise]
    let onSelect:  (Section) -> Void

    var body: some View {
        List {
            pickerFoldersSection
            pickerExercisesSection
        }
        #if os(iOS)
#if os(iOS)
#if os(iOS)
.listStyle(.insetGrouped)
#endif
#endif
#endif
        .scrollContentBackground(.hidden)
    }

    @ViewBuilder
    private var pickerFoldersSection: some View {
        if !folders.isEmpty {
            SwiftUI.Section {
                ForEach(folders) { folder in
                    NavigationLink(
                        destination: PickerFolderLevel(
                            folders:   folder.subfolders,
                            exercises: folder.exercises,
                            onSelect:  onSelect
                        )
                        .timeMasterNavigationTitle(folder.name)
                    ) {
                        FolderRowView(folder: folder)
                    }
                    .listRowBackground(Theme.surface)
                }
            } header: {
                Text("Folders")
                    .font(TimeMasterFont.black(13, relativeTo: .footnote))
            }
        }
    }

    @ViewBuilder
    private var pickerExercisesSection: some View {
        if !exercises.isEmpty {
            SwiftUI.Section {
                ForEach(exercises) { exercise in
                    Button(action: { onSelect(exercise.toSection()) }) {
                        PickerExerciseRow(exercise: exercise)
                    }
                    .listRowBackground(Theme.surface)
                }
            } header: {
                Text("Exercises")
                    .font(TimeMasterFont.black(13, relativeTo: .footnote))
            }
        }
    }
}

// MARK: - PickerExerciseRow

struct PickerExerciseRow: View {
    let exercise: Exercise

    var body: some View {
        HStack(spacing: 12) {
            thumbnailView
            VStack(alignment: .leading, spacing: 3) {
                Text(exercise.name)
                    .font(TimeMasterFont.rowTitle()).foregroundColor(Theme.textPrimary)
                if !exercise.details.isEmpty {
                    Text(exercise.details)
                        .font(TimeMasterFont.caption()).foregroundColor(Theme.textSecondary).lineLimit(1)
                }
                Text("\(exercise.duration)s · \(exercise.restAfter)s rest")
                    .font(TimeMasterFont.micro()).foregroundColor(Theme.toolbarOrange)
            }
            Spacer()
            Image(systemName: "plus.circle")
                .foregroundColor(Theme.toolbarOrange)
        }
    }

    @ViewBuilder
    private var thumbnailView: some View {
        if let item = exercise.mediaItems.first {
            MediaThumbnailView(item: item, size: 40, cornerRadius: 8)
        } else {
            RoundedRectangle(cornerRadius: 8)
                .fill(Theme.surface).frame(width: 40, height: 40)
                .overlay(
                    Image(systemName: "figure.strengthtraining.traditional")
                        .font(.caption).foregroundColor(Theme.textSecondary)
                )
        }
    }
}

#Preview {
    DatabaseSectionPickerView { _ in }
        .environmentObject(DatabaseStore.shared)
}
