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
            .navigationTitle("Exercise Database")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
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
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
    }

    @ViewBuilder
    private var pickerFoldersSection: some View {
        if !folders.isEmpty {
            SwiftUI.Section("Folders") {
                ForEach(folders) { folder in
                    NavigationLink(
                        destination: PickerFolderLevel(
                            folders:   folder.subfolders,
                            exercises: folder.exercises,
                            onSelect:  onSelect
                        )
                        .navigationTitle(folder.name)
                    ) {
                        FolderRowView(folder: folder)
                    }
                    .listRowBackground(Theme.surface)
                }
            }
        }
    }

    @ViewBuilder
    private var pickerExercisesSection: some View {
        if !exercises.isEmpty {
            SwiftUI.Section("Exercises") {
                ForEach(exercises) { exercise in
                    Button(action: { onSelect(exercise.toSection()) }) {
                        PickerExerciseRow(exercise: exercise)
                    }
                    .listRowBackground(Theme.surface)
                }
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
                    .font(.subheadline).fontWeight(.medium).foregroundColor(Theme.textPrimary)
                if !exercise.details.isEmpty {
                    Text(exercise.details)
                        .font(.caption).foregroundColor(Theme.textSecondary).lineLimit(1)
                }
                Text("\(exercise.duration)s · \(exercise.restAfter)s rest")
                    .font(.caption2).foregroundColor(Theme.primary)
            }
            Spacer()
            Image(systemName: "plus.circle")
                .foregroundColor(Theme.primary)
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
