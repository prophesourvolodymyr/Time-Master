import Foundation
import Combine

@MainActor
final class MusicLibraryStore: ObservableObject {
    @Published private(set) var items: [MusicLibraryItem] = []
    @Published private(set) var generalItemIDs: [UUID] = []
    @Published private(set) var typeItemIDs: [String: [UUID]] = [:]
    @Published private(set) var workoutItemIDs: [UUID: [UUID]] = [:]
    @Published private(set) var workouts: [Workout] = []
    @Published private(set) var workoutTypes: [WorkoutType] = WorkoutType.builtIn
    @Published var selectedDestinationByFamily: [MusicDestinationFamily: MusicDestination] = [.general: .general]
    private let defaults: UserDefaults
    private let itemsKey = "music_library_items_v2"
    private let membershipsKey = "music_library_memberships_v2"
    private let selectionKey = "music_library_selection_v1"
    private struct PersistedMemberships: Codable { var general: [UUID]; var types: [String: [UUID]]; var mine: [String: [UUID]] }
    private struct PersistedSelection: Codable { var typeID: String?; var mineID: UUID? }

    init(workouts: [Workout] = [], userDefaults: UserDefaults = .standard, localFilenames: [String]? = nil) {
        self.defaults = userDefaults; load()
        if !workouts.isEmpty { setWorkouts(workouts, persist: false) }
        adoptLocalMusicReferences(localFilenames ?? MusicManager.shared.trackFilenames, persist: false); persist()
    }

    var libraryItems: [MusicLibraryItem] { items }
    var generalItems: [MusicLibraryItem] { items(for: .general) }
    var selectedTypeDestination: MusicDestination? { selectedDestination(for: .type) }
    var selectedMineDestination: MusicDestination? { selectedDestination(for: .mine) }
    var typeMemberships: [String: [UUID]] { typeItemIDs }
    var mineMemberships: [UUID: [UUID]] { workoutItemIDs }
    var localItems: [MusicLibraryItem] { items.filter { $0.source == .local || $0.localReference != nil } }
    func item(id: UUID) -> MusicLibraryItem? { items.first { $0.id == id } }
    func item(withID id: UUID) -> MusicLibraryItem? { item(id: id) }
    func items(for destination: MusicDestination) -> [MusicLibraryItem] { let byID = Dictionary(uniqueKeysWithValues: items.map { ($0.id, $0) }); return itemIDs(for: destination).compactMap { byID[$0] } }
    func items(in destination: MusicDestination) -> [MusicLibraryItem] { items(for: destination) }
    func orderedItems(for destination: MusicDestination) -> [MusicLibraryItem] { items(for: destination) }
    func itemIDs(for destination: MusicDestination) -> [UUID] { switch destination { case .general: return generalItemIDs; case .workoutType(let id): return typeItemIDs[id] ?? []; case .workout(let id): return workoutItemIDs[id] ?? [] } }
    func destinations(for family: MusicDestinationFamily) -> [MusicDestination] { switch family { case .general: return [.general]; case .type: return workoutTypes.map { .workoutType(id: $0.id) }; case .mine: return workouts.map { .workout(id: $0.id) } } }
    func destination(for workoutType: WorkoutType) -> MusicDestination { .workoutType(id: workoutType.id) }
    func destination(for workout: Workout) -> MusicDestination { .workout(id: workout.id) }
    func workout(for id: UUID) -> Workout? { workouts.first { $0.id == id } }
    func workoutType(for id: String) -> WorkoutType? { workoutTypes.first { $0.id == id } }
    func destinationName(_ destination: MusicDestination) -> String { switch destination { case .general: return "General"; case .workoutType(let id): return workoutTypes.first { $0.id == id }?.name ?? id; case .workout(let id): return workouts.first { $0.id == id }?.name ?? "Workout" } }

    func selectedDestination(for family: MusicDestinationFamily) -> MusicDestination? { selectedDestinationByFamily[family] }
    func select(destination: MusicDestination) { selectedDestinationByFamily[destination.family] = destination; persistSelection(); objectWillChange.send() }
    func selectDestination(_ destination: MusicDestination) { select(destination: destination) }
    func select(workoutType: WorkoutType) { select(destination: .workoutType(id: workoutType.id)) }
    func select(workout: Workout) { select(destination: .workout(id: workout.id)) }

