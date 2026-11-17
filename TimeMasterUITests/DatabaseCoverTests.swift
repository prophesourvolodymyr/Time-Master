import XCTest

/// Clicking a cover in a Database list opens the page on the part that holds its first clip, instead of expanding or
/// opening it as a plain row. Runs against the manifests-only library copy at `/tmp/tm-sim-root` (see
/// `CampWalkthroughTests`); without that folder the test is skipped.
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

    func testTappingACoverOpensThePageOnItsAttachments() throws {
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

        let attachments = app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Attachments'")).firstMatch
        XCTAssertTrue(attachments.waitForExistence(timeout: 10), "the page opened and shows its attachments")
        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = "page-opened-from-cover"
        shot.lifetime = .keepAlways
        add(shot)
        XCTAssertTrue(attachments.isSelected, "the page opened on its attachments: \(attachments.debugDescription)")
    }
}
