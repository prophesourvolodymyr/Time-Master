import XCTest

/// Clicking a cover in a Database list shows the page's clips in the in-place media viewer, and its Open Page goes on
/// to the page on the part that holds the clip; a click elsewhere on the card opens the page. Runs against the
/// manifests-only library copy at `/tmp/tm-sim-root`
/// (see `CampWalkthroughTests`); without that folder the test is skipped.
final class DatabaseCoverTests: XCTestCase {
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
        app.discardSavedWorkoutIfOffered()
    }

    override func tearDownWithError() throws {
        app.terminate()
    }

    private func row(_ title: String) -> XCUIElement {
        app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'database-row-' AND label BEGINSWITH %@", title)).firstMatch
    }

    func testTappingACoverShowsItsClipsAndOpenPageGoesOnToThePage() throws {
        let tab = app.buttons["navigation-item-database"].firstMatch
        XCTAssertTrue(tab.waitForExistence(timeout: 30), "Database tab")
        let cardio = row("Cardio")
        for _ in 0..<4 {
            tab.tap()
            if cardio.waitForExistence(timeout: 8) { break }
        }
        XCTAssertTrue(cardio.exists, "the Cardio folder row")
        cardio.tap()

        let child = row("Jumping Jacks")
        XCTAssertTrue(child.waitForExistence(timeout: 8), "the folder expanded to show Jumping Jacks")
        child.coordinate(withNormalizedOffset: CGVector(dx: 0.12, dy: 0.5)).tap()

        let openPage = app.buttons["Open Page"].firstMatch
        XCTAssertTrue(openPage.waitForExistence(timeout: 10), "the cover opened the clip viewer")
        XCTAssertTrue(app.buttons["Close media viewer"].firstMatch.exists, "the viewer can be closed")
        let viewer = XCTAttachment(screenshot: app.screenshot())
        viewer.name = "clip-viewer-from-cover"
        viewer.lifetime = .keepAlways
        add(viewer)
        openPage.tap()

        let attachments = app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Attachments'")).firstMatch
        XCTAssertTrue(attachments.waitForExistence(timeout: 10), "Open Page opened the page and shows its attachments")
        XCTAssertFalse(app.buttons["Open Page"].firstMatch.exists, "the viewer went away")
        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = "page-opened-from-viewer"
        shot.lifetime = .keepAlways
        add(shot)
        XCTAssertTrue(attachments.isSelected, "the page opened on its attachments: \(attachments.debugDescription)")
    }

    func testClosingTheViewerLeavesTheList() throws {
        let tab = app.buttons["navigation-item-database"].firstMatch
        XCTAssertTrue(tab.waitForExistence(timeout: 30), "Database tab")
        let cardio = row("Cardio")
        for _ in 0..<4 {
            tab.tap()
            if cardio.waitForExistence(timeout: 8) { break }
        }
        cardio.tap()
        let child = row("Jumping Jacks")
        XCTAssertTrue(child.waitForExistence(timeout: 8), "the folder expanded to show Jumping Jacks")
        child.coordinate(withNormalizedOffset: CGVector(dx: 0.12, dy: 0.5)).tap()

        let close = app.buttons["Close media viewer"].firstMatch
        XCTAssertTrue(close.waitForExistence(timeout: 10), "the cover opened the clip viewer")
        close.tap()
        let gone = NSPredicate(format: "exists == false")
        expectation(for: gone, evaluatedWith: app.buttons["Open Page"].firstMatch)
        waitForExpectations(timeout: 5)
        XCTAssertTrue(child.isHittable, "back on the list, the row under the pointer again")
    }

    func testTappingTheCardAwayFromItsCoverOpensThePage() throws {
        let tab = app.buttons["navigation-item-database"].firstMatch
        XCTAssertTrue(tab.waitForExistence(timeout: 30), "Database tab")
        let cardio = row("Cardio")
        for _ in 0..<4 {
            tab.tap()
            if cardio.waitForExistence(timeout: 8) { break }
        }
        cardio.tap()
        let child = row("Jumping Jacks")
        XCTAssertTrue(child.waitForExistence(timeout: 8), "the folder expanded to show Jumping Jacks")
        child.coordinate(withNormalizedOffset: CGVector(dx: 0.6, dy: 0.5)).tap()

        let attachments = app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Attachments'")).firstMatch
        XCTAssertTrue(attachments.waitForExistence(timeout: 10), "the card opened the page")
        XCTAssertFalse(app.buttons["Close media viewer"].firstMatch.exists, "no viewer came up for the card")
        XCTAssertFalse(app.buttons["Open Page"].firstMatch.exists, "no viewer came up for the card")
    }
}
