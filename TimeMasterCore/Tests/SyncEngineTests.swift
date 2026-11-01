import XCTest
@testable import TimeMasterCore

final class SyncEngineTests: SyncPairTestCase {
    private func fileExists(_ url: URL) -> Bool { FileManager.default.fileExists(atPath: url.path) }

    func testAnEmptyDeviceReceivesTheWholeLibraryWithItsFiles() async throws {
        let (piano, scales, _) = try makePiano(on: mac)
        let media = try mac.db.uploadMediaToPage(pageID: scales.id, sourceURL: try writeFile("sheet music"))
        let research = try mac.folder(scales.id).appendingPathComponent("research", isDirectory: true)
        try FileManager.default.createDirectory(at: research, withIntermediateDirectories: true)
        try Data("draft".utf8).write(to: research.appendingPathComponent("voicings.md"))
        let group = try mac.db.addSkillGroup(to: piano.id, title: "Foundations")
        let groupID = SkillGroupID.make(containerID: piano.id, sectionID: group.id)
        let groupMedia = try mac.db.uploadMediaToPage(pageID: groupID, sourceURL: try writeFile("group picture"))
        let workout = try makeWorkout(mac)

        let report = try await sync()

        XCTAssertEqual(report.itemsHere, 0)
        XCTAssertEqual(report.itemsThere, 4)
        XCTAssertEqual(phone.pageIDs(), mac.pageIDs())
        XCTAssertEqual(try phone.page(scales.id).markdownBody, "Major and minor.")
        XCTAssertEqual(Set(try phone.page(piano.id).childIDs), Set(try mac.page(piano.id).childIDs))
        XCTAssertEqual(try String(contentsOf: try phone.folder(scales.id).appendingPathComponent("media/\(media)"), encoding: .utf8), "sheet music")
        XCTAssertEqual(try String(contentsOf: try phone.folder(scales.id).appendingPathComponent("research/voicings.md"), encoding: .utf8), "draft")
        let phoneGroupFile = SkillGroupID.mediaFolder(containerFolder: try phone.folder(piano.id), sectionID: group.id).appendingPathComponent(groupMedia)
        XCTAssertEqual(try String(contentsOf: phoneGroupFile, encoding: .utf8), "group picture")
        XCTAssertEqual(try phone.db.getWorkout(id: workout.id).sections.map(\.name), ["Push-ups", "Squats"])
        XCTAssertTrue(libraryProblems(phone).isEmpty, "\(libraryProblems(phone))")
        try assertInSync()
    }

    func testASecondSyncWithNothingNewDoesNothing() async throws {
        try makePiano(on: mac)
        try await sync()
        let report = try await sync()
        XCTAssertEqual(report, SyncReport())
    }

    func testTheFirstChangeFromADeviceComesWithASafetyCopyOnBothSides() async throws {
        try makePiano(on: mac)
        try makePiano(on: phone)
        try await sync()
        XCTAssertFalse(mac.backups().isEmpty, "the device that drove the sync made a backup first")
        XCTAssertFalse(phone.backups().isEmpty, "and so did the device that was updated")
        let before = phone.backups().count
        try makePiano(on: mac)
        try await sync()
        XCTAssertEqual(phone.backups().count, before, "only the first change from a device is preceded by a copy")
    }

    func testAnEmptyLibraryNeedsNoSafetyCopy() async throws {
        try makePiano(on: phone)
        try await sync()
        XCTAssertTrue(mac.backups().isEmpty)
    }

    func testWhenTheDevicesNeverAgreedTheNewerSingleValuesWinAndNothingIsLost() async throws {
        let (_, scales, _) = try makePiano(on: mac)
        try await sync()
        mac.engine.store.deleteBase(peer: try phone.engine.deviceID())
        try mac.edit(scales.id) { $0.skillStatus = .completed; $0.linkURLs = ["https://mac.example"] }
        try phone.edit(scales.id) { $0.markdownBody = "Major and minor. Practise daily."; $0.linkURLs = ["https://phone.example"] }
        try await sync()
        let merged = try mac.page(scales.id)
        XCTAssertEqual(Set(merged.linkURLs), ["https://mac.example", "https://phone.example"], "lists are united")
        XCTAssertEqual(merged.markdownBody, "Major and minor. Practise daily.", "the fuller text wins")
        try assertInSync()
    }

