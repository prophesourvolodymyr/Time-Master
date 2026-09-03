import XCTest
import CoreLocation

final class OutdoorRouteRecordingUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testRunShortcutOpensPermanentMapAndRoutePanes() throws {
        let app = XCUIApplication(bundleIdentifier: "com.timemaster.TimeMaster")
        app.launch()
        XCTAssertTrue(app.buttons["Run"].waitForExistence(timeout: 10))

        let runShortcut = app.buttons["Run"]
        XCTAssertTrue(runShortcut.waitForExistence(timeout: 10))
        runShortcut.tap()

        XCTAssertTrue(app.buttons["Start Run recording"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons["Offline map area"].exists)
        XCTAssertTrue(app.buttons["Focus current location"].exists)
        XCTAssertTrue(app.buttons["Close route"].exists)
        app.buttons["Offline map area"].tap()
        let cityScaleMessage = "Map view resized to city scale. Offline area selection is not available yet."
        let cityScaleNotice = app.descendants(matching: .any)
            .matching(NSPredicate(format: "label == %@", cityScaleMessage))
            .firstMatch
        XCTAssertTrue(cityScaleNotice.waitForExistence(timeout: 5))

        app.buttons["Open map quick pane"].tap()
        XCTAssertTrue(app.buttons["Close Map quick pane"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["Map mode, Explore"].exists)
        XCTAssertFalse(app.buttons["Map mode, Direction"].exists)

        let transit = app.buttons["Map mode, Transit"]
        let cycling = app.buttons["Map mode, Cycling"]
        XCTAssertTrue(transit.waitForExistence(timeout: 5))
        XCTAssertTrue(cycling.waitForExistence(timeout: 5))
        transit.tap()
        cycling.tap()
        XCTAssertTrue((transit.value as? String)?.contains("Selected, On") == true)
        XCTAssertTrue((cycling.value as? String)?.contains("Selected, On") == true)
        XCTAssertTrue((app.buttons["Map mode, Explore"].value as? String)?.contains("Selected base view") == true)
        app.buttons["Close Map quick pane"].tap()

        XCTAssertTrue(app.buttons["Open trophy quick pane"].waitForExistence(timeout: 5))
        app.buttons["Open trophy quick pane"].tap()
        XCTAssertTrue(app.buttons["Close Trophy quick pane"].waitForExistence(timeout: 5))
        app.buttons["Close Trophy quick pane"].tap()

        XCTAssertTrue(app.buttons["Open settings quick pane"].waitForExistence(timeout: 5))
        app.buttons["Open settings quick pane"].tap()
        XCTAssertTrue(app.buttons["Close Settings quick pane"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.switches["Auto Pause"].exists)
        app.buttons["Close Settings quick pane"].tap()

        app.buttons.matching(NSPredicate(format: "label == %@ AND value == %@", "Type", "Closed")).firstMatch.tap()
        XCTAssertTrue(app.buttons["Commit Run"].waitForExistence(timeout: 5))

        app.buttons.matching(NSPredicate(format: "label == %@ AND value == %@", "Type", "Open")).firstMatch.tap()
        app.buttons["Music"].tap()
        XCTAssertTrue(app.otherElements["Music editor"].waitForExistence(timeout: 5))

        app.buttons["Library"].tap()
        XCTAssertTrue(app.buttons["Exit workout library"].waitForExistence(timeout: 5))
    }

    func testWalkAndBikeShortcutsOpenMatchingRecorders() throws {
        let app = XCUIApplication(bundleIdentifier: "com.timemaster.TimeMaster")
        app.launch()
        if app.buttons["Home"].waitForExistence(timeout: 5) {
            app.buttons["Home"].tap()
        }

        XCTAssertTrue(app.buttons["Walk"].waitForExistence(timeout: 10))
        app.buttons["Walk"].tap()
        XCTAssertTrue(app.buttons["Start Walk recording"].waitForExistence(timeout: 10))
        app.buttons["Close route"].tap()

        XCTAssertTrue(app.buttons["Bike"].waitForExistence(timeout: 10))
        app.buttons["Bike"].tap()
        XCTAssertTrue(app.buttons["Start Bike recording"].waitForExistence(timeout: 10))
    }

    func testRunRecordingPauseResumeAndDiscardShortSession() throws {
        let app = XCUIApplication(bundleIdentifier: "com.timemaster.TimeMaster")
        app.launch()

        XCTAssertTrue(app.buttons["Run"].waitForExistence(timeout: 10))
        app.buttons["Run"].tap()
        XCTAssertTrue(app.buttons["Start Run recording"].waitForExistence(timeout: 10))
        app.buttons["Start Run recording"].tap()

        XCTAssertTrue(app.buttons["Stop workout"].waitForExistence(timeout: 10))
        app.buttons["Stop workout"].tap()
        XCTAssertTrue(app.buttons["Resume workout"].waitForExistence(timeout: 5))
        app.buttons["Resume workout"].tap()
        XCTAssertTrue(app.buttons["Stop workout"].waitForExistence(timeout: 5))

        app.buttons["Finish workout"].tap()
        XCTAssertTrue(app.buttons["Start Run recording"].waitForExistence(timeout: 10))
    }

    func testPausedRouteRecoversAfterRelaunch() throws {
        let app = XCUIApplication(bundleIdentifier: "com.timemaster.TimeMaster")
        app.launch()

        XCTAssertTrue(app.buttons["Run"].waitForExistence(timeout: 10))
        app.buttons["Run"].tap()
        XCTAssertTrue(app.buttons["Start Run recording"].waitForExistence(timeout: 10))
        app.buttons["Start Run recording"].tap()
        XCTAssertTrue(app.buttons["Stop workout"].waitForExistence(timeout: 10))
        app.buttons["Stop workout"].tap()
        XCTAssertTrue(app.buttons["Resume workout"].waitForExistence(timeout: 5))

        app.terminate()
        app.launch()
        XCTAssertTrue(app.buttons["Run"].waitForExistence(timeout: 10))
        app.buttons["Run"].tap()
        XCTAssertTrue(app.buttons["Resume workout"].waitForExistence(timeout: 10))
        app.buttons["Resume workout"].tap()
        XCTAssertTrue(app.buttons["Finish workout"].waitForExistence(timeout: 5))
        app.buttons["Finish workout"].tap()
        XCTAssertTrue(app.buttons["Start Run recording"].waitForExistence(timeout: 10))
    }

    func testMovingRouteFinishesEstablishesAndPublishesToProfile() throws {
        let device = XCUIDevice.shared
        device.location = XCUILocation(location: CLLocation(latitude: 37.33490, longitude: -122.00900))
        defer { device.location = nil }

        let app = XCUIApplication(bundleIdentifier: "com.timemaster.TimeMaster")
        app.launch()

        XCTAssertTrue(app.buttons["Run"].waitForExistence(timeout: 10))
        app.buttons["Run"].tap()
        XCTAssertTrue(app.buttons["Start Run recording"].waitForExistence(timeout: 10))
        app.buttons["Start Run recording"].tap()
        XCTAssertTrue(app.buttons["Finish workout"].waitForExistence(timeout: 10))

        for coordinate in [
            CLLocationCoordinate2D(latitude: 37.33494, longitude: -122.00900),
            CLLocationCoordinate2D(latitude: 37.33498, longitude: -122.00900),
            CLLocationCoordinate2D(latitude: 37.33502, longitude: -122.00900)
        ] {
            sleep(2)
            device.location = XCUILocation(location: CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude))
        }
        app.buttons["Finish workout"].tap()

        XCTAssertTrue(app.buttons["Establish workout"].waitForExistence(timeout: 10))
        app.buttons["Establish workout"].tap()
        XCTAssertTrue(app.buttons["Public"].waitForExistence(timeout: 5))
        app.buttons["Public"].tap()
        XCTAssertTrue(app.buttons["Save Public workout"].waitForExistence(timeout: 5))
        app.buttons["Save Public workout"].tap()

        XCTAssertTrue(app.buttons["Start Run recording"].waitForExistence(timeout: 10))
        app.buttons["Library"].tap()
        XCTAssertTrue(app.buttons["Exit workout library"].waitForExistence(timeout: 5))
        app.buttons["Exit workout library"].tap()

        XCTAssertTrue(app.buttons["Profile"].waitForExistence(timeout: 10))
        app.buttons["Profile"].tap()
        XCTAssertTrue(app.staticTexts["Outdoor activity"].waitForExistence(timeout: 10))
    }
}
