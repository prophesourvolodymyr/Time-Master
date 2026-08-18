import Foundation
import Combine
import TimeMasterCore

final class OutdoorActivityStore: ObservableObject {
    @Published private(set) var activities: [OutdoorActivity] = []
    @Published private(set) var recoverableActivities: [OutdoorActivity] = []
    @Published private(set) var targetReachedActivityID: UUID?
    @Published private(set) var plannedRoutes: [PlannedRoute] = []

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

    // MARK: - Persistence

    func reload() {
        try? database.bootstrapIfNeeded()
        plannedRoutes = loadPlannedRoutes()
        var loaded: [OutdoorActivity] = []
        for manifest in (try? database.listOutdoorActivities()) ?? [] {
            guard var activity = try? OutdoorActivity(core: manifest) else { continue }
            let points = ((try? database.readOutdoorTrackPoints(id: manifest.id)) ?? []).map(OutdoorTrackPoint.init)
            let metrics = OutdoorMetricsCalculator.aggregate(points: points, pauses: activity.pauseIntervals)
            if activity.trackPointCount != points.count || abs(activity.distanceMeters - metrics.distanceMeters) > 1 || activity.elapsedSeconds != metrics.elapsedSeconds || activity.movingSeconds != metrics.movingSeconds {
                activity.trackPointCount = points.count
                activity.distanceMeters = metrics.distanceMeters
                activity.elapsedSeconds = metrics.elapsedSeconds
                activity.movingSeconds = metrics.movingSeconds
                activity.averageSpeedMetersPerSecond = metrics.averageSpeedMetersPerSecond
                activity.maxSpeedMetersPerSecond = metrics.maxSpeedMetersPerSecond
                try? database.updateOutdoorActivity(id: activity.id.uuidString, manifest: activity.coreValue)
            }
            loaded.append(activity)
        }
        activities = loaded.sorted { $0.startedAt > $1.startedAt }
        recoverableActivities = activities.filter { !$0.finished }
    }

    func begin(kind: OutdoorActivityKind, timeTargetSeconds: Int? = nil, plannedRoute: PlannedRoute? = nil) throws -> OutdoorActivity {
        var activity = OutdoorActivity(kind: kind, timeTargetSeconds: timeTargetSeconds)
        activity.plannedRouteID = plannedRoute?.id.uuidString
        try database.createOutdoorActivity(id: activity.id.uuidString, manifest: activity.coreValue)
        activeActivity = activity
        activePoints = []
        targetReachedActivityID = nil
        activities.insert(activity, at: 0)
        return activity
    }

    var active: OutdoorActivity? { activeActivity }
    var activeRoute: [OutdoorTrackPoint] { activePoints }

    func append(point: OutdoorTrackPoint) throws {
        guard var activity = activeActivity, !activity.finished else { return }
        try database.appendOutdoorTrackPoint(id: activity.id.uuidString, point: point.coreValue)
        activePoints.append(point)
        activity.trackPointCount = activePoints.count
        let metrics = OutdoorMetricsCalculator.aggregate(points: activePoints, pauses: activity.pauseIntervals)
        activity.distanceMeters = metrics.distanceMeters
        activity.elapsedSeconds = metrics.elapsedSeconds
        activity.movingSeconds = metrics.movingSeconds
        activity.averageSpeedMetersPerSecond = metrics.averageSpeedMetersPerSecond
        activity.maxSpeedMetersPerSecond = metrics.maxSpeedMetersPerSecond
        activeActivity = activity
        replacePublished(activity)
        let now = Date()
        if now.timeIntervalSince(lastPersistedAt) >= 1 {
            try database.updateOutdoorActivity(id: activity.id.uuidString, manifest: activity.coreValue)
            lastPersistedAt = now
        }
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

    @discardableResult
    func finish(at date: Date = Date()) throws -> OutdoorActivity? {
        guard var activity = activeActivity else { return nil }
        closeOpenPause(in: &activity, at: date)
        activity.endedAt = date
        activity.recordingState = .finished
        activity.finished = true
        try saveActive(activity)
        activeActivity = nil
        activePoints = []
        reload()
        return activities.first(where: { $0.id == activity.id }) ?? activity
    }

    func discardActive() throws {
        guard let activity = activeActivity else { return }
        try database.deleteOutdoorActivity(id: activity.id.uuidString)
        activeActivity = nil
        activePoints = []
        activities.removeAll { $0.id == activity.id }
        recoverableActivities.removeAll { $0.id == activity.id }
    }

    func resume(_ activity: OutdoorActivity) throws {
        guard !activity.finished else { return }
        activeActivity = activity
        activePoints = ((try? database.readOutdoorTrackPoints(id: activity.id.uuidString)) ?? []).map(OutdoorTrackPoint.init)
        lastPersistedAt = Date()
    }

    func finishRecovered(_ activity: OutdoorActivity) throws -> OutdoorActivity? {
        try resume(activity)
        return try finish()
    }

    func delete(_ activity: OutdoorActivity) throws {
        try database.deleteOutdoorActivity(id: activity.id.uuidString)
        activities.removeAll { $0.id == activity.id }
        recoverableActivities.removeAll { $0.id == activity.id }
    }

    func clearFinished() throws {
        for activity in activities where activity.finished { try database.deleteOutdoorActivity(id: activity.id.uuidString) }
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
        var updated = activity
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        updated.title = trimmed.isEmpty ? activity.kind.defaultTitle : trimmed
        try database.updateOutdoorActivity(id: updated.id.uuidString, manifest: updated.coreValue)
        replacePublished(updated)
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
        activeActivity = activity
        try database.updateOutdoorActivity(id: activity.id.uuidString, manifest: activity.coreValue)
        replacePublished(activity)
    }

    private func replacePublished(_ activity: OutdoorActivity) {
        if let index = activities.firstIndex(where: { $0.id == activity.id }) { activities[index] = activity }
        else { activities.insert(activity, at: 0) }
        activities.sort { $0.startedAt > $1.startedAt }
        recoverableActivities = activities.filter { !$0.finished }
    }
}
