#if os(macOS)
import XCTest
@testable import TimeMasterCore

private func agent(_ type: String, _ fields: [String: JSONValue] = [:], subagent: String? = nil, sequence: Int = 1) -> EverAgentEvent {
    var data = fields
    data["type"] = .string(type)
    if let subagent { data["subagentId"] = .string(subagent) }
    return EverAgentEvent(sequence: sequence, topic: EverAgentTopic.agent, sessionId: "s-1", data: .object(data))
}

private func assistant(_ blocks: [JSONValue], stop: String? = nil, error: String? = nil) -> JSONValue {
    var message: [String: JSONValue] = ["role": "assistant", "content": .array(blocks)]
    if let stop { message["stopReason"] = .string(stop) }
    if let error { message["errorMessage"] = .string(error) }
    return .object(message)
}

private func text(_ value: String) -> JSONValue { ["type": "text", "text": .string(value)] }

private func update(_ blocks: [JSONValue]) -> EverAgentEvent {
    agent("message_update", ["message": assistant(blocks)])
}

private func end(_ blocks: [JSONValue], stop: String = "stop", error: String? = nil) -> EverAgentEvent {
    agent("message_end", ["message": assistant(blocks, stop: stop, error: error)])
}

private func toolStart(_ id: String, _ name: String, args: JSONValue = [:], intent: String? = nil) -> EverAgentEvent {
    var fields: [String: JSONValue] = ["toolCallId": .string(id), "toolName": .string(name), "args": args]
    if let intent { fields["intent"] = .string(intent) }
    return agent("tool_execution_start", fields)
}

private func toolEnd(_ id: String, _ name: String, failed: Bool = false) -> EverAgentEvent {
    agent("tool_execution_end", ["toolCallId": .string(id), "toolName": .string(name), "result": ["content": []], "isError": .bool(failed)])
}

private func replay(_ events: [EverAgentEvent]) -> CoachTurn {
    var turn = CoachTurn()
    for event in events { turn.apply(event) }
    return turn
}

final class CoachTurnTests: XCTestCase {
    func testStreamedTextReplacesThePartialAndSegmentsJoinAroundToolCalls() {
        let turn = replay([
            agent("agent_start"),
            update([text("Check")]),
            update([text("Checking the library.")]),
            end([text("Checking the library.")], stop: "toolUse"),
            toolStart("c1", "write", args: ["path": "xd://mcp__tmax_list_pages"]),
            toolEnd("c1", "write"),
            update([text("Pages")]),
            update([text("Pages: Core, Cardio")]),
            end([text("Pages: Core, Cardio")]),
            agent("agent_end"),
        ])
        XCTAssertEqual(turn.text, "Checking the library.\n\nPages: Core, Cardio")
        XCTAssertEqual(turn.phase, .finished)
    }

    func testPartialTextIsVisibleWhileStreamingAndNeverDuplicated() {
        var turn = CoachTurn()
        turn.apply(agent("agent_start"))
        turn.apply(update([text("Hel")]))
        turn.apply(update([text("Hello")]))
        XCTAssertEqual(turn.text, "Hello")
        XCTAssertEqual(turn.phase, .running)
        turn.apply(end([text("Hello there")]))
        XCTAssertEqual(turn.text, "Hello there")
    }

    func testToolActivityTakesTheAgentsIntentAndMovesFromRunningToDone() {
        var turn = replay([toolStart("c1", "bash", args: ["command": "ls"], intent: "Listing the folder")])
        XCTAssertEqual(turn.activities.map(\.title), ["Listing the folder"])
        XCTAssertEqual(turn.activities.first?.detail, "ls")
        XCTAssertEqual(turn.activities.first?.status, .running)
        turn.apply(toolEnd("c1", "bash"))
        XCTAssertEqual(turn.activities.first?.status, .done)
        XCTAssertEqual(turn.activities.first?.title, "Listing the folder")
        XCTAssertEqual(turn.activities.first?.detail, "ls")
        XCTAssertEqual(turn.activities.count, 1)
    }

    func testATmaxToolCalledThroughTheDeviceKeepsItsReadableTitleAfterItEnds() {
        let turn = replay([
            toolStart("c1", "write", args: ["path": "xd://mcp__tmax_list_pages"]),
            toolEnd("c1", "write"),
        ])
        XCTAssertEqual(turn.activities.map(\.title), ["Tmax: list pages"])
        XCTAssertEqual(turn.activities.map(\.status), [.done])
    }

    func testAToolCallBlockInAPartialMessageCreatesTheActivityBeforeItStarts() {
        let turn = replay([update([["type": "toolCall", "id": "c9", "name": "bash", "arguments": ["command": "pwd"]]])])
        XCTAssertEqual(turn.activities.map(\.id), ["c9"])
        XCTAssertEqual(turn.activities.first?.title, "Running a command")
        XCTAssertEqual(turn.activities.first?.status, .running)
    }