    func testEditsOnEitherDeviceReachTheOther() async throws {
        let (piano, scales, chords) = try makePiano(on: mac)
        try await sync()
        try mac.edit(scales.id) { $0.title = "Major scales" }
        try phone.edit(chords.id) { $0.skillStatus = .learning }
        try phone.edit(piano.id) { $0.linkURLs = ["https://piano.example"] }
        try await sync()
        XCTAssertEqual(try phone.page(scales.id).title, "Major scales")
        XCTAssertEqual(try mac.page(chords.id).skillStatus, .learning)
        XCTAssertEqual(try mac.page(piano.id).linkURLs, ["https://piano.example"])
        try assertInSync()
    }

    func testAMovedPageMovesOnTheOtherDeviceWithItsPagesAndFiles() async throws {
        let (piano, scales, chords) = try makePiano(on: mac)
        let child = try makePage(mac, "C major", parent: scales.id)
        _ = try mac.db.uploadMediaToPage(pageID: child.id, sourceURL: try writeFile("fingering"))
        try await sync()
        try mac.db.movePage(id: scales.id, newParentID: chords.id, newOrder: 0)
        try await sync()
        XCTAssertEqual(try phone.page(scales.id).parentID, chords.id)
        XCTAssertEqual(try phone.page(chords.id).childIDs, [scales.id])
        XCTAssertEqual(try phone.page(piano.id).childIDs, [chords.id])
        XCTAssertTrue(try phone.folder(child.id).path.hasSuffix("/\(piano.id)/\(chords.id)/\(scales.id)/\(child.id)"))
        XCTAssertTrue(libraryProblems(phone).isEmpty, "\(libraryProblems(phone))")
        try assertInSync()
    }

    func testReorderingChildrenIsFollowed() async throws {
        let (piano, scales, chords) = try makePiano(on: mac)
        try await sync()
        try mac.db.reorderChildren(parentID: piano.id, childIDs: [chords.id, scales.id])
        try await sync()
        XCTAssertEqual(try phone.page(piano.id).childIDs, [chords.id, scales.id])
        try assertInSync()
    }

    func testRootPagesAddedOnBothDevicesGetDistinctPlacesOnBoth() async throws {
        try makePage(mac, "Guitar")
        try makePage(phone, "Piano")
        try await sync()
        try await sync(from: phone, with: mac)
        let orders = mac.pages().values.filter { $0.parentID == nil }.map(\.order).sorted()
        XCTAssertEqual(orders, [0, 1])
        try assertInSync()
    }

    func testMovingARootPageAwayLeavesTheOtherRootsAloneSoALaterDeletionStillWins() async throws {
        let first = try makePage(mac, "First")
        let second = try makePage(mac, "Second")
        let third = try makePage(mac, "Third")
        let fourth = try makePage(mac, "Fourth")
        try await sync()
        let before = phone.pages().values.filter { $0.parentID == nil }.map { "\($0.id) \($0.order)" }.sorted()
        try mac.db.movePage(id: second.id, newParentID: first.id, newOrder: 0)
        try await sync()
        let after = phone.pages().values.filter { $0.parentID == nil && $0.id != second.id }.map { "\($0.id) \($0.order)" }.sorted()
        XCTAssertEqual(after, before.filter { !$0.hasPrefix(second.id) }, "the other root pages were not rewritten on the phone")
        try mac.db.deletePage(id: third.id)
        try await sync()
        XCTAssertFalse(phone.exists(third.id), "a deletion made after a move is not undone by the move")
        XCTAssertTrue(phone.exists(fourth.id))
        let quiet = try await sync()
        XCTAssertEqual(quiet, SyncReport())
        try assertInSync()
    }

    func testADeletedPageIsDeletedOnTheOtherDeviceAndStaysDeleted() async throws {
        let (_, scales, chords) = try makePiano(on: mac)
        try await sync()
        try mac.db.deletePage(id: scales.id)
        try await sync()
        XCTAssertFalse(phone.exists(scales.id))
        XCTAssertTrue(phone.exists(chords.id))
        XCTAssertFalse(phone.trashIsEmpty(), "it went to the trash, not into thin air")
        try await sync()
        try await sync(from: phone, with: mac)
        XCTAssertFalse(mac.exists(scales.id))
        XCTAssertFalse(phone.exists(scales.id), "it does not come back")
        XCTAssertTrue(libraryProblems(phone).isEmpty, "\(libraryProblems(phone))")
        try assertInSync()
    }

