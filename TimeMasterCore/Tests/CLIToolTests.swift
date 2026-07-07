import XCTest
import Foundation

final class CLIToolTests: XCTestCase {
    var tempDir: URL!
    var binaryPath: String!

    override func setUp() {
        super.setUp()
        tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try! FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)

        let buildDir = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent(".build/debug/timemaster-tool")
        binaryPath = buildDir.path
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: tempDir)
        super.tearDown()
    }

    private func runCLI(_ args: [String]) -> (stdout: String, stderr: String, exitCode: Int32) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: binaryPath)
        process.arguments = args

        var env = ProcessInfo.processInfo.environment
        env["TIMEMASTER_DATA_ROOT"] = tempDir.path
        process.environment = env

        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe

        process.launch()
        process.waitUntilExit()

        let stdoutData = stdoutPipe.fileHandleForReading.readDataToEndOfFile()
        let stderrData = stderrPipe.fileHandleForReading.readDataToEndOfFile()

        return (
            String(data: stdoutData, encoding: .utf8) ?? "",
            String(data: stderrData, encoding: .utf8) ?? "",
            process.terminationStatus
        )
    }

    func testListExercisesEmpty() throws {
        let result = runCLI(["list-exercises"])
        XCTAssertEqual(result.exitCode, 0, "stderr: \(result.stderr)")
        XCTAssertTrue(result.stdout.contains("["))
        XCTAssertTrue(result.stdout.contains("]"))
    }

    func testCreateAndGetExercise() throws {
        let json = #"{"id":"test-01","name":"Push-up","duration":30}"#

        let create = runCLI(["create-exercise", json])
        XCTAssertEqual(create.exitCode, 0, "stderr: \(create.stderr)")
        XCTAssertTrue(create.stdout.contains("test-01"))

        let get = runCLI(["get-exercise", "test-01"])
        XCTAssertEqual(get.exitCode, 0, "stderr: \(get.stderr)")
        XCTAssertTrue(get.stdout.contains("Push-up"))
        XCTAssertTrue(get.stdout.contains("guide"))
    }

    func testSearchExercises() throws {
        let json1 = #"{"id":"push-up","name":"Push-up","duration":30}"#
        let json2 = #"{"id":"pull-up","name":"Pull-up","duration":30}"#

        XCTAssertEqual(runCLI(["create-exercise", json1]).exitCode, 0)
        XCTAssertEqual(runCLI(["create-exercise", json2]).exitCode, 0)

        let search = runCLI(["search-exercises", "push"])
        XCTAssertEqual(search.exitCode, 0, "stderr: \(search.stderr)")
        XCTAssertTrue(search.stdout.contains("Push-up"))
        XCTAssertFalse(search.stdout.contains("Pull-up"))
    }

    func testListWorkoutsEmpty() throws {
        let result = runCLI(["list-workouts"])
        XCTAssertEqual(result.exitCode, 0)
        XCTAssertTrue(result.stdout.contains("["))
        XCTAssertTrue(result.stdout.contains("]"))
    }

    func testBuildWorkout() throws {
        let json = #"{"id":"w-01","name":"Morning Routine","sections":[{"exerciseID":"push-up","name":"Push-ups","duration":30,"sets":3,"restBetweenSets":10,"prepareTime":4,"isTimerEnabled":true,"mediaFilenames":[]}]}"#

        let result = runCLI(["build-workout", json])
        XCTAssertEqual(result.exitCode, 0, "stderr: \(result.stderr)")
        XCTAssertTrue(result.stdout.contains("w-01"))

        let list = runCLI(["list-workouts"])
        XCTAssertTrue(list.stdout.contains("Morning Routine"))
    }

    func testGetStats() throws {
        let result = runCLI(["get-stats"])
        XCTAssertEqual(result.exitCode, 0, "stderr: \(result.stderr)")
        XCTAssertTrue(result.stdout.contains("count"))
        XCTAssertTrue(result.stdout.contains("streak"))
    }

    func testListTypes() throws {
        let result = runCLI(["list-types"])
        XCTAssertEqual(result.exitCode, 0, "stderr: \(result.stderr)")
        XCTAssertTrue(result.stdout.contains("Strength"))
        XCTAssertTrue(result.stdout.contains("Cardio"))
        XCTAssertTrue(result.stdout.contains("HIIT"))
        XCTAssertTrue(result.stdout.contains("Yoga"))
    }

    func testValidate() throws {
        let result = runCLI(["validate"])
        XCTAssertEqual(result.exitCode, 0, "stderr: \(result.stderr)")
        XCTAssertTrue(result.stdout.contains("valid"))
    }

    func testUnknownCommand() throws {
        let result = runCLI(["bogus-command"])
        XCTAssertNotEqual(result.exitCode, 0)
        XCTAssertTrue(result.stderr.contains("Unknown command"))
        XCTAssertTrue(result.stderr.contains("Commands"))
    }

    func testInvalidJSONShowsError() throws {
        let result = runCLI(["create-exercise", "NOT_VALID_JSON"])
        XCTAssertNotEqual(result.exitCode, 0)
        XCTAssertTrue(result.stderr.contains("Error"))
    }

    func testMissingArgsShowsError() throws {
        let result = runCLI(["get-exercise"])
        XCTAssertNotEqual(result.exitCode, 0)
        XCTAssertTrue(result.stderr.contains("Error"))
    }

    func testNoArgsShowsHelp() throws {
        let result = runCLI([])
        XCTAssertNotEqual(result.exitCode, 0)
        XCTAssertTrue(result.stderr.contains("Commands"))
    }

    func testHelpFlag() throws {
        let result = runCLI(["--help"])
        XCTAssertEqual(result.exitCode, 0)
        XCTAssertTrue(result.stdout.contains("Commands"))
    }
}
