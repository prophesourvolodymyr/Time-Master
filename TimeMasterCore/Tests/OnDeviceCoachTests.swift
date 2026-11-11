import XCTest
@testable import TimeMasterCore

final class OnDeviceToolRoutingTests: XCTestCase {
    func testALibraryQuestionGetsTheLookupTools() {
        XCTAssertEqual(OnDeviceToolRouting.tools(for: "What exercises do I have for lower body?"), ["search_pages", "get_page", "list_pages"])
    }

    func testAHistoryQuestionGetsHistoryToolsFirstAndWorkoutToolsAfter() {
        XCTAssertEqual(
            OnDeviceToolRouting.tools(for: "How many workouts have I done and what is my streak?"),
            ["get_recent_workouts", "get_stats", "list_workouts", "get_workout"]
        )
    }

    func testANoteRequestOffersTheNoteToolWithTheLookups() {
        XCTAssertEqual(OnDeviceToolRouting.tools(for: "Add a note to Squats: felt strong"), ["add_page_note", "search_pages", "get_page"])
    }

    func testARequestToChangeSomethingOffersOnlyLookups() {
        let tools = OnDeviceToolRouting.tools(for: "Delete my Leg day workout")
        XCTAssertEqual(tools.prefix(2), ["search_pages", "list_workouts"])
        XCTAssertFalse(tools.contains { $0.hasPrefix("delete") || $0.hasPrefix("create") || $0.hasPrefix("update") })
    }

    func testSmallTalkFallsBackToTheDefaultSet() {
        XCTAssertEqual(OnDeviceToolRouting.tools(for: "Hi there"), OnDeviceToolRouting.fallback)
    }

    func testKeywordsMatchWholeWordsNotInnerLetters() {
        XCTAssertEqual(OnDeviceToolRouting.tools(for: "Remind me to hydrate"), OnDeviceToolRouting.fallback)
        XCTAssertTrue(OnDeviceToolRouting.tools(for: "show my settings").contains("get_settings"))
    }

    func testNoMessageEverGetsMoreThanTheLimitOrAToolOutsideTheAllowedSet() {
        let messages = [
            "delete update rename move create the workout and add a note about the stats and settings",
            "what is my streak this week and last week and this month",
            "list types of workouts and exercises in my library", "", "   ",
        ]
        for message in messages {
            let tools = OnDeviceToolRouting.tools(for: message)
            XCTAssertLessThanOrEqual(tools.count, OnDeviceToolRouting.maximumTools, message)
            XCTAssertEqual(Set(tools).count, tools.count, message)
            XCTAssertTrue(Set(tools).isSubset(of: OnDeviceToolRouting.toolNames), message)
        }
    }

    func testTheHelperOnlyReadsAddsNotesAndTodosAndTicksThemOff() {
        let writes: Set<String> = ["add_page_note", "add_todo", "check_todo"]
        for name in OnDeviceToolRouting.toolNames {
            let tool = AgentToolRegistry.tool(named: name)
            XCTAssertNotNil(tool, name)
            XCTAssertEqual(tool?.coach, true, name)
            XCTAssertEqual(tool?.risk, writes.contains(name) ? .write : .read, name)
        }
    }

    func testEveryAllowedParameterIsARealOneAndEveryDefaultIsAllowed() {
        for (name, allowed) in OnDeviceToolRouting.parameters {
            let known = Set(AgentToolRegistry.tool(named: name)?.properties.keys.map { $0 } ?? [])
            XCTAssertTrue(Set(allowed).isSubset(of: known), name)
        }
        for (name, values) in OnDeviceToolRouting.defaults {
            XCTAssertTrue(Set(values.keys).isSubset(of: Set(AgentToolRegistry.tool(named: name)?.properties.keys.map { $0 } ?? [])), name)
        }
    }
}

final class OnDeviceHistoryTests: XCTestCase {
    private func exchange(_ index: Int) -> [OnDeviceMessage] {
        [OnDeviceMessage(role: .user, text: "question \(index)"), OnDeviceMessage(role: .assistant, text: "answer \(index)")]
    }

    func testOnlyTheLastThreeExchangesAreKept() {
        let digest = OnDeviceHistory.digest((1...5).flatMap(exchange))
        XCTAssertFalse(digest.contains("question 2"))
        XCTAssertTrue(digest.contains("You: question 3"))
        XCTAssertTrue(digest.hasSuffix("Coach: answer 5"))
    }

