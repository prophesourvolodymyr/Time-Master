import Foundation

class DatabaseStore: ObservableObject {
    static let shared = DatabaseStore()

    @Published var rootFolders: [ExerciseFolder] = []

    private let storageKey = "exercise_database_v2"

    private init() {
        load()
    }

    // MARK: - Persistence

    func load() {
        if let data = UserDefaults.standard.data(forKey: storageKey),
           let decoded = try? JSONDecoder().decode([ExerciseFolder].self, from: data) {
            rootFolders = decoded
        } else {
            rootFolders = defaultFolders()
            save()
        }
    }

    func save() {
        if let encoded = try? JSONEncoder().encode(rootFolders) {
            UserDefaults.standard.set(encoded, forKey: storageKey)
        }
    }

    // MARK: - Folder lookup

    func folder(id: UUID) -> ExerciseFolder? {
        findFolder(id: id, in: rootFolders)
    }

    private func findFolder(id: UUID, in folders: [ExerciseFolder]) -> ExerciseFolder? {
        for f in folders {
            if f.id == id { return f }
            if let found = findFolder(id: id, in: f.subfolders) { return found }
        }
        return nil
    }

    // MARK: - Root folder CRUD

    func addRootFolder(name: String) {
        rootFolders.append(ExerciseFolder(name: name))
        save()
    }

    func deleteRootFolder(id: UUID) {
        rootFolders.removeAll { $0.id == id }
        save()
    }

    func renameFolder(id: UUID, newName: String) {
        updateFolder(id: id) { $0.name = newName }
    }

    // MARK: - Subfolder CRUD

    func addSubfolder(name: String, toFolderID parentID: UUID) {
        updateFolder(id: parentID) { $0.subfolders.append(ExerciseFolder(name: name)) }
    }

    func deleteSubfolder(id: UUID, fromParentID parentID: UUID) {
        updateFolder(id: parentID) { $0.subfolders.removeAll { $0.id == id } }
    }

    // MARK: - Exercise CRUD

    func addExercise(_ exercise: Exercise, toFolderID folderID: UUID) {
        updateFolder(id: folderID) { $0.exercises.append(exercise) }
    }

    func updateExercise(_ exercise: Exercise, inFolderID folderID: UUID) {
        updateFolder(id: folderID) { folder in
            if let idx = folder.exercises.firstIndex(where: { $0.id == exercise.id }) {
                folder.exercises[idx] = exercise
            }
        }
    }

    func deleteExercise(id: UUID, fromFolderID folderID: UUID) {
        updateFolder(id: folderID) { $0.exercises.removeAll { $0.id == id } }
    }

    // MARK: - Private tree mutation

    private func updateFolder(id: UUID, transform: (inout ExerciseFolder) -> Void) {
        if mutateInArray(&rootFolders, id: id, transform: transform) {
            save()
        }
    }

    @discardableResult
    private func mutateInArray(
        _ folders: inout [ExerciseFolder],
        id: UUID,
        transform: (inout ExerciseFolder) -> Void
    ) -> Bool {
        for i in folders.indices {
            if folders[i].id == id {
                transform(&folders[i])
                return true
            }
            if mutateInArray(&folders[i].subfolders, id: id, transform: transform) {
                return true
            }
        }
        return false
    }

    // MARK: - Default content