    func totalDuration(for destination: MusicDestination) -> TimeInterval { items(for: destination).reduce(0) { $0 + $1.totalDuration } }
    var generalTotalDuration: TimeInterval { totalDuration(for: .general) }
    func duration(for destination: MusicDestination) -> TimeInterval { totalDuration(for: destination) }
    func formattedDuration(for destination: MusicDestination) -> String { Self.formattedDuration(totalDuration(for: destination)) }
    static func formattedDuration(_ duration: TimeInterval) -> String { let minutes = max(0, Int((duration / 60).rounded())), hours = minutes / 60, remainder = minutes % 60; if hours > 0 { return remainder == 0 ? "\(hours)h" : "\(hours)h \(remainder)m" }; return "\(remainder)m" }
    func formattedDuration(_ duration: TimeInterval) -> String { Self.formattedDuration(duration) }

    @discardableResult func add(_ item: MusicLibraryItem, to destination: MusicDestination, at position: Int? = nil) -> Bool { if let index = items.firstIndex(where: { $0.id == item.id }) { items[index] = item } else { items.append(item) }; var ids = itemIDs(for: destination); guard !ids.contains(item.id) else { persist(); return false }; ids.insert(item.id, at: max(0, min(position ?? ids.count, ids.count))); setItemIDs(ids, for: destination); persist(); return true }
    @discardableResult func add(item: MusicLibraryItem, to destination: MusicDestination, position: Int? = nil) -> Bool { add(item, to: destination, at: position) }
    @discardableResult func addItem(_ item: MusicLibraryItem, to destination: MusicDestination, at position: Int? = nil) -> Bool { add(item, to: destination, at: position) }
    @discardableResult func addLocalTrack(filename: String, displayName: String? = nil, duration: TimeInterval = 0, to destination: MusicDestination = .general, at position: Int? = nil) -> MusicLibraryItem { let ref = MusicLocalTrackReference(filename: filename, displayName: displayName, duration: duration); let item = items.first { $0.localReference?.filename == filename } ?? MusicLibraryItem(id: stableLocalItemID(for: filename), name: ref.displayName, source: .local, localReference: ref, duration: duration); _ = add(item, to: destination, at: position); return item }
    @discardableResult func remove(itemID: UUID, from destination: MusicDestination) -> Bool { var ids = itemIDs(for: destination), oldCount = ids.count; ids.removeAll { $0 == itemID }; guard ids.count != oldCount else { return false }; setItemIDs(ids, for: destination); persist(); return true }
    @discardableResult func remove(_ item: MusicLibraryItem, from destination: MusicDestination) -> Bool { remove(itemID: item.id, from: destination) }
    @discardableResult func removeItem(_ itemID: UUID, from destination: MusicDestination) -> Bool { remove(itemID: itemID, from: destination) }
    @discardableResult func deleteItem(_ itemID: UUID) -> Bool { var changed = false; for destination in allDestinations() { changed = remove(itemID: itemID, from: destination) || changed }; if let index = items.firstIndex(where: { $0.id == itemID }) { items.remove(at: index); changed = true }; if changed { persist() }; return changed }
    @discardableResult func reorder(itemID: UUID, in destination: MusicDestination, to position: Int) -> Bool { var ids = itemIDs(for: destination); guard let old = ids.firstIndex(of: itemID) else { return false }; ids.remove(at: old); ids.insert(itemID, at: max(0, min(position, ids.count))); setItemIDs(ids, for: destination); persist(); return true }
    @discardableResult func moveItem(_ itemID: UUID, from source: MusicDestination, to destination: MusicDestination, at position: Int? = nil) -> Bool { if source == destination { return reorder(itemID: itemID, in: source, to: position ?? 0) }; if isWorkoutDestination(source) && isWorkoutDestination(destination) { return false }; guard item(id: itemID) != nil, itemIDs(for: source).contains(itemID) else { return false }; var target = itemIDs(for: destination); target.removeAll { $0 == itemID }; target.insert(itemID, at: max(0, min(position ?? target.count, target.count))); setItemIDs(target, for: destination); _ = remove(itemID: itemID, from: source); persist(); return true }
    @discardableResult func move(_ itemID: UUID, from source: MusicDestination, to destination: MusicDestination, at position: Int? = nil) -> Bool { moveItem(itemID, from: source, to: destination, at: position) }
    @discardableResult func insert(itemID: UUID, into destination: MusicDestination, at position: Int) -> Bool { guard item(id: itemID) != nil else { return false }; var ids = itemIDs(for: destination); ids.removeAll { $0 == itemID }; ids.insert(itemID, at: max(0, min(position, ids.count))); setItemIDs(ids, for: destination); persist(); return true }