    func testEmptyMessagesAndWarningsAreDropped() {
        let digest = OnDeviceHistory.digest([
            OnDeviceMessage(role: .user, text: "hello"),
            OnDeviceMessage(role: .assistant, text: "⚠️ No API key"),
            OnDeviceMessage(role: .assistant, text: "   "),
        ])
        XCTAssertEqual(digest, "Earlier in this chat:\nYou: hello")
    }

    func testLongMessagesAreClippedOnOneLine() {
        let long = String(repeating: "word ", count: 200)
        let digest = OnDeviceHistory.digest([OnDeviceMessage(role: .assistant, text: "first line\n" + long)])
        let line = digest.split(separator: "\n").last.map(String.init) ?? ""
        XCTAssertTrue(line.hasPrefix("Coach: first line word"))
        XCTAssertTrue(line.hasSuffix("…"))
        XCTAssertLessThanOrEqual(line.count, "Coach: ".count + 281)
    }

    func testNoHistoryGivesNoDigest() {
        XCTAssertEqual(OnDeviceHistory.digest([]), "")
    }
}

final class OnDeviceActivityLabelTests: XCTestCase {
    func testKnownToolsReadAsSentences() {
        let search = OnDeviceActivityLabel.make(tool: "search_pages", arguments: ["query": "squat"])
        XCTAssertEqual(search.title, "Searching your library")
        XCTAssertEqual(search.detail, "“squat”")
        XCTAssertEqual(OnDeviceActivityLabel.make(tool: "get_stats", arguments: [:]).title, "Checking your stats")
        XCTAssertEqual(OnDeviceActivityLabel.make(tool: "add_page_note", arguments: ["page": "Squats", "note": "x"]).detail, "Squats")
    }

    func testAnUnknownToolFallsBackToItsName() {
        XCTAssertEqual(OnDeviceActivityLabel.make(tool: "do_something", arguments: [:]).title, "Do something")
    }
}

#if canImport(FoundationModels)
import FoundationModels

@available(iOS 26.0, macOS 26.0, *)
final class OnDeviceSchemaTests: XCTestCase {
    private func properties(of tool: OnDeviceTool) throws -> [String] {
        let data = try JSONEncoder().encode(tool.parameters)
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        return findProperties(in: json).sorted()
    }

    private func findProperties(in value: Any) -> [String] {
        if let dictionary = value as? [String: Any] {
            if let found = dictionary["properties"] as? [String: Any] { return Array(found.keys) }
            for item in dictionary.values {
                let nested = findProperties(in: item)
                if !nested.isEmpty { return nested }
            }
        } else if let array = value as? [Any] {
            for item in array {
                let nested = findProperties(in: item)
                if !nested.isEmpty { return nested }
            }
        }
        return []
    }

    func testEveryAllowedToolBuildsASchemaWithOnlyItsAllowedParameters() throws {
        for name in OnDeviceToolRouting.toolNames {
            let registered = try XCTUnwrap(AgentToolRegistry.tool(named: name))
            let tool = try OnDeviceSchema.tool(for: registered, parameters: OnDeviceToolRouting.parameters[name] ?? [], run: { _, _ in "" })
            XCTAssertEqual(tool.name, name)
            XCTAssertFalse(tool.description.isEmpty, name)
            XCTAssertEqual(try properties(of: tool), (OnDeviceToolRouting.parameters[name] ?? []).sorted(), name)
        }
    }

    func testEveryToolInTheRegistryConvertsEvenWhenItHasNestedObjectsAndEnums() throws {
        for registered in AgentToolRegistry.tools where registered.coach {
            let everything = Array((registered.coachSchema["properties"] as? [String: Any] ?? [:]).keys)
            XCTAssertNoThrow(try OnDeviceSchema.tool(for: registered, parameters: everything, run: { _, _ in "" }), registered.name)
        }
    }

    func testDescriptionsAreCutToTheirFirstSentenceAndALength() {
        XCTAssertEqual(OnDeviceSchema.brief("Page UUID or title path. Second sentence.", limit: 60), "Page UUID or title path")
        XCTAssertEqual(OnDeviceSchema.brief(String(repeating: "a", count: 90), limit: 10)?.count, 10)
        XCTAssertNil(OnDeviceSchema.brief("  ", limit: 10))
    }
}

@available(iOS 26.0, macOS 26.0, *)
final class OnDeviceTrackerTests: XCTestCase {
    private final class Snapshots: @unchecked Sendable {
        private let lock = NSLock()
        private var items: [CoachProgress] = []
        func add(_ progress: CoachProgress) { lock.lock(); items.append(progress); lock.unlock() }
        var all: [CoachProgress] { lock.lock(); defer { lock.unlock() }; return items }
    }

