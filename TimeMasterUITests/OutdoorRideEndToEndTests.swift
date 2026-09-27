import XCTest
import CoreLocation

final class OutdoorRideEndToEndTests: XCTestCase {
    private let app = XCUIApplication(bundleIdentifier: "com.timemaster.TimeMaster")

    override func setUpWithError() throws {
        continueAfterFailure = false
        app.resetAuthorizationStatus(for: .location)
        XCUIDevice.shared.location = XCUILocation(location: CLLocation(latitude: 45.9237, longitude: 6.8694))
        app.launch()
        XCTAssertTrue(app.buttons["Bike"].waitForExistence(timeout: 20))
        if !app.buttons["Bike"].isHittable { app.swipeUp() }
        app.buttons["Bike"].tap()
        allowLocationIfRequested()
        XCTAssertTrue(app.buttons["Start Bike recording"].waitForExistence(timeout: 10))
    }

    override func tearDownWithError() throws {
        let capture = XCTAttachment(screenshot: app.screenshot())
        capture.name = name
        capture.lifetime = .keepAlways
        add(capture)
        XCUIDevice.shared.location = nil
        app.terminate()
    }
    private func allowLocationIfRequested() {
        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        let allow = springboard.buttons["Allow While Using App"]
        if allow.waitForExistence(timeout: 3) { allow.tap() }
    }

    private func startRide() {
        visibleButton("Start Bike recording").tap()
        allowLocationIfRequested()
        XCTAssertTrue(app.buttons["Finish workout"].waitForExistence(timeout: 10))
        XCTAssertFalse(app.buttons["Try Again"].exists, "Location authorization must succeed before measuring a ride")
    }


    private func visibleButton(_ label: String, file: StaticString = #filePath, line: UInt = #line) -> XCUIElement {
        let button = app.buttons[label].firstMatch
        XCTAssertTrue(button.waitForExistence(timeout: 8), label, file: file, line: line)
        XCTAssertTrue(button.isHittable, "Clipped or covered: \(label), frame \(button.frame)", file: file, line: line)
        XCTAssertTrue(app.frame.contains(button.frame), "Outside screen: \(label)", file: file, line: line)
        return button
    }

    private func wait(_ seconds: TimeInterval) {
        let completed = expectation(description: "Allow real location delivery")
        DispatchQueue.main.asyncAfter(deadline: .now() + seconds) { completed.fulfill() }
        wait(for: [completed], timeout: seconds + 3)
    }

    private func move(_ index: Int) {
        let fix = CLLocation(coordinate: .init(latitude: 45.9237 + Double(index) * 0.00009, longitude: 6.8694),
                             altitude: 1_000 + Double(index) * 2, horizontalAccuracy: 4, verticalAccuracy: 3,
                             course: 0, speed: 5, timestamp: Date())
        XCUIDevice.shared.location = XCUILocation(location: fix)
        wait(2)
    }

    private func distanceText() -> String {
        app.descendants(matching: .any).matching(NSPredicate(format: "label BEGINSWITH %@", "Total ")).firstMatch.label
    }

    func testBackgroundRecordingRecoverySavingAndReopening() throws {
        startRide()
        move(0)
        move(1)
        move(2)
        let beforeBackground = distanceText()
        XCUIDevice.shared.press(.home)
        move(3)
        move(4)
        move(5)
        app.activate()
        XCTAssertTrue(app.buttons["Finish workout"].waitForExistence(timeout: 10))
        XCTAssertNotEqual(distanceText(), beforeBackground, "Background GPS must continue adding distance")

        visibleButton("Return to app").tap()
        let liveRide = app.descendants(matching: .any).matching(identifier: "Live Bike").firstMatch
        XCTAssertTrue(liveRide.waitForExistence(timeout: 10))
        move(6)
        liveRide.tap()
        XCTAssertTrue(app.buttons["Finish workout"].waitForExistence(timeout: 10))
        visibleButton("Stop workout").tap()
        let beforeRelaunch = distanceText()
        app.terminate()
        app.launch()
        XCTAssertTrue(app.buttons["Bike"].waitForExistence(timeout: 15))
        app.buttons["Bike"].tap()
        XCTAssertTrue(app.buttons["Resume workout"].waitForExistence(timeout: 10))
        XCTAssertEqual(distanceText(), beforeRelaunch, "Persisted distance must survive termination")
        visibleButton("Resume workout").tap()
        move(7)
        move(8)
        visibleButton("Finish workout").tap()
        visibleButton("Establish workout").tap()
        visibleButton("Private").tap()
        if app.buttons["Save Private workout"].waitForExistence(timeout: 3) {
            visibleButton("Save Private workout").tap()
        }
        XCTAssertTrue(app.buttons["Start Bike recording"].waitForExistence(timeout: 10))
        app.terminate()
        app.launch()
        XCTAssertTrue(app.buttons["Bike"].waitForExistence(timeout: 15))
        app.buttons["Bike"].tap()
        visibleButton("Library").tap()
        XCTAssertTrue(app.buttons["Exit workout library"].waitForExistence(timeout: 10))
        let library = XCTAttachment(string: app.debugDescription)
        library.name = "Saved ride library hierarchy"
        library.lifetime = .keepAlways
        add(library)
        XCTAssertTrue(app.staticTexts["Bike"].exists)
    }

