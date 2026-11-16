import XCTest

/// Walks the Workouts page of a real library on the simulator. The app reads a manifests-only copy of the library
/// (`Workouts`, `Config` with its `.migration_*` markers, and the manifests and `*.md` of `Exercises Database`) from
/// `/tmp/tm-sim-root` through `TIMEMASTER_DATA_ROOT`; without that folder the tests are skipped.
final class CampWalkthroughTests: XCTestCase {
    private static let dataRoot = "/tmp/tm-sim-root"
    private let app = XCUIApplication(bundleIdentifier: "com.timemaster.TimeMaster")

    override func setUpWithError() throws {
        try XCTSkipUnless(
            FileManager.default.fileExists(atPath: Self.dataRoot),
            "No library copy at \(Self.dataRoot)"
        )
        continueAfterFailure = false
        app.launchEnvironment["TIMEMASTER_DATA_ROOT"] = Self.dataRoot
        app.launch()
    }

    override func tearDownWithError() throws {
        app.terminate()
    }

    private var firstSectionHeader: XCUIElement {
        app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Week 1")).firstMatch
    }

    private func openWorkouts() {
        let tab = app.buttons["navigation-item-workouts"].firstMatch
        XCTAssertTrue(tab.waitForExistence(timeout: 30), "Workouts tab")
        for _ in 0..<4 {
            tab.tap()
            if firstSectionHeader.waitForExistence(timeout: 8) { break }
        }
        XCTAssertTrue(firstSectionHeader.exists, "Week 1 section")
    }

    private func firstCardTop(in list: XCUIElement) -> CGFloat? {
        let card = list.buttons.matching(NSPredicate(format: "label MATCHES %@", "^W[1-8] .*")).firstMatch
        return card.exists ? card.frame.minY : nil
    }

    func testWorkoutsListScrollsAndKeepsItsPosition() throws {
        openWorkouts()
        let list = app.scrollViews.firstMatch
        XCTAssertTrue(list.exists)
        let start = firstCardTop(in: list)
        XCTAssertNotNil(start)
        var previous = start ?? 0
        for step in 1...4 {
            list.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.40))
                .press(forDuration: 0.05, thenDragTo: list.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.02)),
                       withVelocity: .slow, thenHoldForDuration: 0.3)
            let top = firstCardTop(in: list) ?? previous - 1
            XCTAssertLessThan(top, previous - 100, "swipe \(step) moved the list down")
            previous = top
        }
    }

    func testTappingACoverOpensThePageAndKeepsTheWorkout() throws {
        openWorkouts()
        let card = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "W1 Mon AM")).firstMatch
        XCTAssertTrue(card.waitForExistence(timeout: 10), "first workout card")
        card.tap()
        XCTAssertTrue(app.buttons["Back to workouts"].firstMatch.waitForExistence(timeout: 15), "builder opened")
        let cover = app.buttons["Open page preview"].firstMatch
        XCTAssertTrue(cover.waitForExistence(timeout: 10), "a cover to tap")
        cover.tap()
        XCTAssertTrue(app.buttons["Close page"].waitForExistence(timeout: 5), "the page opened")
        for _ in 0..<12 {
            usleep(250_000)
            XCTAssertTrue(app.buttons["Close page"].exists, "the page stays open")
            XCTAssertFalse(firstSectionHeader.exists, "the Workouts list did not come back")
        }
        let close = app.buttons.matching(NSPredicate(format: "label == %@", "Close")).allElementsBoundByIndex
            .first { $0.frame.minX > 0 }
        XCTAssertNotNil(close, "the page has a close control")
        close?.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        XCTAssertTrue(app.buttons["Back to workouts"].firstMatch.waitForExistence(timeout: 5), "back on the builder")
    }
}