    func prepareWorkoutTransfer(itemID: UUID, from source: MusicDestination, to destination: MusicDestination, at insertionIndex: Int? = nil) -> MusicTransfer? { guard isWorkoutDestination(source), isWorkoutDestination(destination), source != destination, item(id: itemID) != nil, itemIDs(for: source).contains(itemID) else { return nil }; return MusicTransfer(itemID: itemID, source: source, destination: destination, insertionIndex: insertionIndex) }
    func prepareTransfer(itemID: UUID, from source: MusicDestination, to destination: MusicDestination, at insertionIndex: Int? = nil) -> MusicTransfer? { prepareWorkoutTransfer(itemID: itemID, from: source, to: destination, at: insertionIndex) }
    @discardableResult func commitWorkoutTransfer(_ transfer: MusicTransfer, choice: MusicTransferChoice) -> Bool { guard choice != .cancel, isWorkoutDestination(transfer.source), isWorkoutDestination(transfer.destination), transfer.source != transfer.destination, itemIDs(for: transfer.source).contains(transfer.itemID), item(id: transfer.itemID) != nil else { return false }; var target = itemIDs(for: transfer.destination); target.removeAll { $0 == transfer.itemID }; target.insert(transfer.itemID, at: max(0, min(transfer.insertionIndex ?? target.count, target.count))); setItemIDs(target, for: transfer.destination); if choice == .move { _ = remove(itemID: transfer.itemID, from: transfer.source) }; persist(); return true }
    @discardableResult func commitTransfer(_ transfer: MusicTransfer, choice: MusicTransferChoice) -> Bool { commitWorkoutTransfer(transfer, choice: choice) }

    func search(_ query: String) -> [MusicLibrarySearchResult] { let q = normalizedText(query); guard !q.isEmpty else { return [] }; var result: [MusicLibrarySearchResult] = []; for destination in allDestinations() { let folderMatch = normalizedText(destinationName(destination)).contains(q); for item in items(for: destination) { let itemMatch = normalizedText(item.name).contains(q), tracks = item.tracks.filter { normalizedText($0.name).contains(q) }.map(\.id); if folderMatch || itemMatch || !tracks.isEmpty { result.append(MusicLibrarySearchResult(item: item, destination: destination, matchingTrackIDs: tracks, matchesFolder: folderMatch)) } } }; return result }
    func searchItems(_ query: String) -> [MusicLibraryItem] { var seen = Set<UUID>(); return search(query).compactMap { seen.insert($0.item.id).inserted ? $0.item : nil } }
    func searchLocal(_ query: String) -> [MusicLibrarySearchResult] { search(query) }

    func setWorkouts(_ newWorkouts: [Workout]) { setWorkouts(newWorkouts, persist: true) }
    func updateWorkouts(_ newWorkouts: [Workout]) { setWorkouts(newWorkouts) }
    func accept(workouts: [Workout]) { setWorkouts(workouts) }
    private func setWorkouts(_ newWorkouts: [Workout], persist shouldPersist: Bool) { workouts = newWorkouts; var types = WorkoutType.builtIn; for workout in newWorkouts where !types.contains(where: { $0.id == workout.type.id }) { types.append(workout.type) }; workoutTypes = types; for workout in newWorkouts { var mine = workoutItemIDs[workout.id] ?? []; for filename in workout.musicTrackFilenames where !filename.isEmpty { let item = ensureLocalItem(filename: filename); if !mine.contains(item.id) { mine.append(item.id) }; var type = typeItemIDs[workout.type.id] ?? []; if !type.contains(item.id) { type.append(item.id) }; typeItemIDs[workout.type.id] = type }; workoutItemIDs[workout.id] = mine }; sanitizeMemberships(); if shouldPersist { persist() } }
    func adoptLocalMusicReferences(_ filenames: [String]) { adoptLocalMusicReferences(filenames, persist: true) }
    func adoptMusicManagerTracks() { adoptLocalMusicReferences(MusicManager.shared.trackFilenames) }
    private func adoptLocalMusicReferences(_ filenames: [String], persist shouldPersist: Bool) { var changed = false; var seen = Set<String>(); for filename in filenames where !filename.isEmpty && seen.insert(filename).inserted { let item = items.first { $0.localReference?.filename == filename } ?? ensureLocalItem(filename: filename); if !generalItemIDs.contains(item.id) { generalItemIDs.append(item.id); changed = true } }; if shouldPersist && changed { persist() } }