    func testADeletionMadeOnTheDeviceThatDoesNotDriveReachesTheOther() async throws {
        let (_, scales, _) = try makePiano(on: mac)
        try await sync()
        try phone.db.deletePage(id: scales.id)
        try await sync()
        XCTAssertFalse(mac.exists(scales.id))
        try assertInSync()
    }

    func testDeletingASkillDeletesEverythingBelowIt() async throws {
        let (piano, scales, chords) = try makePiano(on: mac)
        try await sync()
        try mac.db.deletePage(id: piano.id)
        try await sync()
        for id in [piano.id, scales.id, chords.id] { XCTAssertFalse(phone.exists(id)) }
        try assertInSync()
    }

    func testAPageEditedAfterItsDeletionComesBack() async throws {
        let (_, scales, _) = try makePiano(on: mac)
        try await sync()
        try mac.db.deletePage(id: scales.id)
        try phone.edit(scales.id) { $0.markdownBody = "Edited on the phone" }
        try await sync()
        XCTAssertTrue(mac.exists(scales.id), "an edit beats a deletion")
        XCTAssertEqual(try mac.page(scales.id).markdownBody, "Edited on the phone")
        XCTAssertTrue(libraryProblems(mac).isEmpty, "\(libraryProblems(mac))")
        try assertInSync()
    }

    func testAPageThatComesBackAfterItsDeletionKeepsItsFiles() async throws {
        let (_, scales, _) = try makePiano(on: mac)
        let media = try mac.db.uploadMediaToPage(pageID: scales.id, sourceURL: try writeFile("sheet music"))
        try await sync()
        try mac.db.deletePage(id: scales.id)
        try Data("later".utf8).write(to: try phone.folder(scales.id).appendingPathComponent("notes.txt"))
        try await sync()
        for replica in [mac!, phone!] {
            XCTAssertTrue(fileExists(try replica.folder(scales.id).appendingPathComponent("media/\(media)")), "the media file survives on both devices")
            XCTAssertTrue(fileExists(try replica.folder(scales.id).appendingPathComponent("notes.txt")))
        }
        try assertInSync()
    }

    func testPagesNewerThanADeletedParentMoveUpInsteadOfBeingLost() async throws {
        let (piano, scales, _) = try makePiano(on: mac)
        let cMajor = try makePage(mac, "C major", parent: scales.id)
        try await sync()
        let arpeggios = try makePage(phone, "Arpeggios", parent: cMajor.id)
        try mac.db.deletePage(id: scales.id)
        try await sync()
        XCTAssertFalse(phone.exists(scales.id), "the page that was only deleted is gone")
        XCTAssertEqual(try phone.page(cMajor.id).parentID, piano.id, "the page that changed moved up one level")
        XCTAssertEqual(try phone.page(arpeggios.id).parentID, cMajor.id)
        XCTAssertTrue(mac.exists(arpeggios.id))
        XCTAssertEqual(try mac.page(cMajor.id).parentID, piano.id)
        XCTAssertTrue(libraryProblems(phone).isEmpty, "\(libraryProblems(phone))")
        XCTAssertTrue(libraryProblems(mac).isEmpty, "\(libraryProblems(mac))")
        try assertInSync()
    }

    func testEditsToDifferentThingsOnTheSamePageAreBothKept() async throws {
        let (_, scales, _) = try makePiano(on: mac)
        try await sync()
        try mac.edit(scales.id) { $0.title = "Major scales"; $0.linkURLs = ["https://mac.example"] }
        try phone.edit(scales.id) { $0.skillStatus = .completed; $0.linkURLs = ["https://phone.example"] }
        try await sync()
        let merged = try mac.page(scales.id)
        XCTAssertEqual(merged.title, "Major scales")
        XCTAssertEqual(merged.skillStatus, .completed)
        XCTAssertEqual(Set(merged.linkURLs), ["https://mac.example", "https://phone.example"])
        try assertInSync()
    }

