import Foundation
import Combine
import TimeMasterCore

enum OutdoorActivityStoreError: Error, LocalizedError {
    case cannotEstablishUnfinished

    var errorDescription: String? {
        switch self {
        case .cannotEstablishUnfinished:
            "Only a finished outdoor activity can be established."
        }
    }
}

final class OutdoorActivityStore: ObservableObject {
    @Published private(set) var activities: [OutdoorActivity] = []
    @Published private(set) var recoverableActivities: [OutdoorActivity] = []
    @Published private(set) var targetReachedActivityID: UUID?
    @Published private(set) var plannedRoutes: [PlannedRoute] = []
    var establishedActivities: [OutdoorActivity] {
        activities.filter { $0.establishedAt != nil }
    }

    var starredActivities: [OutdoorActivity] {
        establishedActivities.filter(\.starred)
    }

    var publicActivities: [OutdoorActivity] {
        establishedActivities.filter { $0.visibility == .publicVisibility }
    }

    var profileActivities: [OutdoorActivity] { publicActivities }
    var established: [OutdoorActivity] { establishedActivities }
    var starred: [OutdoorActivity] { starredActivities }

    private let database: DatabaseManager

    private var routesDirectory: URL {
        database.routesDirectory
    }

    private var activeActivity: OutdoorActivity?
    private var activePoints: [OutdoorTrackPoint] = []
    private var lastPersistedAt = Date.distantPast
    init(database: DatabaseManager = .shared) {
        self.database = database
        reload()
    }

    func reload() {
        try? database.bootstrapIfNeeded()
        plannedRoutes = loadPlannedRoutes()
        var loadedByID: [UUID: OutdoorActivity] = [:]
        for manifest in (try? database.listOutdoorActivities()) ?? [] {
            guard var activity = try? OutdoorActivity(core: manifest) else { continue }
            let requiresMigration = activity.schemaVersion < TimeMasterCore.OutdoorActivityManifest.currentSchemaVersion
            if requiresMigration {
                activity.schemaVersion = TimeMasterCore.OutdoorActivityManifest.currentSchemaVersion
            }
            if activity.finished {
                if requiresMigration {
                    try? database.updateOutdoorActivity(id: activity.id.uuidString, manifest: activity.coreValue)
                }
            } else {
                let points = ((try? database.readOutdoorTrackPoints(id: manifest.id)) ?? []).map(OutdoorTrackPoint.init)
                let metrics = OutdoorMetricsCalculator.aggregate(points: points, pauses: activity.pauseIntervals)
                let correctedElapsed = max(activity.elapsedSeconds, metrics.elapsedSeconds)
                let correctedMoving = min(correctedElapsed, max(activity.movingSeconds, metrics.movingSeconds))
                if activity.trackPointCount != points.count
                    || abs(activity.distanceMeters - metrics.distanceMeters) > 1
                    || activity.elapsedSeconds != correctedElapsed
                    || activity.movingSeconds != correctedMoving
                    || requiresMigration {
                    activity.trackPointCount = points.count
                    activity.distanceMeters = metrics.distanceMeters
                    activity.elapsedSeconds = correctedElapsed
                    activity.movingSeconds = correctedMoving
                    activity.averageSpeedMetersPerSecond = correctedMoving > 0 ? metrics.distanceMeters / Double(correctedMoving) : nil
                    activity.maxSpeedMetersPerSecond = [activity.maxSpeedMetersPerSecond, metrics.maxSpeedMetersPerSecond].compactMap { $0 }.max()
                    if activity.distanceMeters > 0, activity.movingSeconds > 0 {
                        activity.averagePaceSecondsPerKilometer = Double(activity.movingSeconds) * 1_000 / activity.distanceMeters
                    }
                    try? database.updateOutdoorActivity(id: activity.id.uuidString, manifest: activity.coreValue)
                }
            }
            loadedByID[activity.id] = activity
        }
        activities = loadedByID.values.sorted { $0.startedAt > $1.startedAt }
        recoverableActivities = activities.filter { !$0.finished && $0.establishedAt == nil }
    }

