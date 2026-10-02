#if os(iOS)
import Foundation
import Combine

enum TripPlannerEntry: Equatable {
    case build, custom, preview
}

@MainActor
final class OutdoorTripEditor: ObservableObject {
    @Published private(set) var route: PlannedRoute
    @Published private(set) var isRouting = false
    @Published private(set) var errorMessage: String?
    @Published private(set) var revision = 0
    @Published private(set) var canUndo = false
    @Published private(set) var mapPoints: [OutdoorTrackPoint]
    @Published var picking = false
    @Published var replacingStopID: UUID?
    @Published var isGenerating = false
    @Published private(set) var currentLocation: TripCoordinate?
    private let store: OutdoorActivityStore
    private var routeTask: Task<Void, Never>?
    private var generation = 0
    private var undoStack: [PlannedRoute] = []
    private var lastRoutedTrip: OutdoorTrip?
    private var dragOriginal: PlannedRoute?
    private var dragStopID: UUID?
    private var dragControlIndex: Int?
    private var importedTrip: OutdoorTrip
    private var openedTitle: String

    var trip: OutdoorTrip { route.trip ?? importedTrip }
    var canSave: Bool { (route.trip == nil ? route.points.count > 1 : trip.isRouted) && !isRouting && !isGenerating && dragOriginal == nil }
    var hasChanges: Bool { canUndo || route.title != openedTitle }
    var isDragging: Bool { dragOriginal != nil }

    init(route: PlannedRoute?, kind: OutdoorActivityKind, store: OutdoorActivityStore) {
        self.store = store
        var value = route ?? PlannedRoute(title: "New trip", points: [])
        if value.trip == nil, value.points.isEmpty { value.trip = OutdoorTrip(kind: kind) }
        self.route = value
        mapPoints = value.points
        importedTrip = OutdoorTrip(kind: kind, stops: Self.stops(for: value))
        openedTitle = value.title
        lastRoutedTrip = value.trip?.isRouted == true ? value.trip : nil
    }

    deinit { routeTask?.cancel() }

    func open(_ saved: PlannedRoute?, kind: OutdoorActivityKind) {
        generation += 1
        routeTask?.cancel()
        finishDragState()
        undoStack.removeAll(keepingCapacity: true)
        canUndo = false
        isRouting = false
        isGenerating = false
        errorMessage = nil
        picking = false
        replacingStopID = nil
        var value = saved ?? PlannedRoute(title: "New trip", points: [])
        if value.trip == nil, value.points.isEmpty { value.trip = OutdoorTrip(kind: kind) }
        route = value
        mapPoints = value.points
        importedTrip = OutdoorTrip(kind: kind, stops: Self.stops(for: value))
        openedTitle = value.title
        lastRoutedTrip = value.trip?.isRouted == true ? value.trip : nil
        revision += 1
    }

    func useSuggestion(_ suggestion: PlannedRoute) {
        generation += 1
        routeTask?.cancel()
        rememberUndo()
        route.trip = suggestion.trip
        route.points = suggestion.points
        if route.title == "New trip" { route.title = suggestion.title }
        mapPoints = route.points
        lastRoutedTrip = route.trip
        isRouting = false
        errorMessage = nil
        revision += 1
        persistRecovery()
    }

    func pick(_ coordinate: TripCoordinate) {
        putStop(TripPlace(id: UUID().uuidString, name: "Map point", detail: "", coordinate: coordinate), replacing: replacingStopID)
        picking = false
        replacingStopID = nil
    }

    func setCurrentLocation(_ coordinate: TripCoordinate) {
        guard coordinate.isValid else { return }
        currentLocation = coordinate
        guard trip.stops.isEmpty, route.points.isEmpty, coordinate.isValid else { return }
        change { $0.stops = [TripStop(name: "Current location", coordinate: coordinate)] }
    }

    func rename(_ title: String) {
        route.title = title
        persistRecovery()
    }

