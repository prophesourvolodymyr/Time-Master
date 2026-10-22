import XCTest

final class PhysiquePoseGuideAccessibilityTests: XCTestCase {
    override func setUpWithError() throws { continueAfterFailure = false }

    func testReferenceChoicesAreNamedSelectableAndInsideTheViewport() {
        checkReferenceChoices(contentSize: nil)
    }

    func testReferenceChoicesRemainUsableAtLargestAccessibilityText() {
        checkReferenceChoices(contentSize: "UICTContentSizeCategoryAccessibilityXXXL")
    }

    private func checkReferenceChoices(contentSize: String?) {
        let app = XCUIApplication(bundleIdentifier: "com.timemaster.TimeMaster")
        app.launchArguments = ["-tm.navigation.order.v1", "(physique)", "-tm.navigation.scheduleSettingsAdded", "YES", "-tm.navigation.rankedAdded", "YES"]
        if let contentSize { app.launchArguments += ["-UIPreferredContentSizeCategoryName", contentSize] }
        app.launch()
        defer { app.terminate() }
        XCTAssertTrue(app.otherElements["physique-root"].waitForExistence(timeout: 40))
        dismissSavedWorkoutPrompt(app)
        XCTAssertTrue(app.buttons["Rules"].firstMatch.waitForExistence(timeout: 10))
        let rules = app.buttons.matching(identifier: "Rules").allElementsBoundByIndex.first(where: { $0.isHittable }) ?? app.buttons["Rules"].firstMatch
        rules.tap()
        XCTAssertTrue(app.staticTexts["Rules and rubric"].firstMatch.waitForExistence(timeout: 10))
        let guide = app.buttons["Open pose guide"].firstMatch
        for _ in 0..<24 {
            if guide.exists && guide.isHittable { break }
            app.swipeUp()
        }
        XCTAssertTrue(guide.isHittable)
        guide.tap()

        let viewport = app.windows.firstMatch.frame
        for title in ["Front double biceps", "Side physique", "Rear double biceps"] {
            let choice = app.buttons[title].firstMatch
            XCTAssertTrue(choice.waitForExistence(timeout: 10))
            XCTAssertGreaterThanOrEqual(choice.frame.minX, viewport.minX - 0.5)
            XCTAssertLessThanOrEqual(choice.frame.maxX, viewport.maxX + 0.5)
        }
        let front = app.buttons["Front double biceps"].firstMatch
        let side = app.buttons["Side physique"].firstMatch
        XCTAssertTrue(front.isSelected)
        side.tap()
        XCTAssertTrue(side.isSelected)
        XCTAssertFalse(front.isSelected)
    }

    private func dismissSavedWorkoutPrompt(_ app: XCUIApplication) {
        let close = app.buttons["workout-resume-close"]
        if close.waitForExistence(timeout: 3) { close.tap() }
        let privacyCover = app.otherElements["physique-privacy-cover"]
        if privacyCover.exists, app.buttons["Continue"].firstMatch.isHittable {
            app.buttons["Continue"].firstMatch.tap()
        }
    }
}