    func testNotesEditedInTwoPlacesAreMerged() async throws {
        let (_, scales, _) = try makePiano(on: mac)
        try mac.edit(scales.id) { $0.markdownBody = "Warm up\n\nScales\n\nCool down" }
        try await sync()
        try mac.edit(scales.id) { $0.markdownBody = "Warm up 10 min\n\nScales\n\nCool down" }
        try phone.edit(scales.id) { $0.markdownBody = "Warm up\n\nScales\n\nCool down and stretch" }
        let report = try await sync()
        XCTAssertEqual(try mac.page(scales.id).markdownBody, "Warm up 10 min\n\nScales\n\nCool down and stretch")
        XCTAssertTrue(report.conflicts.isEmpty)
        let guide = try String(contentsOf: try mac.folder(scales.id).appendingPathComponent("guide.md"), encoding: .utf8)
        XCTAssertTrue(guide.contains("Cool down and stretch"), "the guide.md mirror follows")
        try assertInSync()
    }

    func testNotesEditedInTheSamePlaceKeepBothVersions() async throws {
        let (_, scales, _) = try makePiano(on: mac)
        try mac.edit(scales.id) { $0.markdownBody = "Practise" }
        try await sync()
        try mac.edit(scales.id) { $0.markdownBody = "Practise on the Mac" }
        try phone.edit(scales.id) { $0.markdownBody = "Practise on the phone" }
        let report = try await sync()
        let body = try mac.page(scales.id).markdownBody
        XCTAssertTrue(body.contains("Practise on the Mac") && body.contains("Practise on the phone"), "nothing lost: \(body)")
        XCTAssertEqual(report.conflicts, ["Scales"])
        try assertInSync()
    }

    func testPagesAddedOnBothDevicesUnderTheSameParentAllSurvive() async throws {
        let (piano, _, _) = try makePiano(on: mac)
        try await sync()
        let fromMac = try makePage(mac, "Arpeggios", parent: piano.id)
        let fromPhone = try makePage(phone, "Pedalling", parent: piano.id)
        try await sync()
        XCTAssertEqual(try mac.page(piano.id).childIDs.count, 4)
        XCTAssertTrue(Set(try mac.page(piano.id).childIDs).isSuperset(of: [fromMac.id, fromPhone.id]))
        XCTAssertTrue(libraryProblems(mac).isEmpty, "\(libraryProblems(mac))")
        try assertInSync()
    }

    func testAFileDeletedOnOneDeviceIsDeletedOnTheOtherAndKeptInTheTrash() async throws {
        let (_, scales, _) = try makePiano(on: mac)
        let research = try mac.folder(scales.id).appendingPathComponent("research", isDirectory: true)
        try FileManager.default.createDirectory(at: research, withIntermediateDirectories: true)
        try Data("scratch".utf8).write(to: research.appendingPathComponent("temp.txt"))
        try await sync()
        let onPhone = try phone.folder(scales.id).appendingPathComponent("research/temp.txt")
        XCTAssertTrue(fileExists(onPhone))
        try FileManager.default.removeItem(at: research.appendingPathComponent("temp.txt"))
        try await sync()
        XCTAssertFalse(fileExists(onPhone))
        XCTAssertFalse(phone.trashIsEmpty())
        try assertInSync()
    }

    func testAChangedFileReplacesTheOldOneWhichGoesToTheTrash() async throws {
        let (_, scales, _) = try makePiano(on: mac)
        let research = try mac.folder(scales.id).appendingPathComponent("research", isDirectory: true)
        try FileManager.default.createDirectory(at: research, withIntermediateDirectories: true)
        try Data("version one".utf8).write(to: research.appendingPathComponent("plan.md"))
        try await sync()
        try Data("version two, longer".utf8).write(to: research.appendingPathComponent("plan.md"))
        try await sync()
        XCTAssertEqual(try String(contentsOf: try phone.folder(scales.id).appendingPathComponent("research/plan.md"), encoding: .utf8), "version two, longer")
        XCTAssertFalse(phone.trashIsEmpty())
        try assertInSync()
    }