    func begin(
        kind: OutdoorActivityKind,
        timeTargetSeconds: Int? = nil,
        plannedRoute: PlannedRoute? = nil,
        preferences: OutdoorRecordingPreferences? = nil
    ) throws -> OutdoorActivity {
        var activity = OutdoorActivity(kind: kind, timeTargetSeconds: timeTargetSeconds)
        if let preferences {
            activity.visibility = preferences.defaultVisibility
            activity.hideStartFinish = preferences.hideStartFinish
            activity.endpointPrivacyMeters = TimeMasterCore.OutdoorActivityManifest.clampedEndpointPrivacyMeters(
                preferences.endpointPrivacyMeters
            )
            activity.allowComments = preferences.allowComments
            activity.showPlayerTracks = preferences.showPlayerTracks
        }
        activity.plannedRouteID = plannedRoute?.id.uuidString
        try database.createOutdoorActivity(id: activity.id.uuidString, manifest: activity.coreValue)
        activeActivity = activity
        activePoints = []
        targetReachedActivityID = nil
        replacePublished(activity)
        return activity
    }

    var active: OutdoorActivity? { activeActivity }
    var activeRoute: [OutdoorTrackPoint] { activePoints }

    func append(
        point: OutdoorTrackPoint,
        filteredElevationGainMeters: Double? = nil,
        filteredHighestElevationMeters: Double? = nil
    ) throws {
        guard var activity = activeActivity, !activity.finished else { return }
        try database.appendOutdoorTrackPoint(id: activity.id.uuidString, point: point.coreValue)
        activePoints.append(point)
        activity.trackPointCount = activePoints.count
        let metrics = OutdoorMetricsCalculator.aggregate(points: activePoints, pauses: activity.pauseIntervals)
        activity.distanceMeters = metrics.distanceMeters
        activity.elapsedSeconds = max(activity.elapsedSeconds, max(0, Int(point.timestamp.timeIntervalSince(activity.startedAt).rounded())))
        activity.movingSeconds = metrics.movingSeconds
        activity.averageSpeedMetersPerSecond = metrics.averageSpeedMetersPerSecond
        activity.maxSpeedMetersPerSecond = metrics.maxSpeedMetersPerSecond
        updateElevationAndPace(
            &activity,
            filteredElevationGainMeters: filteredElevationGainMeters,
            filteredHighestElevationMeters: filteredHighestElevationMeters
        )
        let now = Date()
        if now.timeIntervalSince(lastPersistedAt) >= 1 {
            try database.updateOutdoorActivity(id: activity.id.uuidString, manifest: activity.coreValue)
            lastPersistedAt = now
        }
        activeActivity = activity
        replacePublished(activity)
        if let target = activity.timeTargetSeconds, activity.elapsedSeconds >= target, targetReachedActivityID == nil {
            targetReachedActivityID = activity.id
        }
    }

    func pauseManually(at date: Date = Date()) throws {
        try transition(to: .manualPaused, at: date, automatic: false)
    }

    func resumeManually(at date: Date = Date()) throws {
        guard var activity = activeActivity, activity.recordingState == .manualPaused else { return }
        closeOpenPause(in: &activity, at: date)
        activity.recordingState = .recording
        try saveActive(activity)
    }

    func pauseAutomatically(at date: Date = Date()) throws {
        try transition(to: .autoPaused, at: date, automatic: true)
    }

    func resumeAutomatically(at date: Date = Date()) throws {
        guard var activity = activeActivity, activity.recordingState == .autoPaused else { return }
        closeOpenPause(in: &activity, at: date)
        activity.recordingState = .recording
        try saveActive(activity)
    }

    func lap(at date: Date = Date()) throws {
        guard var activity = activeActivity else { return }
        let lap = OutdoorLap(number: activity.laps.count + 1, timestamp: date, elapsedSeconds: activity.elapsedSeconds, distanceMeters: activity.distanceMeters)
        activity.laps.append(lap)
        try saveActive(activity)
    }
    func checkpoint(at date: Date = Date()) throws {
        guard var activity = activeActivity, !activity.finished else { return }
        activity.elapsedSeconds = max(activity.elapsedSeconds, max(0, Int(date.timeIntervalSince(activity.startedAt).rounded())))
        try saveActive(activity)
    }

