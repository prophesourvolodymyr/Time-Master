import XCTest
@testable import TimeMasterCore

final class SyncNewFieldsTests: SyncPairTestCase {
    private func restExerciseWorkout(on replica: Replica, rest: String, big: String) throws -> WorkoutManifest {
        let id = UUID().uuidString
        let slots = (0..<3).map { index in
            WorkoutSetSlotManifest(
                exerciseID: "dips", name: "Dips", duration: 40, restAfter: index < 2 ? 60 : 0,
                restExerciseID: index < 2 ? rest : nil
            )
        }
        let manifest = WorkoutManifest(id: id, name: "Pull day", sections: [
            WorkoutSectionManifest(
                exerciseID: "dips", name: "Dips", duration: 40, sets: 3, restBetweenSets: 60, slots: slots,
                bigRestRow: WorkoutRestRowManifest(kind: .big, duration: 45, exerciseID: big), restExerciseID: rest
            ),
            WorkoutSectionManifest(exerciseID: "rows", name: "Rows", duration: 40),
        ])
        try replica.db.createWorkout(id: id, manifest: manifest)
        return manifest
    }

    private func makeExercise(_ replica: Replica, _ title: String) throws -> ExercisePageManifest {
        let folder = try makePage(replica, "Calisthenics \(title)", type: nil)
        let manifest = ExercisePageManifest(title: title, pageKind: .leaf, duration: 30)
        try replica.db.createPage(manifest: manifest, parentID: folder.id)
        return try replica.page(manifest.id)
    }

    func testAWorkoutWithRestExercisesArrivesWhole() async throws {
        let workout = try restExerciseWorkout(on: mac, rest: "wrist-page", big: "dislocates-page")

        try await sync()

        let arrived = try phone.db.getWorkout(id: workout.id)
        XCTAssertEqual(arrived.sections[0].restExerciseID, "wrist-page")
        XCTAssertEqual(arrived.sections[0].bigRestRow?.exerciseID, "dislocates-page")
        XCTAssertEqual(arrived.sections[0].slots.map(\.restExerciseID), ["wrist-page", "wrist-page", nil])
        XCTAssertEqual(arrived.totalDuration, workout.totalDuration)
        try assertInSync()
    }

    func testChangingTheRestExerciseOnOneDeviceReachesTheOtherAndKeepsTheRest() async throws {
        let workout = try restExerciseWorkout(on: mac, rest: "wrist-page", big: "dislocates-page")
        try await sync()

        var edited = try phone.db.getWorkout(id: workout.id)
        edited.sections[0].restExerciseID = "twist-page"
        for index in edited.sections[0].slots.indices.dropLast() { edited.sections[0].slots[index].restExerciseID = "twist-page" }
        edited.sections[0].bigRestRow?.exerciseID = nil
        try phone.db.updateWorkout(id: workout.id, manifest: edited)
        try await sync()

        let onMac = try mac.db.getWorkout(id: workout.id)
        XCTAssertEqual(onMac.sections[0].slots.map(\.restExerciseID), ["twist-page", "twist-page", nil])
        XCTAssertNil(onMac.sections[0].bigRestRow?.exerciseID)
        XCTAssertEqual(onMac.sections[0].bigRestRow?.duration, 45)
        try assertInSync()
    }

    func testTheSkillsAnExerciseTrainsTravelAndDifferentSkillsAddedOnBothDevicesAreBothKept() async throws {
        let handstand = try makePage(mac, "Handstand")
        let planche = try makePage(mac, "Planche")
        let press = try makePage(mac, "Press")
        let wallWalk = try makeExercise(mac, "Wall Walk")
        try mac.edit(wallWalk.id) { $0.trains = [SkillTraining(skillID: handstand.id, tier: .s)] }
        try await sync()
        XCTAssertEqual(try phone.page(wallWalk.id).trains, [SkillTraining(skillID: handstand.id, tier: .s)])

        try mac.edit(wallWalk.id) { $0.trains.append(SkillTraining(skillID: planche.id, tier: .c)) }
        try phone.edit(wallWalk.id) { $0.trains.append(SkillTraining(skillID: press.id, tier: .a)) }
        try await sync()

        let onMac = try mac.page(wallWalk.id).trains
        let onPhone = try phone.page(wallWalk.id).trains
        XCTAssertEqual(Set(onMac.map(\.skillID)), [handstand.id, planche.id, press.id])
        XCTAssertEqual(onMac.sorted { $0.skillID < $1.skillID }, onPhone.sorted { $0.skillID < $1.skillID })
        try assertInSync()
    }

    func testATierChangedOnOneDeviceAndAnotherSkillRemovedOnTheOtherBothApply() async throws {
        let handstand = try makePage(mac, "Handstand")
        let planche = try makePage(mac, "Planche")
        let wallWalk = try makeExercise(mac, "Wall Walk")
        try mac.edit(wallWalk.id) { $0.trains = [SkillTraining(skillID: handstand.id, tier: .s), SkillTraining(skillID: planche.id, tier: .b)] }
        try await sync()

        try mac.edit(wallWalk.id) { page in
            page.trains = page.trains.map { $0.skillID == handstand.id ? SkillTraining(skillID: handstand.id, tier: .a) : $0 }
        }
        try phone.edit(wallWalk.id) { $0.trains.removeAll { $0.skillID == planche.id } }
        try await sync()

        XCTAssertEqual(try mac.page(wallWalk.id).trains, [SkillTraining(skillID: handstand.id, tier: .a)])
        XCTAssertEqual(try phone.page(wallWalk.id).trains, [SkillTraining(skillID: handstand.id, tier: .a)])
        try assertInSync()
    }

    func testAPictureIconOfAnExercisePageArrivesWithItsFile() async throws {
        let jab = try makeExercise(mac, "Jab")
        let picture = try writeFile("not really a png", named: "icon.png")
        let filename = try mac.db.uploadMediaToPage(pageID: jab.id, sourceURL: picture)
        try mac.edit(jab.id) { $0.iconImage = filename }

        try await sync()

        let arrived = try phone.page(jab.id)
        XCTAssertEqual(arrived.iconImage, filename)
        let file = try phone.folder(jab.id).appendingPathComponent("media").appendingPathComponent(filename)
        XCTAssertEqual(try String(contentsOf: file, encoding: .utf8), "not really a png")
        try assertInSync()
    }

    func testASymbolIconOnAFolderAndItsRemovalSyncBothWays() async throws {
        let boxing = try makePage(mac, "Boxing", type: nil)
        try mac.edit(boxing.id) { $0.iconName = "figure.boxing"; $0.iconType = .system }
        try await sync()
        XCTAssertEqual(try phone.page(boxing.id).iconName, "figure.boxing")
        XCTAssertEqual(try phone.page(boxing.id).iconType, .system)

        try phone.edit(boxing.id) { $0.iconName = nil; $0.iconType = nil }
        try await sync()

        XCTAssertNil(try mac.page(boxing.id).iconName)
        try assertInSync()
    }
}