    func testMusicControlsRemainReachableBeforeAndDuringRide() throws {
        visibleButton("Music").tap()
        XCTAssertTrue(app.otherElements["Music editor"].waitForExistence(timeout: 8))
        visibleButton("Choose music section").tap()
        XCTAssertTrue(app.pickerWheels.firstMatch.waitForExistence(timeout: 5))
        visibleButton("Close music section chooser").tap()
        visibleButton("Search music").tap()
        visibleButton("Close music search tray").tap()
        let handle = app.otherElements["Music pane handle"]
        XCTAssertTrue(handle.exists)
        handle.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).press(forDuration: 0.1, thenDragTo: app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.3)))
        visibleButton("Choose music section").tap()
        visibleButton("Close music section chooser").tap()
        handle.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).press(forDuration: 0.1, thenDragTo: app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.98)))
        startRide()
        visibleButton("Music").tap()
        visibleButton("Choose music section").tap()
        visibleButton("Close music section chooser").tap()
        visibleButton("Finish workout").tap()
        XCTAssertTrue(app.buttons["Start Bike recording"].waitForExistence(timeout: 10))
    }

    func testMapModesRecenterAndSettingsPersistence() throws {
        visibleButton("Focus current location").tap()
        let following = NSPredicate(format: "value == %@", "Following")
        expectation(for: following, evaluatedWith: app.buttons["Focus current location"])
        waitForExpectations(timeout: 10)
        let mapPoint = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.25))
        mapPoint.press(forDuration: 0.1, thenDragTo: app.coordinate(withNormalizedOffset: CGVector(dx: 0.8, dy: 0.3)))
        XCTAssertEqual(app.buttons["Focus current location"].value as? String, "Not following")
        visibleButton("Focus current location").tap()
        expectation(for: following, evaluatedWith: app.buttons["Focus current location"])
        waitForExpectations(timeout: 10)
        visibleButton("Open map quick pane").tap()
        for mode in ["Terrain", "Satellite", "Explore"] {
            visibleButton("Map mode, \(mode)").tap()
            wait(2)
        }
        for mode in ["3D", "Transit", "Cycling", "Dark"] {
            let option = visibleButton("Map mode, \(mode)")
            option.tap()
            wait(1)
            option.tap()
        }
        XCTAssertFalse(app.buttons["Map mode, Traffic"].isEnabled)
        visibleButton("Close Map quick pane").tap()
        visibleButton("Open settings quick pane").tap()
        let autoPause = app.switches["Auto Pause"]
        XCTAssertTrue(autoPause.waitForExistence(timeout: 5))
        let original = autoPause.value as? String
        autoPause.tap()
        let changed = autoPause.value as? String
        XCTAssertNotEqual(original, changed)
        visibleButton("Close Settings quick pane").tap()
        visibleButton("Close route").tap()
        app.terminate()
        app.launch()
        XCTAssertTrue(app.buttons["Bike"].waitForExistence(timeout: 15))
        app.buttons["Bike"].tap()
        visibleButton("Open settings quick pane").tap()
        XCTAssertEqual(app.switches["Auto Pause"].value as? String, changed)
        app.switches["Auto Pause"].tap()
    }
}