    @discardableResult
    func finish(at date: Date = Date()) throws -> OutdoorActivity? {
        guard var activity = activeActivity else { return nil }
        if activity.distanceMeters < 3 {
            try database.deleteOutdoorActivity(id: activity.id.uuidString)
            activeActivity = nil
            activePoints = []
            removePublished(id: activity.id)
            return nil
        }
        closeOpenPause(in: &activity, at: date)
        activity.endedAt = date
        activity.elapsedSeconds = max(activity.elapsedSeconds, max(0, Int(date.timeIntervalSince(activity.startedAt).rounded())))
        activity.recordingState = .finished
        activity.finished = true
        try saveActive(activity)
        activeActivity = nil
        activePoints = []
        return activities.first(where: { $0.id == activity.id }) ?? activity
    }
    func discardActive() throws {
        guard let activity = activeActivity else { return }
        try database.deleteOutdoorActivity(id: activity.id.uuidString)
        activeActivity = nil
        activePoints = []
        removePublished(id: activity.id)
    }

    func resume(_ activity: OutdoorActivity) throws {
        var resumed = activities.first(where: { $0.id == activity.id }) ?? activity
        if resumed.finished {
            resumed.finished = false
            resumed.endedAt = nil
            resumed.recordingState = .recording
            try database.updateOutdoorActivity(id: resumed.id.uuidString, manifest: resumed.coreValue)
        }
        let points = try database.readOutdoorTrackPoints(id: resumed.id.uuidString).map(OutdoorTrackPoint.init)
        activeActivity = resumed
        activePoints = points
        lastPersistedAt = Date()
        replacePublished(resumed)
    }

    func finishRecovered(_ activity: OutdoorActivity) throws -> OutdoorActivity? {
        try resume(activity)
        return try finish()
    }

    func delete(_ activity: OutdoorActivity) throws {
        try database.deleteOutdoorActivity(id: activity.id.uuidString)
        removePublished(id: activity.id)
        if activeActivity?.id == activity.id {
            activeActivity = nil
            activePoints = []
        }
    }

    func clearFinished() throws {
        for activity in activities where activity.finished {
            try database.deleteOutdoorActivity(id: activity.id.uuidString)
        }
        reload()
    }

    func trackPoints(for activity: OutdoorActivity) -> [OutdoorTrackPoint] {
        ((try? database.readOutdoorTrackPoints(id: activity.id.uuidString)) ?? []).map(OutdoorTrackPoint.init)
    }


    func plannedRoute(withID id: String) -> PlannedRoute? {
        plannedRoutes.first { $0.id.uuidString.caseInsensitiveCompare(id) == .orderedSame }
    }

    func savePlannedRoute(_ route: PlannedRoute) throws {
        try database.bootstrapIfNeeded()
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(route)
        let url = routesDirectory.appendingPathComponent("\(route.id.uuidString).json")
        try data.write(to: url, options: .atomic)
        plannedRoutes = loadPlannedRoutes()
    }

    func deletePlannedRoute(_ route: PlannedRoute) throws {
        let url = routesDirectory.appendingPathComponent("\(route.id.uuidString).json")
        try FileManager.default.removeItem(at: url)
        plannedRoutes.removeAll { $0.id == route.id }
    }



    private func loadPlannedRoutes() -> [PlannedRoute] {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        guard let urls = try? FileManager.default.contentsOfDirectory(
            at: routesDirectory,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        ) else {
            return []
        }
        return urls
            .filter { $0.pathExtension == "json" }
            .compactMap { try? decoder.decode(PlannedRoute.self, from: Data(contentsOf: $0)) }
            .sorted { $0.createdAt < $1.createdAt }
    }

    func updateTitle(_ title: String, for activity: OutdoorActivity) throws {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        _ = try persistMutation(activity) { updated in
            updated.title = trimmed.isEmpty ? updated.kind.defaultTitle : trimmed
        }
    }