    private func defaultFolders() -> [ExerciseFolder] {
        [
            ExerciseFolder(name: "Upper Body",
                subfolders: [
                    ExerciseFolder(name: "Push", exercises: [
                        Exercise(name: "Push-ups",
                                 description: "Classic push-up. Keep core tight, body in a straight line.",
                                 duration: 30, restAfter: 10),
                        Exercise(name: "Pike Push-ups",
                                 description: "Hips high in a pike. Lower head between hands to target shoulders.",
                                 duration: 30, restAfter: 15),
                        Exercise(name: "Diamond Push-ups",
                                 description: "Hands form a diamond under your chest. Isolates triceps.",
                                 duration: 30, restAfter: 15),
                    ]),
                    ExerciseFolder(name: "Pull", exercises: [
                        Exercise(name: "Inverted Rows",
                                 description: "Under a table or bar. Pull chest up to the surface.",
                                 duration: 30, restAfter: 15),
                        Exercise(name: "Scapular Pulls",
                                 description: "Dead hang from bar. Retract shoulder blades without bending elbows.",
                                 duration: 20, restAfter: 10),
                    ]),
                ],
                exercises: [
                    Exercise(name: "Arm Circles",
                             description: "Forward and backward circles. Loosen the shoulder joint.",
                             duration: 30, restAfter: 5),
                    Exercise(name: "Shoulder Shrugs",
                             description: "Shrug shoulders to ears, hold 1s, release.",
                             duration: 20, restAfter: 5),
                ]
            ),
            ExerciseFolder(name: "Lower Body",
                subfolders: [
                    ExerciseFolder(name: "Quads", exercises: [
                        Exercise(name: "Squats",
                                 description: "Feet shoulder-width. Knees track over toes. Keep chest up.",
                                 duration: 30, restAfter: 15),
                        Exercise(name: "Jump Squats",
                                 description: "Explosive squat with full extension at top. Land softly.",
                                 duration: 30, restAfter: 20),
                        Exercise(name: "Wall Sit",
                                 description: "Back flat against wall. Hold 90° position.",
                                 duration: 45, restAfter: 15),
                    ]),
                    ExerciseFolder(name: "Glutes", exercises: [
                        Exercise(name: "Glute Bridges",
                                 description: "Lie on back. Drive hips up and squeeze glutes at the top.",
                                 duration: 30, restAfter: 10),
                        Exercise(name: "Lunges",
                                 description: "Step forward. Back knee hovers just above the floor.",
                                 duration: 30, restAfter: 15),
                        Exercise(name: "Donkey Kicks",
                                 description: "On all fours. Kick heel straight up, squeeze glute at top.",
                                 duration: 30, restAfter: 10),
                    ]),
                ]
            ),
            ExerciseFolder(name: "Core", exercises: [
                Exercise(name: "Plank",
                         description: "Forearm plank. Keep hips level — don't let them sag or pike.",
                         duration: 45, restAfter: 15),
                Exercise(name: "Crunches",
                         description: "Controlled crunch. Hands light behind head — don't pull your neck.",
                         duration: 30, restAfter: 10),
                Exercise(name: "Leg Raises",
                         description: "Flat on back. Raise straight legs to 90°, lower slowly.",
                         duration: 30, restAfter: 15),
                Exercise(name: "Russian Twists",
                         description: "Rotate side to side. Lift feet off the floor for extra challenge.",
                         duration: 30, restAfter: 15),
                Exercise(name: "Bicycle Crunches",
                         description: "Alternate elbow to opposite knee. Control the rotation.",
                         duration: 30, restAfter: 10),
                Exercise(name: "Mountain Climbers",
                         description: "High plank. Drive knees alternately to chest at a quick pace.",
                         duration: 30, restAfter: 10),
            ]),
            ExerciseFolder(name: "Cardio", exercises: [
                Exercise(name: "Jumping Jacks",
                         description: "Full extension at top, feet together on landing.",
                         duration: 45, restAfter: 10),
                Exercise(name: "High Knees",
                         description: "Drive knees up to hip height. Pump arms for speed.",
                         duration: 30, restAfter: 10),
                Exercise(name: "Burpees",
                         description: "Squat → kick back → push-up → jump up. Full body blast.",
                         duration: 30, restAfter: 20),
                Exercise(name: "Skaters",
                         description: "Side-to-side lateral bounds. Reach hand to opposite foot.",
                         duration: 30, restAfter: 15),
            ]),
        ]
    }
}
