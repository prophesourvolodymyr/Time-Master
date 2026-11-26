import XCTest
@testable import TimeMasterCore

final class AgentRecordToolsTests: XCTestCase {
    var root: URL!
    var database: DatabaseManager!
    var toolbox: AgentToolbox!
    var boxingID = ""

    private let mixedHistory: [(String, Int)] = [("E5", 1), ("E4", 2), ("E1", 30), ("E2", 20), ("E3", 10)]

    override func setUpWithError() throws {
        root = FileManager.default.temporaryDirectory.appendingPathComponent("record-tools-\(UUID().uuidString)", isDirectory: true)
        database = DatabaseManager(fs: FileSystemHelper(dataRoot: root))
        try database.bootstrapIfNeeded()
        toolbox = AgentToolbox(database: database)
        boxingID = try call("create_container_page", ["title": "Boxing", "workoutType": "Strength"])["id"] as! String
        for (title, duration) in [("Jab", 30), ("Cross", 40), ("Shadow", 60)] {
            try call("create_exercise_page", ["title": title, "parent": boxingID, "duration": duration])
        }
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: root)
    }

    @discardableResult
    private func call(_ name: String, _ arguments: [String: Any], dryRun: Bool = false) throws -> [String: Any] {
        try toolbox.call(name, arguments: arguments, dryRun: dryRun).value
    }

    private func output(_ name: String, _ arguments: [String: Any]) throws -> AgentToolOutput {
        try toolbox.call(name, arguments: arguments)
    }

    private func failure(_ block: () throws -> Void) -> AgentToolError? {
        do { try block(); return nil } catch { return error as? AgentToolError }
    }

    private func stored(_ name: String) throws -> WorkoutManifest {
        let id = try call("get_workout", ["workout": name])["id"] as! String
        return try database.getWorkout(id: id)
    }

    private func sections(_ name: String) throws -> [[String: Any]] {
        try call("get_workout", ["workout": name])["sections"] as! [[String: Any]]
    }

    private func moment(daysAgo: Int) -> Date {
        Date(timeIntervalSince1970: ((Date().timeIntervalSince1970 - Double(daysAgo) * 86400) / 60).rounded(.down) * 60)
    }

    private func localText(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = .current
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm"
        return formatter.string(from: date)
    }

    private func historyText() throws -> String {
        try String(contentsOf: root.appendingPathComponent("History/entries.jsonl"), encoding: .utf8)
    }

    private func historyNames() throws -> [String] {
        try database.readHistory().map(\.workoutName)
    }

    @discardableResult
    private func seedHistory(_ items: [(String, Int)]) throws -> [HistoryEntry] {
        let entries = items.map {
            HistoryEntry(workoutId: UUID().uuidString, workoutName: $0.0, completedAt: moment(daysAgo: $0.1), durationCompleted: 600, workoutType: .strength)
        }
        try database.replaceHistory(entries)
        return entries
    }

    private func makeActivity(kind: OutdoorActivityKind = .run, title: String? = nil, daysAgo: Int, meters: Double = 5000, finished: Bool = true) throws -> OutdoorActivityManifest {
        let started = moment(daysAgo: daysAgo)
        let manifest = OutdoorActivityManifest(
            kind: kind, title: title, startedAt: started, endedAt: finished ? started.addingTimeInterval(1800) : nil,
            elapsedSeconds: 1800, movingSeconds: 1700, distanceMeters: meters,
            recordingState: finished ? .finished : .recording, finished: finished
        )
        try database.createOutdoorActivity(id: manifest.id, manifest: manifest)
        return manifest
    }

    func testUndoingALoggedWorkoutRestoresTheHistoryFileExactly() throws {
        try seedHistory(mixedHistory)
        let before = try historyText()

        let logged = try output("log_workout", ["name": "Heavy bag", "seconds": 900, "type": "Cardio", "completedAt": localText(moment(daysAgo: 15))])

        XCTAssertEqual(try historyNames(), ["E5", "E4", "E1", "E2", "E3", "Heavy bag"])
        XCTAssertEqual(logged.effects.count, 1)
        XCTAssertFalse(toolbox.revert(logged.effects).isEmpty)
        XCTAssertEqual(try historyText(), before)
    }

    func testUndoingADeletedEntryPutsItBackInItsPlaceWhateverTheOrderOfTheFile() throws {
        let entries = try seedHistory(mixedHistory)
        let before = try historyText()

        for entry in entries {
            let deleted = try output("delete_history_entry", ["id": entry.id])
            XCTAssertEqual(try database.readHistory().count, 4)
            XCTAssertFalse(try historyNames().contains(entry.workoutName))
            XCTAssertEqual(deleted.effects.count, 1)
            toolbox.revert(deleted.effects)
            XCTAssertEqual(try historyText(), before, entry.workoutName)
        }
    }

    func testUndoingADeleteAfterTheHistoryMovedOnKeepsNewEntriesAndFindsTheSpotByDate() throws {
        let entries = try seedHistory(mixedHistory)
        let deleted = try output("delete_history_entry", ["id": entries[3].id])
        var moved = try database.readHistory()
        moved.insert(HistoryEntry(workoutId: UUID().uuidString, workoutName: "New", completedAt: moment(daysAgo: 0), durationCompleted: 300), at: 0)
        try database.replaceHistory(moved)

        toolbox.revert(deleted.effects)
        XCTAssertEqual(try historyNames(), ["New", "E5", "E4", "E1", "E2", "E3"])

        let again = try output("delete_history_entry", ["id": entries[3].id])
        try call("delete_history_entry", ["id": entries[2].id])
        try call("delete_history_entry", ["id": entries[4].id])
        toolbox.revert(again.effects)
        XCTAssertEqual(try historyNames(), ["New", "E5", "E4", "E2"])
    }

    func testHistoryEffectsStayCompactOnALongHistoryAndSurviveTheJournalOnDisk() throws {
        let entries = (0..<3000).map {
            HistoryEntry(workoutId: UUID().uuidString, workoutName: "Session \($0)", completedAt: moment(daysAgo: 1 + $0 % 400), durationCompleted: 600, workoutType: .strength)
        }
        try database.replaceHistory(entries)
        let before = try historyText()

        let logged = try output("log_workout", ["name": "Heavy bag", "seconds": 900])
        let deleted = try output("delete_history_entry", ["id": entries[1500].id])
        let journal = try JSONEncoder().encode(logged.effects + deleted.effects)

        XCTAssertLessThan(journal.count, 1500)
        let restored = try JSONDecoder().decode([AgentEffect].self, from: journal)
        XCTAssertEqual(restored, logged.effects + deleted.effects)
        toolbox.revert(restored)
        XCTAssertEqual(try historyText(), before)
    }

    func testUndoingATwiceRevertedEffectChangesNothing() throws {
        let entries = try seedHistory(mixedHistory)
        let deleted = try output("delete_history_entry", ["id": entries[1].id])
        let logged = try output("log_workout", ["name": "Extra", "seconds": 60])
        toolbox.revert(deleted.effects)
        toolbox.revert(logged.effects)
        let settled = try historyText()

        toolbox.revert(deleted.effects)
        toolbox.revert(logged.effects)

        XCTAssertEqual(try historyText(), settled)
        XCTAssertEqual(try historyNames(), ["E5", "E4", "E1", "E2", "E3"])
    }

    func testUndoingADeleteOnASyncedLibraryAlsoDropsTheDeletionMark() throws {
        let entries = try seedHistory(mixedHistory)
        let store = SyncStateStore(fs: database.fs)
        try store.saveState(SyncState())
        let key = entries[0].id.lowercased()

        let deleted = try output("delete_history_entry", ["id": entries[0].id])
        XCTAssertNotNil(store.loadState().historyTombstones[key])

        toolbox.revert(deleted.effects)
        XCTAssertNil(store.loadState().historyTombstones[key])
        XCTAssertEqual(try historyNames().first, "E5")
    }

    func testLogWorkoutTakesNameTypeAndLengthFromASavedWorkout() throws {
        try call("build_workout", ["name": "Bag round", "type": "Cardio", "sections": [["exercise": "Boxing/Jab", "sets": 2, "restBetweenSets": 10]]])
        let workout = try stored("Bag round")

        let logged = try call("log_workout", ["workout": "Bag round", "completedAt": localText(moment(daysAgo: 3))])

        XCTAssertEqual(logged["name"] as? String, "Bag round")
        XCTAssertEqual(logged["type"] as? String, "Cardio")
        XCTAssertEqual(logged["seconds"] as? Int, workout.totalDuration)
        XCTAssertEqual(logged["workout"] as? String, workout.id)
        XCTAssertNil(logged["partial"])
        let entry = try XCTUnwrap(try database.readHistory().first { $0.id == logged["id"] as? String })
        XCTAssertEqual(entry.workoutId, workout.id)
        XCTAssertEqual(entry.durationCompleted, workout.totalDuration)
        XCTAssertEqual(entry.workoutType.id, "Cardio")
    }

    func testAPartialWorkoutKeepsThePlannedLengthAndReportsTheTimeDone() throws {
        try call("build_workout", ["name": "Bag round", "sections": [["exercise": "Boxing/Jab", "sets": 3]]])
        let workout = try stored("Bag round")

        let logged = try call("log_workout", ["workout": "Bag round", "seconds": 240, "partial": true])

        XCTAssertEqual(logged["partial"] as? Bool, true)
        XCTAssertEqual(logged["seconds"] as? Int, 240)
        let entry = try XCTUnwrap(try database.readHistory().first)
        XCTAssertTrue(entry.isPartial)
        XCTAssertEqual(entry.elapsedSeconds, 240)
        XCTAssertEqual(entry.durationCompleted, workout.totalDuration)
        XCTAssertEqual((try call("list_history", [:])["entries"] as! [[String: Any]])[0]["seconds"] as? Int, 240)
        XCTAssertEqual(failure { _ = try self.call("log_workout", ["workout": "Bag round", "partial": true]) }?.code, "invalid_argument")
    }

    func testLogWorkoutByNameRecordsAnEntryThatNoWorkoutOwns() throws {
        let logged = try call("log_workout", ["name": "Run in the park", "seconds": 1500])

        XCTAssertEqual(logged["type"] as? String, "Other")
        XCTAssertNil(logged["workout"])
        let entry = try XCTUnwrap(try database.readHistory().first)
        XCTAssertNotNil(UUID(uuidString: entry.workoutId))
        XCTAssertNotNil(UUID(uuidString: entry.id))
        XCTAssertNil((try call("list_history", [:])["entries"] as! [[String: Any]])[0]["workout"])
    }

    func testLogWorkoutReadsLocalTimesOffsetsAndDatesAndRefusesTheRestWithAnExample() throws {
        func logged(_ text: String) throws -> Date {
            let result = try call("log_workout", ["name": "Probe", "seconds": 60, "completedAt": text])
            return try XCTUnwrap(try database.readHistory().first { $0.id == result["id"] as? String }).completedAt
        }
        let calendar = Calendar.current

        XCTAssertEqual(try logged("2025-03-01T18:30:00+02:00"), try XCTUnwrap(ISO8601DateFormatter().date(from: "2025-03-01T18:30:00+02:00")))
        XCTAssertEqual(try logged("2025-03-01T18:30:00Z"), try XCTUnwrap(ISO8601DateFormatter().date(from: "2025-03-01T18:30:00Z")))
        XCTAssertEqual(try logged("2025-03-01T18:30"), calendar.date(from: DateComponents(year: 2025, month: 3, day: 1, hour: 18, minute: 30)))
        XCTAssertEqual(try logged("2025-03-01 18:30"), calendar.date(from: DateComponents(year: 2025, month: 3, day: 1, hour: 18, minute: 30)))
        XCTAssertEqual(try logged("2025-03-01"), calendar.date(from: DateComponents(year: 2025, month: 3, day: 1, hour: 12)))

        for text in ["soon", "2025-02-30", "2025-03-01T25:00", "01/03/2025", "2025-03-01T18:30+99:00"] {
            let error = failure { _ = try self.call("log_workout", ["name": "Probe", "seconds": 60, "completedAt": text]) }
            XCTAssertEqual(error?.code, "invalid_argument", text)
            XCTAssertTrue(error?.hint?.contains("2026-11-24T18:30") == true, text)
        }
        XCTAssertEqual(try database.readHistory().count, 5)
    }

    func testLogWorkoutRefusesTheFutureButAcceptsTodayByDateAlone() throws {
        let later = failure { _ = try self.call("log_workout", ["name": "Later", "seconds": 60, "completedAt": self.localText(Date().addingTimeInterval(3 * 86400))]) }
        XCTAssertEqual(later?.code, "invalid_argument")
        XCTAssertTrue(later?.hint?.contains("up to now") == true)

        let today = DateFormatter()
        today.locale = Locale(identifier: "en_US_POSIX")
        today.dateFormat = "yyyy-MM-dd"
        let result = try call("log_workout", ["name": "Today", "seconds": 60, "completedAt": today.string(from: Date())])
        let entry = try XCTUnwrap(try database.readHistory().first { $0.id == result["id"] as? String })
        XCTAssertLessThanOrEqual(entry.completedAt, Date())
        XCTAssertEqual(try database.readHistory().count, 1)
    }

    func testLogWorkoutNeedsSomethingToRecordAndKnownReferences() throws {
        XCTAssertEqual(failure { _ = try self.call("log_workout", ["seconds": 60]) }?.code, "invalid_argument")
        XCTAssertEqual(failure { _ = try self.call("log_workout", ["name": "No length"]) }?.code, "invalid_argument")
        XCTAssertEqual(failure { _ = try self.call("log_workout", ["workout": "Nope"]) }?.code, "not_found")
        XCTAssertEqual(failure { _ = try self.call("log_workout", ["name": "Odd", "seconds": 60, "type": "Underwater"]) }?.code, "unknown_workout_type")
        XCTAssertEqual(failure { _ = try self.call("log_workout", ["name": "Odd", "seconds": 0]) }?.code, "invalid_argument")
        XCTAssertTrue(try database.readHistory().isEmpty)
    }

    func testListHistoryShowsLocalTimeNewestFirstFiltersAndBoundsTheReply() throws {
        for (name, days, type) in [("A", 1, "Strength"), ("B", 3, "Cardio"), ("C", 10, "Cardio"), ("D", 40, "Strength")] {
            try call("log_workout", ["name": name, "seconds": 600, "type": type, "completedAt": localText(moment(daysAgo: days))])
        }

        let week = try call("list_history", ["days": 7])
        let weekItems = week["entries"] as! [[String: Any]]
        XCTAssertEqual(weekItems.map { $0["name"] as? String }, ["A", "B"])
        XCTAssertEqual(week["total"] as? Int, 2)
        XCTAssertNil(week["more"])
        XCTAssertEqual(weekItems[0]["at"] as? String, localText(moment(daysAgo: 1)) + (weekItems[0]["at"] as! String).dropFirst(16))
        XCTAssertNotNil((weekItems[0]["at"] as! String).range(of: #"T\d{2}:\d{2}(Z|[+-]\d{2}:\d{2})$"#, options: .regularExpression))

        let cardio = try call("list_history", ["days": 30, "type": "Cardio"])
        XCTAssertEqual((cardio["entries"] as! [[String: Any]]).map { $0["name"] as? String }, ["B", "C"])

        let limited = try call("list_history", ["days": 365, "limit": 3])
        XCTAssertEqual((limited["entries"] as! [[String: Any]]).map { $0["name"] as? String }, ["A", "B", "C"])
        XCTAssertEqual(limited["total"] as? Int, 4)
        XCTAssertEqual(limited["more"] as? Int, 1)
    }

    func testDeleteHistoryEntryRemovesOnlyThatEntryAndDryRunChangesNothing() throws {
        let entries = try seedHistory(mixedHistory)
        let before = try historyText()

        let preview = try toolbox.call("delete_history_entry", arguments: ["id": entries[2].id], dryRun: true)
        XCTAssertEqual(preview.value["dryRun"] as? Bool, true)
        XCTAssertTrue(preview.effects.isEmpty)
        let previewLog = try toolbox.call("log_workout", arguments: ["name": "Ghost", "seconds": 60], dryRun: true)
        XCTAssertTrue(previewLog.effects.isEmpty)
        XCTAssertEqual(try historyText(), before)

        let deleted = try call("delete_history_entry", ["id": entries[2].id.lowercased()])
        XCTAssertEqual(deleted["deleted"] as? Bool, true)
        XCTAssertEqual(deleted["name"] as? String, "E1")
        XCTAssertEqual(try historyNames(), ["E5", "E4", "E2", "E3"])
        XCTAssertEqual(failure { _ = try self.call("delete_history_entry", ["id": entries[2].id]) }?.code, "not_found")
        XCTAssertEqual(AgentToolRegistry.tool(named: "delete_history_entry")?.risk, .delete)
    }

    func testOutdoorActivitiesListNewestFirstAndGetCountsTheRoutePointsWithoutDumpingThem() throws {
        let old = try makeActivity(kind: .walk, title: "Evening walk", daysAgo: 9, meters: 3200)
        let recent = try makeActivity(kind: .run, daysAgo: 1, meters: 5230)
        let unfinished = try makeActivity(kind: .bike, daysAgo: 0, meters: 100, finished: false)
        for index in 0..<50 {
            try database.appendOutdoorTrackPoint(id: recent.id, point: OutdoorTrackPoint(
                timestamp: recent.startedAt.addingTimeInterval(Double(index) * 10), latitude: 47 + Double(index) / 1000, longitude: 8,
                elevationMeters: 400 + Double(index), horizontalAccuracyMeters: 5, speedMetersPerSecond: 3, state: .recording
            ))
        }

        let listed = try call("list_outdoor_activities", [:])
        let items = listed["activities"] as! [[String: Any]]
        XCTAssertEqual(items.map { $0["id"] as? String }, [unfinished.id, recent.id, old.id])
        XCTAssertEqual(items[0]["finished"] as? Bool, false)
        XCTAssertNil(items[1]["title"])
        XCTAssertEqual(items[2]["title"] as? String, "Evening walk")
        XCTAssertEqual(items[1]["distanceKm"] as? Double, 5.23)
        XCTAssertEqual(items[1]["seconds"] as? Int, 1800)
        XCTAssertEqual(try call("list_outdoor_activities", ["kind": "run"])["total"] as? Int, 1)
        XCTAssertEqual(try call("list_outdoor_activities", ["days": 5])["total"] as? Int, 2)
        XCTAssertEqual(try call("list_outdoor_activities", ["limit": 1])["more"] as? Int, 2)

        let detail = try call("get_outdoor_activity", ["id": recent.id.lowercased()])
        XCTAssertEqual(detail["trackPoints"] as? Int, 50)
        XCTAssertNil(detail["points"])
        XCTAssertEqual(detail["distanceMeters"] as? Double, 5230)
        XCTAssertEqual(detail["movingSeconds"] as? Int, 1700)
        XCTAssertEqual(detail["visibility"] as? String, "private")
        XCTAssertEqual(detail["finished"] as? Bool, true)
        XCTAssertEqual(failure { _ = try self.call("get_outdoor_activity", ["id": "missing"]) }?.code, "not_found")
    }

    func testRoutePointsComeBackAsAnEvenSampleOnRequest() throws {
        let activity = try makeActivity(daysAgo: 1)
        for index in 0..<50 {
            try database.appendOutdoorTrackPoint(id: activity.id, point: OutdoorTrackPoint(
                timestamp: activity.startedAt.addingTimeInterval(Double(index) * 10), latitude: 47, longitude: 8 + Double(index) / 1000,
                horizontalAccuracyMeters: 5, state: .recording
            ))
        }

        let sample = try call("get_outdoor_activity", ["id": activity.id, "points": true, "limit": 5])["points"] as! [[String: Any]]
        XCTAssertEqual(sample.map { $0["t"] as? Int }, [0, 120, 240, 360, 490])
        XCTAssertEqual(sample.first?["lon"] as? Double, 8)
        XCTAssertEqual(sample.last?["lon"] as? Double, 8.049)
        XCTAssertNil(sample.first?["ele"])
        XCTAssertEqual((try call("get_outdoor_activity", ["id": activity.id, "points": true, "limit": 200])["points"] as! [[String: Any]]).count, 50)
        XCTAssertEqual((try call("get_outdoor_activity", ["id": activity.id, "points": true, "limit": 1])["points"] as! [[String: Any]]).count, 1)
        XCTAssertEqual(failure { _ = try self.call("get_outdoor_activity", ["id": activity.id, "points": true, "limit": 201]) }?.code, "invalid_argument")
    }

    func testDeleteOutdoorActivityMovesItWithItsRouteToTheTrash() throws {
        let activity = try makeActivity(daysAgo: 2)
        try database.appendOutdoorTrackPoint(id: activity.id, point: OutdoorTrackPoint(timestamp: activity.startedAt, latitude: 47, longitude: 8, horizontalAccuracyMeters: 5, state: .recording))

        let preview = try call("delete_outdoor_activity", ["id": activity.id], dryRun: true)
        XCTAssertEqual(preview["dryRun"] as? Bool, true)
        XCTAssertEqual(try database.listOutdoorActivities().count, 1)

        let deleted = try call("delete_outdoor_activity", ["id": activity.id])
        XCTAssertEqual(deleted["trashed"] as? Bool, true)
        XCTAssertTrue(try database.listOutdoorActivities().isEmpty)
        let trash = root.appendingPathComponent(".trash")
        let moved = try XCTUnwrap(try FileManager.default.contentsOfDirectory(atPath: trash.path).first { $0.hasSuffix(activity.id) })
        XCTAssertTrue(FileManager.default.fileExists(atPath: trash.appendingPathComponent("\(moved)/track.jsonl").path))
        XCTAssertEqual(failure { _ = try self.call("delete_outdoor_activity", ["id": activity.id]) }?.code, "not_found")
        XCTAssertEqual(AgentToolRegistry.tool(named: "delete_outdoor_activity")?.risk, .delete)
    }

    func testUpdateOutdoorActivityChangesWhatIsPassedAndLeavesPrivacyAlone() throws {
        let activity = try makeActivity(kind: .run, daysAgo: 2)

        let changed = try call("update_outdoor_activity", ["id": activity.id, "title": "Hill repeats", "starred": true, "description": " Windy ", "tags": ["hills", "Hills", " tempo "]])
        XCTAssertEqual(Set(changed["changed"] as! [String]), ["title", "starred", "description", "tags"])
        var saved = try database.getOutdoorActivity(id: activity.id)
        XCTAssertEqual(saved.title, "Hill repeats")
        XCTAssertTrue(saved.starred)
        XCTAssertEqual(saved.publicDescription, "Windy")
        XCTAssertEqual(saved.tags, ["hills", "tempo"])
        XCTAssertEqual(saved.kind, .run)
        XCTAssertEqual(saved.visibility, .privateVisibility)
        XCTAssertEqual(saved.distanceMeters, 5000)

        try call("update_outdoor_activity", ["id": activity.id, "kind": "walk"])
        saved = try database.getOutdoorActivity(id: activity.id)
        XCTAssertEqual(saved.kind, .walk)
        XCTAssertEqual(saved.title, "Hill repeats")

        try call("update_outdoor_activity", ["id": activity.id, "title": ""])
        XCTAssertEqual(try database.getOutdoorActivity(id: activity.id).title, "Walk")
        try call("update_outdoor_activity", ["id": activity.id, "kind": "bike"])
        XCTAssertEqual(try database.getOutdoorActivity(id: activity.id).title, "Bike")
        try call("update_outdoor_activity", ["id": activity.id, "tags": [], "description": ""])
        saved = try database.getOutdoorActivity(id: activity.id)
        XCTAssertTrue(saved.tags.isEmpty)
        XCTAssertEqual(saved.publicDescription, "")
    }

    func testUpdateOutdoorActivityRefusesUnfinishedOnesEmptyCallsAndDryRunChangesNothing() throws {
        let live = try makeActivity(kind: .run, daysAgo: 0, finished: false)
        let done = try makeActivity(kind: .run, daysAgo: 3)

        XCTAssertEqual(failure { _ = try self.call("update_outdoor_activity", ["id": live.id, "title": "x"]) }?.code, "invalid_argument")
        XCTAssertEqual(failure { _ = try self.call("update_outdoor_activity", ["id": done.id]) }?.code, "invalid_argument")
        XCTAssertEqual(failure { _ = try self.call("update_outdoor_activity", ["id": done.id, "kind": "runWalk"]) }?.code, "invalid_argument")
        let preview = try call("update_outdoor_activity", ["id": done.id, "title": "Preview", "starred": true], dryRun: true)
        XCTAssertEqual(preview["dryRun"] as? Bool, true)
        XCTAssertEqual(try database.getOutdoorActivity(id: done.id).title, "Run")
        XCTAssertFalse(try database.getOutdoorActivity(id: done.id).starred)
        XCTAssertEqual(try database.getOutdoorActivity(id: live.id).title, "Run")
    }

    func testValidateLibraryIgnoresUnsetFieldsAndPointsAtUnreadableManifests() throws {
        let healthy = try call("validate_library", [:])
        XCTAssertEqual(healthy["withErrors"] as? Int, 0)
        XCTAssertNil(healthy["problems"])
        XCTAssertNil(healthy["withWarnings"])
        XCTAssertGreaterThanOrEqual(healthy["checked"] as! Int, 4)
        XCTAssertEqual(healthy["healthy"] as? Int, healthy["checked"] as? Int)

        let hookID = try call("create_exercise_page", ["title": "Hook", "parent": boxingID])["id"] as! String
        try Data("{ not json".utf8).write(to: database.exercisesDatabaseURL.appendingPathComponent("\(boxingID)/\(hookID)/manifest.json"))
        try call("build_workout", ["name": "Broken", "sections": [["exercise": "Boxing/Jab"]]])
        let workoutID = try stored("Broken").id
        try Data("{ not json".utf8).write(to: root.appendingPathComponent("Workouts/\(workoutID)/manifest.json"))

        let report = try call("validate_library", [:])
        XCTAssertEqual(report["withErrors"] as? Int, 2)
        XCTAssertEqual(report["healthy"] as? Int, (report["checked"] as! Int) - 2)
        let problems = report["problems"] as! [[String: Any]]
        XCTAssertEqual(problems.count, 2)
        XCTAssertTrue(problems.allSatisfy { ($0["errors"] as? [String])?.contains("Failed to parse manifest.json") == true })
        XCTAssertEqual(problems.first { ($0["path"] as? String)?.hasSuffix(hookID) == true }?["in"] as? String, "Boxing")
        XCTAssertEqual(problems.first { $0["path"] as? String == "Workouts/\(workoutID)" }?["path"] as? String, "Workouts/\(workoutID)")
        XCTAssertNil(report["more"])
    }

    func testValidateLibraryListsFiftyProblemsAndCountsTheRest() throws {
        var ids: [String] = []
        for index in 0..<53 {
            ids.append(try call("create_exercise_page", ["title": "Drill \(index)", "parent": boxingID])["id"] as! String)
        }
        for id in ids {
            try Data("{".utf8).write(to: database.exercisesDatabaseURL.appendingPathComponent("\(boxingID)/\(id)/manifest.json"))
        }

        let report = try call("validate_library", [:])

        XCTAssertEqual(report["withErrors"] as? Int, 53)
        XCTAssertEqual((report["problems"] as! [[String: Any]]).count, 50)
        XCTAssertEqual(report["more"] as? Int, 3)
    }

    func testCreateBackupCopiesTheLibraryIntoANewFolderUnderBackups() throws {
        try call("build_workout", ["name": "Keep me", "sections": [["exercise": "Boxing/Jab"]]])
        let workoutID = try stored("Keep me").id
        let backups = root.appendingPathComponent("Backups")

        let preview = try call("create_backup", [:], dryRun: true)
        XCTAssertEqual(preview["dryRun"] as? Bool, true)
        XCTAssertTrue(try FileManager.default.contentsOfDirectory(atPath: backups.path).isEmpty)

        let made = try call("create_backup", ["label": "before cleanup"])
        let folder = try XCTUnwrap(made["folder"] as? String)
        XCTAssertTrue(folder.hasSuffix("-before-cleanup"))
        XCTAssertFalse(folder.contains("/"))
        XCTAssertEqual(made["in"] as? String, "Backups")
        XCTAssertTrue((made["contains"] as! [String]).contains("Exercises Database"))
        XCTAssertTrue(FileManager.default.fileExists(atPath: backups.appendingPathComponent("\(folder)/Workouts/\(workoutID)/manifest.json").path))

        try call("delete_workout", ["workout": "Keep me"])
        XCTAssertTrue(FileManager.default.fileExists(atPath: backups.appendingPathComponent("\(folder)/Workouts/\(workoutID)/manifest.json").path))
        XCTAssertTrue(try call("create_backup", [:])["folder"] as! String != folder)
        XCTAssertEqual(failure { _ = try self.call("create_backup", ["label": "../etc"]) }?.code, "invalid_argument")
    }

    private func workoutIDs(_ workout: WorkoutManifest) -> [String] {
        func slotIDs(_ slot: WorkoutSetSlotManifest) -> [String] {
            [slot.id] + [slot.restRow?.id].compactMap { $0 } + slot.children.flatMap(slotIDs)
        }
        return [workout.id] + workout.sections.flatMap { section in
            [section.id] + [section.bigRestRow?.id].compactMap { $0 } + section.slots.flatMap(slotIDs)
        }
    }

    func testDuplicateWorkoutCopiesEverythingWithFreshIdsAndLeavesTheGroupsAlone() throws {
        try call("build_workout", ["name": "Mat", "colorHex": "FF9500", "sections": [
            ["exercise": "Boxing/Jab", "sets": 2, "restBetweenSets": 40, "restExercise": ["Boxing/Cross"]],
            ["bundle": ["exercises": [["exercise": "Boxing/Jab", "duration": 20], ["callout": "Switch stance"]], "sets": 2]],
            ["combo": ["calls": ["1-2", "1-2-3"], "rounds": 2, "icon": "flame.fill"]],
        ]])
        try call("create_workout_group", ["title": "Week 1", "workouts": ["Mat"]])
        let original = try stored("Mat")

        let copy = try call("duplicate_workout", ["workout": "Mat"])

        XCTAssertEqual(copy["name"] as? String, "Mat Copy")
        XCTAssertEqual(copy["copyOf"] as? String, "Mat")
        let duplicate = try stored("Mat Copy")
        XCTAssertEqual(duplicate.id, copy["id"] as? String)
        XCTAssertNotEqual(duplicate.id, original.id)
        XCTAssertTrue(Set(workoutIDs(original)).isDisjoint(with: workoutIDs(duplicate)))
        XCTAssertEqual(Set(workoutIDs(duplicate)).count, workoutIDs(duplicate).count)
        XCTAssertEqual(workoutIDs(duplicate).count, workoutIDs(original).count)
        XCTAssertEqual(duplicate.totalDuration, original.totalDuration)
        XCTAssertEqual(duplicate.sections.map(\.name), original.sections.map(\.name))
        XCTAssertEqual(duplicate.sections.map(\.isCombo), [false, false, true])
        XCTAssertEqual(duplicate.sections[2].iconName, "flame.fill")
        XCTAssertEqual(duplicate.sections[0].restExerciseID, original.sections[0].restExerciseID)
        XCTAssertEqual(duplicate.colorHex, "FF9500")
        XCTAssertEqual(duplicate.sections[1].slots[0].children.map(\.name), original.sections[1].slots[0].children.map(\.name))

        let groups = try call("list_workout_groups", [:])
        XCTAssertEqual((groups["groups"] as! [[String: Any]])[0]["workouts"] as? [String], ["Mat"])
        XCTAssertTrue((groups["ungrouped"] as! [String]).contains("Mat Copy"))
        XCTAssertEqual(try call("duplicate_workout", ["workout": "Mat"])["name"] as? String, "Mat Copy 2")
        XCTAssertEqual(try stored("Mat").id, original.id)
    }

    func testDuplicateWorkoutNamesAndGroupsTheCopyAndUndoRemovesIt() throws {
        try call("build_workout", ["name": "Mat", "sections": [["exercise": "Boxing/Jab"]]])
        try call("create_workout_group", ["title": "Week 1", "workouts": ["Mat"]])

        XCTAssertEqual(failure { _ = try self.call("duplicate_workout", ["workout": "Mat", "name": "mat"]) }?.code, "already_exists")
        XCTAssertEqual(failure { _ = try self.call("duplicate_workout", ["workout": "Mat", "group": "Week 9"]) }?.code, "not_found")
        XCTAssertEqual(failure { _ = try self.call("duplicate_workout", ["workout": "Nope"]) }?.code, "not_found")
        let preview = try toolbox.call("duplicate_workout", arguments: ["workout": "Mat", "name": "Mat B", "group": "Week 1"], dryRun: true)
        XCTAssertEqual(preview.value["dryRun"] as? Bool, true)
        XCTAssertTrue(preview.effects.isEmpty)
        XCTAssertEqual(try database.listWorkouts().count, 1)

        let made = try output("duplicate_workout", ["workout": "Mat", "name": "Mat B", "group": "Week 1"])
        XCTAssertEqual(made.value["group"] as? String, "Week 1")
        XCTAssertEqual(((try call("list_workout_groups", [:]))["groups"] as! [[String: Any]])[0]["workouts"] as? [String], ["Mat", "Mat B"])

        XCTAssertFalse(toolbox.revert(made.effects).isEmpty)
        XCTAssertEqual(try database.listWorkouts().map(\.name), ["Mat"])
        XCTAssertEqual(((try call("list_workout_groups", [:]))["groups"] as! [[String: Any]])[0]["workouts"] as? [String], ["Mat"])
    }

    private func comboWorkout(_ name: String = "Bag work") throws {
        try call("build_workout", ["name": name, "sections": [
            ["combo": ["calls": ["1-2", "1-2-3", "1-1-2-slip"], "rounds": 3, "icon": "flame.fill"], "name": "Round robin"],
            ["exercise": "Boxing/Shadow"],
        ]])
    }

    func testAComboIsBuiltInTheShapeTheAppBuilds() throws {
        let built = try call("build_workout", ["name": "Bag work", "sections": [
            ["combo": ["calls": ["1-2", "1-2-3", "1-1-2-slip"], "rounds": 3, "icon": "flame.fill"], "name": "Round robin"],
            ["exercise": "Boxing/Shadow"],
        ]])

        XCTAssertEqual(built["combos"] as? Int, 1)
        XCTAssertNil(built["bundles"])
        let workout = try stored("Bag work")
        let combo = workout.sections[0]
        XCTAssertTrue(combo.isCombo)
        XCTAssertEqual(combo.mode, .bundle)
        XCTAssertTrue(combo.bundleVoiceEnabled)
        XCTAssertTrue(combo.isTimerEnabled)
        XCTAssertEqual(combo.name, "Round robin")
        XCTAssertEqual(combo.iconName, "flame.fill")
        XCTAssertEqual(combo.iconType, "system")
        XCTAssertEqual(combo.exerciseID, "")
        XCTAssertEqual(combo.sets, 3)
        XCTAssertEqual(combo.restBetweenSets, 20)
        XCTAssertEqual(combo.prepareTime, 3)
        XCTAssertEqual(combo.customRestAfter, 30)
        XCTAssertEqual(combo.bigRestRow?.duration, 30)
        XCTAssertEqual(combo.slots.map(\.name), ["Set 1", "Set 2", "Set 3"])
        XCTAssertEqual(combo.slots.map(\.prepareTime), [3, 0, 0])
        XCTAssertEqual(combo.slots.map(\.restAfter), [20, 20, 0])
        XCTAssertEqual(combo.slots.map(\.playbackRest), [20, 20, 0])
        XCTAssertEqual(combo.slots[0].children.map(\.name), ["1-2", "1-2-3", "1-1-2-slip"])
        let leaves = combo.slots.flatMap(\.children)
        XCTAssertTrue(leaves.allSatisfy { $0.duration == 5 && $0.restAfter == 0 && $0.prepareTime == 0 && $0.exerciseID.isEmpty && $0.children.isEmpty })
        XCTAssertEqual(Set(leaves.map(\.id)).count, 9)
        XCTAssertEqual(combo.calculatedDuration, 3 + 9 * 5 + 20 + 20)
        XCTAssertEqual(workout.totalDuration, built["totalSeconds"] as? Int)
        XCTAssertEqual(workout.sections[0].bigRestRow?.duration, 30)
    }

    func testComboTimingsAndOptionsAreTheOnesGiven() throws {
        try call("build_workout", ["name": "Bag work", "sections": [
            ["combo": ["calls": ["1-2"], "rounds": 2, "secondsPerCall": 8, "restBetweenRounds": 45, "voice": false, "order": "random", "icon": "🥊"], "untimed": true, "prepareTime": 6, "restAfter": 15],
            ["exercise": "Boxing/Jab"],
        ]])

        let combo = try stored("Bag work").sections[0]
        XCTAssertEqual(combo.slots.map(\.duration), [8, 8])
        XCTAssertEqual(combo.slots[0].children.map(\.duration), [8])
        XCTAssertEqual(combo.slots.map(\.restAfter), [45, 0])
        XCTAssertEqual(combo.restBetweenSets, 45)
        XCTAssertEqual(combo.duration, 8)
        XCTAssertFalse(combo.bundleVoiceEnabled)
        XCTAssertEqual(combo.bundleOrder, .random)
        XCTAssertFalse(combo.isTimerEnabled)
        XCTAssertEqual(combo.prepareTime, 6)
        XCTAssertEqual(combo.slots.map(\.prepareTime), [6, 0])
        XCTAssertEqual(combo.customRestAfter, 15)
        XCTAssertEqual(combo.iconType, "emoji")
    }

    func testCallsAreReadLeniently() throws {
        try call("build_workout", ["name": "Lenient", "sections": [["combo": ["calls": ["123", "1 2 3", "1,2,slip", "1-2-Slip", "12slip", " 6-reset "], "rounds": 1]]]])

        XCTAssertEqual(try stored("Lenient").sections[0].slots[0].children.map(\.name), ["1-2-3", "1-2-3", "1-2-slip", "1-2-slip", "1-2-slip", "6-reset"])
    }

    func testUnknownMovesEmptyCallsAndLongCallsAreRefusedWithTheMovesToUse() throws {
        for calls in [["jab"], ["1-7"], ["0"], [" - "], [""], ["1-2-3-4-5-6-1-2-3"], ["1-2", "uppercut"]] {
            let error = failure { _ = try self.call("build_workout", ["name": "Bad", "sections": [["combo": ["calls": calls]]]]) }
            XCTAssertEqual(error?.code, "invalid_argument", "\(calls)")
            XCTAssertTrue(error?.hint?.contains("Moves") == true || error?.hint?.contains("Split") == true, "\(calls)")
        }
        let unknown = failure { _ = try self.call("build_workout", ["name": "Bad", "sections": [["combo": ["calls": ["1-jab"]]]]]) }
        XCTAssertTrue(unknown?.message.contains("'jab'") == true)
        XCTAssertTrue(unknown?.hint?.contains("lead hook") == true)
        let tooMany = failure { _ = try self.call("build_workout", ["name": "Bad", "sections": [["combo": ["calls": Array(repeating: "1-2", count: 41)]]]]) }
        XCTAssertEqual(tooMany?.code, "invalid_argument")
        XCTAssertEqual(failure { _ = try self.call("build_workout", ["name": "Bad", "sections": [["combo": ["rounds": 2]]]]) }?.code, "invalid_argument")
        XCTAssertEqual(failure { _ = try self.call("build_workout", ["name": "Bad", "sections": [["combo": ["calls": ["1-2"], "rounds": 0]]]]) }?.code, "invalid_argument")
        XCTAssertEqual(failure { _ = try self.call("build_workout", ["name": "Bad", "sections": [["combo": ["calls": ["1-2"], "tempo": 3]]]]) }?.code, "invalid_argument")
        XCTAssertTrue(try database.listWorkouts().isEmpty)
    }

    func testACombosOtherSectionArgumentsMustNotContradictIt() throws {
        let conflicts: [[String: Any]] = [
            ["combo": ["calls": ["1-2"]], "exercise": "Boxing/Jab"],
            ["combo": ["calls": ["1-2"]], "bundle": ["exercises": [["exercise": "Boxing/Jab"]]]],
            ["combo": ["calls": ["1-2"]], "sets": 2],
            ["combo": ["calls": ["1-2"]], "duration": 10],
            ["combo": ["calls": ["1-2"]], "restBetweenSets": 10],
            ["combo": ["calls": ["1-2"]], "repCount": 10],
            ["combo": ["calls": ["1-2"], "name": "A"], "name": "B"],
        ]
        for section in conflicts {
            XCTAssertEqual(failure { _ = try self.call("build_workout", ["name": "Bad", "sections": [section]]) }?.code, "invalid_argument", "\(section.keys)")
        }
        XCTAssertTrue(failure { _ = try self.call("build_workout", ["name": "Bad", "sections": [["combo": ["calls": ["1-2"]], "sets": 2]]]) }?.hint?.contains("combo.rounds") == true)
        try call("build_workout", ["name": "Same", "sections": [["combo": ["calls": ["1-2"], "name": "Bag"], "name": "bag"]]])
        XCTAssertEqual(try stored("Same").sections[0].name, "bag")
        try call("build_workout", ["name": "Inner", "sections": [["combo": ["calls": ["1-2"], "name": "Inner name"]]]])
        XCTAssertEqual(try stored("Inner").sections[0].name, "Inner name")
        try call("build_workout", ["name": "Default", "sections": [["combo": ["calls": ["1-2"]]]]])
        XCTAssertEqual(try stored("Default").sections[0].name, "Combo")
    }

    func testGetWorkoutMarksCombosAndListWorkoutsCountsThemApartFromBundles() throws {
        try call("build_workout", ["name": "Mixed", "sections": [
            ["combo": ["calls": ["1-2", "1-2-3", "1-1-2-slip"], "rounds": 3, "icon": "flame.fill"], "name": "Round robin"],
            ["bundle": ["exercises": [["exercise": "Boxing/Jab"], ["exercise": "Boxing/Cross"]], "sets": 2]],
            ["exercise": "Boxing/Shadow"],
        ]])

        let read = try sections("Mixed")

        XCTAssertEqual(read[0]["kind"] as? String, "combo")
        XCTAssertEqual(read[0]["name"] as? String, "Round robin")
        XCTAssertEqual(read[0]["calls"] as? [String], ["1-2", "1-2-3", "1-1-2-slip"])
        XCTAssertEqual(read[0]["rounds"] as? Int, 3)
        XCTAssertEqual(read[0]["secondsPerCall"] as? Int, 5)
        XCTAssertEqual(read[0]["restBetweenRounds"] as? Int, 20)
        XCTAssertEqual(read[0]["icon"] as? String, "flame.fill")
        XCTAssertEqual(read[0]["seconds"] as? Int, 3 + 9 * 5 + 20 + 20)
        for absent in ["exercises", "sets", "voice", "order", "roundCalls", "prepareTime", "untimed"] { XCTAssertNil(read[0][absent], absent) }
        XCTAssertEqual(read[1]["kind"] as? String, "bundle")
        XCTAssertEqual(read[2]["kind"] as? String, "exercise")

        let listed = (try call("list_workouts", [:])["workouts"] as! [[String: Any]])[0]
        XCTAssertEqual(listed["bundles"] as? Int, 1)
        XCTAssertEqual(listed["combos"] as? Int, 1)
    }

    func testGetWorkoutReportsCombosWhoseRoundsOrTimingsWereEditedInTheApp() throws {
        try comboWorkout()
        var workout = try stored("Bag work")
        workout.sections[0].slots[1].children.removeLast()
        workout.sections[0].slots[2].children[0].duration = 9
        workout.sections[0].slots[0].restAfter = 30
        workout.sections[0].slots[0].restRow?.duration = 30
        workout.sections[0].bundleVoiceEnabled = false
        workout.sections[0].slots[1].children[0].alias = "1 1"
        try database.updateWorkout(id: workout.id, manifest: workout)

        let combo = try sections("Bag work")[0]

        XCTAssertNil(combo["calls"])
        XCTAssertEqual(combo["roundCalls"] as? [[String]], [["1-2", "1-2-3", "1-1-2-slip"], ["1-1", "1-2-3"], ["1-2", "1-2-3", "1-1-2-slip"]])
        XCTAssertNil(combo["secondsPerCall"])
        XCTAssertEqual(combo["roundCallSeconds"] as? [[Int]], [[5, 5, 5], [5, 5], [9, 5, 5]])
        XCTAssertEqual(combo["roundRests"] as? [Int], [30, 20])
        XCTAssertEqual(combo["voice"] as? Bool, false)
    }

    func testUpdatingAComboChangesOnlyWhatIsPassedAndKeepsItsFlagAndIcon() throws {
        try comboWorkout()
        let before = try stored("Bag work").sections[0]

        let changed = try call("update_workout_section", ["workout": "Bag work", "section": "Round robin", "combo": ["rounds": 5]])

        XCTAssertEqual(changed["changed"] as? [String], ["rounds"])
        XCTAssertEqual(changed["kind"] as? String, "combo")
        var section = try stored("Bag work").sections[0]
        XCTAssertTrue(section.isCombo)
        XCTAssertEqual(section.iconName, "flame.fill")
        XCTAssertEqual(section.sets, 5)
        XCTAssertEqual(section.slots.map(\.name), ["Set 1", "Set 2", "Set 3", "Set 4", "Set 5"])
        XCTAssertEqual(section.slots.map(\.restAfter), [20, 20, 20, 20, 0])
        XCTAssertEqual(section.slots.map(\.prepareTime), [3, 0, 0, 0, 0])
        XCTAssertEqual(section.slots[4].children.map(\.name), ["1-2", "1-2-3", "1-1-2-slip"])
        XCTAssertEqual(Set(section.slots.flatMap(\.children).map(\.id)).count, 15)
        XCTAssertEqual(Array(section.slots.prefix(3)).map(\.id), before.slots.map(\.id))

        try call("update_workout_section", ["workout": "Bag work", "section": "1", "combo": ["calls": ["1", "2-3", "reset"], "secondsPerCall": 8, "restBetweenRounds": 15]])
        section = try stored("Bag work").sections[0]
        XCTAssertEqual(section.slots.count, 5)
        XCTAssertTrue(section.slots.allSatisfy { $0.children.map(\.name) == ["1", "2-3", "reset"] && $0.children.allSatisfy { $0.duration == 8 } })
        XCTAssertEqual(section.slots.map(\.restAfter), [15, 15, 15, 15, 0])
        XCTAssertEqual(section.restBetweenSets, 15)
        XCTAssertEqual(section.duration, 8)
        XCTAssertEqual(section.name, "Round robin")
        XCTAssertEqual(section.iconName, "flame.fill")
        XCTAssertTrue(section.isCombo)

        try call("update_workout_section", ["workout": "Bag work", "section": "1", "combo": ["rounds": 2]])
        section = try stored("Bag work").sections[0]
        XCTAssertEqual(section.slots.map(\.restAfter), [15, 0])
        XCTAssertEqual(section.sets, 2)
    }

    func testUpdatingAComboKeepsEverythingElseWhenOnlyOneThingChanges() throws {
        try comboWorkout()
        let before = try stored("Bag work").sections[0]

        try call("update_workout_section", ["workout": "Bag work", "section": "1", "combo": ["icon": "🥊"]])
        var section = try stored("Bag work").sections[0]
        XCTAssertEqual(section.iconName, "🥊")
        XCTAssertEqual(section.iconType, "emoji")
        XCTAssertEqual(section.slots.map(\.id), before.slots.map(\.id))
        XCTAssertEqual(section.slots.flatMap(\.children).map(\.id), before.slots.flatMap(\.children).map(\.id))

        try call("update_workout_section", ["workout": "Bag work", "section": "1", "combo": ["icon": ""]])
        section = try stored("Bag work").sections[0]
        XCTAssertNil(section.iconName)
        XCTAssertNil(section.iconType)
        XCTAssertTrue(section.isCombo)

        try call("update_workout_section", ["workout": "Bag work", "section": "1", "name": "Bag", "restAfter": 45, "untimed": true, "prepareTime": 6])
        section = try stored("Bag work").sections[0]
        XCTAssertTrue(section.isCombo)
        XCTAssertEqual(section.name, "Bag")
        XCTAssertEqual(section.bigRestRow?.duration, 45)
        XCTAssertFalse(section.isTimerEnabled)
        XCTAssertEqual(section.slots.map(\.prepareTime), [6, 0, 0])
        XCTAssertEqual(section.prepareTime, 6)
        XCTAssertEqual(section.slots[0].children.map(\.name), ["1-2", "1-2-3", "1-1-2-slip"])

        try call("update_workout_section", ["workout": "Bag work", "section": "Bag", "combo": ["name": "Combo B", "voice": false, "order": "random"]])
        section = try stored("Bag work").sections[0]
        XCTAssertEqual(section.name, "Combo B")
        XCTAssertFalse(section.bundleVoiceEnabled)
        XCTAssertEqual(section.bundleOrder, .random)
        XCTAssertEqual(failure { _ = try self.call("update_workout_section", ["workout": "Bag work", "section": "1", "name": "X", "combo": ["name": "Y"]]) }?.code, "invalid_argument")
        XCTAssertEqual(failure { _ = try self.call("update_workout_section", ["workout": "Bag work", "section": "1", "combo": ["calls": ["jab"]]]) }?.code, "invalid_argument")
        XCTAssertEqual(try stored("Bag work").sections[0].name, "Combo B")
    }

    func testAPlainBundleArgumentOnAComboIsRefusedWithAHintToUseCombo() throws {
        try comboWorkout()
        try call("update_workout_section", ["workout": "Bag work", "section": "2", "name": "Shadow rounds"])

        let bundle = failure { _ = try self.call("update_workout_section", ["workout": "Bag work", "section": "1", "bundle": ["sets": 2]]) }
        XCTAssertEqual(bundle?.code, "invalid_argument")
        XCTAssertTrue(bundle?.hint?.contains("combo") == true)
        for (key, instead) in [("sets", "combo.rounds"), ("duration", "combo.secondsPerCall"), ("restBetweenSets", "combo.restBetweenRounds")] {
            let error = failure { _ = try self.call("update_workout_section", ["workout": "Bag work", "section": "1", key: 10]) }
            XCTAssertEqual(error?.code, "invalid_argument", key)
            XCTAssertTrue(error?.hint?.contains(instead) == true, key)
        }
        XCTAssertEqual(failure { _ = try self.call("update_workout_section", ["workout": "Bag work", "section": "1", "repCount": 4]) }?.code, "invalid_argument")
        let notACombo = failure { _ = try self.call("update_workout_section", ["workout": "Bag work", "section": "Shadow rounds", "combo": ["rounds": 2]]) }
        XCTAssertEqual(notACombo?.code, "invalid_argument")
        XCTAssertEqual(try stored("Bag work").sections[0].slots.count, 3)
    }

    func testAddWorkoutSectionAppendsAComboAndKeepsTheRestBetweenSections() throws {
        try call("build_workout", ["name": "Mat", "restBetweenSections": 25, "sections": [["exercise": "Boxing/Jab"]]])

        let added = try call("add_workout_section", ["workout": "Mat", "combo": ["calls": ["1-2"], "rounds": 2, "secondsPerCall": 4], "name": "Bag"])

        XCTAssertEqual(added["kind"] as? String, "combo")
        XCTAssertEqual(added["previousSectionRest"] as? Int, 25)
        var workout = try stored("Mat")
        XCTAssertEqual(workout.sections.map(\.name), ["Jab", "Bag"])
        XCTAssertEqual(workout.sections[0].bigRestRow?.duration, 25)
        XCTAssertTrue(workout.sections[1].isCombo)
        XCTAssertEqual(workout.sections[1].bigRestRow?.duration, 0)
        XCTAssertEqual(workout.sections[1].slots.count, 2)

        try call("add_workout_section", ["workout": "Mat", "combo": ["calls": ["3-4"]], "position": 1])
        workout = try stored("Mat")
        XCTAssertEqual(workout.sections.map(\.isCombo), [true, false, true])
        XCTAssertEqual(workout.sections[0].bigRestRow?.duration, 25)
        XCTAssertEqual(workout.sections[0].name, "Combo")
        XCTAssertEqual(try call("remove_workout_section", ["workout": "Mat", "section": "1"])["removed"] as? String, "Combo")
    }

    func testARestExerciseCanFillTheBreakBetweenComboRounds() throws {
        try call("build_workout", ["name": "Mat", "sections": [
            ["combo": ["calls": ["1-2"], "rounds": 3, "restBetweenRounds": 60], "restExercise": "Boxing/Shadow"],
            ["exercise": "Boxing/Jab"],
        ]])

        let combo = try stored("Mat").sections[0]
        XCTAssertEqual(combo.slots.map { $0.restExerciseID == nil }, [false, false, true])
        XCTAssertEqual(try sections("Mat")[0]["restExercise"] as? String, "Boxing/Shadow")

        try call("update_workout_section", ["workout": "Mat", "section": "1", "combo": ["rounds": 4]])
        XCTAssertEqual(try stored("Mat").sections[0].slots.map { $0.restExerciseID == nil }, [false, false, false, true])
    }

    func testWorkoutsWithoutComboFieldsReadAsBeforeAndNoToolTurnsThemIntoCombos() throws {
        try call("build_workout", ["name": "Plain", "sections": [
            ["bundle": ["exercises": [["exercise": "Boxing/Jab"], ["exercise": "Boxing/Cross"]], "sets": 2]],
            ["exercise": "Boxing/Shadow"],
        ]])

        let section = try stored("Plain").sections[0]
        XCTAssertFalse(section.isCombo)
        XCTAssertNil(section.iconName)
        XCTAssertEqual(try sections("Plain")[0]["kind"] as? String, "bundle")
        try call("update_workout_section", ["workout": "Plain", "section": "1", "bundle": ["sets": 3], "name": "Drills"])
        let after = try stored("Plain").sections[0]
        XCTAssertFalse(after.isCombo)
        XCTAssertEqual(after.sets, 3)
        let object = try XCTUnwrap(try JSONSerialization.jsonObject(with: JSONEncoder().encode(after)) as? [String: Any])
        XCTAssertNil(object["isCombo"])
        XCTAssertNil(object["iconName"])
    }

    func testUpdateWorkoutSetsIconColorAndCoverStyleAndGetWorkoutShowsThem() throws {
        try call("build_workout", ["name": "Mat", "sections": [["exercise": "Boxing/Jab"]]])
        let plain = try call("get_workout", ["workout": "Mat"])
        XCTAssertNil(plain["colorHex"])
        XCTAssertNil(plain["coverStyle"])

        let changed = try call("update_workout", ["workout": "Mat", "colorHex": "#ff9500", "coverStyle": "icon"])

        XCTAssertEqual(Set(changed["changed"] as! [String]), ["colorHex", "coverStyle"])
        let workout = try stored("Mat")
        XCTAssertEqual(workout.colorHex, "FF9500")
        XCTAssertEqual(workout.coverStyle, .icon)
        let read = try call("get_workout", ["workout": "Mat"])
        XCTAssertEqual(read["colorHex"] as? String, "FF9500")
        XCTAssertEqual(read["coverStyle"] as? String, "icon")
        try call("update_workout", ["workout": "Mat", "coverStyle": "exerciseThumbnails"])
        XCTAssertNil(try call("get_workout", ["workout": "Mat"])["coverStyle"])
        for bad in ["orange", "FF95", "GG9500", ""] {
            XCTAssertEqual(failure { _ = try self.call("update_workout", ["workout": "Mat", "colorHex": bad]) }?.code, "invalid_argument", bad)
        }
        XCTAssertEqual(failure { _ = try self.call("update_workout", ["workout": "Mat", "coverStyle": "customImage"]) }?.code, "invalid_argument")
        XCTAssertEqual(try stored("Mat").colorHex, "FF9500")

        try call("build_workout", ["name": "Tinted", "colorHex": "34C759", "coverStyle": "icon", "sections": [["exercise": "Boxing/Jab"]]])
        XCTAssertEqual(try stored("Tinted").colorHex, "34C759")
        XCTAssertEqual(try stored("Tinted").coverStyle, .icon)
    }

    func testGetWorkoutShowsRepCountsPrepareTimesNamesAndCalloutsAndTheyFeedBackIn() throws {
        try call("build_workout", ["name": "Mat", "sections": [
            ["exercise": "Boxing/Jab", "name": "Warm-up jabs", "repCount": 12, "prepareTime": 10],
            ["bundle": ["exercises": [
                ["exercise": "Boxing/Jab", "duration": 20, "repCount": 8, "name": "Slow jab"],
                ["callout": "Switch stance", "duration": 4],
                ["exercise": "Boxing/Cross"],
            ], "sets": 2]],
        ]])

        let read = try sections("Mat")

        XCTAssertEqual(read[0]["name"] as? String, "Warm-up jabs")
        XCTAssertEqual(read[0]["repCount"] as? Int, 12)
        XCTAssertEqual(read[0]["prepareTime"] as? Int, 10)
        let exercises = read[1]["exercises"] as! [[String: Any]]
        XCTAssertEqual(exercises[0]["exercise"] as? String, "Boxing/Jab")
        XCTAssertEqual(exercises[0]["name"] as? String, "Slow jab")
        XCTAssertEqual(exercises[0]["repCount"] as? Int, 8)
        XCTAssertEqual(exercises[1]["callout"] as? String, "Switch stance")
        XCTAssertNil(exercises[1]["exercise"])
        XCTAssertEqual(exercises[1]["duration"] as? Int, 4)
        XCTAssertEqual(exercises[1]["restAfter"] as? Int, 0)
        XCTAssertNil(exercises[2]["name"])
        XCTAssertNil(exercises[2]["repCount"])

        let slot = try stored("Mat").sections[1].slots[0].children[1]
        XCTAssertEqual(slot.exerciseID, "")
        XCTAssertEqual(slot.name, "Switch stance")
        XCTAssertEqual(slot.duration, 4)

        try call("update_workout_section", ["workout": "Mat", "section": "2", "bundle": ["exercises": exercises]])
        XCTAssertEqual(try sections("Mat")[1]["exercises"] as? [[String: Any]] as NSArray?, exercises as NSArray)
        XCTAssertEqual(failure { _ = try self.call("update_workout_section", ["workout": "Mat", "section": "2", "bundle": ["exercises": [["duration": 5]]]]) }?.code, "invalid_argument")
        XCTAssertEqual(failure { _ = try self.call("update_workout_section", ["workout": "Mat", "section": "2", "bundle": ["exercises": [["exercise": "Boxing/Jab", "callout": "Hi"]]]]) }?.code, "invalid_argument")
    }

    func testTheSkillDocumentsOnlyShowCommandsTheToolsAccept() throws {
        let commandPattern = try NSRegularExpression(pattern: #"`tmax (\w+)([^`]*)`"#)
        let flagPattern = try NSRegularExpression(pattern: #"(?<![\w-])--([a-z][a-z-]*)"#)
        let payloadPattern = try NSRegularExpression(pattern: #"--(json|combo) '([^']*)'"#)
        var commands = 0
        var payloads = 0
        var flags = 0
        for file in ["workout-history.md", "boxing-combos.md"] {
            let text = try String(contentsOf: root.appendingPathComponent("skills/\(file)"), encoding: .utf8)
            for match in commandPattern.matches(in: text, range: NSRange(text.startIndex..., in: text)) {
                let tool = String(text[try XCTUnwrap(Range(match.range(at: 1), in: text))])
                let rest = String(text[try XCTUnwrap(Range(match.range(at: 2), in: text))])
                let known = try XCTUnwrap(AgentToolRegistry.tool(named: tool), "\(file): unknown tool \(tool)")
                let properties = Set(known.properties.keys.map { $0.lowercased() })
                for flag in flagPattern.matches(in: rest, range: NSRange(rest.startIndex..., in: rest)) {
                    let name = String(rest[try XCTUnwrap(Range(flag.range(at: 1), in: rest))]).replacingOccurrences(of: "-", with: "")
                    XCTAssertTrue(properties.contains(name) || ["dryrun", "json"].contains(name), "\(file): \(tool) has no --\(name)")
                    flags += 1
                }
                for payload in payloadPattern.matches(in: rest, range: NSRange(rest.startIndex..., in: rest)) {
                    let kind = String(rest[try XCTUnwrap(Range(payload.range(at: 1), in: rest))])
                    let json = String(rest[try XCTUnwrap(Range(payload.range(at: 2), in: rest))])
                    let object = try XCTUnwrap(try JSONSerialization.jsonObject(with: Data(json.utf8)) as? [String: Any], "\(file): \(json)")
                    var arguments: [String: Any] = kind == "json" ? object : ["combo": object]
                    for key in ["workout", "section"] where kind == "combo" && known.properties[key] != nil { arguments[key] = key == "workout" ? "w" : "1" }
                    XCTAssertNoThrow(try AgentToolRegistry.validate(tool, arguments: arguments), "\(file): \(tool) \(json)")
                    payloads += 1
                }
                commands += 1
            }
        }
        XCTAssertGreaterThanOrEqual(commands, 15)
        XCTAssertGreaterThanOrEqual(flags, 25)
        XCTAssertGreaterThanOrEqual(payloads, 3)
    }
}
