#if os(iOS)
import SwiftUI

struct OutdoorActivityDetailPineContent: View {
    @ObservedObject var store: OutdoorActivityStore
    @ObservedObject var preferences: OutdoorRecordingPreferencesStore
    let activityID: UUID
    let points: [OutdoorTrackPoint]
    @Binding var isEditing: Bool
    let onShowMap: () -> Void
    let onDeleted: () -> Void
    let onModalStateChange: (Bool) -> Void

    @State private var showingDelete = false
    @State private var errorMessage: String?
    @AccessibilityFocusState private var deleteButtonFocused: Bool

    private var activity: OutdoorActivity? {
        store.activities.first { $0.id == activityID }
    }

    var body: some View {
        Group {
            if let activity {
                OutdoorAdaptivePane { compact in
                    ScrollView(.vertical, showsIndicators: false) {
                        VStack(spacing: compact ? 14 : 22) {
                            HStack(spacing: 8) {
                                Text(activity.title)
                                    .font(.title2.weight(.bold))
                                    .multilineTextAlignment(.center)
                                Button {
                                    perform { try store.toggleStarred(for: activity) }
                                } label: {
                                    Image(systemName: activity.starred ? "star.fill" : "star")
                                        .font(.title2)
                                        .foregroundStyle(activity.starred ? Theme.restAccent : Theme.textSecondary)
                                        .frame(minWidth: 44, minHeight: 44)
                                }
                                .buttonStyle(.plain)
                                .accessibilityLabel(activity.starred ? "Remove star" : "Star workout")
                            }
                            .frame(maxWidth: .infinity)
                            VStack(spacing: 8) {
                                OutdoorVisibilityPicker(visibility: Binding(get: { activity.visibility }, set: { visibility in
                                    perform { try store.setVisibility(visibility, for: activity) }
                                }), prominent: true)
                                Label(activity.kind.displayName, systemImage: activity.kind.iconName)
                                    .font(.caption.weight(.medium))
                                    .foregroundStyle(Theme.textSecondary)
                            }
                            OutdoorRouteSummary(activity: activity, units: preferences.preferences.unitSystem, compact: compact)
                            Button(action: onShowMap) {
                                OutdoorRouteThumbnailView(points: points, cacheKey: activity.id.uuidString)
                                    .overlay(alignment: .bottomTrailing) {
                                        Label("View on map", systemImage: "arrow.up.left.and.arrow.down.right")
                                            .font(.caption.weight(.semibold))
                                            .padding(10)
                                            .background(.regularMaterial, in: Capsule())
                                            .padding(10)
                                    }
                            }
                            .buttonStyle(.plain)
                            .disabled(points.isEmpty)
                            .accessibilityLabel("View the recorded route on the map")
                            .accessibilityHint("Closes the details pane until you return from the map")
                            if !activity.playedTracks.isEmpty, activity.showPlayerTracks {
                                OutdoorPlayedTrackSummary(tracks: activity.playedTracks)
                            }
                            if let errorMessage { OutdoorInlineError(message: errorMessage) }
                        }
                        .padding(.horizontal, 4)
                        .padding(.top, compact ? 4 : 12)
                        .padding(.bottom, 8)
                    }
                } actions: { compact in
                    let layout = compact ? AnyLayout(VStackLayout(spacing: 10)) : AnyLayout(HStackLayout(spacing: 10))
                    layout {
                        OutdoorExportShareControl(activity: activity, points: points, preferences: preferences, compact: compact)
                        Button(role: .destructive) { showingDelete = true } label: {
                            Image(systemName: "trash")
                                .font(.body.weight(.semibold))
                                .foregroundStyle(.red)
                                .frame(width: 44, height: 44)
                        }
                        .buttonStyle(OutdoorAccessoryButtonStyle())
                        .accessibilityFocused($deleteButtonFocused)
                        .accessibilityLabel("Delete workout")
                    }
                }
                .sheet(isPresented: $isEditing) {
                    OutdoorWorkoutEditor(store: store, activity: activity)
                }
            } else {
                OutdoorInlineError(message: "This route is no longer available.").padding(18)
            }
        }
        .foregroundStyle(Theme.textPrimary)
        .accessibilityHidden(showingDelete)
        .onChange(of: showingDelete) { visible in
            onModalStateChange(visible)
            if !visible { deleteButtonFocused = true }
        }
        .onDisappear { onModalStateChange(false) }
        .overlay {
            if showingDelete, let activity {
                OutdoorDeletionConfirmation(activity: activity, isPresented: $showingDelete) {
                    perform {
                        try store.delete(activity)
                        onDeleted()
                    }
                }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Workout details")
    }

    private func perform(_ action: () throws -> Void) {
        do {
            try action()
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

struct OutdoorWorkoutEditor: View {
    @ObservedObject var store: OutdoorActivityStore
    let activity: OutdoorActivity
    @Environment(\.dismiss) private var dismiss
    @State private var title = ""
    @State private var kind: OutdoorActivityKind = .bike
    @State private var visibility: OutdoorActivityVisibility = .privateVisibility
    @State private var description = ""
    @State private var tagText = ""
    @State private var allowComments = true
    @State private var hideStartFinish = true
    @State private var endpointPrivacyMeters = 200
    @State private var showPlayerTracks = true
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Form {
                SwiftUI.Section("Workout") {
                    TextField("Workout name", text: $title)
                        .textInputAutocapitalization(.sentences)
                        .accessibilityLabel("Workout name")
                    OutdoorActivityTypePicker(kind: $kind)
                    OutdoorVisibilityPicker(visibility: $visibility)
                }
                SwiftUI.Section("Notes & privacy") {
                    OutdoorPublicDetailsFields(
                        description: $description,
                        tagText: $tagText,
                        allowComments: $allowComments,
                        hideStartFinish: $hideStartFinish,
                        endpointPrivacyMeters: $endpointPrivacyMeters,
                        showPlayerTracks: $showPlayerTracks,
                        showsPublicOptions: visibility == .publicVisibility
                    )
                }
                if let errorMessage { SwiftUI.Section { OutdoorInlineError(message: errorMessage) } }
            }
            .tint(Theme.restAccent)
            .navigationTitle("Edit workout")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("Save", action: save).fontWeight(.semibold) }
            }
            .onAppear {
                title = activity.title
                kind = activity.kind
                visibility = activity.visibility
                description = activity.publicDescription
                tagText = activity.tags.joined(separator: ", ")
                allowComments = activity.allowComments
                hideStartFinish = activity.hideStartFinish
                endpointPrivacyMeters = activity.endpointPrivacyMeters
                showPlayerTracks = activity.showPlayerTracks
            }
        }
    }

    private func save() {
        do {
            let name = title == activity.kind.defaultTitle ? kind.defaultTitle : title
            try store.setKind(kind, for: activity)
            try store.updateTitle(name, for: activity)
            try store.setVisibility(visibility, for: activity)
            try store.updateDetails(for: activity, description: description, tags: outdoorParsedTags(tagText), allowComments: allowComments, hideStartFinish: hideStartFinish, endpointPrivacyMeters: endpointPrivacyMeters, showPlayerTracks: showPlayerTracks)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
#endif
