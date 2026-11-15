import Foundation
import TimeMasterCore

/// A titled section on the Workouts page. Sections keep the order the user gives them, and so do the workouts inside.
struct WorkoutGroup: Identifiable, Equatable, Codable {
    var id: UUID
    var title: String
    var icon: String
    var iconType: SkillBoardIconType?
    var workoutIDs: [UUID]

    init(id: UUID = UUID(), title: String, icon: String = "", iconType: SkillBoardIconType? = nil, workoutIDs: [UUID] = []) {
        self.id = id
        self.title = title
        self.icon = icon
        self.iconType = iconType
        self.workoutIDs = workoutIDs
    }

    init(core: WorkoutGroupManifest) {
        self.init(
            id: UUID(uuidString: core.id) ?? UUID(),
            title: core.title,
            icon: core.icon,
            iconType: core.iconType,
            workoutIDs: core.workoutIDs.compactMap(UUID.init(uuidString:))
        )
    }

    var core: WorkoutGroupManifest {
        WorkoutGroupManifest(id: id.uuidString, title: title, icon: icon, iconType: icon.isEmpty ? nil : iconType, workoutIDs: workoutIDs.map(\.uuidString))
    }
}

extension WorkoutStore {
    private static let workoutGroupsKey = "workout_groups"

    func loadWorkoutGroups() {
        guard let data = UserDefaults.standard.data(forKey: Self.workoutGroupsKey),
              let groups = try? JSONDecoder().decode([WorkoutGroup].self, from: data) else { return }
        workoutGroups = groups
    }

    private func saveWorkoutGroups() {
        if MigrationManager.isMigrationComplete {
            saveConfigToFileSystem()
        } else if let data = try? JSONEncoder().encode(workoutGroups) {
            UserDefaults.standard.set(data, forKey: Self.workoutGroupsKey)
        }
    }

    func workoutGroup(containing workoutID: UUID) -> WorkoutGroup? {
        workoutGroups.first { $0.workoutIDs.contains(workoutID) }
    }

    @discardableResult
    func addWorkoutGroup(title: String, icon: String, iconType: SkillBoardIconType?) -> WorkoutGroup {
        let group = WorkoutGroup(title: title, icon: icon, iconType: iconType)
        workoutGroups.append(group)
        saveWorkoutGroups()
        return group
    }

    func updateWorkoutGroup(id: UUID, title: String, icon: String, iconType: SkillBoardIconType?) {
        guard let index = workoutGroups.firstIndex(where: { $0.id == id }) else { return }
        workoutGroups[index].title = title
        workoutGroups[index].icon = icon
        workoutGroups[index].iconType = iconType
        saveWorkoutGroups()
    }

    /// The section goes; its workouts stay saved, in no section.
    func deleteWorkoutGroup(id: UUID) {
        workoutGroups.removeAll { $0.id == id }
        saveWorkoutGroups()
    }

    /// Drops one section onto another: it takes the target's place, after it when coming from above and before it
    /// when coming from below.
    func moveWorkoutGroup(_ id: UUID, onto targetID: UUID) {
        guard id != targetID,
              let from = workoutGroups.firstIndex(where: { $0.id == id }),
              let to = workoutGroups.firstIndex(where: { $0.id == targetID }) else { return }
        let group = workoutGroups.remove(at: from)
        workoutGroups.insert(group, at: to)
        saveWorkoutGroups()
    }

    func moveWorkoutGroup(_ id: UUID, by offset: Int) {
        guard let from = workoutGroups.firstIndex(where: { $0.id == id }) else { return }
        let to = min(max(0, from + offset), workoutGroups.count - 1)
        guard to != from else { return }
        let group = workoutGroups.remove(at: from)
        workoutGroups.insert(group, at: to)
        saveWorkoutGroups()
    }

    func moveWorkoutGroupToEnd(_ id: UUID) {
        guard let from = workoutGroups.firstIndex(where: { $0.id == id }), from != workoutGroups.count - 1 else { return }
        workoutGroups.append(workoutGroups.remove(at: from))
        saveWorkoutGroups()
    }

    /// Puts a workout into a section (nil takes it out of every section). With a target workout it lands at the
    /// target's place, after it when it came from above in the same section; without one it goes to the end.
    func moveWorkout(_ workoutID: UUID, toGroup groupID: UUID?, at targetID: UUID? = nil) {
        guard workoutID != targetID else { return }
        let source = workoutGroups.firstIndex { $0.workoutIDs.contains(workoutID) }
        let sourceIndex = source.flatMap { workoutGroups[$0].workoutIDs.firstIndex(of: workoutID) }
        for index in workoutGroups.indices {
            workoutGroups[index].workoutIDs.removeAll { $0 == workoutID }
        }
        if let groupID, let target = workoutGroups.firstIndex(where: { $0.id == groupID }) {
            var place = workoutGroups[target].workoutIDs.count
            if let targetID, let targetIndex = workoutGroups[target].workoutIDs.firstIndex(of: targetID) {
                let comesFromAbove = source == target && (sourceIndex ?? .max) <= targetIndex
                place = comesFromAbove ? targetIndex + 1 : targetIndex
            }
            workoutGroups[target].workoutIDs.insert(workoutID, at: min(place, workoutGroups[target].workoutIDs.count))
        }
        saveWorkoutGroups()
    }

    func removeFromWorkoutGroups(_ workoutID: UUID) {
        guard workoutGroups.contains(where: { $0.workoutIDs.contains(workoutID) }) else { return }
        for index in workoutGroups.indices {
            workoutGroups[index].workoutIDs.removeAll { $0 == workoutID }
        }
        saveWorkoutGroups()
    }

    /// A duplicate sits right under the workout it copies.
    func placeClone(_ cloneID: UUID, after originalID: UUID) {
        guard let group = workoutGroups.firstIndex(where: { $0.workoutIDs.contains(originalID) }),
              let index = workoutGroups[group].workoutIDs.firstIndex(of: originalID) else { return }
        workoutGroups[group].workoutIDs.insert(cloneID, at: index + 1)
        saveWorkoutGroups()
    }
}
