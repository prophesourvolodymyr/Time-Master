import Combine
import Foundation
import TimeMasterCore

extension Notification.Name {
    static let outdoorRecordingPreferencesDidChange = Notification.Name("OutdoorRecordingPreferencesDidChange")
}

@MainActor
final class OutdoorRecordingPreferencesStore: NSObject, ObservableObject {
    @Published var preferences: TimeMasterCore.OutdoorRecordingPreferences

    private let database: DatabaseManager

    init(database: DatabaseManager = .shared) {
        self.database = database
        let config = try? database.loadConfig()
        preferences = config?.outdoorRecording ?? TimeMasterCore.OutdoorRecordingPreferences()
        super.init()
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handlePreferencesDidChange),
            name: .outdoorRecordingPreferencesDidChange,
            object: nil
        )
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    @objc private func handlePreferencesDidChange() {
        try? reload()
    }

    func reload() throws {
        let config = try database.loadConfig()
        preferences = config.outdoorRecording ?? TimeMasterCore.OutdoorRecordingPreferences()
    }

    func update(_ newPreferences: TimeMasterCore.OutdoorRecordingPreferences) throws {
        var config = try database.loadConfig()
        config.outdoorRecording = newPreferences
        try database.saveConfig(config)
        preferences = newPreferences
    }

    func update(_ change: (inout TimeMasterCore.OutdoorRecordingPreferences) -> Void) throws {
        var newPreferences = preferences
        change(&newPreferences)
        try update(newPreferences)
    }

    func setUnitSystem(_ value: TimeMasterCore.OutdoorUnitSystem) throws {
        try update { $0.unitSystem = value }
    }

    func setAutoPause(_ value: Bool) throws {
        try update { $0.autoPause = value }
    }

    func setKeepScreenAwake(_ value: Bool) throws {
        try update { $0.keepScreenAwake = value }
    }

    func setGPSAccuracy(_ value: TimeMasterCore.OutdoorGPSAccuracy) throws {
        try update { $0.gpsAccuracy = value }
    }

    func setElevationSource(_ value: TimeMasterCore.OutdoorElevationSource) throws {
        try update { $0.elevationSource = value }
    }

    func setSpeedSmoothing(_ value: Bool) throws {
        try update { $0.speedSmoothing = value }
    }

    func setAutoDownloadRouteArea(_ value: Bool) throws {
        try update { $0.autoDownloadRouteArea = value }
    }

    func setWeatherInfo(_ value: Bool) throws {
        try update { $0.weatherInfo = value }
    }

    func setAudioCues(_ value: TimeMasterCore.OutdoorAudioCues) throws {
        try update { $0.audioCues = value }
    }

    func setDefaultVisibility(_ value: TimeMasterCore.OutdoorActivityVisibility) throws {
        try update { $0.defaultVisibility = value }
    }

    func setHideStartFinish(_ value: Bool) throws {
        try update { $0.hideStartFinish = value }
    }

    func setEndpointPrivacyMeters(_ value: Int) throws {
        try update { $0.endpointPrivacyMeters = TimeMasterCore.OutdoorActivityManifest.clampedEndpointPrivacyMeters(value) }
    }

    func setAllowComments(_ value: Bool) throws {
        try update { $0.allowComments = value }
    }

    func setShowPlayerTracks(_ value: Bool) throws {
        try update { $0.showPlayerTracks = value }
    }

    func setHaptics(_ value: Bool) throws {
        try update { $0.haptics = value }
    }

    func setExportFormat(_ value: TimeMasterCore.OutdoorExportFormat) throws {
        try update { $0.exportFormat = value }
    }
}
