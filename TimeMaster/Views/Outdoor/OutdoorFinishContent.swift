#if os(iOS)
import Foundation
import SwiftUI
import TimeMasterCore

struct OutdoorFinishContent: View {
    @ObservedObject var store: OutdoorActivityStore
    @ObservedObject var preferences: OutdoorRecordingPreferencesStore
    let activity: OutdoorActivity?
    let points: [OutdoorTrackPoint]
    let expansion: CGFloat
    let onResume: () -> Void
    let onEstablished: (OutdoorActivity) -> Void
    let onDeleted: () -> Void
    let onModalStateChange: (Bool) -> Void

    @State private var title = ""
    @State private var visibility: OutdoorActivityVisibility = .privateVisibility
    @State private var description = ""
    @State private var tagText = ""
    @State private var allowComments = true
    @State private var hideStartFinish = true
    @State private var endpointPrivacyMeters = 200
    @State private var showPlayerTracks = true
    @State private var showingDetails = false
    @State private var showingDelete = false
    @State private var errorMessage: String?
    @State private var isSaving = false
    @State private var didLoad = false

    private var currentActivity: OutdoorActivity? {
        guard let activity else { return nil }
        return store.activities.first { $0.id == activity.id } ?? activity
    }

    private var recentTags: [String] {
        var tags: [String] = []
        for activity in store.establishedActivities {
            for tag in activity.tags where !tags.contains(tag) {
                tags.append(tag)
                if tags.count == 12 { return tags }
            }
        }
        return tags
    }

