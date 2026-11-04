import XCTest
@testable import TimeMasterCore

private func assistant(_ text: String) -> JSONValue {
    ["role": "assistant", "content": [["type": "text", "text": .string(text)]], "stopReason": "stop"]
}

private func streamingUpdate(sequence: Int, streamed text: String, kind: String = "text_delta") -> EverAgentEvent {
    var circular = assistant(text)
    circular["content"] = "[Circular]"
    return EverAgentEvent(sequence: sequence, topic: EverAgentTopic.agent, sessionId: "s-1", data: [
        "type": "message_update",
        "message": circular,
        "assistantMessageEvent": ["type": .string(kind), "contentIndex": 0, "partial": assistant(text)],
    ])
}

private func agentEvent(_ type: String, sequence: Int, message: JSONValue? = nil) -> EverAgentEvent {
    var data: JSONValue = ["type": .string(type)]
    if let message { data["message"] = message }
    return EverAgentEvent(sequence: sequence, topic: EverAgentTopic.agent, sessionId: "s-1", data: data)
}

final class EverAgentStreamedMessageTests: XCTestCase {
    func testAStreamingUpdateReadsThePartialWhenTheGatewayMarksTheMessageContentAsCircular() {
        let event = streamingUpdate(sequence: 7, streamed: "Mock reply ")
        XCTAssertEqual(event.data["message"]["content"], "[Circular]")
        let message = event.message
        XCTAssertEqual(message?.role, "assistant")
        XCTAssertEqual(message?.text, "Mock reply ")
        XCTAssertEqual(message?.content, [.text("Mock reply ")])
        XCTAssertEqual(message?.stopReason, "stop")
    }

    func testAMessageWithRealContentStillWinsOverThePartial() {
        let event = EverAgentEvent(sequence: 1, topic: EverAgentTopic.agent, data: [
            "type": "message_update",
            "message": assistant("From the message"),
            "assistantMessageEvent": ["type": "text_delta", "partial": assistant("From the partial")],
        ])
        XCTAssertEqual(event.message?.text, "From the message")
    }

    func testThePartialIsUsedWhenThereIsNoMessage() {
        let event = EverAgentEvent(sequence: 1, topic: EverAgentTopic.agent, data: [
            "type": "message_update",
            "assistantMessageEvent": ["type": "text_delta", "partial": assistant("Only the partial")],
        ])
        XCTAssertEqual(event.message?.text, "Only the partial")
    }

    func testAnEventWhoseOnlyContentIsCircularHasNoMessage() {
        var circular = assistant("hidden")
        circular["content"] = "[Circular]"
        let both = EverAgentEvent(sequence: 1, topic: EverAgentTopic.agent, data: [
            "type": "message_update",
            "message": circular,
            "assistantMessageEvent": ["type": "text_delta", "partial": circular],
        ])
        XCTAssertNil(both.message)
        let messageOnly = EverAgentEvent(sequence: 2, topic: EverAgentTopic.agent, data: ["type": "message_update", "message": circular])
        XCTAssertNil(messageOnly.message)
    }

    func testAPartialWhoseContentIsCircularFallsBackToTheMessage() {
        var circular = assistant("hidden")
        circular["content"] = "[Circular]"
        let event = EverAgentEvent(sequence: 1, topic: EverAgentTopic.agent, data: [
            "type": "message_update",
            "message": assistant("Real text"),
            "assistantMessageEvent": ["type": "text_delta", "partial": circular],
        ])
        XCTAssertEqual(event.message?.text, "Real text")
    }

    func testPlainStringContentIsStillAMessage() {
        let event = EverAgentEvent(sequence: 1, topic: EverAgentTopic.agent, data: [
            "type": "message_start",
            "message": ["role": "user", "content": "Plan my week"],
        ])
        XCTAssertEqual(event.message?.role, "user")
        XCTAssertEqual(event.message?.text, "Plan my week")
    }

    func testOnlyAgentEventsCarryMessages() {
        let session = EverAgentEvent(sequence: 1, topic: EverAgentTopic.session, data: [
            "message": assistant("text"),
            "assistantMessageEvent": ["partial": assistant("text")],
        ])
        XCTAssertNil(session.message)
    }

    func testACoachTurnShowsTheStreamedTextInsteadOfTheCircularMarker() {
        var turn = CoachTurn()
        turn.apply(agentEvent("agent_start", sequence: 1))
        turn.apply(agentEvent("message_start", sequence: 2, message: ["role": "user", "content": [["type": "text", "text": "Hello"]]]))
        turn.apply(agentEvent("message_end", sequence: 3, message: ["role": "user", "content": [["type": "text", "text": "Hello"]]]))
        turn.apply(agentEvent("message_start", sequence: 4, message: assistant("")))
        XCTAssertEqual(turn.text, "")
        var seen: [String] = []
        for (index, text) in ["Mock ", "Mock reply ", "Mock reply to: ", "Mock reply to: Hello "].enumerated() {
            turn.apply(streamingUpdate(sequence: 5 + index, streamed: text, kind: index == 0 ? "text_start" : "text_delta"))
            seen.append(turn.text)
            XCTAssertEqual(turn.phase, .running)
            XCTAssertEqual(turn.progress.text, text)
        }
        XCTAssertEqual(seen, ["Mock ", "Mock reply ", "Mock reply to: ", "Mock reply to: Hello "])
        XCTAssertFalse(seen.contains { $0.contains("Circular") })
        turn.apply(agentEvent("message_end", sequence: 20, message: assistant("Mock reply to: Hello")))
        XCTAssertEqual(turn.text, "Mock reply to: Hello")
        turn.apply(agentEvent("agent_end", sequence: 21))
        XCTAssertEqual(turn.phase, .finished)
        XCTAssertEqual(turn.text, "Mock reply to: Hello")
        XCTAssertTrue(turn.isFinished)
    }

    func testAStreamingToolCallShowsAsAnActivityBeforeItStarts() {
        let blocks: JSONValue = [
            ["type": "text", "text": "Running it. "],
            ["type": "toolCall", "id": "call-1", "name": "bash", "arguments": ["command": "sleep 40", "i": "Sleeping for a while"]],
        ]
        var message = assistant("")
        message["content"] = blocks
        var circular = message
        circular["content"] = "[Circular]"
        let update = EverAgentEvent(sequence: 5, topic: EverAgentTopic.agent, sessionId: "s-1", data: [
            "type": "message_update",
            "message": circular,
            "assistantMessageEvent": ["type": "toolcall_end", "partial": message],
        ])
        var turn = CoachTurn()
        turn.apply(agentEvent("agent_start", sequence: 1))
        turn.apply(update)
        XCTAssertEqual(turn.text, "Running it. ")
        XCTAssertEqual(turn.activities.map(\.title), ["Sleeping for a while"])
        XCTAssertEqual(turn.activities.first?.status, .running)
    }
}
