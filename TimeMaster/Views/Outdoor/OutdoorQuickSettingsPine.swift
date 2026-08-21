#if os(iOS)
import SwiftUI
import UIKit
import TimeMasterCore

struct OutdoorQuickSettingsPine: View {
    @ObservedObject var preferences: OutdoorRecordingPreferencesStore
    @ObservedObject private var offlineManager = OutdoorMapOfflineManager.shared
    let offlineCapabilities: [OutdoorMapCapability]
    let onManageMusic: () -> Void

    @State private var showOfflineDetails = false
    @State private var errorMessage: String?

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 14) {
                settingsSection("Workout") {
                    unitRow
                    boolRow(
                        title: "Auto Pause",
                        subtitle: "Pause when movement stops",
                        systemImage: "pause.circle",
                        binding: boolBinding(\.autoPause)
                    )
                    boolRow(
                        title: "Keep Screen Awake",
                        subtitle: "While workout is active",
                        systemImage: "iphone",
                        binding: boolBinding(\.keepScreenAwake)
                    )
                }

                settingsSection("Recording") {
                    enumRow(
                        title: "GPS Accuracy",
                        subtitle: "Core Location / GNSS",
                        systemImage: "location.circle",
                        selection: enumBinding(\.gpsAccuracy),
                        values: TimeMasterCore.OutdoorGPSAccuracy.allCases,
                        titleForValue: { $0 == .precise ? "Precise" : "Balanced" }
                    )
                    enumRow(
                        title: "Elevation Source",
                        subtitle: "GPS + barometer recommended",
                        systemImage: "chart.line.uptrend.xyaxis",
                        selection: enumBinding(\.elevationSource),
                        values: TimeMasterCore.OutdoorElevationSource.allCases,
                        titleForValue: { value in
                            switch value {
                            case .hybrid: "Hybrid"
                            case .gps: "GPS"
                            case .barometer: "Barometer"
                            }
                        }
                    )
                    boolRow(
                        title: "Speed Smoothing",
                        subtitle: "Reduce GPS display jitter",
                        systemImage: "waveform.path.ecg",
                        binding: boolBinding(\.speedSmoothing)
                    )
                }

                settingsSection("Maps & Offline") {
                    Button {
                        showOfflineDetails.toggle()
                    } label: {
                        settingRowLabel(
                            title: "Offline Maps",
                            subtitle: "Downloaded regions & storage",
                            systemImage: "map"
                        ) {
                            HStack(spacing: 5) {
                                Text("Manage")
                                    .font(.caption.weight(.semibold))
                                Image(systemName: showOfflineDetails ? "chevron.up" : "chevron.right")
                                    .font(.caption2.weight(.bold))
                            }
                            .foregroundStyle(Theme.restAccent)
                        }
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Manage offline maps")
                    .accessibilityValue(showOfflineDetails ? "Installed-region details shown" : "Installed-region details hidden")

                    if showOfflineDetails {
                        offlineDetails
                            .transition(.opacity)
                    }

                    boolRow(
                        title: "Auto-download Route Area",
                        subtitle: autoDownloadSubtitle,
                        systemImage: "arrow.down.circle",
                        binding: boolBinding(\.autoDownloadRouteArea),
                        isEnabled: autoDownloadAvailable
                    )
                    boolRow(
                        title: "Weather Info",
                        subtitle: "Automatic condition display",
                        systemImage: "cloud.sun",
                        binding: boolBinding(\.weatherInfo)
                    )
                }

                settingsSection("Music") {
                    Button(action: onManageMusic) {
                        settingRowLabel(
                            title: "Music Sections",
                            subtitle: "Existing Music Settings system",
                            systemImage: "music.note"
                        ) {
                            HStack(spacing: 5) {
                                Text("Manage")
                                    .font(.caption.weight(.semibold))
                                Image(systemName: "chevron.right")
                                    .font(.caption2.weight(.bold))
                            }
                            .foregroundStyle(Theme.restAccent)
                        }
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Manage music sections")
                    .accessibilityHint("Focuses the existing Music settings pine.")

                    enumRow(
                        title: "Audio Cues",
                        subtitle: "Workout announcements",
                        systemImage: "waveform",
                        selection: enumBinding(\.audioCues),
                        values: TimeMasterCore.OutdoorAudioCues.allCases,
                        titleForValue: { value in
                            switch value {
                            case .off: "Off"
                            case .quiet: "Quiet"
                            case .normal: "Normal"
                            }
                        }
                    )
                }

                settingsSection("Privacy") {
                    visibilityRow
                    boolRow(
                        title: "Hide Start & Finish",
                        subtitle: "Default location privacy",
                        systemImage: "eye.slash",
                        binding: boolBinding(\.hideStartFinish)
                    )
                    if preferences.preferences.hideStartFinish {
                        endpointDistanceRow
                    }
                    boolRow(
                        title: "Allow Comments",
                        subtitle: "Default for public posts",
                        systemImage: "bubble.left",
                        binding: boolBinding(\.allowComments)
                    )
                    boolRow(
                        title: "Show Player Tracks",
                        subtitle: "On public workout posts",
                        systemImage: "music.note",
                        binding: boolBinding(\.showPlayerTracks)
                    )
                }

                settingsSection("Feedback & Export") {
                    boolRow(
                        title: "Haptics",
                        subtitle: "Pines, selection & workout actions",
                        systemImage: "waveform.path",
                        binding: boolBinding(\.haptics)
                    )
                    enumRow(
                        title: "Export Format",
                        subtitle: "Preferred workout file",
                        systemImage: "square.and.arrow.down",
                        selection: enumBinding(\.exportFormat),
                        values: TimeMasterCore.OutdoorExportFormat.allCases,
                        titleForValue: { $0 == .gpx ? "GPX" : "FIT" }
                    )
                }

                if let errorMessage {
                    Text(errorMessage)
                        .font(.caption2)
                        .foregroundStyle(.yellow)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.horizontal, 4)
                }
            }
            .padding(.horizontal, 12)
            .padding(.bottom, 12)
        }
        .scrollIndicators(.hidden)
    }

    private var autoDownloadAvailable: Bool {
        offlineCapabilities.contains { $0.isUsable && $0.cacheRights.offlineInstallationAllowed }
    }

    private var autoDownloadSubtitle: String {
        autoDownloadAvailable ? "Prepare nearby eligible map data" : "Unavailable until an offline-licensed source is configured"
    }

    private var unitRow: some View {
        settingRowLabel(title: "Units", subtitle: "Workout distance & speed", systemImage: "plus.forwardslash.minus") {
            Picker("Unit system", selection: enumBinding(\.unitSystem)) {
                ForEach(TimeMasterCore.OutdoorUnitSystem.allCases, id: \.self) { value in
                    Text(value == .metric ? "Metric" : "Imperial").tag(value)
                }
            }
            .pickerStyle(.segmented)
            .frame(width: 148)
            .accessibilityLabel("Unit system")
        }
    }

    private var visibilityRow: some View {
        settingRowLabel(title: "Default Visibility", subtitle: "New established workouts", systemImage: "eye") {
            Picker("Default workout visibility", selection: enumBinding(\.defaultVisibility)) {
                Text("Private").tag(TimeMasterCore.OutdoorActivityVisibility.privateVisibility)
                Text("Public").tag(TimeMasterCore.OutdoorActivityVisibility.publicVisibility)
            }
            .pickerStyle(.segmented)
            .frame(width: 148)
            .accessibilityLabel("Default workout visibility")
        }
    }

    private var endpointDistanceRow: some View {
        settingRowLabel(title: "Privacy distance", subtitle: "Applied to public representations", systemImage: "ruler") {
            Picker("Privacy distance", selection: Binding(
                get: { preferences.preferences.endpointPrivacyMeters },
                set: { value in
                    commit { $0.endpointPrivacyMeters = TimeMasterCore.OutdoorActivityManifest.clampedEndpointPrivacyMeters(value) }
                }
            )) {
                Text("100 m").tag(100)
                Text("200 m").tag(200)
                Text("500 m").tag(500)
            }
            .pickerStyle(.menu)
            .tint(Theme.restAccent)
        }
    }

    private var offlineDetails: some View {
        VStack(alignment: .leading, spacing: 8) {
            if offlineManager.installedRegions.isEmpty {
                Label("No installed offline regions", systemImage: "map")
                    .foregroundStyle(Theme.textSecondary)
            } else {
                Label("\(offlineManager.installedRegions.count) installed region\(offlineManager.installedRegions.count == 1 ? "" : "s")", systemImage: "map.fill")
                    .foregroundStyle(Theme.textPrimary)
                ForEach(Array(offlineManager.installedRegions.enumerated()), id: \.offset) { _, region in
                    VStack(alignment: .leading, spacing: 2) {
                        Text(region.provider.rawValue)
                            .font(.caption.weight(.semibold))
                        Text(region.capabilities.map(\.displayName).joined(separator: ", "))
                            .font(.caption2)
                            .foregroundStyle(Theme.textSecondary)
                        Text("Downloaded \(region.downloadedAt, style: .date)")
                            .font(.caption2)
                            .foregroundStyle(Theme.textSecondary)
                    }
                }
            }

            if !offlineManager.activeDownloads.isEmpty {
                ForEach(Array(offlineManager.activeDownloads.enumerated()), id: \.offset) { _, download in
                    VStack(alignment: .leading, spacing: 5) {
                        HStack {
                            Text(download.modes.map(\.displayName).joined(separator: ", "))
                                .font(.caption.weight(.semibold))
                            Spacer()
                            Button("Cancel", role: .destructive) {
                                offlineManager.cancelDownload(id: download.id)
                            }
                            .font(.caption2.weight(.semibold))
                        }
                        ProgressView(value: download.fractionCompleted)
                            .tint(Theme.restAccent)
                            .accessibilityLabel("Offline map download progress")
                            .accessibilityValue(Text(download.fractionCompleted, format: .percent))
                    }
                }
            }

            let eligible = offlineCapabilities.filter { $0.isUsable && $0.cacheRights.offlineInstallationAllowed }
            if eligible.isEmpty {
                Text("Area selection is unavailable until a provider grants offline installation rights. Existing map data remains discoverable here.")
                    .font(.caption2)
                    .foregroundStyle(Theme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                Text("Eligible offline layers: \(eligible.map { $0.mode.displayName }.joined(separator: ", "))")
                    .font(.caption2)
                    .foregroundStyle(Theme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .font(.caption)
        .padding(.leading, 44)
        .padding(.trailing, 4)
        .accessibilityElement(children: .contain)
    }

    private func settingsSection<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(title.uppercased())
                .font(.caption2.weight(.bold))
                .tracking(0.7)
                .foregroundStyle(Theme.textSecondary)
                .padding(.leading, 4)
            VStack(spacing: 1) {
                content()
            }
            .padding(8)
            .background(Theme.surface.opacity(0.72), in: RoundedRectangle(cornerRadius: 17, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 17, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.11), lineWidth: 1)
            }
        }
    }

    private func boolRow(title: String, subtitle: String, systemImage: String, binding: Binding<Bool>, isEnabled: Bool = true) -> some View {
        settingRowLabel(title: title, subtitle: subtitle, systemImage: systemImage) {
            Toggle(title, isOn: binding)
                .labelsHidden()
                .tint(Theme.restAccent)
                .disabled(!isEnabled)
                .accessibilityLabel(title)
                .accessibilityValue(binding.wrappedValue ? "On" : "Off")
        }
        .opacity(isEnabled ? 1 : 0.56)
    }

    private func enumRow<Value: Hashable & CaseIterable>(
        title: String,
        subtitle: String,
        systemImage: String,
        selection: Binding<Value>,
        values: Value.AllCases,
        titleForValue: @escaping (Value) -> String
    ) -> some View where Value.AllCases: RandomAccessCollection {
        settingRowLabel(title: title, subtitle: subtitle, systemImage: systemImage) {
            Picker(title, selection: selection) {
                ForEach(values, id: \.self) { value in
                    Text(titleForValue(value)).tag(value)
                }
            }
            .pickerStyle(.menu)
            .tint(Theme.restAccent)
            .accessibilityLabel(title)
            .accessibilityValue(titleForValue(selection.wrappedValue))
        }
    }

    private func settingRowLabel<Accessory: View>(title: String, subtitle: String, systemImage: String, @ViewBuilder accessory: () -> Accessory) -> some View {
        HStack(alignment: .center, spacing: 9) {
            Image(systemName: systemImage)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Theme.restAccent)
                .frame(width: 24)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Theme.textPrimary)
                    .lineLimit(2)
                Text(subtitle)
                    .font(.caption2)
                    .foregroundStyle(Theme.textSecondary)
                    .lineLimit(2)
            }
            Spacer(minLength: 4)
            accessory()
        }
        .padding(.vertical, 7)
        .contentShape(Rectangle())
    }

    private func boolBinding(_ keyPath: WritableKeyPath<TimeMasterCore.OutdoorRecordingPreferences, Bool>) -> Binding<Bool> {
        Binding(
            get: { preferences.preferences[keyPath: keyPath] },
            set: { value in commit { $0[keyPath: keyPath] = value } }
        )
    }

    private func enumBinding<Value>(_ keyPath: WritableKeyPath<TimeMasterCore.OutdoorRecordingPreferences, Value>) -> Binding<Value> {
        Binding(
            get: { preferences.preferences[keyPath: keyPath] },
            set: { value in commit { $0[keyPath: keyPath] = value } }
        )
    }

    private func commit(_ change: (inout TimeMasterCore.OutdoorRecordingPreferences) -> Void) {
        do {
            try preferences.update(change)
            errorMessage = nil
            if preferences.preferences.haptics {
                UISelectionFeedbackGenerator().selectionChanged()
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
#endif