    func testRemovingMediaRemovesItsFileOnTheOtherDevice() async throws {
        let (_, scales, _) = try makePiano(on: mac)
        let media = try mac.db.uploadMediaToPage(pageID: scales.id, sourceURL: try writeFile("sheet"))
        try await sync()
        try mac.db.removeMediaFromPage(pageID: scales.id, filename: media)
        try await sync()
        XCTAssertTrue(try phone.page(scales.id).mediaFilenames.isEmpty)
        XCTAssertFalse(fileExists(try phone.folder(scales.id).appendingPathComponent("media/\(media)")))
        try assertInSync()
    }

    func testAMediaFileAttachedOnBothSidesKeepsBothFiles() async throws {
        let (_, scales, _) = try makePiano(on: mac)
        try await sync()
        let a = try mac.db.uploadMediaToPage(pageID: scales.id, sourceURL: try writeFile("mac picture", named: "a.txt"))
        let b = try phone.db.uploadMediaToPage(pageID: scales.id, sourceURL: try writeFile("phone picture", named: "b.txt"))
        try await sync()
        for replica in [mac!, phone!] {
            XCTAssertEqual(Set(try replica.page(scales.id).mediaFilenames), [a, b])
            XCTAssertTrue(fileExists(try replica.folder(scales.id).appendingPathComponent("media/\(a)")))
            XCTAssertTrue(fileExists(try replica.folder(scales.id).appendingPathComponent("media/\(b)")))
        }
        try assertInSync()
    }

    func testWorkoutsSyncAndMergeSectionsFromBothDevices() async throws {
        let workout = try makeWorkout(mac)
        try await sync()
        var onMac = try mac.db.getWorkout(id: workout.id)
        onMac.sections[0].duration = 45
        try mac.db.updateWorkout(id: workout.id, manifest: onMac)
        var onPhone = try phone.db.getWorkout(id: workout.id)
        onPhone.sections.append(WorkoutSectionManifest(exerciseID: "", name: "Plank", duration: 60))
        onPhone.name = "Full body!"
        try phone.db.updateWorkout(id: workout.id, manifest: onPhone)
        try await sync()
        for replica in [mac!, phone!] {
            let merged = try replica.db.getWorkout(id: workout.id)
            XCTAssertEqual(merged.name, "Full body!")
            XCTAssertEqual(merged.sections.map(\.name), ["Push-ups", "Squats", "Plank"])
            XCTAssertEqual(merged.sections[0].duration, 45)
        }
        try await sync()
        XCTAssertEqual(try mac.db.listWorkouts().count, 1)
        try assertInSync()
    }

    func testSavingAnUnchangedWorkoutAgainTouchesNothing() throws {
        let workout = try makeWorkout(mac)
        let url = mac.fs.workoutsDirectory.appendingPathComponent(workout.id).appendingPathComponent("manifest.json")
        let before = try FileManager.default.attributesOfItem(atPath: url.path)[.modificationDate] as? Date
        try mac.db.updateWorkout(id: workout.id, manifest: try mac.db.getWorkout(id: workout.id))
        XCTAssertTrue(mac.trashIsEmpty())
        XCTAssertEqual(try FileManager.default.attributesOfItem(atPath: url.path)[.modificationDate] as? Date, before)
        var changed = try mac.db.getWorkout(id: workout.id)
        changed.name = "Renamed"
        try mac.db.updateWorkout(id: workout.id, manifest: changed)
        XCTAssertFalse(mac.trashIsEmpty())
        XCTAssertEqual(try mac.db.getWorkout(id: workout.id).name, "Renamed")
    }

    func testTheReportSaysWhichKindsOfThingsArrived() async throws {
        try makePage(phone, "Guitar")
        _ = try makeWorkout(phone)
        try phone.db.appendHistoryEntry(historyEntry("Run", at: 1_800_000_000))
        let first = try await sync()
        XCTAssertEqual(first.changes, [.pages, .workouts, .history])
        try Data("photo".utf8).write(to: phone.photos.appendingPathComponent("p.jpg"))
        try Data("track".utf8).write(to: phone.music.appendingPathComponent("t.mp3"))
        try phone.db.saveConfig(ConfigManifest(weeklyGoal: 3))
        let second = try await sync()
        XCTAssertEqual(second.changes, [.files, .music, .config])
        let quiet = try await sync()
        XCTAssertEqual(quiet.changes, [])
    }

