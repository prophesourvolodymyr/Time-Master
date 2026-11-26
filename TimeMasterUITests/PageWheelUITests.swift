import XCTest

/// The page wheel, instant page switching, edge swipes and the bar's edit mode, driven with real gestures on the
/// simulator against the manifests-only library copy at `/tmp/tm-sim-root` (see `CampWalkthroughTests`); without that
/// folder the tests are skipped. Every step keeps a screenshot.
final class PageWheelUITests: XCTestCase {
    private static let dataRoot = "/tmp/tm-sim-root"
    private let app = XCUIApplication(bundleIdentifier: "com.timemaster.TimeMaster")

    override func setUpWithError() throws {
        try XCTSkipUnless(FileManager.default.fileExists(atPath: Self.dataRoot), "No library copy at \(Self.dataRoot)")
        continueAfterFailure = false
        app.launchEnvironment["TIMEMASTER_DATA_ROOT"] = Self.dataRoot
        app.launchArguments += [
            "-tm.navigation.order.v1",
            "(coach, profile, workouts, home, database, schedule, skills, map, ranked, physique, analytics, settings)",
            "-tm.navigation.placement", "bottom",
            "-tm.navigation.editorGuideSeen", "YES"
        ]
        app.launch()
        app.discardSavedWorkoutIfOffered()
        XCTAssertTrue(bar.waitForExistence(timeout: 30), "the menu bar")
    }

    override func tearDownWithError() throws {
        app.terminate()
    }

    private var bar: XCUIElement { app.otherElements["carousel-navigation"].firstMatch }
    private func item(_ id: String) -> XCUIElement { app.buttons["navigation-item-\(id)"].firstMatch }
    private func slice(_ id: String) -> XCUIElement { app.descendants(matching: .any)["page-wheel-slice-\(id)"].firstMatch }
    private var hub: XCUIElement { app.descendants(matching: .any)["page-wheel-hub"].firstMatch }

    private func keep(_ name: String) {
        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = name
        shot.lifetime = .keepAlways
        add(shot)
    }

    private func isSelected(_ id: String) -> Bool {
        (item(id).value as? String)?.hasPrefix("Selected") == true
    }