    private func tracker() -> (OnDeviceTracker, Snapshots) {
        let snapshots = Snapshots()
        return (OnDeviceTracker(emit: { snapshots.add($0) }), snapshots)
    }

    func testASuccessfulCallShowsRunningThenDoneAndGetsItsDefaultLimit() async throws {
        let (tracker, snapshots) = tracker()
        let received = Snapshots()
        let output = try await tracker.run(name: "search_pages", json: #"{"query":"squat"}"#) { _, json in
            received.add(CoachProgress(text: json))
            return #"{"results":[]}"#
        }
        XCTAssertEqual(output, #"{"results":[]}"#)
        XCTAssertEqual(received.all.first?.text, #"{"limit":10,"query":"squat"}"#)
        XCTAssertEqual(snapshots.all.map { $0.activities.map(\.status) }, [[.running], [.done]])
        XCTAssertEqual(snapshots.all.first?.statusTitle, "Searching your library")
        XCTAssertNil(snapshots.all.last?.statusTitle)
    }

    func testAnErrorResultMarksTheRowFailed() async throws {
        let (tracker, snapshots) = tracker()
        _ = try await tracker.run(name: "get_page", json: #"{"page":"x"}"#) { _, _ in "TOOL ERROR: No page matches 'x'." }
        XCTAssertEqual(snapshots.all.last?.activities.map(\.status), [.failed])
        XCTAssertEqual(tracker.stuckMessage(), "The on-device helper could not finish this: TOOL ERROR: No page matches 'x'.")
    }

    func testTheSameCallTwiceIsAnsweredFromMemoryAndAThirdAttemptStopsTheLoop() async throws {
        let (tracker, _) = tracker()
        let ran = Snapshots()
        let execute: @Sendable (String, String) async -> String = { _, _ in ran.add(CoachProgress()); return "ERROR" }
        _ = try await tracker.run(name: "get_page", json: #"{"page":"x"}"#, execute: execute)
        let second = try await tracker.run(name: "get_page", json: #"{"page":"x"}"#, execute: execute)
        XCTAssertTrue(second.hasPrefix("You already made this exact call"))
        do {
            _ = try await tracker.run(name: "get_page", json: #"{"page":"x"}"#, execute: execute)
            XCTFail("The loop was not stopped")
        } catch let error as OnDeviceLimit {
            XCTAssertEqual(error, .repeatedCall)
        }
        XCTAssertEqual(ran.all.count, 1)
    }

    func testMoreThanTheCallLimitStopsTheTurn() async throws {
        let (tracker, _) = tracker()
        for index in 1...OnDeviceCoach.maximumCalls {
            _ = try await tracker.run(name: "get_page", json: #"{"page":"\#(index)"}"#) { _, _ in "{}" }
        }
        do {
            _ = try await tracker.run(name: "get_page", json: #"{"page":"last"}"#) { _, _ in "{}" }
            XCTFail("The call limit was not enforced")
        } catch let error as OnDeviceLimit {
            XCTAssertEqual(error, .tooManyCalls)
        }
    }

    func testALongResultIsCutBeforeItCanFillTheContextWindow() async throws {
        let (tracker, _) = tracker()
        let output = try await tracker.run(name: "list_workouts", json: "{}") { _, _ in String(repeating: "x", count: 5_000) }
        XCTAssertTrue(output.hasPrefix(String(repeating: "x", count: OnDeviceCoach.outputLimit)))
        XCTAssertTrue(output.hasSuffix("ask for less to see the rest.]"))
        XCTAssertLessThan(output.count, OnDeviceCoach.outputLimit + 100)
    }

    func testFinishingClosesRunningRowsAndFailingKeepsTheMessage() {
        let (finished, finishedSnapshots) = tracker()
        finished.update(text: "Hello")
        finished.finish()
        XCTAssertEqual(finishedSnapshots.all.last, CoachProgress(text: "Hello", isFinished: true))
        let (failed, failedSnapshots) = tracker()
        failed.fail("No model")
        XCTAssertEqual(failedSnapshots.all.last?.failure, "No model")
        XCTAssertEqual(failedSnapshots.all.last?.isFinished, true)
    }

    func testNotesListTheLatestLookupsForTheFallbackAnswer() async throws {
        let (tracker, _) = tracker()
        XCTAssertEqual(tracker.notes(), "No lookups were made.")
        _ = try await tracker.run(name: "get_stats", json: "{}") { _, _ in #"{"workouts":3}"# }
        XCTAssertEqual(tracker.notes(), #"- get_stats: {"workouts":3}"#)
    }
}
#endif