    func change(_ mutation: (inout OutdoorTrip) -> Void) {
        rememberUndo()
        var trip = self.trip
        mutation(&trip)
        trip.updatedAt = Date()
        route.trip = trip
        revision += 1
        persistRecovery()
        recalculate()
    }

    func putStop(_ place: TripPlace, replacing id: UUID?) {
        change { trip in
            if let id, let index = trip.stops.firstIndex(where: { $0.id == id }) {
                trip.stops[index].name = place.name
                trip.stops[index].coordinate = place.coordinate
                trip.stops[index].shapingPoints = []
                if index + 1 < trip.stops.count { trip.stops[index + 1].shapingPoints = [] }
            } else {
                trip.stops.append(TripStop(name: place.name, coordinate: place.coordinate))
            }
        }
    }

    func moveStop(_ id: UUID, by offset: Int) {
        change { trip in
            guard let index = trip.stops.firstIndex(where: { $0.id == id }), trip.stops.indices.contains(index + offset) else { return }
            trip.stops.swapAt(index, index + offset)
            for i in max(0, min(index, index + offset))...min(trip.stops.count - 1, max(index, index + offset) + 1) {
                trip.stops[i].shapingPoints = []
            }
        }
    }

    func deleteStop(_ id: UUID) {
        change { trip in
            guard let index = trip.stops.firstIndex(where: { $0.id == id }) else { return }
            trip.stops.remove(at: index)
            if index < trip.stops.count { trip.stops[index].shapingPoints = [] }
        }
    }

    func undo() {
        guard let previous = undoStack.popLast() else { return }
        generation += 1
        routeTask?.cancel()
        isRouting = false
        route = previous
        mapPoints = previous.points
        revision += 1
        canUndo = !undoStack.isEmpty
        errorMessage = nil
        persistRecovery()
        if !trip.isRouted, trip.stops.count >= 2 { recalculate() }
    }

    func beginDrag(legID: UUID, coordinateIndex: Int) {
        guard !isRouting, !isGenerating, !isDragging, trip.isRouted,
              let leg = trip.legs.first(where: { $0.id == legID && $0.mode == .active }),
              let stopIndex = trip.stops.firstIndex(where: { $0.id == legID }),
              coordinateIndex >= 0, coordinateIndex < leg.coordinates.count else { return }
        dragOriginal = route
        dragStopID = legID
        let insertion = max(0, min(trip.stops[stopIndex].shapingPoints.count, leg.controlPointIndices.dropFirst().dropLast().prefix { $0 <= coordinateIndex }.count))
        let lowerLimit = leg.controlPointIndices.indices.contains(insertion) ? leg.controlPointIndices[insertion] : 0
        let upperLimit = leg.controlPointIndices.indices.contains(insertion + 1) ? leg.controlPointIndices[insertion + 1] : leg.coordinates.count - 1
        var lower = coordinateIndex
        var upper = coordinateIndex
        var distance = 0.0
        while lower > lowerLimit, distance < 150 {
            distance += leg.coordinates[lower].distance(to: leg.coordinates[lower - 1])
            lower -= 1
        }
        distance = 0
        while upper < upperLimit, distance < 150 {
            distance += leg.coordinates[upper].distance(to: leg.coordinates[upper + 1])
            upper += 1
        }
        var controls: [TripCoordinate] = []
        if lower > lowerLimit { controls.append(leg.coordinates[lower]) }
        dragControlIndex = insertion + controls.count
        controls.append(leg.coordinates[coordinateIndex])
        if upper < upperLimit { controls.append(leg.coordinates[upper]) }
        var updated = trip
        updated.stops[stopIndex].shapingPoints.insert(contentsOf: controls, at: insertion)
        route.trip = updated
        errorMessage = nil
    }

    func updateDrag(_ coordinate: TripCoordinate, ended: Bool) {
        guard coordinate.isValid, let id = dragStopID, let insertion = dragControlIndex,
              let stop = trip.stops.firstIndex(where: { $0.id == id }) else { return }
        var updated = trip
        updated.stops[stop].shapingPoints[insertion] = coordinate
        route.trip = updated
        recalculate(delay: ended ? 0 : 220_000_000, completingDrag: ended)
    }

