import XCTest

final class DriverTests: XCTestCase {
    @MainActor
    func testServe() throws {
        continueAfterFailure = true
        let environment = ProcessInfo.processInfo.environment
        let root = URL(fileURLWithPath: environment["TMAX_DRIVER_DIR"] ?? "/tmp/tmax-driver", isDirectory: true)
        let bundleID = environment["TMAX_APP_BUNDLE_ID"] ?? "com.timemaster.TimeMaster"
        try DriverServer(root: root, app: XCUIApplication(bundleIdentifier: bundleID)).run()
    }
}