    var body: some View {
        Group {
            if let activity = currentActivity {
                VStack(spacing: 0) {
                    ScrollView(.vertical, showsIndicators: false) {
                        VStack(alignment: .leading, spacing: 18) {
                            HStack {
                                Label("Workout complete", systemImage: "checkmark.circle.fill")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(Theme.restAccent)
                                Spacer()
                                Menu {
                                    Button("Delete workout", role: .destructive) { showingDelete = true }
                                } label: {
                                    Image(systemName: "ellipsis")
                                        .frame(minWidth: 44, minHeight: 44)
                                }
                                .buttonStyle(.plain)
                                .accessibilityLabel("Finished workout options")
                            }
                            HStack(spacing: 10) {
                                TextField("Name your workout", text: $title)
                                    .font(.title2.weight(.bold))
                                    .textInputAutocapitalization(.sentences)
                                    .submitLabel(.done)
                                    .onSubmit { saveTitle() }
                                    .accessibilityLabel("Workout name")
                                Image(systemName: "pencil")
                                    .font(.body)
                                    .foregroundStyle(Theme.textSecondary)
                                    .accessibilityHidden(true)
                            }
                            .frame(minHeight: 44)
                            OutdoorWorkoutSummary(activity: activity, units: preferences.preferences.unitSystem, expanded: expansion >= 0.4)
                            ViewThatFits(in: .horizontal) {
                                HStack(spacing: 10) { selectors(activity) }
                                VStack(alignment: .leading, spacing: 8) { selectors(activity) }
                            }
                            Text(visibility == .publicVisibility ? "This workout will appear on your local profile." : "Private. Your workout stays in your own library.")
                                .font(.caption)
                                .foregroundStyle(Theme.textSecondary)
                            DisclosureGroup("Notes & privacy", isExpanded: $showingDetails) {
                                OutdoorPublicDetailsFields(
                                    description: $description,
                                    tagText: $tagText,
                                    allowComments: $allowComments,
                                    hideStartFinish: $hideStartFinish,
                                    endpointPrivacyMeters: $endpointPrivacyMeters,
                                    showPlayerTracks: $showPlayerTracks,
                                    recentTags: recentTags
                                )
                                .padding(.top, 16)
                            }
                            .font(.subheadline.weight(.semibold))
                            .tint(Theme.restAccent)
                            if expansion >= 0.4 {
                                OutdoorRouteThumbnailView(points: points, cacheKey: activity.id.uuidString)
                            }
                            if !activity.playedTracks.isEmpty {
                                OutdoorPlayedTrackSummary(tracks: activity.playedTracks)
                            }
                            if let errorMessage { OutdoorInlineError(message: errorMessage) }
                        }
                        .padding(.horizontal, 20)
                        .padding(.bottom, 20)
                    }
                    .scrollDismissesKeyboard(.interactively)
                    Divider().overlay(Color.white.opacity(0.1))
                    HStack(spacing: 10) {
                        Button {
                            resume(activity)
                        } label: {
                            Label("Resume", systemImage: "play.fill")
                                .font(.subheadline.weight(.semibold))
                        }
                        .buttonStyle(OutdoorAccessoryButtonStyle())
                        .accessibilityLabel("Resume workout")
                        OutdoorExportShareControl(activity: exportDraft(activity), points: points, preferences: preferences, compact: true)
                        Button {
                            save(activity)
                        } label: {
                            Group {
                                if isSaving { ProgressView() }
                                else { Text("Save").font(.headline) }
                            }
                            .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(OutdoorPineButtonStyle(prominent: true))
                        .accessibilityLabel("Save workout")
                        .accessibilityIdentifier("save-outdoor-workout")
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .disabled(isSaving)
                }
            } else {
                OutdoorInlineError(message: "Finished workout is unavailable.").padding(18)
            }
        }
        .accessibilityHidden(showingDelete)
        .overlay {
            if showingDelete, let activity = currentActivity {
                OutdoorDeletionConfirmation(activity: activity, isPresented: $showingDelete) {
                    do {
                        try store.delete(activity)
                        onDeleted()
                    } catch {
                        errorMessage = error.localizedDescription
                    }
                }
            }
        }
        .onChange(of: showingDelete, perform: onModalStateChange)
        .onAppear { loadDraft() }
        .onDisappear {
            if let activity = currentActivity, store.activities.contains(where: { $0.id == activity.id }), activity.title != title {
                saveTitle()
            }
            onModalStateChange(false)
        }
    }

    private func selectors(_ activity: OutdoorActivity) -> some View {
        Group {
            OutdoorActivityTypePicker(kind: Binding(get: { activity.kind }, set: { kind in
                do {
                    try store.setKind(kind, for: activity)
                    if title == activity.kind.defaultTitle { title = kind.defaultTitle }
                    errorMessage = nil
                } catch {
                    errorMessage = error.localizedDescription
                }
            }))
            OutdoorVisibilityPicker(visibility: $visibility)
        }
    }

    private func loadDraft() {
        guard !didLoad, let activity = currentActivity else { return }
        didLoad = true
        title = activity.title
        visibility = activity.establishedAt == nil ? preferences.preferences.defaultVisibility : activity.visibility
        description = activity.publicDescription
        tagText = activity.tags.joined(separator: ", ")
        allowComments = activity.allowComments
        hideStartFinish = activity.hideStartFinish
        endpointPrivacyMeters = activity.endpointPrivacyMeters
        showPlayerTracks = activity.showPlayerTracks
    }

    private func exportDraft(_ activity: OutdoorActivity) -> OutdoorActivity {
        var draft = activity
        let name = title.trimmingCharacters(in: .whitespacesAndNewlines)
        draft.title = name.isEmpty ? activity.kind.defaultTitle : name
        draft.visibility = visibility
        draft.hideStartFinish = hideStartFinish
        draft.endpointPrivacyMeters = endpointPrivacyMeters
        return draft
    }

    private func saveTitle() {
        guard let activity = currentActivity else { return }
        do {
            try store.updateTitle(title, for: activity)
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func save(_ activity: OutdoorActivity) {
        isSaving = true
        errorMessage = nil
        do {
            try store.updateTitle(title, for: activity)
            let saved = try store.establish(
                activity,
                visibility: visibility,
                publicDescription: description,
                tags: outdoorParsedTags(tagText),
                allowComments: allowComments,
                hideStartFinish: hideStartFinish,
                endpointPrivacyMeters: endpointPrivacyMeters,
                showPlayerTracks: showPlayerTracks
            )
            onEstablished(saved)
        } catch {
            errorMessage = error.localizedDescription
            isSaving = false
        }
    }

    private func resume(_ activity: OutdoorActivity) {
        do {
            try store.updateTitle(title, for: activity)
            try store.setVisibility(visibility, for: activity)
            try store.updateDetails(for: activity, description: description, tags: outdoorParsedTags(tagText), allowComments: allowComments, hideStartFinish: hideStartFinish, endpointPrivacyMeters: endpointPrivacyMeters, showPlayerTracks: showPlayerTracks)
            onResume()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

struct OutdoorExportShareControl: View {
    let activity: OutdoorActivity
    let points: [OutdoorTrackPoint]
    @ObservedObject var preferences: OutdoorRecordingPreferencesStore
    let compact: Bool

    @State private var showingPicker = false
    @State private var formatRaw: String
    @State private var privacyApplied: Bool
    @State private var exportURL: URL?
    @State private var errorMessage: String?

    init(activity: OutdoorActivity, points: [OutdoorTrackPoint], preferences: OutdoorRecordingPreferencesStore, compact: Bool = false) {
        self.activity = activity
        self.points = points
        self.preferences = preferences
        self.compact = compact
        _formatRaw = State(initialValue: preferences.preferences.exportFormat == .fit ? "FIT" : "GPX")
        _privacyApplied = State(initialValue: activity.visibility == .publicVisibility && activity.hideStartFinish)
    }

    var body: some View {
        Button {
            privacyApplied = activity.visibility == .publicVisibility && activity.hideStartFinish
            exportURL = nil
            errorMessage = nil
            showingPicker = true
        } label: {
            if compact {
                Image(systemName: "square.and.arrow.up")
            } else {
                Label("Share or export", systemImage: "square.and.arrow.up")
                    .frame(maxWidth: .infinity)
            }
        }
        .buttonStyle(OutdoorAccessoryButtonStyle())
        .accessibilityLabel("Share or export workout")
        .sheet(isPresented: $showingPicker) {
            NavigationStack {
                Form {
                    SwiftUI.Section {
                        Picker("Format", selection: $formatRaw) {
                            Text("GPX").tag("GPX")
                            Text("FIT").tag("FIT")
                        }
                        .pickerStyle(.segmented)
                        .onChange(of: formatRaw) { _ in exportURL = nil }
                        Toggle("Hide start and finish", isOn: $privacyApplied)
                            .onChange(of: privacyApplied) { _ in exportURL = nil }
                    } footer: {
                        Text(privacyApplied ? "Your configured endpoint privacy is applied to this exported route." : "The complete recorded route will be included.")
                    }
                    if let errorMessage {
                        SwiftUI.Section { OutdoorInlineError(message: errorMessage) }
                    }
                    SwiftUI.Section {
                        if let exportURL {
                            ShareLink(item: exportURL) {
                                Label("Share file", systemImage: "square.and.arrow.up")
                            }
                        } else {
                            Button("Prepare export", action: prepareExport)
                        }
                    }
                }
                .tint(Theme.restAccent)
                .navigationTitle("Export workout")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Done") { showingPicker = false }
                    }
                }
            }
            .presentationDetents([.medium, .large])
        }
        .onChange(of: activity) { _ in exportURL = nil }
    }

    private func prepareExport() {
        errorMessage = nil
        do {
            let format: TimeMasterCore.OutdoorExportFormat = formatRaw == "FIT" ? .fit : .gpx
            exportURL = try OutdoorExportService.shareURL(for: activity, points: points, format: format, privacyApplied: privacyApplied)
        } catch {
            exportURL = nil
            errorMessage = error.localizedDescription
        }
    }
}
#endif