    func cancelDrag() {
        guard let original = dragOriginal else { return }
        generation += 1
        routeTask?.cancel()
        route = original
        mapPoints = original.points
        isRouting = false
        finishDragState()
        revision += 1
    }

    func recalculate(delay: UInt64 = 0, completingDrag: Bool = false) {
        generation += 1
        let token = generation
        routeTask?.cancel()
        guard trip.stops.count >= 2 else {
            route.trip?.legs = []
            route.trip?.routingFingerprint = nil
            route.points = []
            mapPoints = []
            isRouting = false
            return
        }
        let input = trip
        let cached = lastRoutedTrip
        isRouting = true
        errorMessage = nil
        routeTask = Task { [weak self] in
            do {
                if delay > 0 { try await Task.sleep(nanoseconds: delay) }
                let routed = try await OutdoorTripService().route(input, previous: cached)
                try Task.checkCancellation()
                guard let self, token == self.generation else { return }
                self.route.trip = routed
                self.route.points = routed.points
                self.mapPoints = self.route.points
                self.lastRoutedTrip = routed
                self.isRouting = false
                self.revision += 1
                if completingDrag {
                    if let original = self.dragOriginal { self.undoStack.append(original); self.canUndo = true }
                    self.finishDragState()
                }
                if !self.isDragging { self.persistRecovery() }
            } catch {
                guard let self, token == self.generation, !Task.isCancelled else { return }
                self.isRouting = false
                if completingDrag { self.cancelDrag() }
                self.errorMessage = error.localizedDescription
            }
        }
    }

    func save(draft: Bool) throws -> PlannedRoute {
        guard draft || canSave else { throw TripServiceError.message("Wait for a valid route before saving, or keep this as a draft.") }
        if isDragging { cancelDrag() }
        route.trip?.isDraft = draft
        route.trip?.updatedAt = Date()
        let title = route.title.trimmingCharacters(in: .whitespacesAndNewlines)
        route.title = title.isEmpty ? "\(trip.kind.displayName) trip" : title
        try store.savePlannedRoute(route)
        try store.saveTripRecovery(nil)
        generation += 1
        routeTask?.cancel()
        return route
    }

    func delete() throws {
        generation += 1
        routeTask?.cancel()
        if store.plannedRoutes.contains(where: { $0.id == route.id }) { try store.deletePlannedRoute(route) }
        try store.saveTripRecovery(nil)
    }

    func discardEdits() throws {
        generation += 1
        routeTask?.cancel()
        try store.saveTripRecovery(nil)
    }

    func preserve() {
        if isDragging { cancelDrag() }
        persistRecovery()
    }

    func suspend() {
        cancelDrag()
        generation += 1
        routeTask?.cancel()
        isRouting = false
        picking = false
    }

    private func rememberUndo() {
        undoStack.append(route)
        if undoStack.count > 30 { undoStack.removeFirst() }
        canUndo = true
    }

    private func finishDragState() {
        dragOriginal = nil
        dragStopID = nil
        dragControlIndex = nil
    }

    private static func stops(for route: PlannedRoute) -> [TripStop] {
        guard route.trip == nil, let first = route.points.first, let last = route.points.last, route.points.count > 1 else { return [] }
        let start = TripStop(name: "Imported start", coordinate: TripCoordinate(latitude: first.latitude, longitude: first.longitude))
        var finish = TripStop(name: "Imported finish", coordinate: TripCoordinate(latitude: last.latitude, longitude: last.longitude))
        let step = max(1, route.points.count / 12)
        for index in stride(from: step, to: route.points.count - 1, by: step) {
            let point = route.points[index]
            finish.shapingPoints.append(TripCoordinate(latitude: point.latitude, longitude: point.longitude))
        }
        return [start, finish]
    }

    private func persistRecovery() {
        do { try store.saveTripRecovery(route) }
        catch { errorMessage = "Could not protect this edit: \(error.localizedDescription)" }
    }
}
#endif