    func testADeletedWorkoutIsDeletedOnTheOtherDevice() async throws {
        let workout = try makeWorkout(mac)
        try await sync()
        try phone.db.deleteWorkout(id: workout.id)
        try await sync()
        XCTAssertTrue(try mac.db.listWorkouts().isEmpty)
        try assertInSync()
    }

    func testFinishedActivitiesSyncAndARecordingInProgressStaysWhereItIs() async throws {
        let finished = UUID().uuidString
        var manifest = OutdoorActivityManifest(id: finished, kind: .run, startedAt: Date(timeIntervalSince1970: 1_800_000_000))
        manifest.finished = true
        manifest.recordingState = .finished
        try mac.db.createOutdoorActivity(id: finished, manifest: manifest)
        try mac.db.appendOutdoorTrackPoint(id: finished, point: OutdoorTrackPoint(timestamp: Date(timeIntervalSince1970: 1_800_000_001), latitude: 1, longitude: 2, horizontalAccuracyMeters: 3, state: .recording))
        let live = UUID().uuidString
        try mac.db.createOutdoorActivity(id: live, manifest: OutdoorActivityManifest(id: live, kind: .bike, startedAt: Date()))
        try await sync()
        XCTAssertEqual(try phone.db.getOutdoorActivity(id: finished).kind, .run)
        XCTAssertEqual(try phone.db.readOutdoorTrackPoints(id: finished).count, 1)
        XCTAssertThrowsError(try phone.db.getOutdoorActivity(id: live))
        XCTAssertNoThrow(try mac.db.getOutdoorActivity(id: live))
        try await sync()
        try assertInSync()
    }