    private func waitUntilSelected(_ id: String, timeout: TimeInterval = 6) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if isSelected(id) { return true }
            RunLoop.current.run(until: Date().addingTimeInterval(0.1))
        }
        return isSelected(id)
    }

    /// Swipes up from the middle of the bar, far enough to form the wheel, and lets go.
    private func pullWheelOpen() {
        let window = app.windows.firstMatch
        let start = window.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.955))
        let end = window.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.45))
        start.press(forDuration: 0.05, thenDragTo: end, withVelocity: .default, thenHoldForDuration: 0.05)
    }

    /// The pages on the bar in their order, read from where the bar draws them.
    private func barOrder() -> [String] {
        app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'navigation-item-'")).allElementsBoundByIndex
            .sorted { $0.frame.midX < $1.frame.midX }
            .map { String($0.identifier.dropFirst("navigation-item-".count)) }
    }

    private func selectedPageID() -> String? {
        barOrder().first { isSelected($0) }
    }

    func testSwipingUpTurnsTheBarIntoTheWheelAndATapOpensASlice() throws {
        keep("01-bar-at-rest")
        pullWheelOpen()
        XCTAssertTrue(hub.waitForExistence(timeout: 4), "the wheel formed with its hub")
        XCTAssertTrue(slice("schedule").exists, "every page has a slice")
        XCTAssertTrue(slice("settings").exists)
        keep("02-wheel-open")

        slice("schedule").tap()
        XCTAssertTrue(waitUntilSelected("schedule"), "the tapped slice opened its page")
        XCTAssertTrue(hub.waitForNonExistence(timeout: 3), "the wheel folded back into the bar")
        RunLoop.current.run(until: Date().addingTimeInterval(1.2))
        keep("03-schedule-from-wheel")
    }

    func testTheHubOpensTheSliceAtTheTopAndTappingOutsideCloses() throws {
        let before = selectedPageID()
        pullWheelOpen()
        XCTAssertTrue(hub.waitForExistence(timeout: 4))
        app.windows.firstMatch.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.84)).tap()
        RunLoop.current.run(until: Date().addingTimeInterval(0.8))
        XCTAssertEqual(selectedPageID(), before, "closing without a choice keeps the page")

        pullWheelOpen()
        XCTAssertTrue(hub.waitForExistence(timeout: 4))
        hub.tap()
        RunLoop.current.run(until: Date().addingTimeInterval(0.8))
        XCTAssertEqual(selectedPageID(), before, "the hub opens the slice at the top, the page already on screen")
    }

    func testSpinningTheWheelTurnsANewPageToTheTop() throws {
        let before = selectedPageID()
        pullWheelOpen()
        XCTAssertTrue(hub.waitForExistence(timeout: 4))
        keep("04-before-spin")
        let wheelFrame = hub.frame
        let window = app.windows.firstMatch
        let origin = window.coordinate(withNormalizedOffset: .zero)
        let center = CGPoint(x: wheelFrame.midX, y: wheelFrame.midY)
        let start = origin.withOffset(CGVector(dx: center.x + 120, dy: center.y - 40))
        let end = origin.withOffset(CGVector(dx: center.x + 60, dy: center.y + 110))
        start.press(forDuration: 0.05, thenDragTo: end, withVelocity: .fast, thenHoldForDuration: 0)
        RunLoop.current.run(until: Date().addingTimeInterval(1.2))
        keep("05-after-spin")
        hub.tap()
        RunLoop.current.run(until: Date().addingTimeInterval(1))
        XCTAssertNotEqual(selectedPageID(), before, "the spin brought another page to the top and the hub opened it")
        keep("06-opened-after-spin")
    }

    /// One finger: up from the bar until the wheel has formed, on to a slice, a rest there, and the page opens on release.
    func testOneHeldSwipeFromTheBarOpensTheSliceItEndsOn() throws {
        XCTAssertFalse(isSelected("skills"))
        pullWheelOpen()
        XCTAssertTrue(hub.waitForExistence(timeout: 4))
        let target = slice("skills").frame
        app.windows.firstMatch.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.84)).tap()
        RunLoop.current.run(until: Date().addingTimeInterval(0.9))

        let window = app.windows.firstMatch
        let origin = window.coordinate(withNormalizedOffset: .zero)
        let start = window.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.955))
        let end = origin.withOffset(CGVector(dx: target.midX, dy: target.midY))
        start.press(forDuration: 0.05, thenDragTo: end, withVelocity: .slow, thenHoldForDuration: 0.6)
        RunLoop.current.run(until: Date().addingTimeInterval(1))
        keep("07-one-held-swipe")
        XCTAssertTrue(waitUntilSelected("skills"), "the slice under the finger opened when it lifted")
    }

    /// On the open wheel a drag from the hub points at a slice like a marking menu and opens it on release.
    func testADragFromTheHubOpensTheSliceItPointsAt() throws {
        XCTAssertFalse(isSelected("analytics"))
        pullWheelOpen()
        XCTAssertTrue(hub.waitForExistence(timeout: 4))
        let target = slice("analytics")
        XCTAssertTrue(target.exists)
        let hubPoint = hub.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        hubPoint.press(forDuration: 0.1, thenDragTo: target.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)),
                       withVelocity: .slow, thenHoldForDuration: 0.4)
        RunLoop.current.run(until: Date().addingTimeInterval(1))
        keep("07b-hub-drag")
        XCTAssertTrue(waitUntilSelected("analytics"), "the slice the drag pointed at opened")
    }

    func testSearchTurnsTheWheelAndShowsWhatItFoundBelowThePages() throws {
        pullWheelOpen()
        let field = app.textFields["page-wheel-search"].firstMatch
        XCTAssertTrue(field.waitForExistence(timeout: 4), "the search field under the wheel")
        field.tap()
        RunLoop.current.run(until: Date().addingTimeInterval(0.6))
        keep("08-search-focused-on-keyboard")
        field.typeText("sched")
        RunLoop.current.run(until: Date().addingTimeInterval(0.8))
        keep("09-search-page")
        XCTAssertEqual((slice("schedule").value as? String)?.hasPrefix("Selected"), true, "the wheel turned to Schedule")

        field.clearAndType("w1 mon")
        let bubble = app.descendants(matching: .any)["page-wheel-bubble"].firstMatch
        XCTAssertTrue(bubble.waitForExistence(timeout: 4), "the thinking bubble with the matches")
        RunLoop.current.run(until: Date().addingTimeInterval(0.6))
        keep("10-search-bubble-tree")
        XCTAssertEqual((slice("workouts").value as? String)?.hasPrefix("Selected"), true, "the wheel turned to Workouts")
        let workout = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'page-wheel-result-workout:'")).firstMatch
        XCTAssertTrue(workout.exists, "a workout in the tree")
        workout.tap()
        XCTAssertTrue(waitUntilSelected("workouts"), "the workout opened on the Workouts page")
        RunLoop.current.run(until: Date().addingTimeInterval(1.5))
        keep("11-workout-from-search")
    }

    func testSearchOpensALibraryPageInsideItsPage() throws {
        pullWheelOpen()
        let field = app.textFields["page-wheel-search"].firstMatch
        XCTAssertTrue(field.waitForExistence(timeout: 4))
        field.tap()
        field.typeText("jumping jacks")
        let bubble = app.descendants(matching: .any)["page-wheel-bubble"].firstMatch
        XCTAssertTrue(bubble.waitForExistence(timeout: 4))
        keep("12-library-search")
        let result = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'page-wheel-result-library:' AND label CONTAINS[c] 'Jumping'")).firstMatch
        XCTAssertTrue(result.exists, "the exercise in the tree")
        result.tap()
        XCTAssertTrue(waitUntilSelected("database"), "the Database page")
        RunLoop.current.run(until: Date().addingTimeInterval(2))
        keep("13-library-page-from-search")
    }

    func testEdgeSwipesMoveToTheNeighboursOnBothSides() throws {
        let ids = barOrder()
        guard let start = selectedPageID() else { return XCTFail("a selected page") }
        let window = app.windows.firstMatch
        let fromRight = window.coordinate(withNormalizedOffset: CGVector(dx: 0.995, dy: 0.45))
        fromRight.press(forDuration: 0.02, thenDragTo: window.coordinate(withNormalizedOffset: CGVector(dx: 0.3, dy: 0.47)),
                        withVelocity: .fast, thenHoldForDuration: 0)
        RunLoop.current.run(until: Date().addingTimeInterval(0.9))
        keep("14-after-right-edge-swipe")
        let afterRight = selectedPageID()
        if let index = ids.firstIndex(of: start), index + 1 < ids.count {
            XCTAssertEqual(afterRight, ids[index + 1], "the right edge brought the next page")
        }
        let fromLeft = window.coordinate(withNormalizedOffset: CGVector(dx: 0.005, dy: 0.45))
        fromLeft.press(forDuration: 0.02, thenDragTo: window.coordinate(withNormalizedOffset: CGVector(dx: 0.75, dy: 0.47)),
                       withVelocity: .fast, thenHoldForDuration: 0)
        RunLoop.current.run(until: Date().addingTimeInterval(0.9))
        keep("15-after-left-edge-swipe")
        XCTAssertEqual(selectedPageID(), start, "the left edge brought the page back")
    }

    func testSwitchingPagesShowsTheShellAtOnceAndThenThePage() throws {
        let tab = item("database")
        XCTAssertTrue(tab.waitForExistence(timeout: 10))
        tab.tap()
        keep("16-database-switch-first-frames")
        XCTAssertTrue(waitUntilSelected("database"))
        RunLoop.current.run(until: Date().addingTimeInterval(1.2))
        keep("17-database-built")
        item("skills").tap()
        keep("18-skills-switch-first-frames")
        RunLoop.current.run(until: Date().addingTimeInterval(1.2))
        keep("19-skills-built")
    }

    func testEditModeShowsARedMinusOnEveryPageThatRemovesIt() throws {
        let window = app.windows.firstMatch
        window.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.955)).press(forDuration: 0.9)
        let dismissGuide = app.buttons["navigation-guide-dismiss"].firstMatch
        if dismissGuide.waitForExistence(timeout: 2) { dismissGuide.tap() }
        let minuses = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'navigation-remove-'"))
        XCTAssertTrue(minuses.firstMatch.waitForExistence(timeout: 4), "red minus buttons in edit mode")
        XCTAssertGreaterThan(minuses.count, 3, "every page carries one")
        keep("20-edit-mode-minus")
        let id = "workouts"
        let minus = app.buttons["navigation-remove-\(id)"].firstMatch
        XCTAssertTrue(minus.isHittable, "the minus on Workouts, beside Home")
        minus.tap()
        RunLoop.current.run(until: Date().addingTimeInterval(0.6))
        XCTAssertFalse(app.buttons["navigation-item-\(id)"].exists, "\(id) left the bar")
        keep("21-page-removed")
        app.buttons["navigation-add"].firstMatch.tap()
        let catalog = app.buttons["navigation-catalog-\(id)"].firstMatch
        XCTAssertTrue(catalog.waitForExistence(timeout: 4))
        catalog.tap()
        XCTAssertTrue(app.buttons["navigation-item-\(id)"].waitForExistence(timeout: 4), "\(id) is back on the bar")
        window.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.3)).tap()
    }
}

private extension XCUIElement {
    func clearAndType(_ text: String) {
        tap()
        if let current = value as? String, !current.isEmpty {
            typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: current.count))
        }
        typeText(text)
    }
}