    func testAFailedToolStaysFailedAndOpenToolsCloseWhenTheTurnEnds() {
        var turn = replay([
            toolStart("c1", "bash", args: ["command": "false"]),
            toolEnd("c1", "bash", failed: true),
            toolStart("c2", "read", args: ["path": "/tmp/a.txt"]),
        ])
        XCTAssertEqual(turn.activities.map(\.status), [.failed, .running])
        turn.apply(toolEnd("c1", "bash"))
        XCTAssertEqual(turn.activities.first?.status, .failed)
        turn.apply(agent("agent_end"))
        XCTAssertEqual(turn.activities.map(\.status), [.failed, .done])
    }

    func testAProviderErrorOnTheLastMessageFailsTheTurnWithItsMessage() {
        let turn = replay([
            agent("agent_start"),
            end([], stop: "error", error: "401 api key expired"),
            agent("agent_end"),
        ])
        XCTAssertEqual(turn.phase, .failed("401 api key expired"))
        XCTAssertEqual(turn.text, "")
    }

    func testAnErrorWithoutAMessageUsesAPlainFallback() {
        let turn = replay([end([], stop: "error"), agent("agent_end")])
        XCTAssertEqual(turn.phase, .failed("The provider ended this turn with an error."))
    }

    func testARetryThatSucceedsAfterAnErroredMessageIsNotAFailure() {
        let turn = replay([
            agent("agent_start"),
            end([], stop: "error", error: "overloaded"),
            update([text("Here you go")]),
            end([text("Here you go")]),
            agent("agent_end"),
        ])
        XCTAssertEqual(turn.phase, .finished)
        XCTAssertEqual(turn.text, "Here you go")
    }

    func testAGatewayLevelErrorFailsTheTurnAndStaysFailed() {
        var turn = replay([
            agent("agent_start"),
            EverAgentEvent(sequence: 5, topic: EverAgentTopic.agentError, sessionId: "s-1", data: ["message": "Worker disconnected during an agent turn"]),
        ])
        XCTAssertEqual(turn.phase, .failed("Worker disconnected during an agent turn"))
        turn.apply(agent("agent_end"))
        XCTAssertEqual(turn.phase, .failed("Worker disconnected during an agent turn"))
        XCTAssertTrue(turn.isFinished)
    }

    func testAQuestionPausesTheTurnAndOnlyItsOwnCloseResumesIt() {
        var turn = replay([agent("agent_start")])
        let request: JSONValue = ["requestId": "r1", "kind": "question", "title": "Question", "payload": ["questions": []]]
        turn.apply(EverAgentEvent(sequence: 2, topic: EverAgentTopic.uiRequest, sessionId: "s-1", data: request))
        XCTAssertEqual(turn.phase, .waitingForUser)
        XCTAssertEqual(turn.request?.requestId, "r1")
        turn.apply(EverAgentEvent(sequence: 3, topic: EverAgentTopic.uiRequestClosed, sessionId: "s-1", data: ["requestId": "other"]))
        XCTAssertEqual(turn.phase, .waitingForUser)
        turn.apply(EverAgentEvent(sequence: 4, topic: EverAgentTopic.uiRequestClosed, sessionId: "s-1", data: ["requestId": "r1"]))
        XCTAssertEqual(turn.phase, .running)
        XCTAssertNil(turn.request)
    }

    func testAnsweringARequestResumesTheTurn() {
        var turn = replay([
            agent("agent_start"),
            EverAgentEvent(sequence: 2, topic: EverAgentTopic.uiRequest, sessionId: "s-1", data: ["requestId": "r1", "kind": "confirm", "title": "Go on?"]),
        ])
        turn.resolveRequest()
        XCTAssertEqual(turn.phase, .running)
        XCTAssertNil(turn.request)
    }

    func testSubagentsShowAsActivityAndNeverAddText() {
        let turn = replay([
            agent("agent_start", subagent: "child-1"),
            agent("message_update", ["message": assistant([text("child talking")])], subagent: "child-1"),
            agent("message_end", ["message": assistant([text("child done")])], subagent: "child-1"),
            agent("agent_end", subagent: "child-1"),
        ])
        XCTAssertEqual(turn.text, "")
        XCTAssertEqual(turn.activities.map(\.id), ["sub:child-1"])
        XCTAssertEqual(turn.activities.first?.status, .done)
        XCTAssertNotEqual(turn.phase, .finished)
    }

    func testThinkingShowsUntilTextArrives() {
        var turn = replay([update([["type": "thinking", "thinking": "Let me think"]])])
        XCTAssertTrue(turn.isThinking)
        turn.apply(update([["type": "thinking", "thinking": "Let me think"], text("Answer")]))
        XCTAssertFalse(turn.isThinking)
    }

    func testUserAndToolResultMessagesNeverBecomeCoachText() {
        let turn = replay([
            agent("message_start", ["message": ["role": "user", "content": [text("Plan my week")]]]),
            agent("message_end", ["message": ["role": "toolResult", "content": [text("{\"pages\":[]}")]]]),
        ])
        XCTAssertEqual(turn.text, "")
    }