    func testRoutesAndLegacyMediaAndLooseFolders() async throws {
        let routeID = UUID().uuidString
        try mac.fs.ensureDirectory(mac.fs.routesDirectory)
        try Data(#"{"id":"\#(routeID)","name":"Park loop","points":[1,2,3]}"#.utf8).write(to: mac.fs.routesDirectory.appendingPathComponent("\(routeID).json"))
        try Data(".trip".utf8).write(to: mac.fs.routesDirectory.appendingPathComponent(".trip-recovery.json"))
        try Data("legacy picture".utf8).write(to: mac.fs.mediaDirectory.appendingPathComponent("legacy.jpg"))
        try Data("photo".utf8).write(to: mac.photos.appendingPathComponent("photo.jpg"))
        try Data("track".utf8).write(to: phone.music.appendingPathComponent("track.mp3"))
        try await sync()
        let route = try JSONSerialization.jsonObject(with: Data(contentsOf: phone.fs.routesDirectory.appendingPathComponent("\(routeID).json"))) as? [String: Any]
        XCTAssertEqual(route?["name"] as? String, "Park loop")
        XCTAssertFalse(fileExists(phone.fs.routesDirectory.appendingPathComponent(".trip-recovery.json")))
        XCTAssertEqual(try String(contentsOf: phone.fs.mediaDirectory.appendingPathComponent("legacy.jpg"), encoding: .utf8), "legacy picture")
        XCTAssertEqual(try String(contentsOf: phone.photos.appendingPathComponent("photo.jpg"), encoding: .utf8), "photo")
        XCTAssertEqual(try String(contentsOf: mac.music.appendingPathComponent("track.mp3"), encoding: .utf8), "track")
        try FileManager.default.removeItem(at: mac.photos.appendingPathComponent("photo.jpg"))
        try await sync()
        XCTAssertFalse(fileExists(phone.photos.appendingPathComponent("photo.jpg")))
        try assertInSync()
    }

    func testAFolderThatOneDeviceDoesNotShareIsLeftAlone() async throws {
        let bare = try makeReplica("bare", deviceName: "Bare")
        let withoutPhotos = Replica(
            db: bare.db, engine: SyncEngine(database: bare.db, deviceName: "Bare", extra: .none), photos: bare.photos, music: bare.music
        )
        try Data("photo".utf8).write(to: mac.photos.appendingPathComponent("photo.jpg"))
        try makePiano(on: mac)
        try await sync(from: withoutPhotos, with: mac)
        XCTAssertEqual(withoutPhotos.pageIDs(), mac.pageIDs())
        XCTAssertFalse(fileExists(withoutPhotos.photos.appendingPathComponent("photo.jpg")))
        XCTAssertTrue(fileExists(mac.photos.appendingPathComponent("photo.jpg")))
    }

    private func entries(_ replica: Replica) throws -> [HistoryEntry] { try replica.db.readHistory() }

    func testHistoryFromBothDevicesIsCombined() async throws {
        try mac.db.appendHistoryEntry(historyEntry("Run", at: 1_800_000_000))
        try phone.db.appendHistoryEntry(historyEntry("Swim", at: 1_800_100_000))
        try phone.db.appendHistoryEntry(historyEntry("Lift", at: 1_850_000_000))
        let report = try await sync()
        XCTAssertEqual(try entries(mac).count, 3)
        XCTAssertEqual(Set(try entries(mac).map(\.id)), Set(try entries(phone).map(\.id)))
        XCTAssertEqual(report.historyHere, 2)
        XCTAssertEqual(report.historyThere, 1)
        try assertInSync()
    }

    func testADeletedHistoryEntryIsDeletedOnTheOtherDevice() async throws {
        let keep = historyEntry("Run", at: 1_800_000_000)
        let drop = historyEntry("Swim", at: 1_800_000_500)
        try mac.db.appendHistoryEntry(keep)
        try mac.db.appendHistoryEntry(drop)
        try await sync()
        XCTAssertEqual(try entries(phone).count, 2)
        try mac.db.replaceHistory(try entries(mac).filter { $0.id != drop.id })
        try await sync()
        XCTAssertEqual(try entries(phone).map(\.id), [keep.id])
        try await sync()
        XCTAssertEqual(try entries(mac).map(\.id), [keep.id], "it does not come back")
        try assertInSync()
    }

    func testTheScheduleAndSettingsSyncButRecordingPreferencesStayOnTheirDevice() async throws {
        var config = ConfigManifest(weeklyGoal: 5, restDays: ["2026-01-01"], trainingDays: [1, 3])
        config.outdoorRecording = OutdoorRecordingPreferences(keepScreenAwake: true, gpsAccuracy: .precise)
        var schedule = WeeklyWorkoutSchedule()
        schedule.plans = [WeeklyWorkoutSchedule.Plan(name: "My Plan", entries: [WeeklyWorkoutSchedule.Entry(title: "Run", weekday: 2)])]
        config.workoutSchedule = schedule
        try mac.db.saveConfig(config)
        var phoneConfig = ConfigManifest()
        phoneConfig.outdoorRecording = OutdoorRecordingPreferences(keepScreenAwake: false, gpsAccuracy: .balanced)
        try phone.db.saveConfig(phoneConfig)
        let report = try await sync()
        XCTAssertTrue(report.configHere || report.configThere)
        let onPhone = try phone.db.loadConfig()
        XCTAssertEqual(onPhone.restDays, ["2026-01-01"])
        XCTAssertEqual(onPhone.workoutSchedule?.plans.first?.entries.count, 1)
        XCTAssertEqual(onPhone.outdoorRecording?.gpsAccuracy, .balanced, "the phone keeps its own recording preferences")
        XCTAssertEqual(try mac.db.loadConfig().outdoorRecording?.keepScreenAwake, true)

        var changed = try phone.db.loadConfig()
        changed.workoutSchedule?.plans[0].entries.append(WeeklyWorkoutSchedule.Entry(title: "Swim", weekday: 4))
        try phone.db.saveConfig(changed)
        try await sync()
        XCTAssertEqual(try mac.db.loadConfig().workoutSchedule?.plans.first?.entries.count, 2)
        try assertInSync()
    }

    func testDifferentFormatsRefuseToSync() async throws {
        struct OldDevice: SyncEndpoint {
            let inner: SyncService
            func index() async throws -> SyncIndex {
                var index = try await inner.index()
                index.schema += 1
                return index
            }
            func bundles(keys: [String]) async throws -> [SyncUnitBundle] { try await inner.bundles(keys: keys) }
            func readFile(unitKey: String, path: String, offset: Int64, length: Int) async throws -> Data { try await inner.readFile(unitKey: unitKey, path: path, offset: offset, length: length) }
            func pushStart(_ request: SyncPushRequest) async throws -> SyncPushTicket { try await inner.pushStart(request) }
            func pushFile(token: String, unitKey: String, path: String, offset: Int64, data: Data) async throws { try await inner.pushFile(token: token, unitKey: unitKey, path: path, offset: offset, data: data) }
            func pushCommit(token: String) async throws -> SyncPushResult { try await inner.pushCommit(token: token) }
            func shardLines(month: String) async throws -> [String] { try await inner.shardLines(month: month) }
            func mergeHistory(month: String, lines: [String], tombstones: [String: SyncStamp]) async throws -> SyncHistoryMerge { try await inner.mergeHistory(month: month, lines: lines, tombstones: tombstones) }
            func configPayload() async throws -> SyncConfigPayload? { try await inner.configPayload() }
            func applyConfig(_ payload: SyncConfigPayload, expectedHash: String?) async throws -> Bool { try await inner.applyConfig(payload, expectedHash: expectedHash) }
        }
        try makePiano(on: phone)
        let peer = SyncPeerRecord(id: try phone.engine.deviceID(), name: "iPhone", platform: "iphone", key: Data(repeating: 1, count: 32))
        let driver = SyncDriver(engine: mac.engine, peer: peer, remote: OldDevice(inner: SyncService(engine: phone.engine)))
        do {
            _ = try await driver.reconcile()
            XCTFail("expected a refusal")
        } catch {
            XCTAssertEqual(error as? SyncFailure, .incompatible)
        }
        XCTAssertTrue(mac.pageIDs().isEmpty)
    }

    func testAPageThatCannotBeReadIsNeverTurnedIntoADeletion() async throws {
        let (_, scales, chords) = try makePiano(on: mac)
        try await sync()
        try Data("{ \"title\": ".utf8).write(to: try mac.folder(scales.id).appendingPathComponent("manifest.json"))
        try await sync()
        XCTAssertTrue(phone.exists(scales.id))
        XCTAssertTrue(phone.exists(chords.id))
    }

    func testAnUnrelatedFolderWithoutAPageManifestDoesNotBlockDeletions() async throws {
        let (_, scales, _) = try makePiano(on: mac)
        try await sync()
        let legacy = mac.fs.exercisesDatabaseDirectory.appendingPathComponent("Old exercises", isDirectory: true)
        try FileManager.default.createDirectory(at: legacy, withIntermediateDirectories: true)
        try Data(#"{"name":"Squat","kind":"exercise"}"#.utf8).write(to: legacy.appendingPathComponent("manifest.json"))
        try mac.db.deletePage(id: scales.id)
        try await sync()
        XCTAssertFalse(phone.exists(scales.id))
    }

    func testThreeDevicesConvergeThroughOneAnother() async throws {
        let tablet = try makeReplica("tablet", deviceName: "iPad")
        let (_, scales, _) = try makePiano(on: mac)
        try await sync()
        try await sync(from: tablet, with: phone)
        try tablet.edit(scales.id) { $0.skillStatus = .completed }
        try await sync(from: tablet, with: phone)
        try await sync(from: mac, with: phone)
        XCTAssertEqual(try mac.page(scales.id).skillStatus, .completed)
        XCTAssertEqual(try phone.page(scales.id).skillStatus, .completed)
    }

    func testPeersAreKeptPrivateAndRemovedWithTheirBase() async throws {
        let peer = SyncPeerRecord(id: "other", name: "iPhone", platform: "iphone", key: Data(repeating: 3, count: 32))
        try mac.engine.addPeer(peer)
        let file = mac.engine.store.directory.appendingPathComponent("peers.json")
        let permissions = (try FileManager.default.attributesOfItem(atPath: file.path))[.posixPermissions] as? Int
        XCTAssertEqual(permissions, 0o600)
        try mac.engine.store.saveBase(SyncBase(), peer: "other")
        try mac.engine.removePeer(id: "other")
        XCTAssertTrue(mac.engine.peers().isEmpty)
        XCTAssertFalse(fileExists(mac.engine.store.directory.appendingPathComponent("bases/other.json")))
    }
}