    @discardableResult
    private func persistMutation(
        _ activity: OutdoorActivity,
        _ mutation: (inout OutdoorActivity) -> Void
    ) throws -> OutdoorActivity {
        var updated = activities.first(where: { $0.id == activity.id })
            ?? (activeActivity?.id == activity.id ? activeActivity : nil)
            ?? activity
        mutation(&updated)
        try database.updateOutdoorActivity(id: updated.id.uuidString, manifest: updated.coreValue)
        if activeActivity?.id == updated.id {
            activeActivity = updated
        }
        replacePublished(updated)
        return updated
    }

    func setStarred(_ starred: Bool, for activity: OutdoorActivity) throws {
        _ = try persistMutation(activity) { $0.starred = starred }
    }

    func updateStarred(_ starred: Bool, for activity: OutdoorActivity) throws {
        try setStarred(starred, for: activity)
    }

    func toggleStarred(for activity: OutdoorActivity) throws {
        _ = try persistMutation(activity) { $0.starred.toggle() }
    }

    func setVisibility(_ visibility: OutdoorActivityVisibility, for activity: OutdoorActivity) throws {
        _ = try persistMutation(activity) {
            $0.visibility = visibility
            if visibility == .publicVisibility { $0.hasPublicMetadata = true }
        }
    }

    func updateVisibility(_ visibility: OutdoorActivityVisibility, for activity: OutdoorActivity) throws {
        try setVisibility(visibility, for: activity)
    }

    func setPublicDescription(_ description: String, for activity: OutdoorActivity) throws {
        _ = try persistMutation(activity) {
            $0.publicDescription = description
            $0.hasPublicMetadata = true
        }
    }

    func updatePublicDescription(_ description: String, for activity: OutdoorActivity) throws {
        try setPublicDescription(description, for: activity)
    }

    func setTags(_ tags: [String], for activity: OutdoorActivity) throws {
        _ = try persistMutation(activity) {
            $0.tags = tags
            $0.hasPublicMetadata = true
        }
    }

    func updateTags(_ tags: [String], for activity: OutdoorActivity) throws {
        try setTags(tags, for: activity)
    }

    func setAllowComments(_ allow: Bool, for activity: OutdoorActivity) throws {
        _ = try persistMutation(activity) {
            $0.allowComments = allow
            $0.hasPublicMetadata = true
        }
    }

    func updateAllowComments(_ allow: Bool, for activity: OutdoorActivity) throws {
        try setAllowComments(allow, for: activity)
    }

    func setHideStartFinish(_ hide: Bool, for activity: OutdoorActivity) throws {
        _ = try persistMutation(activity) {
            $0.hideStartFinish = hide
            $0.hasPublicMetadata = true
        }
    }

    func setEndpointPrivacyMeters(_ meters: Int, for activity: OutdoorActivity) throws {
        _ = try persistMutation(activity) {
            $0.endpointPrivacyMeters = TimeMasterCore.OutdoorActivityManifest.clampedEndpointPrivacyMeters(meters)
            $0.hasPublicMetadata = true
        }
    }

    func updateEndpointPrivacyMeters(_ meters: Int, for activity: OutdoorActivity) throws {
        try setEndpointPrivacyMeters(meters, for: activity)
    }

    func setShowPlayerTracks(_ show: Bool, for activity: OutdoorActivity) throws {
        _ = try persistMutation(activity) {
            $0.showPlayerTracks = show
            $0.hasPublicMetadata = true
        }
    }

    func updateShowPlayerTracks(_ show: Bool, for activity: OutdoorActivity) throws {
        try setShowPlayerTracks(show, for: activity)
    }

    func setPlayedTracks(_ tracks: [OutdoorPlayedTrackEvent], for activity: OutdoorActivity) throws {
        _ = try persistMutation(activity) { $0.playedTracks = tracks }
    }

    func updatePlayedTracks(_ tracks: [OutdoorPlayedTrackEvent], for activity: OutdoorActivity) throws {
        try setPlayedTracks(tracks, for: activity)
    }

    func addPlayedTrackEvent(_ event: OutdoorPlayedTrackEvent, for activity: OutdoorActivity) throws {
        _ = try persistMutation(activity) { $0.playedTracks.append(event) }
    }