    func testAResyncAsksForAReloadAndReconcileRebuildsTheAnswerFromTheConversation() throws {
        var turn = replay([
            agent("agent_start"),
            update([text("partial that was dropped")]),
            EverAgentEvent(sequence: 0, topic: EverAgentTopic.resync, data: ["reason": "backpressure"]),
        ])
        XCTAssertTrue(turn.needsReload)
        let session = try EverAgentSession(json: [
            "id": "s-1", "projectId": "p", "title": "Coach", "revision": 3, "runtime": "mac",
            "createdAt": "2026-11-01T10:00:00Z", "updatedAt": "2026-11-01T10:00:09Z",
            "messages": [
                ["role": "user", "content": "earlier question"],
                ["role": "assistant", "content": [text("earlier answer")], "stopReason": "stop"],
                ["role": "user", "content": "Plan my week"],
                ["role": "assistant", "content": [text("Checking.")], "stopReason": "toolUse"],
                ["role": "toolResult", "content": [text("{}")]],
                ["role": "assistant", "content": [text("Monday: legs")], "stopReason": "stop"],
            ],
            "state": ["isStreaming": false],
        ])
        turn.reconcile(with: session)
        XCTAssertFalse(turn.needsReload)
        XCTAssertEqual(turn.text, "Checking.\n\nMonday: legs")
        XCTAssertEqual(turn.phase, .finished)
    }

    func testReconcileReportsAnErroredLastReply() throws {
        var turn = replay([agent("agent_start")])
        let session = try EverAgentSession(json: [
            "id": "s-1", "projectId": "p", "title": "Coach", "revision": 1, "runtime": "mac",
            "createdAt": "2026-11-01T10:00:00Z", "updatedAt": "2026-11-01T10:00:09Z",
            "messages": [
                ["role": "user", "content": "hello"],
                ["role": "assistant", "content": [], "stopReason": "error", "errorMessage": "quota exceeded"],
            ],
            "state": ["isStreaming": false],
        ])
        turn.reconcile(with: session)
        XCTAssertEqual(turn.phase, .failed("quota exceeded"))
    }

    func testReconcileLeavesARunningTurnRunningWhileTheConversationStillStreams() throws {
        var turn = replay([agent("agent_start")])
        let session = try EverAgentSession(json: [
            "id": "s-1", "projectId": "p", "title": "Coach", "revision": 1, "runtime": "mac",
            "createdAt": "2026-11-01T10:00:00Z", "updatedAt": "2026-11-01T10:00:09Z",
            "messages": [["role": "user", "content": "hello"]],
            "state": ["isStreaming": true],
        ])
        turn.reconcile(with: session)
        XCTAssertEqual(turn.phase, .running)
    }

    func testFailKeepsThePartialAnswerClosesOpenToolsAndDropsAPendingQuestion() {
        var turn = replay([
            agent("agent_start"),
            update([text("Here is part of")]),
            toolStart("c1", "bash", args: ["command": "sleep 5"]),
            EverAgentEvent(sequence: 2, topic: EverAgentTopic.uiRequest, sessionId: "s-1", data: ["requestId": "r1", "kind": "confirm", "title": "Go on?"]),
        ])
        turn.fail("The connection to EverAgent closed.")
        XCTAssertEqual(turn.phase, .failed("The connection to EverAgent closed."))
        XCTAssertEqual(turn.text, "Here is part of")
        XCTAssertEqual(turn.activities.map(\.status), [.failed])
        XCTAssertNil(turn.request)
        XCTAssertTrue(turn.isFinished)
    }

    func testANoticeActivityGoesFirstAndIsReplacedNotDuplicated() {
        var turn = replay([toolStart("c1", "read", args: ["path": "/tmp/a.txt"])])
        let notice = CoachActivity(id: "tmax-tools", title: "The Tmax tools did not connect", status: .failed)
        turn.addActivity(notice)
        turn.addActivity(CoachActivity(id: "tmax-tools", title: "Still not connected", status: .failed))
        XCTAssertEqual(turn.activities.map(\.id), ["tmax-tools", "c1"])
        XCTAssertEqual(turn.activities.first?.title, "Still not connected")
    }

    func testProgressShowsTheRunningToolAsTheStatusAndAFailureAsFinished() {
        var turn = replay([agent("agent_start"), update([text("Hello")]), toolStart("c1", "bash", args: ["command": "ls"], intent: "Listing the folder")])
        XCTAssertEqual(turn.progress.text, "Hello")
        XCTAssertEqual(turn.progress.statusTitle, "Listing the folder")
        XCTAssertEqual(turn.progress.activities.map(\.title), ["Listing the folder"])
        XCTAssertFalse(turn.progress.isFinished)
        turn.fail("Gone")
        XCTAssertEqual(turn.progress.failure, "Gone")
        XCTAssertNil(turn.progress.statusTitle)
        XCTAssertTrue(turn.progress.isFinished)
    }

    func testProgressAsksForTheUsersAnswerWhileAQuestionIsOpen() {
        let turn = replay([
            agent("agent_start"),
            EverAgentEvent(sequence: 2, topic: EverAgentTopic.uiRequest, sessionId: "s-1", data: ["requestId": "r1", "kind": "confirm", "title": "Go on?"]),
        ])
        XCTAssertEqual(turn.progress.statusTitle, "Waiting for your answer")
        XCTAssertFalse(turn.progress.isFinished)
    }
}
#endif
