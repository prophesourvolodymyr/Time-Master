import XCTest

/// Plays an untimed exercise on the simulator: the player waits for Done instead of counting down, and a Done tapped
/// too early is answered by the two guard popups. It builds a one-workout copy of the manifests-only library at
/// `/tmp/tm-sim-root` (see `CampWalkthroughTests`); without that folder the test is skipped.
final class UntimedDoneFlowTests: XCTestCase {
    private static let sourceRoot = "/tmp/tm-sim-root"
    private static let dataRoot = "/tmp/tm-sim-done-root"
    private static let workoutID = "D0DE0000-0000-4000-8000-000000000001"
    private let app = XCUIApplication(bundleIdentifier: "com.timemaster.TimeMaster")

    override func setUpWithError() throws {
        try XCTSkipUnless(
            FileManager.default.fileExists(atPath: Self.sourceRoot),
            "No library copy at \(Self.sourceRoot)"
        )
        try Self.prepareLibrary()
        continueAfterFailure = false
        app.launchEnvironment["TIMEMASTER_DATA_ROOT"] = Self.dataRoot
        app.launch()
        app.discardSavedWorkoutIfOffered()
    }

    override func tearDownWithError() throws {
        app.terminate()
    }

    private static func prepareLibrary() throws {
        let files = FileManager.default
        try? files.removeItem(atPath: dataRoot)
        try files.createDirectory(atPath: dataRoot, withIntermediateDirectories: true)
        for name in try files.contentsOfDirectory(atPath: sourceRoot) where name != "Workouts" {
            try files.copyItem(atPath: "\(sourceRoot)/\(name)", toPath: "\(dataRoot)/\(name)")
        }
        let sourceWorkouts = "\(sourceRoot)/Workouts"
        var templateWorkout: [String: Any]?
        var templateSection: [String: Any]?
        for name in try files.contentsOfDirectory(atPath: sourceWorkouts).sorted() {
            guard let data = try? Data(contentsOf: URL(fileURLWithPath: "\(sourceWorkouts)/\(name)/manifest.json")),
                  let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let sections = object["sections"] as? [[String: Any]],
                  let found = sections.first(where: {
                      ($0["mode"] as? String) == "timed" && $0["exerciseID"] != nil
                  })
            else { continue }
            templateWorkout = object
            templateSection = found
            break
        }
        var workout = try XCTUnwrap(templateWorkout, "a workout to copy")
        var section = try XCTUnwrap(templateSection, "a timed section to copy")
        section["isTimerEnabled"] = false
        section["repCount"] = 10
        section["sets"] = 1
        section["name"] = "Untimed Push-ups"
        workout["id"] = workoutID
        workout["name"] = "Done Flow Test"
        workout["prepareTime"] = 3
        workout["sections"] = [section]
        let folder = "\(dataRoot)/Workouts/\(workoutID)"
        try files.createDirectory(atPath: folder, withIntermediateDirectories: true)
        try JSONSerialization.data(withJSONObject: workout, options: [.prettyPrinted])
            .write(to: URL(fileURLWithPath: "\(folder)/manifest.json"))

        let configPath = "\(dataRoot)/Config/manifest.json"
        let configData = try Data(contentsOf: URL(fileURLWithPath: configPath))
        var config = try XCTUnwrap(JSONSerialization.jsonObject(with: configData) as? [String: Any])
        var groups = config["workoutGroups"] as? [[String: Any]] ?? []
        if var first = groups.first {
            first["workoutIDs"] = [workoutID]
            groups = [first]
        }
        config["workoutGroups"] = groups
        try JSONSerialization.data(withJSONObject: config, options: [.prettyPrinted])
            .write(to: URL(fileURLWithPath: configPath))
    }

    private func element(_ identifier: String) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: identifier).firstMatch
    }

    private func snapshot(_ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    private func startWorkoutAndWaitForDone() -> XCUIElement {
        let tab = app.buttons["navigation-item-workouts"].firstMatch
        XCTAssertTrue(tab.waitForExistence(timeout: 30), "Workouts tab")
        let card = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Done Flow Test")).firstMatch
        for _ in 0..<4 {
            tab.tap()
            if card.waitForExistence(timeout: 8) { break }
        }
        XCTAssertTrue(card.exists, "the test workout card")
        card.tap()

        let start = app.buttons["Start Workout"].firstMatch
        XCTAssertTrue(start.waitForExistence(timeout: 15), "Start Workout in the builder")
        start.tap()

        let noWarmUp = app.buttons["No warm-up"].firstMatch
        XCTAssertTrue(noWarmUp.waitForExistence(timeout: 10), "the warm-up chooser")
        noWarmUp.tap()
        app.buttons["Start"].firstMatch.tap()

        let done = element("player.done")
        XCTAssertTrue(done.waitForExistence(timeout: 25), "an untimed exercise offers Done")
        XCTAssertTrue(element("player.elapsed").exists, "an untimed exercise shows how long it has been going")
        snapshot("30-untimed-panel")
        return done
    }

    private func tapDoneAndDismissTheJoke(_ done: XCUIElement) {
        done.tap()
        XCTAssertTrue(element("player.early.superhuman").waitForExistence(timeout: 3), "first early Done: the joke popup")
        snapshot("31-superhuman-popup")
        element("player.early.superhuman.yes").tap()
        XCTAssertFalse(element("player.early.superhuman").waitForExistence(timeout: 1), "Yes only closes the popup")
        XCTAssertTrue(done.exists, "the exercise carries on")
    }

    private func waitUntilGone(_ element: XCUIElement) {
        expectation(for: NSPredicate(format: "exists == false"), evaluatedWith: element)
        waitForExpectations(timeout: 10)
    }

    func testAnEarlyDoneAsksTwiceAndYesFinishesTheSet() throws {
        let done = startWorkoutAndWaitForDone()
        tapDoneAndDismissTheJoke(done)
        done.tap()
        XCTAssertTrue(element("player.early.confirm").waitForExistence(timeout: 3), "second early Done: asks to confirm")
        snapshot("32-confirm-popup")
        element("player.early.confirm.yes").tap()
        waitUntilGone(done)
    }

    func testNotYetKeepsTheSetGoingAndTheNextEarlyDoneLeavesIt() throws {
        let done = startWorkoutAndWaitForDone()
        tapDoneAndDismissTheJoke(done)
        done.tap()
        XCTAssertTrue(element("player.early.confirm").waitForExistence(timeout: 3), "second early Done: asks to confirm")
        element("player.early.confirm.no").tap()
        XCTAssertFalse(element("player.early.confirm").waitForExistence(timeout: 1), "Not yet closes the popup")
        XCTAssertTrue(done.exists, "Not yet keeps the exercise going")
        done.tap()
        XCTAssertFalse(element("player.early.confirm").waitForExistence(timeout: 1), "the answered question is not asked again")
        waitUntilGone(done)
    }
}
