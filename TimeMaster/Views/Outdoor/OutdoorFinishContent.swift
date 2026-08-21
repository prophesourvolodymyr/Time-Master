#if os(iOS)
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

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @State private var showingEstablish = false
    @State private var showingDelete = false
    @State private var title = ""
    @State private var errorMessage: String?
    @State private var titleSaveTask: Task<Void, Never>?

    private var currentActivity: OutdoorActivity? {
        guard let activity else { return nil }
        return store.activities.first(where: { $0.id == activity.id }) ?? activity
    }

    var body: some View {
        let progress = min(1, max(0, expansion))
        let compactLayout = progress < 0.45

        ZStack(alignment: .bottom) {
            if let activity = currentActivity {
                VStack(spacing: 0) {
                    ScrollView(.vertical, showsIndicators: false) {
                        VStack(spacing: 12) {
                            if compactLayout {
                                compactResult(activity)
                            } else {
                                expandedResult(activity, progress: progress)
                            }
                            if let errorMessage {
                                OutdoorInlineError(message: errorMessage)
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 52)
                        .padding(.bottom, 10)
                    }
                    .scrollDismissesKeyboard(.interactively)
                    .accessibilityHidden(showingEstablish || showingDelete)

                    if !showingEstablish && !showingDelete {
                        actions(activity, compact: compactLayout)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(reduceTransparency ? Theme.surface : Color.white.opacity(0.04))
                    }
                }
            } else {
                OutdoorInlineError(message: "Finished workout is unavailable.")
                    .padding(18)
                    .accessibilityHidden(showingEstablish || showingDelete)
            }

            if showingEstablish, let activity = currentActivity {
                OutdoorEstablishContent(
                    store: store,
                    preferences: preferences,
                    activity: activity,
                    points: points,
                    onCancel: {
                        showingEstablish = false
                    },
                    onEstablished: { established in
                        showingEstablish = false
                        onEstablished(established)
                    }
                )
                .transition(reduceMotion ? .opacity : .move(edge: .bottom).combined(with: .opacity))
            }

            if showingDelete, let activity = currentActivity {
                OutdoorDeletionConfirmation(activity: activity, isPresented: $showingDelete) {
                    delete(activity)
                }
            }
        }
        .onChange(of: showingEstablish) { _ in
            onModalStateChange(showingEstablish || showingDelete)
        }
        .onChange(of: showingDelete) { _ in
            onModalStateChange(showingEstablish || showingDelete)
        }
        .onAppear {
            if title.isEmpty { title = currentActivity?.title ?? "" }
        }
        .onDisappear {
            titleSaveTask?.cancel()
            onModalStateChange(false)
        }
    }

    private func compactResult(_ activity: OutdoorActivity) -> some View {
        let units = preferences.preferences.unitSystem
        return VStack(spacing: 5) {
            titleField(font: .headline.weight(.semibold))
            HStack(alignment: .center, spacing: 8) {
                VStack(alignment: .leading, spacing: 0) {
                    Text(outdoorDistanceText(activity.distanceMeters, unitSystem: units, precision: true))
                        .font(.title2.bold().monospacedDigit())
                        .minimumScaleFactor(0.68)
                        .lineLimit(1)
                    Text("Distance")
                        .font(.caption2)
                        .foregroundStyle(Theme.textSecondary)
                }
                Spacer(minLength: 0)
                compactMetric("Gain", outdoorElevationText(activity.elevationGainMeters, unitSystem: units))
                compactMetric("Top", outdoorSpeedText(activity.maxSpeedMetersPerSecond, unitSystem: units))
                compactMetric("Pace", outdoorPaceText(activity.averagePaceSecondsPerKilometer, unitSystem: units))
            }
            HStack(spacing: 8) {
                OutdoorPlayedTrackSummary(tracks: activity.playedTracks)
                Spacer(minLength: 0)
                Label("More Info", systemImage: "chevron.up")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(Theme.textSecondary)
                    .padding(.horizontal, 9)
                    .frame(minHeight: 24)
                    .background(
                        reduceTransparency ? Theme.surface2 : Theme.surface2.opacity(0.72),
                        in: Capsule()
                    )
                    .accessibilityHint("Expand the route pine to reveal complete workout details")
            }
        }
    }

    private func expandedResult(_ activity: OutdoorActivity, progress: CGFloat) -> some View {
        VStack(spacing: 12) {
            header(activity)
            metrics(activity, progress: progress)
            OutdoorPlayedTrackSummary(tracks: activity.playedTracks)
                .frame(maxWidth: .infinity, alignment: .leading)
            OutdoorRouteThumbnailView(
                points: points,
                compact: progress < 0.65,
                cacheKey: activity.id.uuidString
            )
            .frame(maxWidth: .infinity)
            .frame(height: 178 * progress)
            .opacity(progress)
            .clipped()
        }
    }

    private func compactMetric(_ label: String, _ value: String) -> some View {
        VStack(alignment: .trailing, spacing: 0) {
            Text(value)
                .font(.caption.weight(.semibold).monospacedDigit())
                .lineLimit(1)
                .minimumScaleFactor(0.72)
            Text(label)
                .font(.caption2)
                .foregroundStyle(Theme.textSecondary)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(label) \(value)")
    }

    private func header(_ activity: OutdoorActivity) -> some View {
        VStack(spacing: 9) {
            HStack(spacing: 8) {
                OutdoorTypeBadge(kind: activity.kind)
                Spacer(minLength: 0)
                Text(outdoorDateText(activity.startedAt))
                    .font(.caption)
                    .foregroundStyle(Theme.textSecondary)
                    .lineLimit(1)
            }
            titleField(font: .title3.weight(.semibold))
        }
    }
    private func titleField(font: Font) -> some View {
        TextField("Workout title", text: $title)
            .font(font)
            .multilineTextAlignment(.center)
            .textInputAutocapitalization(.words)
            .submitLabel(.done)
            .onSubmit { saveTitle() }
            .onChange(of: title) { _ in
                scheduleTitleSave()
            }
            .accessibilityLabel("Workout title")
    }


    private func metrics(_ activity: OutdoorActivity, progress: CGFloat) -> some View {
        let units = preferences.preferences.unitSystem
        return VStack(spacing: 12) {
            VStack(spacing: 2) {
                Text(outdoorDistanceText(activity.distanceMeters, unitSystem: units, precision: true))
                    .font(.largeTitle.bold().monospacedDigit())
                    .minimumScaleFactor(0.72)
                    .foregroundStyle(Theme.textPrimary)
                Text("distance")
                    .font(.caption)
                    .foregroundStyle(Theme.textSecondary)
            }
            .frame(maxWidth: .infinity)
            HStack(spacing: 12) {
                OutdoorMetricTile(label: "Elapsed", value: outdoorDurationText(activity.elapsedSeconds))
                OutdoorMetricTile(label: "Gain", value: outdoorElevationText(activity.elevationGainMeters, unitSystem: units))
                OutdoorMetricTile(label: "Top speed", value: outdoorSpeedText(activity.maxSpeedMetersPerSecond, unitSystem: units))
                OutdoorMetricTile(label: "Pace", value: outdoorPaceText(activity.averagePaceSecondsPerKilometer, unitSystem: units))
            }
            .padding(.horizontal, 2)
            HStack(spacing: 12) {
                OutdoorMetricTile(label: "Moving", value: outdoorDurationText(activity.movingSeconds))
                OutdoorMetricTile(label: "Highest", value: outdoorElevationText(activity.highestElevationMeters, unitSystem: units))
                OutdoorMetricTile(label: "Points", value: activity.trackPointCount.formatted())
            }
            .frame(height: 58 * progress)
            .opacity(progress)
            .clipped()
        }
    }

    @ViewBuilder
    private func actions(_ activity: OutdoorActivity, compact: Bool) -> some View {
        if compact {
            if #available(iOS 26.0, *) {
                GlassEffectContainer(spacing: 6) {
                    compactActions(activity)
                }
            } else {
                compactActions(activity)
            }
        } else {
            VStack(spacing: 8) {
                Button(action: openEstablish) {
                    Label("Establish workout", systemImage: "checkmark.circle.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(OutdoorPineButtonStyle(prominent: true))
                HStack(spacing: 8) {
                    OutdoorExportShareControl(activity: activity, points: points, preferences: preferences)
                    Button {
                        onResume()
                    } label: {
                        Label("Resume", systemImage: "play.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(OutdoorPineButtonStyle())
                    Button {
                        showingDelete = true
                    } label: {
                        Image(systemName: "trash")
                    }
                    .buttonStyle(OutdoorPineButtonStyle(circular: true))
                    .accessibilityLabel("Delete finished workout")
                }
            }
        }
    }

    private func compactActions(_ activity: OutdoorActivity) -> some View {
        HStack(spacing: 6) {
            Button(action: openEstablish) {
                Label("Establish", systemImage: "checkmark.circle.fill")
                    .lineLimit(1)
            }
            .buttonStyle(OutdoorPineButtonStyle(prominent: true))
            .accessibilityLabel("Establish workout")
            OutdoorExportShareControl(
                activity: activity,
                points: points,
                preferences: preferences,
                compact: true
            )
            Button {
                onResume()
            } label: {
                Label("Resume", systemImage: "play.fill")
                    .lineLimit(1)
            }
            .buttonStyle(OutdoorPineButtonStyle())
            Button {
                showingDelete = true
            } label: {
                Image(systemName: "trash")
            }
            .buttonStyle(OutdoorPineButtonStyle(circular: true))
            .accessibilityLabel("Delete finished workout")
        }
        .frame(maxWidth: .infinity)
    }

    private func openEstablish() {
        saveTitle()
        guard errorMessage == nil else { return }
        showingEstablish = true
    }

    private func scheduleTitleSave() {
        titleSaveTask?.cancel()
        guard let activity = currentActivity else { return }
        let value = title
        titleSaveTask = Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(350))
            guard !Task.isCancelled else { return }
            do {
                try store.updateTitle(value, for: activity)
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    private func saveTitle() {
        titleSaveTask?.cancel()
        guard let activity = currentActivity else { return }
        do {
            try store.updateTitle(title, for: activity)
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func delete(_ activity: OutdoorActivity) {
        do {
            try store.delete(activity)
            onDeleted()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

struct OutdoorEstablishContent: View {
    @ObservedObject var store: OutdoorActivityStore
    @ObservedObject var preferences: OutdoorRecordingPreferencesStore
    let activity: OutdoorActivity
    let points: [OutdoorTrackPoint]
    let onCancel: () -> Void
    let onEstablished: (OutdoorActivity) -> Void

    @State private var visibility: OutdoorActivityVisibility
    @State private var description: String
    @State private var tagText: String
    @State private var allowComments: Bool
    @State private var hideStartFinish: Bool
    @State private var endpointPrivacyMeters: Int
    @State private var showPlayerTracks: Bool
    @State private var errorMessage: String?
    @State private var isSaving = false

    private var recentTags: [String] {
        var values: [String] = []
        for tag in store.establishedActivities.flatMap(\.tags) where !tag.isEmpty && !values.contains(tag) {
            values.append(tag)
        }
        return Array(values.prefix(12))
    }

    init(
        store: OutdoorActivityStore,
        preferences: OutdoorRecordingPreferencesStore,
        activity: OutdoorActivity,
        points: [OutdoorTrackPoint],
        onCancel: @escaping () -> Void,
        onEstablished: @escaping (OutdoorActivity) -> Void
    ) {
        self.store = store
        self.preferences = preferences
        self.activity = activity
        self.points = points
        self.onCancel = onCancel
        self.onEstablished = onEstablished
        _visibility = State(initialValue: activity.establishedAt == nil ? preferences.preferences.defaultVisibility : activity.visibility)
        _description = State(initialValue: activity.publicDescription)
        _tagText = State(initialValue: activity.tags.joined(separator: ", "))
        _allowComments = State(initialValue: activity.allowComments)
        _hideStartFinish = State(initialValue: activity.hideStartFinish)
        _endpointPrivacyMeters = State(initialValue: activity.endpointPrivacyMeters)
        _showPlayerTracks = State(initialValue: activity.showPlayerTracks)
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            Color.black.opacity(0.3)
                .ignoresSafeArea()
                .accessibilityHidden(true)
            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 14) {
                    HStack {
                        Text("Establish workout")
                            .font(.headline.weight(.semibold))
                        Spacer()
                        Button("Close", systemImage: "xmark") {
                            onCancel()
                        }
                        .labelStyle(.iconOnly)
                        .buttonStyle(OutdoorPineButtonStyle(circular: true))
                    }
                    Text("Choose how this finished workout is saved.")
                        .font(.subheadline)
                        .foregroundStyle(Theme.textSecondary)
                    Picker("Visibility", selection: $visibility) {
                        Text("Private").tag(OutdoorActivityVisibility.privateVisibility)
                        Text("Public").tag(OutdoorActivityVisibility.publicVisibility)
                    }
                    .pickerStyle(.segmented)
                    .accessibilityLabel("Workout visibility")
                    if visibility == .publicVisibility {
                        publicFields
                            .transition(.opacity)
                    } else if activity.hasPublicMetadata {
                        Text("Your saved public details will stay available if you publish this workout again.")
                            .font(.caption)
                            .foregroundStyle(Theme.textSecondary)
                            .padding(.vertical, 4)
                    }
                    if let errorMessage {
                        OutdoorInlineError(message: errorMessage)
                    }
                    Button {
                        establish()
                    } label: {
                        if isSaving {
                            ProgressView().tint(Theme.background)
                        } else {
                            Label("Save \(visibility == .publicVisibility ? "Public" : "Private") workout", systemImage: "checkmark")
                        }
                    }
                    .buttonStyle(OutdoorPineButtonStyle(prominent: true))
                    .disabled(isSaving)
                }
                .padding(18)
            }
            .frame(maxHeight: 520)
            .background(Theme.surface, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous).strokeBorder(Color.white.opacity(0.14), lineWidth: 1))
            .padding(10)
        }
    }

    private var publicFields: some View {
        VStack(alignment: .leading, spacing: 12) {
            TextField("Description", text: $description, axis: .vertical)
                .lineLimit(3...6)
                .textFieldStyle(.roundedBorder)
            VStack(alignment: .leading, spacing: 7) {
                Text("Tags")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Theme.textSecondary)
                TextField("Run, trail, morning", text: $tagText)
                    .textFieldStyle(.roundedBorder)
                if !recentTags.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 6) {
                            ForEach(recentTags, id: \.self) { tag in
                                Button(tag) {
                                    var tags = parsedTags
                                    if !tags.contains(tag) { tags.append(tag) }
                                    tagText = tags.joined(separator: ", ")
                                }
                                .font(.caption)
                                .buttonStyle(OutdoorPineButtonStyle())
                                .frame(minHeight: 34)
                                .accessibilityLabel("Add tag \(tag)")
                            }
                        }
                    }
                }
            }
            Toggle("Hide Start & Finish", isOn: $hideStartFinish)
            if hideStartFinish {
                Picker("Privacy distance", selection: $endpointPrivacyMeters) {
                    ForEach(OutdoorPrivacyService.supportedEndpointDistancesMeters, id: \.self) { meters in
                        Text("\(meters) m").tag(meters)
                    }
                }
                .pickerStyle(.segmented)
            }
            Toggle("Allow Comments", isOn: $allowComments)
            Toggle("Show Player Tracks", isOn: $showPlayerTracks)
        }
    }

    private var parsedTags: [String] {
        var values: [String] = []
        for value in tagText.split(separator: ",").map({ $0.trimmingCharacters(in: .whitespacesAndNewlines) }) where !value.isEmpty {
            if !values.contains(value) { values.append(value) }
        }
        return values
    }

    private func establish() {
        isSaving = true
        errorMessage = nil
        do {
            let result = try store.establish(
                activity,
                visibility: visibility,
                publicDescription: visibility == .publicVisibility ? description : nil,
                tags: visibility == .publicVisibility ? parsedTags : nil,
                allowComments: visibility == .publicVisibility ? allowComments : nil,
                hideStartFinish: visibility == .publicVisibility ? hideStartFinish : nil,
                endpointPrivacyMeters: visibility == .publicVisibility && hideStartFinish ? endpointPrivacyMeters : nil,
                showPlayerTracks: visibility == .publicVisibility ? showPlayerTracks : nil
            )
            onEstablished(result)
        } catch {
            isSaving = false
            errorMessage = error.localizedDescription
        }
    }
}

struct OutdoorExportShareControl: View {
    let activity: OutdoorActivity
    let points: [OutdoorTrackPoint]
    @ObservedObject var preferences: OutdoorRecordingPreferencesStore
    let compact: Bool
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    @State private var showingPicker = false
    @State private var formatRaw: String
    @State private var privacyApplied: Bool
    @State private var exportURL: URL?
    @State private var errorMessage: String?

    init(
        activity: OutdoorActivity,
        points: [OutdoorTrackPoint],
        preferences: OutdoorRecordingPreferencesStore,
        compact: Bool = false
    ) {
        self.activity = activity
        self.points = points
        self.preferences = preferences
        self.compact = compact
        _formatRaw = State(initialValue: preferences.preferences.exportFormat == .fit ? "FIT" : "GPX")
        _privacyApplied = State(initialValue: activity.visibility == .publicVisibility && activity.hideStartFinish)
    }

    var body: some View {
        VStack(spacing: 8) {
            Button {
                showingPicker.toggle()
            } label: {
                if compact {
                    Image(systemName: "square.and.arrow.up")
                } else {
                    Label("Share or Export", systemImage: "square.and.arrow.up")
                        .frame(maxWidth: .infinity)
                }
            }
            .buttonStyle(OutdoorPineButtonStyle())
            .accessibilityLabel("Share or export workout")
            if showingPicker {
                VStack(alignment: .leading, spacing: 10) {
                    Picker("Format", selection: $formatRaw) {
                        Text("GPX").tag("GPX")
                        Text("FIT").tag("FIT")
                    }
                    .pickerStyle(.segmented)
                    .onChange(of: formatRaw) { _ in exportURL = nil }
                    Toggle("Apply endpoint privacy", isOn: $privacyApplied)
                        .onChange(of: privacyApplied) { _ in exportURL = nil }
                    if let errorMessage {
                        OutdoorInlineError(message: errorMessage)
                    }
                    if let exportURL {
                        ShareLink(item: exportURL) {
                            Label("Open system share", systemImage: "square.and.arrow.up")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(OutdoorPineButtonStyle(prominent: true))
                    } else {
                        Button("Prepare export") {
                            prepareExport()
                        }
                        .buttonStyle(OutdoorPineButtonStyle(prominent: true))
                    }
                }
                .padding(10)
                .background(
                    reduceTransparency ? Theme.surface2 : Theme.surface2.opacity(0.72),
                    in: RoundedRectangle(cornerRadius: 14, style: .continuous)
                )
            }
        }
    }

    private func prepareExport() {
        errorMessage = nil
        do {
            let format: TimeMasterCore.OutdoorExportFormat = formatRaw == "FIT" ? .fit : .gpx
            exportURL = try OutdoorExportService.shareURL(
                for: activity,
                points: points,
                format: format,
                privacyApplied: privacyApplied
            )
        } catch {
            exportURL = nil
            errorMessage = error.localizedDescription
        }
    }
}
#endif