    private func load() { if let data = defaults.data(forKey: itemsKey), let decoded = try? JSONDecoder().decode([MusicLibraryItem].self, from: data) { var seen = Set<UUID>(); items = decoded.filter { seen.insert($0.id).inserted } }; if let data = defaults.data(forKey: membershipsKey), let decoded = try? JSONDecoder().decode(PersistedMemberships.self, from: data) { generalItemIDs = decoded.general; typeItemIDs = decoded.types; workoutItemIDs = Dictionary(uniqueKeysWithValues: decoded.mine.compactMap { key, value in guard let id = UUID(uuidString: key) else { return nil }; return (id, value) }) } else if !items.isEmpty { generalItemIDs = items.map(\.id) }; if let data = defaults.data(forKey: selectionKey), let decoded = try? JSONDecoder().decode(PersistedSelection.self, from: data) { if let id = decoded.typeID { selectedDestinationByFamily[.type] = .workoutType(id: id) }; if let id = decoded.mineID { selectedDestinationByFamily[.mine] = .workout(id: id) } }; sanitizeMemberships() }
    private func persist() { if let data = try? JSONEncoder().encode(items) { defaults.set(data, forKey: itemsKey) }; let mine = Dictionary(uniqueKeysWithValues: workoutItemIDs.map { ($0.key.uuidString, $0.value) }); if let data = try? JSONEncoder().encode(PersistedMemberships(general: generalItemIDs, types: typeItemIDs, mine: mine)) { defaults.set(data, forKey: membershipsKey) }; persistSelection() }
    private func persistSelection() { let typeID = selectedDestinationByFamily[.type].flatMap { if case .workoutType(let id) = $0 { return id }; return nil }; let mineID = selectedDestinationByFamily[.mine].flatMap { if case .workout(let id) = $0 { return id }; return nil }; if let data = try? JSONEncoder().encode(PersistedSelection(typeID: typeID, mineID: mineID)) { defaults.set(data, forKey: selectionKey) } }
    private func allDestinations() -> [MusicDestination] { [.general] + workoutTypes.map { .workoutType(id: $0.id) } + workouts.map { .workout(id: $0.id) } }
    private func isWorkoutDestination(_ destination: MusicDestination) -> Bool { if case .general = destination { return false }; return true }
    private func setItemIDs(_ ids: [UUID], for destination: MusicDestination) { let unique = ids.uniqued(); switch destination { case .general: generalItemIDs = unique; case .workoutType(let id): typeItemIDs[id] = unique; case .workout(let id): workoutItemIDs[id] = unique } }
    private func sanitizeMemberships() { let valid = Set(items.map(\.id)); generalItemIDs = generalItemIDs.filter(valid.contains).uniqued(); typeItemIDs = typeItemIDs.mapValues { $0.filter(valid.contains).uniqued() }; workoutItemIDs = workoutItemIDs.mapValues { $0.filter(valid.contains).uniqued() }; if selectedDestinationByFamily[.type] == nil, let first = workoutTypes.first { selectedDestinationByFamily[.type] = .workoutType(id: first.id) } }
    private func ensureLocalItem(filename: String) -> MusicLibraryItem { if let existing = items.first(where: { $0.localReference?.filename == filename }) { return existing }; let ref = MusicLocalTrackReference(filename: filename); let item = MusicLibraryItem(id: stableLocalItemID(for: filename), name: ref.displayName, source: .local, localReference: ref, duration: ref.duration ?? 0); items.append(item); return item }
    private func stableLocalItemID(for filename: String) -> UUID { var first: UInt64 = 14695981039346656037, second: UInt64 = 1099511628211; for byte in filename.utf8 { first ^= UInt64(byte); first &*= 1099511628211; second ^= UInt64(byte &* 31); second &*= 14695981039346656037 }; let hex = String(format: "%016llx%016llx", first, second); let c = Array(hex); let value = String(c[0..<8]) + "-" + String(c[8..<12]) + "-4" + String(c[13..<16]) + "-a" + String(c[16..<19]) + "-" + String(c[19..<31]); return UUID(uuidString: value) ?? UUID() }
    private func normalizedText(_ value: String) -> String { value.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current) }
}
private extension Array where Element: Equatable { func uniqued() -> [Element] { reduce(into: [Element]()) { if !$0.contains($1) { $0.append($1) } } } }