    @discardableResult
    func establish(
        _ activity: OutdoorActivity,
        visibility: OutdoorActivityVisibility,
        publicDescription: String? = nil,
        tags: [String]? = nil,
        allowComments: Bool? = nil,
        hideStartFinish: Bool? = nil,
        endpointPrivacyMeters: Int? = nil,
        showPlayerTracks: Bool? = nil,
        at date: Date = Date()
    ) throws -> OutdoorActivity {
        guard activity.finished else { throw OutdoorActivityStoreError.cannotEstablishUnfinished }
        return try persistMutation(activity) {
            $0.establishedAt = date
            $0.visibility = visibility
            if let publicDescription { $0.publicDescription = publicDescription }
            if let tags { $0.tags = tags }
            if let allowComments { $0.allowComments = allowComments }
            if let hideStartFinish { $0.hideStartFinish = hideStartFinish }
            if let endpointPrivacyMeters {
                $0.endpointPrivacyMeters = TimeMasterCore.OutdoorActivityManifest.clampedEndpointPrivacyMeters(endpointPrivacyMeters)
            }
            if let showPlayerTracks { $0.showPlayerTracks = showPlayerTracks }
            if visibility == .publicVisibility { $0.hasPublicMetadata = true }
        }
    }
    private func updateElevationAndPace(
        _ activity: inout OutdoorActivity,
        filteredElevationGainMeters: Double? = nil,
        filteredHighestElevationMeters: Double? = nil
    ) {
        if activity.distanceMeters > 0, activity.movingSeconds > 0 {
            activity.averagePaceSecondsPerKilometer = Double(activity.movingSeconds) * 1_000 / activity.distanceMeters
        } else {
            activity.averagePaceSecondsPerKilometer = nil
        }

        let absoluteElevations = activePoints.compactMap(\.elevationMeters).filter(\.isFinite)
        if let highest = filteredHighestElevationMeters {
            activity.highestElevationMeters = max(activity.highestElevationMeters ?? highest, highest)
        } else if let highest = absoluteElevations.max() {
            activity.highestElevationMeters = highest
        }

        if let filteredElevationGainMeters {
            activity.elevationGainMeters = max(activity.elevationGainMeters ?? 0, filteredElevationGainMeters)
            return
        }

        var gain = 0.0
        var previousAbsolute: Double?
        var previousRelative: Double?
        for point in activePoints {
            if let elevation = point.elevationMeters, elevation.isFinite {
                if let previousAbsolute {
                    let change = elevation - previousAbsolute
                    if change > 1.5 { gain += change }
                }
                previousAbsolute = elevation
                previousRelative = nil
            } else if let relative = point.barometricRelativeAltitudeMeters, relative.isFinite {
                if let previousRelative {
                    let change = relative - previousRelative
                    if change > 1.5 { gain += change }
                }
                previousRelative = relative
            }
        }
        if !absoluteElevations.isEmpty || activePoints.contains(where: { $0.barometricRelativeAltitudeMeters?.isFinite == true }) {
            activity.elevationGainMeters = gain
        }
    }

    private func transition(to state: OutdoorRecordingState, at date: Date, automatic: Bool) throws {
        guard var activity = activeActivity, activity.recordingState == .recording else { return }
        activity.pauseIntervals.append(OutdoorPauseInterval(startedAt: date, automatic: automatic))
        activity.recordingState = state
        try saveActive(activity)
    }

    private func closeOpenPause(in activity: inout OutdoorActivity, at date: Date) {
        guard let index = activity.pauseIntervals.lastIndex(where: { $0.endedAt == nil }) else { return }
        activity.pauseIntervals[index].endedAt = date
    }

    private func saveActive(_ activity: OutdoorActivity) throws {
        try database.updateOutdoorActivity(id: activity.id.uuidString, manifest: activity.coreValue)
        activeActivity = activity
        replacePublished(activity)
    }

    private func replacePublished(_ activity: OutdoorActivity) {
        if let index = activities.firstIndex(where: { $0.id == activity.id }) {
            activities[index] = activity
        } else {
            activities.insert(activity, at: 0)
        }
        activities.sort { $0.startedAt > $1.startedAt }
        recoverableActivities = activities.filter { !$0.finished && $0.establishedAt == nil }
    }

    private func removePublished(id: UUID) {
        activities.removeAll { $0.id == id }
        recoverableActivities.removeAll { $0.id == id }
    }
}
