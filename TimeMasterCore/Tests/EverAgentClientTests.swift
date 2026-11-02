#if os(macOS)
import XCTest
@testable import TimeMasterCore

private let projectJSON: JSONValue = ["id": "p1", "name": "Tmax", "root": "/Users/me/Tmax", "revision": 3, "createdAt": "2026-10-01T00:00:00Z"]

private let leaseJSON: JSONValue = ["ownerDeviceId": "local-owner", "runtime": "mac", "leaseId": "lease-1", "expiresAt": "2026-11-01T10:00:45Z"]

private let transcriptJSON: JSONValue = {
    let user: JSONValue = ["role": "user", "content": "Plan my week"]
    let blocks: [JSONValue] = [
        ["type": "thinking", "thinking": "Let me look"],
        ["type": "text", "text": "Sure. "],
        ["type": "toolCall", "id": "call-1", "name": "tmax_list_workouts", "arguments": ["limit": 3]],
        ["type": "text", "text": "Done."],
        ["type": "image", "data": "QUJD", "mimeType": "image/png"],
        ["type": "audio", "seconds": 2],
    ]
    let assistant: JSONValue = ["role": "assistant", "content": .array(blocks), "stopReason": "toolUse"]
    let failed: JSONValue = ["role": "assistant", "content": [], "stopReason": "error", "errorMessage": "Provider overloaded"]
    return [
        "id": "s-1", "projectId": "p1", "title": "Coach", "revision": 4, "runtime": "mac",
        "createdAt": "2026-11-01T10:00:00Z", "updatedAt": "2026-11-01T10:05:00Z",
        "model": ["provider": "anthropic", "id": "claude-opus"],
        "messages": [user, assistant, failed],
        "entries": [],
        "state": ["isStreaming": true],
    ]
}()

private func script(_ results: [String: JSONValue]) -> @Sendable (FakeRequest) -> FakeReply? {
    { request in
        let key = request.method == "worker.call" ? "worker.call:" + request.params["method"].text : request.method
        return results[key].map { .result($0) }
    }
}

final class EverAgentClientTests: XCTestCase {
    private struct Rig {
        let client: EverAgentClient
        let gateway: FakeGateway
        let connection: FakeConnection
    }

    private var gateways: [FakeGateway] = []
    private var clients: [EverAgentClient] = []

    override func tearDown() async throws {
        for client in clients { await client.close() }
        for gateway in gateways { gateway.stop() }
        clients = []
        gateways = []
    }

    private func rig(
        pausesReading: Bool = false,
        timeout: TimeInterval = 5,
        requestLimitBytes: Int = EverAgentClient.gatewayRequestLimitBytes,
        responder: (@Sendable (FakeRequest) -> FakeReply?)? = nil
    ) async throws -> Rig {
        let gateway = try FakeGateway(pausesReading: pausesReading, responder: responder)
        gateways.append(gateway)
        let client = EverAgentClient(socketPath: gateway.path, requestTimeout: timeout, requestLimitBytes: requestLimitBytes)
        clients.append(client)
        try await client.connect()
        let connection = try await gateway.nextConnection()
        return Rig(client: client, gateway: gateway, connection: connection)
    }

    private func subscribe(_ rig: Rig, sessionId: String? = nil, topics: [String]? = nil) async throws -> EventReader {
        let client = rig.client
        let task = Task { try await client.subscribe(sessionId: sessionId, topics: topics) }
        let request = try await rig.connection.nextRequest()
        XCTAssertEqual(request.method, "events.subscribe")
        rig.connection.respond(to: request, result: ["subscribed": true, "sequence": 7])
        return EventReader(try await task.value)
    }

    private func outcome<Value>(of task: Task<Value, Error>, file: StaticString = #filePath, line: UInt = #line) async -> EverAgentError? {
        switch await task.result {
        case .success(let value):
            XCTFail("Expected a failure but got \(value)", file: file, line: line)
            return nil
        case .failure(let error):
            guard let typed = error as? EverAgentError else {
                XCTFail("Expected an EverAgentError but got \(error)", file: file, line: line)
                return nil
            }
            return typed
        }
    }

    private func failure<Value>(file: StaticString = #filePath, line: UInt = #line, _ body: () async throws -> Value) async -> EverAgentError? {
        do {
            let value = try await body()
            XCTFail("Expected a failure but got \(value)", file: file, line: line)
            return nil
        } catch let error as EverAgentError {
            return error
        } catch {
            XCTFail("Expected an EverAgentError but got \(error)", file: file, line: line)
            return nil
        }
    }

    private func answer(_ rig: Rig, _ method: String, with result: JSONValue) async throws {
        let request = try await rig.connection.nextRequest()
        XCTAssertEqual(request.method, method)
        rig.connection.respond(to: request, result: result)
    }

    func testConnectFailsWhenNoGatewayIsRunning() async {
        let path = "/tmp/tmax-ea-none-\(UUID().uuidString.prefix(8)).sock"
        let client = EverAgentClient(socketPath: path)
        let error = await failure { try await client.connect() }
        XCTAssertEqual(error, .gatewayNotRunning(path: path))
        let connected = await client.isConnected
        XCTAssertFalse(connected)
    }

    func testConnectRejectsSocketPathsLongerThanSunPath() async {
        let limit = MemoryLayout.size(ofValue: sockaddr_un().sun_path) - 1
        let fits = "/tmp/" + String(repeating: "p", count: limit - 5)
        XCTAssertEqual(fits.utf8.count, limit)
        let fitting = EverAgentClient(socketPath: fits)
        let accepted = await failure { try await fitting.connect() }
        XCTAssertEqual(accepted, .gatewayNotRunning(path: fits))
        let tooLong = fits + "p"
        let rejecting = EverAgentClient(socketPath: tooLong)
        let rejected = await failure { try await rejecting.connect() }
        XCTAssertEqual(rejected, .socketPathTooLong(path: tooLong, limit: limit))
    }

    func testDefaultSocketPathPointsAtTheGatewayControlSocket() {
        let expected = FileManager.default.homeDirectoryForCurrentUser.path + "/.ompp/server/control.sock"
        XCTAssertEqual(EverAgentClient.defaultSocketPath, expected)
        XCTAssertEqual(EverAgentClient().socketPath, expected)
    }

    func testConnectIsIdempotentAndCloseIsRepeatable() async throws {
        let rig = try await rig()
        try await rig.client.connect()
        try await rig.client.connect()
        let task = Task { try await rig.client.request("ping") }
        try await answer(rig, "ping", with: "pong")
        let pong = try await task.value
        XCTAssertEqual(pong, "pong")
        XCTAssertEqual(rig.gateway.connectionCount, 1)
        await rig.client.close()
        await rig.client.close()
        let connected = await rig.client.isConnected
        XCTAssertFalse(connected)
    }

    func testRequestsWithoutAConnectionFailWithConnectionClosed() async {
        let client = EverAgentClient(socketPath: "/tmp/tmax-ea-never.sock")
        let request = await failure { try await client.request("server.info") }
        XCTAssertEqual(request, .connectionClosed)
        let subscription = await failure { try await client.subscribe() }
        XCTAssertEqual(subscription, .connectionClosed)
        let info = await failure { try await client.serverInfo() }
        XCTAssertEqual(info, .connectionClosed)
    }

    func testRequestSendsOneJSONLineAndReturnsTheResult() async throws {
        let rig = try await rig()
        let params: [String: JSONValue] = ["root": "/tmp/p", "n": 3, "flags": [true, .null], "text": "héllo \"quoted\"\n"]
        let client = rig.client
        let task = Task { try await client.request("projects.attach", params: params) }
        let request = try await rig.connection.nextRequest()
        XCTAssertEqual(request.method, "projects.attach")
        XCTAssertEqual(request.params, .object(params))
        XCTAssertFalse(request.id.isEmpty)
        rig.connection.respond(to: request, result: ["id": "p1"])
        let result = try await task.value
        XCTAssertEqual(result, ["id": "p1"])
        let next = Task { try await client.request("server.info") }
        let second = try await rig.connection.nextRequest()
        XCTAssertNotEqual(second.id, request.id)
        XCTAssertEqual(second.params, [:])
        rig.connection.respond(to: second, result: .null)
        let nothing = try await next.value
        XCTAssertEqual(nothing, .null)
    }

    func testConcurrentRequestsCorrelateAcrossOutOfOrderResponsesAndInterleavedEvents() async throws {
        let rig = try await rig()
        let events = try await subscribe(rig, sessionId: "s1")
        let client = rig.client
        let alpha = Task { try await client.request("alpha", params: ["n": 1]) }
        let beta = Task { try await client.request("beta", params: ["n": 2]) }
        let gamma = Task { try await client.request("gamma", params: ["n": 3]) }
        var received: [String: FakeRequest] = [:]
        for _ in 0..<3 {
            let request = try await rig.connection.nextRequest()
            received[request.method] = request
        }
        XCTAssertEqual(Set(received.keys), ["alpha", "beta", "gamma"])
        XCTAssertEqual(Set(received.values.map(\.id)).count, 3)
        XCTAssertEqual(received["beta"]?.params, ["n": 2])
        rig.connection.push(topic: "agent", sequence: 8, sessionId: "s1", data: ["type": "agent_start"])
        rig.connection.respond(to: received["gamma"]!, result: "third")
        rig.connection.push(topic: "agent", sequence: 9, sessionId: "s1", data: ["type": "turn_start"])
        rig.connection.respond(to: received["alpha"]!, result: "first")
        rig.connection.push(topic: "agent", sequence: 10, sessionId: "s1", data: ["type": "turn_end"])
        rig.connection.respond(to: received["beta"]!, result: "second")
        let results = try await (alpha.value, beta.value, gamma.value)
        XCTAssertEqual(results.0, "first")
        XCTAssertEqual(results.1, "second")
        XCTAssertEqual(results.2, "third")
        var sequences: [Int] = []
        for _ in 0..<3 { sequences.append(try await events.expectEvent().sequence) }
        XCTAssertEqual(sequences, [8, 9, 10])
    }

    func testManyConcurrentRequestsAllGetTheirOwnAnswers() async throws {
        let rig = try await rig(responder: { request in .result(["echo": request.params["n"], "method": .string(request.method)]) })
        let client = rig.client
        let results = try await withThrowingTaskGroup(of: (Int, JSONValue).self) { group in
            for index in 0..<200 {
                group.addTask { (index, try await client.request("echo.\(index % 7)", params: ["n": .int(index)])) }
            }
            var collected: [Int: JSONValue] = [:]
            for try await (index, value) in group { collected[index] = value }
            return collected
        }
        XCTAssertEqual(results.count, 200)
        for index in 0..<200 {
            XCTAssertEqual(results[index], ["echo": .int(index), "method": .string("echo.\(index % 7)")])
        }
    }

    func testFramesSplitAcrossReadsAreReassembled() async throws {
        let rig = try await rig()
        let client = rig.client
        let task = Task { try await client.request("first") }
        let request = try await rig.connection.nextRequest()
        let reply: JSONValue = ["id": .string(request.id), "result": ["text": "héllo 😀 wörld"]]
        let line = reply.jsonString + "\n"
        rig.connection.sendChunked(Data(line.utf8), chunkSize: 5, pauseMilliseconds: 1)
        let result = try await task.value
        XCTAssertEqual(result, ["text": "héllo 😀 wörld"])
    }

    func testFramesCoalescedInOneReadAreAllDelivered() async throws {
        let rig = try await rig()
        let events = try await subscribe(rig, sessionId: "s1")
        let client = rig.client
        let second = Task { try await client.request("two") }
        let third = Task { try await client.request("three") }
        var byMethod: [String: FakeRequest] = [:]
        for _ in 0..<2 {
            let request = try await rig.connection.nextRequest()
            byMethod[request.method] = request
        }
        let lines: [JSONValue] = [
            ["id": .string(byMethod["three"]!.id), "result": "3"],
            FakeConnection.eventObject(topic: "agent", sequence: 20, sessionId: "s1", projectId: nil, data: ["type": "turn_start"]),
            ["id": .string(byMethod["two"]!.id), "result": "2"],
            FakeConnection.eventObject(topic: "agent", sequence: 21, sessionId: "s1", projectId: nil, data: ["type": "message_start"]),
        ]
        var blob = Data()
        for line in lines {
            blob.append(line.serialized())
            blob.append(0x0A)
        }
        blob.append(Data(#"{"type":"event","sequence":22,"topic":"agent","sessionId":"s1","da"#.utf8))
        rig.connection.sendRaw(blob)
        let twoResult = try await second.value
        let threeResult = try await third.value
        XCTAssertEqual(twoResult, "2")
        XCTAssertEqual(threeResult, "3")
        let firstEvent = try await events.expectEvent()
        let secondEvent = try await events.expectEvent()
        XCTAssertEqual([firstEvent.sequence, secondEvent.sequence], [20, 21])
        rig.connection.sendRaw(Data(("ta\":{\"type\":\"turn_end\"}}\n").utf8))
        let last = try await events.expectEvent()
        XCTAssertEqual(last.sequence, 22)
        XCTAssertEqual(last.agentType, "turn_end")
    }

    func testLargeFramesTravelBothWays() async throws {
        let rig = try await rig()
        let events = try await subscribe(rig)
        let client = rig.client
        let blob = String(repeating: "0123456789abcdef", count: 3 * 65_536)
        XCTAssertGreaterThan(blob.utf8.count, 3_000_000)
        let task = Task { try await client.request("big", params: ["blob": .string(blob)]) }
        let request = try await rig.connection.nextRequest(timeout: 15)
        XCTAssertEqual(request.params["blob"].stringValue, blob)
        let reply: JSONValue = ["id": .string(request.id), "result": ["blob": .string(blob + "!"), "n": 1]]
        var response = reply.serialized()
        response.append(0x0A)
        response.append(FakeConnection.eventObject(topic: "agent", sequence: 31, sessionId: nil, projectId: nil, data: ["after": "big"]).serialized())
        response.append(0x0A)
        rig.connection.sendChunked(response, chunkSize: 200_000)
        let result = try await withTimeout(15, "the large response") { try await task.value }
        XCTAssertEqual(result["blob"].stringValue, blob + "!")
        XCTAssertEqual(result["n"], 1)
        let event = try await events.expectEvent()
        XCTAssertEqual(event.sequence, 31)
        XCTAssertEqual(event.data["after"], "big")
    }

    func testRemoteErrorsMapToTypedErrors() async throws {
        let codes = ["unauthorized", "invalid_request", "not_found", "conflict", "unavailable", "busy", "cancelled", "internal"]
        let rig = try await rig(responder: { request in
            .failure(code: request.method, message: "message for \(request.method)", details: request.method == "busy" ? ["sessionId": "s"] : nil)
        })
        for code in codes {
            let error = await failure { try await rig.client.request(code) }
            XCTAssertEqual(error, .remote(code: code, message: "message for \(code)", details: code == "busy" ? ["sessionId": "s"] : nil))
        }
        XCTAssertEqual(codes, [
            EverAgentErrorCode.unauthorized, EverAgentErrorCode.invalidRequest, EverAgentErrorCode.notFound, EverAgentErrorCode.conflict,
            EverAgentErrorCode.unavailable, EverAgentErrorCode.busy, EverAgentErrorCode.cancelled, EverAgentErrorCode.internalFailure,
        ])
        let stillConnected = await rig.client.isConnected
        XCTAssertTrue(stillConnected)
    }

    func testErrorsDescribeThemselvesForPeople() {
        let descriptions: [(EverAgentError, [String])] = [
            (.gatewayNotRunning(path: "/x/control.sock"), ["not running", "/x/control.sock"]),
            (.gatewayTooOld, ["too old", "Update EverAgent"]),
            (.socketPathTooLong(path: "/long", limit: 103), ["too long", "103"]),
            (.io(operation: "open", code: EACCES), ["open", "ermission"]),
            (.protocol("odd"), ["odd"]),
            (.remote(code: "busy", message: "claimed elsewhere", details: nil), ["claimed elsewhere"]),
            (.remote(code: "internal", message: "", details: nil), ["internal"]),
            (.connectionClosed, ["closed"]),
            (.cancelled, ["cancelled"]),
            (.timeout(operation: "server.info", after: 75), ["server.info", "75 seconds"]),
            (.timeout(operation: "x", after: 1), ["1 second"]),
            (.timeout(operation: "x", after: 0.15), ["0.15 seconds"]),
            (.requestTooLarge(bytes: 200, limit: 100), ["200", "100"]),
        ]
        for (error, fragments) in descriptions {
            let text = error.errorDescription ?? ""
            for fragment in fragments { XCTAssertTrue(text.contains(fragment), "\(text) should mention \(fragment)") }
        }
    }

    func testAnUnparsableRequestErrorFailsTheOldestPendingRequest() async throws {
        let rig = try await rig()
        let events = try await subscribe(rig)
        let client = rig.client
        let first = Task { try await client.request("first") }
        _ = try await rig.connection.nextRequest()
        let second = Task { try await client.request("second") }
        let secondRequest = try await rig.connection.nextRequest()
        rig.connection.sendLine(#"{"id":"","error":{"code":"invalid_request","message":"invalid JSON-RPC request"}}"#)
        let error = await outcome(of: first)
        XCTAssertEqual(error, .remote(code: "invalid_request", message: "invalid JSON-RPC request", details: nil))
        rig.connection.respond(to: secondRequest, result: "fine")
        let result = try await second.value
        XCTAssertEqual(result, "fine")
        rig.connection.sendLine(#"{"id":"","error":{"code":"invalid_request","message":"nobody is waiting"}}"#)
        rig.connection.sendLine(#"{"id":"","result":"ignored"}"#)
        rig.connection.push(topic: "agent", sequence: 1)
        _ = try await events.expectEvent()
        let third = Task { try await client.request("third") }
        try await answer(rig, "third", with: "still fine")
        let thirdResult = try await third.value
        XCTAssertEqual(thirdResult, "still fine")
    }

    func testAResponseWithoutAnOutcomeFailsOnlyThatRequest() async throws {
        let rig = try await rig()
        let client = rig.client
        let task = Task { try await client.request("odd") }
        let request = try await rig.connection.nextRequest()
        rig.connection.send(["id": .string(request.id)])
        let error = await outcome(of: task)
        guard case .protocol? = error else { return XCTFail("Wrong error: \(String(describing: error))") }
        let connected = await client.isConnected
        XCTAssertTrue(connected)
        let next = Task { try await client.request("next") }
        try await answer(rig, "next", with: "ok")
        let result = try await next.value
        XCTAssertEqual(result, "ok")
    }

    func testAMalformedLineClosesTheConnectionWithAProtocolError() async throws {
        let rig = try await rig()
        let events = try await subscribe(rig)
        let client = rig.client
        let task = Task { try await client.request("doomed") }
        _ = try await rig.connection.nextRequest()
        rig.connection.sendLine("this is not json")
        let error = await outcome(of: task)
        guard case .protocol? = error else { return XCTFail("Wrong error: \(String(describing: error))") }
        let connected = await client.isConnected
        XCTAssertFalse(connected)
        let finished = try await events.next()
        XCTAssertNil(finished)
        let afterwards = await failure { try await client.request("again") }
        XCTAssertEqual(afterwards, .connectionClosed)
    }

    func testLinesTheClientDoesNotUnderstandAreIgnored() async throws {
        let rig = try await rig()
        let client = rig.client
        rig.connection.sendLine("")
        rig.connection.sendLine("[1,2,3]")
        rig.connection.sendLine(#"{"type":"authenticated","deviceId":"x"}"#)
        rig.connection.sendLine(#"{"id":"tmax-9999","result":"nobody asked"}"#)
        rig.connection.sendLine(#"{"type":"event","sequence":1,"data":{}}"#)
        let task = Task { try await client.request("after-noise") }
        try await answer(rig, "after-noise", with: "ok")
        let result = try await task.value
        XCTAssertEqual(result, "ok")
        let connected = await client.isConnected
        XCTAssertTrue(connected)
    }

    func testARequestTimesOutAndALateResponseIsIgnored() async throws {
        let rig = try await rig()
        let client = rig.client
        let slow = Task { try await client.request("slow", timeout: 0.15) }
        let late = try await rig.connection.nextRequest()
        let error = await outcome(of: slow)
        XCTAssertEqual(error, .timeout(operation: "slow", after: 0.15))
        rig.connection.respond(to: late, result: "too late")
        let next = Task { try await client.request("next") }
        try await answer(rig, "next", with: "ok")
        let result = try await next.value
        XCTAssertEqual(result, "ok")
        let connected = await client.isConnected
        XCTAssertTrue(connected)
    }

    func testPerRequestTimeoutOverridesTheClientDefault() async throws {
        let rig = try await rig(timeout: 0.1)
        let client = rig.client
        let patient = Task { try await client.request("patient", timeout: 3) }
        let request = try await rig.connection.nextRequest()
        try await Task.sleep(nanoseconds: 300_000_000)
        rig.connection.respond(to: request, result: "patience")
        let result = try await patient.value
        XCTAssertEqual(result, "patience")
        let impatient = Task { try await client.request("impatient") }
        _ = try await rig.connection.nextRequest()
        let error = await outcome(of: impatient)
        XCTAssertEqual(error, .timeout(operation: "impatient", after: 0.1))
    }

    func testCancellationFailsTheRequestAndALateResponseIsIgnored() async throws {
        let rig = try await rig()
        let client = rig.client
        let task = Task { try await client.request("slow") }
        let request = try await rig.connection.nextRequest()
        task.cancel()
        let error = await outcome(of: task)
        XCTAssertEqual(error, .cancelled)
        rig.connection.respond(to: request, result: "late")
        let next = Task { try await client.request("next") }
        try await answer(rig, "next", with: "ok")
        let result = try await next.value
        XCTAssertEqual(result, "ok")
        let connected = await client.isConnected
        XCTAssertTrue(connected)
    }

    func testAnAlreadyCancelledTaskNeverSendsARequest() async throws {
        let rig = try await rig()
        let client = rig.client
        let task = Task { () -> JSONValue in
            while !Task.isCancelled { await Task.yield() }
            return try await client.request("never")
        }
        task.cancel()
        let error = await outcome(of: task)
        XCTAssertEqual(error, .cancelled)
        let next = Task { try await client.request("after") }
        let request = try await rig.connection.nextRequest()
        XCTAssertEqual(request.method, "after")
        rig.connection.respond(to: request, result: 1)
        _ = try await next.value
        XCTAssertEqual(rig.connection.receivedRequests.map(\.method), ["after"])
    }

    func testOversizedRequestsAreRejectedBeforeAnythingIsSent() async throws {
        let rig = try await rig(requestLimitBytes: 256)
        let client = rig.client
        let error = await failure { try await client.request("big", params: ["blob": .string(String(repeating: "x", count: 1000))]) }
        guard case .requestTooLarge(let bytes, let limit)? = error else { return XCTFail("Wrong error: \(String(describing: error))") }
        XCTAssertEqual(limit, 256)
        XCTAssertGreaterThan(bytes, 1000)
        let small = Task { try await client.request("small") }
        let request = try await rig.connection.nextRequest()
        XCTAssertEqual(request.method, "small")
        rig.connection.respond(to: request, result: "ok")
        _ = try await small.value
        XCTAssertEqual(rig.connection.receivedRequests.map(\.method), ["small"])
    }

    func testRequestsToAGatewayThatHasGoneFailWithoutRaisingSIGPIPE() async throws {
        let rig = try await rig()
        rig.connection.closeFromServer()
        try await rig.connection.waitUntilClosed()
        let client = rig.client
        for _ in 0..<3 {
            let error = await failure { try await client.request("late") }
            XCTAssertEqual(error, .connectionClosed)
        }
    }

    func testPendingRequestsFailWhenTheGatewayDrops() async throws {
        let rig = try await rig()
        let events = try await subscribe(rig)
        let client = rig.client
        let first = Task { try await client.request("a") }
        let second = Task { try await client.request("b") }
        _ = try await rig.connection.nextRequest()
        _ = try await rig.connection.nextRequest()
        rig.connection.closeFromServer()
        let firstError = await outcome(of: first)
        let secondError = await outcome(of: second)
        XCTAssertEqual(firstError, .connectionClosed)
        XCTAssertEqual(secondError, .connectionClosed)
        let finished = try await events.next()
        XCTAssertNil(finished)
        let connected = await client.isConnected
        XCTAssertFalse(connected)
        let request = await failure { try await client.request("c") }
        XCTAssertEqual(request, .connectionClosed)
        let subscription = await failure { try await client.subscribe() }
        XCTAssertEqual(subscription, .connectionClosed)
    }

    func testAPartialLineAtDisconnectIsDiscarded() async throws {
        let rig = try await rig()
        let client = rig.client
        let task = Task { try await client.request("a") }
        let request = try await rig.connection.nextRequest()
        rig.connection.sendRaw(Data(#"{"id":"\#(request.id)","result":"trunc"#.utf8))
        rig.connection.closeFromServer()
        let error = await outcome(of: task)
        XCTAssertEqual(error, .connectionClosed)
    }

    func testClientCanReconnectAfterTheGatewayDrops() async throws {
        let rig = try await rig()
        rig.connection.closeFromServer()
        let client = rig.client
        let deadline = Date().addingTimeInterval(5)
        while await client.isConnected && Date() < deadline { try await Task.sleep(nanoseconds: 2_000_000) }
        let stillConnected = await client.isConnected
        XCTAssertFalse(stillConnected)
        try await client.connect()
        let second = try await rig.gateway.nextConnection()
        let task = Task { try await client.request("again") }
        let request = try await second.nextRequest()
        second.respond(to: request, result: "back")
        let result = try await task.value
        XCTAssertEqual(result, "back")
    }

    func testCloseFailsPendingRequestsFinishesStreamsAndAllowsReconnect() async throws {
        let rig = try await rig()
        let events = try await subscribe(rig)
        let client = rig.client
        let pending = Task { try await client.request("pending") }
        _ = try await rig.connection.nextRequest()
        await client.close()
        let error = await outcome(of: pending)
        XCTAssertEqual(error, .connectionClosed)
        let finished = try await events.next()
        XCTAssertNil(finished)
        try await rig.connection.waitForPeerClose()
        let connected = await client.isConnected
        XCTAssertFalse(connected)
        try await client.connect()
        let second = try await rig.gateway.nextConnection()
        let task = Task { try await client.request("fresh") }
        let request = try await second.nextRequest()
        second.respond(to: request, result: "new connection")
        let result = try await task.value
        XCTAssertEqual(result, "new connection")
        XCTAssertEqual(rig.gateway.connectionCount, 2)
    }

    func testCloseReleasesAWriteBlockedOnASilentGateway() async throws {
        let rig = try await rig(pausesReading: true)
        let client = rig.client
        let huge = String(repeating: "x", count: 24 * 1024 * 1024)
        let task = Task { try await client.request("huge", params: ["blob": .string(huge)]) }
        try await Task.sleep(nanoseconds: 100_000_000)
        try await withTimeout(5, "close to return") { await client.close() }
        let error = await outcome(of: task)
        XCTAssertEqual(error, .connectionClosed)
    }

    func testDroppingTheClientClosesTheSocket() async throws {
        let gateway = try FakeGateway()
        gateways.append(gateway)
        var client: EverAgentClient? = EverAgentClient(socketPath: gateway.path)
        try await client?.connect()
        let connection = try await gateway.nextConnection()
        client = nil
        try await connection.waitForPeerClose()
    }

    func testSubscribeSendsTheFiltersAndYieldsPushedEvents() async throws {
        let rig = try await rig()
        let client = rig.client
        let task = Task { try await client.subscribe(sessionId: "s9", topics: ["agent", "ui.request"]) }
        let request = try await rig.connection.nextRequest()
        XCTAssertEqual(request.method, "events.subscribe")
        XCTAssertEqual(request.params, ["sessionId": "s9", "topics": ["agent", "ui.request"]])
        rig.connection.respond(to: request, result: ["subscribed": true, "sequence": 41])
        let events = EventReader(try await task.value)
        rig.connection.push(topic: "ui.request", sequence: 42, sessionId: "s9", projectId: "p1", data: ["requestId": "r1", "kind": "confirm", "title": "Allow?"])
        let event = try await events.expectEvent()
        XCTAssertEqual(event, EverAgentEvent(sequence: 42, topic: "ui.request", projectId: "p1", sessionId: "s9", data: ["requestId": "r1", "kind": "confirm", "title": "Allow?"]))
        let unfiltered = Task { try await client.subscribe() }
        let second = try await rig.connection.nextRequest()
        XCTAssertEqual(second.params, [:])
        rig.connection.respond(to: second, result: ["subscribed": true, "sequence": 43])
        _ = try await unfiltered.value
    }

    func testEventsExposeTheirFieldsAndFlagResync() async throws {
        let rig = try await rig()
        let events = try await subscribe(rig)
        rig.connection.push(topic: "agent", sequence: 11, sessionId: "s1", projectId: "p1", data: ["type": "message_end"])
        rig.connection.sendLine(#"{"type":"event","sequence":0,"topic":"events.resync","data":{"reason":"backpressure"}}"#)
        rig.connection.push(topic: "session", sequence: 12)
        let agent = try await events.expectEvent()
        XCTAssertEqual(agent, EverAgentEvent(sequence: 11, topic: "agent", projectId: "p1", sessionId: "s1", data: ["type": "message_end"]))
        XCTAssertFalse(agent.resync)
        let resync = try await events.expectEvent()
        XCTAssertTrue(resync.resync)
        XCTAssertEqual(resync.topic, EverAgentTopic.resync)
        XCTAssertEqual(resync.sequence, 0)
        XCTAssertNil(resync.sessionId)
        XCTAssertEqual(resync.data["reason"], "backpressure")
        let session = try await events.expectEvent()
        XCTAssertFalse(session.resync)
        XCTAssertNil(session.projectId)
        XCTAssertNil(session.sessionId)
        XCTAssertEqual(session.data, [:])
    }

    func testEventsFollowingTheAcknowledgementAreNotLost() async throws {
        let rig = try await rig()
        let client = rig.client
        let task = Task { try await client.subscribe(sessionId: "s1") }
        let request = try await rig.connection.nextRequest()
        var blob = Data()
        let lines: [JSONValue] = [
            ["id": .string(request.id), "result": ["subscribed": true, "sequence": 50]],
            FakeConnection.eventObject(topic: "agent", sequence: 51, sessionId: "s1", projectId: nil, data: ["type": "agent_start"]),
            FakeConnection.eventObject(topic: "agent", sequence: 52, sessionId: "s1", projectId: nil, data: ["type": "turn_start"]),
            FakeConnection.eventObject(topic: "agent", sequence: 53, sessionId: "s1", projectId: nil, data: ["type": "turn_end"]),
        ]
        for line in lines {
            blob.append(line.serialized())
            blob.append(0x0A)
        }
        rig.connection.sendRaw(blob)
        let events = EventReader(try await task.value)
        var sequences: [Int] = []
        for _ in 0..<3 { sequences.append(try await events.expectEvent().sequence) }
        XCTAssertEqual(sequences, [51, 52, 53])
    }

    func testASecondSubscriptionReplacesTheFirstStream() async throws {
        let rig = try await rig()
        let first = try await subscribe(rig, sessionId: "a")
        rig.connection.push(topic: "agent", sequence: 1, sessionId: "a")
        let before = try await first.expectEvent()
        XCTAssertEqual(before.sequence, 1)
        let second = try await subscribe(rig, sessionId: "b")
        let finished = try await first.next()
        XCTAssertNil(finished)
        rig.connection.push(topic: "agent", sequence: 2, sessionId: "b")
        let after = try await second.expectEvent()
        XCTAssertEqual(after.sequence, 2)
        XCTAssertEqual(after.sessionId, "b")
    }

    func testStoppingToIterateEndsTheSubscriptionWithoutDisturbingTheConnection() async throws {
        let rig = try await rig()
        let client = rig.client
        do {
            let events = try await subscribe(rig)
            rig.connection.push(topic: "agent", sequence: 1)
            _ = try await events.expectEvent()
        }
        rig.connection.push(topic: "agent", sequence: 2)
        let task = Task { try await client.request("still") }
        try await answer(rig, "still", with: "alive")
        let result = try await task.value
        XCTAssertEqual(result, "alive")
        let connected = await client.isConnected
        XCTAssertTrue(connected)
    }

    func testEventsPushedWithoutASubscriptionAreDropped() async throws {
        let rig = try await rig()
        let client = rig.client
        rig.connection.push(topic: "agent", sequence: 1, sessionId: "s1")
        let ping = Task { try await client.request("ping") }
        try await answer(rig, "ping", with: "pong")
        _ = try await ping.value
        let events = try await subscribe(rig)
        rig.connection.push(topic: "agent", sequence: 2, sessionId: "s1")
        let event = try await events.expectEvent()
        XCTAssertEqual(event.sequence, 2)
    }

    func testSubscribeMapsNotFoundToGatewayTooOld() async throws {
        let rig = try await rig(responder: { request in
            request.method == "events.subscribe" ? .failure(code: "not_found", message: "unknown RPC method") : .failure(code: "not_found", message: "session not found")
        })
        let client = rig.client
        let error = await failure { try await client.subscribe(sessionId: "s1") }
        XCTAssertEqual(error, .gatewayTooOld)
        XCTAssertTrue(error?.errorDescription?.contains("Update EverAgent") == true)
        let connected = await client.isConnected
        XCTAssertTrue(connected)
        let other = await failure { try await client.getSession(sessionId: "missing") }
        XCTAssertEqual(other, .remote(code: "not_found", message: "session not found", details: nil))
        let again = await failure { try await client.subscribe() }
        XCTAssertEqual(again, .gatewayTooOld)
    }

    func testOtherSubscribeFailuresKeepTheirMeaning() async throws {
        let rig = try await rig(responder: { _ in .failure(code: "busy", message: "too many simultaneous requests") })
        let client = rig.client
        let error = await failure { try await client.subscribe() }
        XCTAssertEqual(error, .remote(code: "busy", message: "too many simultaneous requests", details: nil))
    }

    func testSubscribeRequiresTheGatewayToAcknowledge() async throws {
        let rig = try await rig(responder: { _ in .result([:]) })
        let client = rig.client
        let error = await failure { try await client.subscribe() }
        guard case .protocol? = error else { return XCTFail("Wrong error: \(String(describing: error))") }
        let connected = await client.isConnected
        XCTAssertTrue(connected)
    }

    func testEventHelpersExposeMessagesAndApprovals() {
        let partial: JSONValue = ["role": "assistant", "content": [["type": "text", "text": "Hel"]]]
        let update = EverAgentEvent(sequence: 1, topic: "agent", sessionId: "s", data: ["type": "message_update", "message": partial, "assistantMessageEvent": ["type": "text_delta", "partial": ["role": "assistant", "content": [["type": "text", "text": "Ignored"]]]]])
        XCTAssertEqual(update.agentType, "message_update")
        XCTAssertEqual(update.message?.role, "assistant")
        XCTAssertEqual(update.message?.text, "Hel")
        let viaPartial = EverAgentEvent(sequence: 2, topic: "agent", data: ["type": "message_update", "assistantMessageEvent": ["type": "text_delta", "partial": ["role": "assistant", "content": [["type": "text", "text": "Hello"]]]]])
        XCTAssertEqual(viaPartial.message?.text, "Hello")
        let tool = EverAgentEvent(sequence: 3, topic: "agent", data: ["type": "tool_execution_start", "toolName": "bash", "subagentId": "agent-7"])
        XCTAssertNil(tool.message)
        XCTAssertEqual(tool.subagentId, "agent-7")
        let notAgent = EverAgentEvent(sequence: 4, topic: "session", data: ["type": "message_update", "message": partial])
        XCTAssertNil(notAgent.agentType)
        XCTAssertNil(notAgent.message)
        XCTAssertNil(notAgent.subagentId)
        let ask = EverAgentEvent(sequence: 5, topic: "ui.request", sessionId: "s", data: ["requestId": "r1", "kind": "confirm", "title": "Run rm -rf?", "message": "It deletes things", "payload": ["tool": "bash"]])
        XCTAssertEqual(ask.uiRequest?.requestId, "r1")
        XCTAssertEqual(ask.uiRequest?.kind, "confirm")
        XCTAssertEqual(ask.uiRequest?.title, "Run rm -rf?")
        XCTAssertEqual(ask.uiRequest?.message, "It deletes things")
        XCTAssertEqual(ask.uiRequest?.payload, ["tool": "bash"])
        let bare = EverAgentEvent(sequence: 6, topic: "ui.request", data: ["requestId": "r2"])
        XCTAssertEqual(bare.uiRequest?.kind, "")
        XCTAssertNil(bare.uiRequest?.message)
        XCTAssertNil(EverAgentEvent(sequence: 7, topic: "ui.request", data: ["kind": "confirm"]).uiRequest)
        XCTAssertNil(EverAgentEvent(sequence: 8, topic: "agent", data: ["requestId": "r3"]).uiRequest)
    }

    func testServerInfoReportsEventSubscriptionSupport() async throws {
        let capabilities = FakeBox<[JSONValue]>(["sessions", "events.after", "worker"])
        let rig = try await rig(responder: { request in
            guard request.method == "server.info" else { return nil }
            return .result(["serverId": "srv-1", "name": "Volodymyr's Mac", "platform": "macos", "protocolVersion": 1, "capabilities": .array(capabilities.value)])
        })
        let client = rig.client
        let old = try await client.serverInfo()
        XCTAssertEqual(old.serverId, "srv-1")
        XCTAssertEqual(old.name, "Volodymyr's Mac")
        XCTAssertEqual(old.platform, "macos")
        XCTAssertEqual(old.protocolVersion, 1)
        XCTAssertEqual(old.capabilities, ["sessions", "events.after", "worker"])
        XCTAssertFalse(old.supportsEventSubscription)
        capabilities.value = ["sessions", "events.after", "events.subscribe", "worker"]
        let current = try await client.serverInfo()
        XCTAssertTrue(current.supportsEventSubscription)
        XCTAssertEqual(current.capabilities.count, 4)
        capabilities.value = []
        let bare = try await client.serverInfo()
        XCTAssertFalse(bare.supportsEventSubscription)
        XCTAssertEqual(bare.capabilities, [])
    }

    func testServerInfoWithoutAServerIdIsAProtocolError() async throws {
        let rig = try await rig(responder: script(["server.info": ["name": "not a gateway"]]))
        let client = rig.client
        let error = await failure { try await client.serverInfo() }
        guard case .protocol? = error else { return XCTFail("Wrong error: \(String(describing: error))") }
    }

    func testProjectsAreListedAndAttached() async throws {
        let second: JSONValue = ["id": "p2", "name": "Other", "root": "/other", "revision": 0, "createdAt": "2026-10-02T00:00:00Z"]
        let rig = try await rig(responder: script(["projects.list": ["projects": [projectJSON, second]], "projects.attach": projectJSON]))
        let client = rig.client
        let projects = try await client.projects()
        XCTAssertEqual(projects.map(\.id), ["p1", "p2"])
        XCTAssertEqual(projects.first?.name, "Tmax")
        XCTAssertEqual(projects.first?.root, "/Users/me/Tmax")
        XCTAssertEqual(projects.first?.revision, 3)
        XCTAssertEqual(projects.first?.createdAt, "2026-10-01T00:00:00Z")
        let attached = try await client.attachProject(root: "/Users/me/Tmax")
        XCTAssertEqual(attached, projects.first)
        XCTAssertEqual(rig.connection.receivedRequests.last?.params, ["root": "/Users/me/Tmax"])
    }

    func testCreateSessionSavesThenClaims() async throws {
        let rig = try await rig(responder: { request in
            switch request.method {
            case "sessions.save": return .result(request.params["session"])
            case "sessions.claim": return .result(leaseJSON)
            default: return nil
            }
        })
        let model = EverAgentModelRef(provider: "anthropic", id: "claude-opus")
        let sessionId = try await rig.client.createSession(projectId: "p1", title: "Coach", model: model)
        let requests = rig.connection.receivedRequests
        XCTAssertEqual(requests.map(\.method), ["sessions.save", "sessions.claim"])
        let save = requests[0].params
        let session = save["session"]
        XCTAssertEqual(session["id"], .string(sessionId))
        XCTAssertEqual(UUID(uuidString: sessionId)?.uuidString.lowercased(), sessionId)
        XCTAssertEqual(session["projectId"], "p1")
        XCTAssertEqual(session["title"], "Coach")
        XCTAssertEqual(session["runtime"], "mac")
        XCTAssertEqual(session["revision"], 0)
        XCTAssertEqual(session["messages"], [])
        XCTAssertEqual(session["entries"], [])
        XCTAssertEqual(session["model"], ["provider": "anthropic", "id": "claude-opus"])
        XCTAssertEqual(save["baseRevision"], 0)
        XCTAssertFalse(save["opId"].text.isEmpty)
        XCTAssertEqual(session["createdAt"], session["updatedAt"])
        let created = ISO8601DateFormatter().date(from: session["createdAt"].text)
        XCTAssertNotNil(created)
        XCTAssertLessThan(abs(created?.timeIntervalSinceNow ?? 1_000), 60)
        XCTAssertEqual(requests[1].params, ["sessionId": .string(sessionId), "runtime": "mac"])
        let other = try await rig.client.createSession(projectId: "p1", title: "Second")
        XCTAssertNotEqual(other, sessionId)
        let secondSave = rig.connection.receivedRequests[2].params
        XCTAssertTrue(secondSave["session"]["model"].isNull)
        XCTAssertNotEqual(secondSave["opId"], save["opId"])
    }

    func testCreateSessionStopsWhenTheClaimFails() async throws {
        let rig = try await rig(responder: { request in
            switch request.method {
            case "sessions.save": return .result(request.params["session"])
            default: return .failure(code: "busy", message: "session is owned by another device")
            }
        })
        let client = rig.client
        let error = await failure { try await client.createSession(projectId: "p1", title: "Coach") }
        XCTAssertEqual(error, .remote(code: "busy", message: "session is owned by another device", details: nil))
    }

    func testPromptClaimsThenCallsTheWorker() async throws {
        let rig = try await rig(responder: script(["sessions.claim": leaseJSON, "worker.call:session.prompt": ["accepted": true, "state": "started"]]))
        let client = rig.client
        let result = try await client.prompt(sessionId: "s1", projectId: "p1", text: "What should I train today?")
        XCTAssertEqual(result, EverAgentPromptResult(json: ["accepted": true, "state": "started"]))
        XCTAssertTrue(result.accepted)
        XCTAssertEqual(result.state, "started")
        XCTAssertFalse(result.queued)
        let requests = rig.connection.receivedRequests
        XCTAssertEqual(requests.map(\.method), ["sessions.claim", "worker.call"])
        XCTAssertEqual(requests[0].params, ["sessionId": "s1", "runtime": "mac"])
        let call = requests[1].params
        XCTAssertEqual(call["projectId"], "p1")
        XCTAssertEqual(call["sessionId"], "s1")
        XCTAssertEqual(call["method"], "session.prompt")
        XCTAssertEqual(call["arguments"], ["sessionId": "s1", "text": "What should I train today?"])
        XCTAssertFalse(call["opId"].text.isEmpty)
        let image: JSONValue = ["type": "image", "data": "QUJD", "mimeType": "image/png"]
        _ = try await client.prompt(sessionId: "s1", projectId: "p1", text: "Look at this", images: [image])
        let withImage = rig.connection.receivedRequests[3].params
        XCTAssertEqual(withImage["arguments"], ["sessionId": "s1", "text": "Look at this", "images": [image]])
        XCTAssertNotEqual(withImage["opId"], call["opId"])
    }

    func testPromptReportsABusyAgentWithoutThrowing() async throws {
        let rig = try await rig(responder: script(["sessions.claim": leaseJSON, "worker.call:session.prompt": ["accepted": false, "state": "busy"]]))
        let result = try await rig.client.prompt(sessionId: "s1", projectId: "p1", text: "again")
        XCTAssertFalse(result.accepted)
        XCTAssertEqual(result.state, "busy")
        let queued = EverAgentPromptResult(json: ["accepted": true, "queued": true])
        XCTAssertTrue(queued.queued)
        XCTAssertNil(queued.state)
    }

    func testPromptDoesNotReachTheWorkerWhenAnotherDeviceOwnsTheSession() async throws {
        let rig = try await rig(responder: { request in
            request.method == "sessions.claim" ? .failure(code: "busy", message: "session is owned by another device") : .result(["accepted": true])
        })
        let client = rig.client
        let error = await failure { try await client.prompt(sessionId: "s1", projectId: "p1", text: "hi") }
        XCTAssertEqual(error, .remote(code: "busy", message: "session is owned by another device", details: nil))
        XCTAssertEqual(rig.connection.receivedRequests.map(\.method), ["sessions.claim"])
    }

    func testAbortAndSetModelClaimThenCallTheWorker() async throws {
        let rig = try await rig(responder: script([
            "sessions.claim": leaseJSON,
            "worker.call:session.abort": ["aborted": true],
            "worker.call:session.setModel": ["switched": [:], "state": [:]],
        ]))
        let client = rig.client
        try await client.abort(sessionId: "s1", projectId: "p1")
        try await client.setModel(sessionId: "s1", projectId: "p1", model: EverAgentModelRef(provider: "openai", id: "gpt-5"), thinkingLevel: "high")
        try await client.setModel(sessionId: "s1", projectId: "p1", model: EverAgentModelRef(provider: "openai", id: "gpt-5"))
        let requests = rig.connection.receivedRequests
        XCTAssertEqual(requests.map(\.method), ["sessions.claim", "worker.call", "sessions.claim", "worker.call", "sessions.claim", "worker.call"])
        XCTAssertEqual(requests[1].params["method"], "session.abort")
        XCTAssertEqual(requests[1].params["arguments"], ["sessionId": "s1"])
        XCTAssertEqual(requests[1].params["sessionId"], "s1")
        XCTAssertFalse(requests[1].params["opId"].text.isEmpty)
        XCTAssertEqual(requests[3].params["method"], "session.setModel")
        XCTAssertEqual(requests[3].params["arguments"], ["sessionId": "s1", "model": ["provider": "openai", "id": "gpt-5"], "thinkingLevel": "high"])
        XCTAssertFalse(requests[3].params["opId"].text.isEmpty)
        XCTAssertEqual(requests[5].params["arguments"], ["sessionId": "s1", "model": ["provider": "openai", "id": "gpt-5"]])
        XCTAssertNotEqual(requests[3].params["opId"], requests[5].params["opId"])
    }

    func testRespondUIAnswersAnApprovalWithoutClaiming() async throws {
        let rig = try await rig(responder: script(["worker.ui.response": ["accepted": true]]))
        let client = rig.client
        try await client.respondUI(projectId: "p1", sessionId: "s1", requestId: "r1", result: ["approved": true])
        try await client.respondUI(projectId: "p1", sessionId: "s1", requestId: "r2", result: .null, cancelled: true)
        let requests = rig.connection.receivedRequests
        XCTAssertEqual(requests.map(\.method), ["worker.ui.response", "worker.ui.response"])
        XCTAssertEqual(requests[0].params, ["projectId": "p1", "sessionId": "s1", "requestId": "r1", "result": ["approved": true]])
        XCTAssertEqual(requests[1].params, ["projectId": "p1", "sessionId": "s1", "requestId": "r2", "result": .null, "cancelled": true])
    }

    func testRespondUISurfacesAnExpiredRequest() async throws {
        let rig = try await rig(responder: { _ in .failure(code: "not_found", message: "worker UI request is no longer pending") })
        let client = rig.client
        let error = await failure { try await client.respondUI(projectId: "p1", sessionId: "s1", requestId: "r1", result: ["approved": true]) }
        XCTAssertEqual(error, .remote(code: "not_found", message: "worker UI request is no longer pending", details: nil))
    }

    func testModelsAndProviderCatalogAreTyped() async throws {
        let models: JSONValue = ["models": [
            ["provider": "anthropic", "id": "claude-opus", "name": "Claude Opus", "contextWindow": 200_000],
            ["provider": "openai", "id": "gpt-5"],
            ["id": "no-provider"],
        ]]
        let catalog: JSONValue = ["providers": [
            ["id": "anthropic", "name": "Anthropic", "method": "oauth", "available": true, "storedAs": "anthropic", "accounts": [
                ["id": "1", "label": "me@example.com", "detail": "Home", "kind": "oauth"],
                ["label": "no id"],
            ]],
            ["id": "openrouter", "accounts": []],
            ["name": "no id"],
        ]]
        let rig = try await rig(responder: script(["worker.call:models.list": models, "worker.call:providers.catalog": catalog]))
        let client = rig.client
        let listed = try await client.models(projectId: "p1")
        XCTAssertEqual(listed.map(\.id), ["claude-opus", "gpt-5"])
        XCTAssertEqual(listed.map(\.name), ["Claude Opus", "gpt-5"])
        XCTAssertEqual(listed[0].ref, EverAgentModelRef(provider: "anthropic", id: "claude-opus"))
        XCTAssertEqual(listed[0].raw["contextWindow"], 200_000)
        let providers = try await client.providerCatalog(projectId: "p1")
        XCTAssertEqual(providers.map(\.id), ["anthropic", "openrouter"])
        XCTAssertEqual(providers.map(\.name), ["Anthropic", "openrouter"])
        XCTAssertEqual(providers[0].accounts, [EverAgentProviderAccount(json: ["id": "1", "label": "me@example.com", "detail": "Home", "kind": "oauth"])!])
        XCTAssertEqual(providers[0].accounts.first?.detail, "Home")
        XCTAssertEqual(providers[0].raw["method"], "oauth")
        XCTAssertTrue(providers[1].accounts.isEmpty)
        let requests = rig.connection.receivedRequests
        XCTAssertEqual(requests[0].params, ["projectId": "p1", "method": "models.list", "arguments": [:]])
        XCTAssertEqual(requests[1].params, ["projectId": "p1", "method": "providers.catalog", "arguments": [:]])
    }

    func testGetSessionParsesTheTranscript() async throws {
        let rig = try await rig(responder: script(["sessions.get": transcriptJSON]))
        let session = try await rig.client.getSession(sessionId: "s-1")
        XCTAssertEqual(rig.connection.receivedRequests.first?.params, ["sessionId": "s-1"])
        XCTAssertEqual(session.id, "s-1")
        XCTAssertEqual(session.projectId, "p1")
        XCTAssertEqual(session.title, "Coach")
        XCTAssertEqual(session.revision, 4)
        XCTAssertEqual(session.runtime, "mac")
        XCTAssertEqual(session.createdAt, "2026-11-01T10:00:00Z")
        XCTAssertEqual(session.updatedAt, "2026-11-01T10:05:00Z")
        XCTAssertEqual(session.model, EverAgentModelRef(provider: "anthropic", id: "claude-opus"))
        XCTAssertTrue(session.isStreaming)
        XCTAssertEqual(session.raw, transcriptJSON)
        XCTAssertEqual(session.messages.map(\.role), ["user", "assistant", "assistant"])
        XCTAssertEqual(session.messages[0].content, [.text("Plan my week")])
        XCTAssertEqual(session.messages[0].text, "Plan my week")
        XCTAssertNil(session.messages[0].stopReason)
        let assistant = session.messages[1]
        XCTAssertEqual(assistant.stopReason, "toolUse")
        XCTAssertEqual(assistant.text, "Sure. Done.")
        XCTAssertEqual(assistant.content, [
            .thinking("Let me look"),
            .text("Sure. "),
            .toolCall(id: "call-1", name: "tmax_list_workouts", arguments: ["limit": 3]),
            .text("Done."),
            .image(mimeType: "image/png", data: "QUJD"),
            .other(type: "audio", raw: ["type": "audio", "seconds": 2]),
        ])
        XCTAssertEqual(session.messages[2].stopReason, "error")
        XCTAssertEqual(session.messages[2].errorMessage, "Provider overloaded")
        XCTAssertEqual(session.messages[2].content, [])
        XCTAssertEqual(session.messages[2].text, "")
    }

    func testGetSessionRejectsARecordWithoutAnId() async throws {
        let rig = try await rig(responder: script(["sessions.get": ["title": "anonymous"]]))
        let client = rig.client
        let error = await failure { try await client.getSession(sessionId: "s") }
        guard case .protocol? = error else { return XCTFail("Wrong error: \(String(describing: error))") }
    }

    func testEventsAfterFetchesWhatWasMissed() async throws {
        let batch: JSONValue = ["events": [
            ["type": "event", "sequence": 8, "topic": "agent", "sessionId": "s1", "data": ["type": "agent_end"]],
            ["sequence": 9, "topic": "session.updated", "projectId": "p1", "data": [:]],
            ["sequence": 10, "data": [:]],
        ], "sequence": 9]
        let rig = try await rig(responder: script(["events.after": batch]))
        let client = rig.client
        let result = try await client.eventsAfter(sequence: 7, limit: 100)
        XCTAssertEqual(result.sequence, 9)
        XCTAssertEqual(result.events.map(\.sequence), [8, 9])
        XCTAssertEqual(result.events[0].agentType, "agent_end")
        XCTAssertEqual(result.events[1].projectId, "p1")
        _ = try await client.eventsAfter(sequence: 9)
        let requests = rig.connection.receivedRequests
        XCTAssertEqual(requests[0].params, ["sequence": 7, "limit": 100])
        XCTAssertEqual(requests[1].params, ["sequence": 9])
    }

    func testListToolsUsesTheSessionRoute() async throws {
        let tools: JSONValue = ["tools": [["name": "read", "description": "Read a file", "parameters": [:]], ["description": "nameless"], ["name": "mcp_tmax_list"]]]
        let rig = try await rig(responder: script(["worker.call:tools.list": tools]))
        let listed = try await rig.client.listTools(sessionId: "s1", projectId: "p1")
        XCTAssertEqual(listed.map(\.name), ["read", "mcp_tmax_list"])
        XCTAssertEqual(listed.map(\.description), ["Read a file", ""])
        XCTAssertEqual(rig.connection.receivedRequests[0].params, ["projectId": "p1", "sessionId": "s1", "method": "tools.list", "arguments": ["sessionId": "s1"]])
    }

    func testWaitForToolsPollsUntilAPrefixedToolAppears() async throws {
        let polls = FakeCounter()
        let rig = try await rig(responder: { request in
            guard request.method == "worker.call", request.params["method"] == "tools.list" else { return nil }
            var tools: [JSONValue] = [["name": "read", "description": "Read files"], ["name": "mcp_other_tool"]]
            if polls.increment() >= 4 {
                tools.append(["name": "mcp_tmax_list_workouts", "description": "List workouts"])
                tools.append(["name": "mcp_tmax_create_page"])
            }
            return .result(["tools": .array(tools)])
        })
        let started = Date()
        let found = try await rig.client.waitForTools(sessionId: "s1", projectId: "p1", prefix: "mcp_tmax_", timeout: 5, pollInterval: 0.01)
        XCTAssertEqual(found.map(\.name), ["mcp_tmax_list_workouts", "mcp_tmax_create_page"])
        XCTAssertEqual(found.first?.description, "List workouts")
        XCTAssertEqual(polls.value, 4)
        XCTAssertLessThan(Date().timeIntervalSince(started), 4)
        let calls = rig.connection.receivedRequests
        XCTAssertEqual(calls.count, 4)
        XCTAssertEqual(calls[0].params, ["projectId": "p1", "sessionId": "s1", "method": "tools.list", "arguments": ["sessionId": "s1"]])
        XCTAssertTrue(calls[0].params["opId"].isNull)
    }

    func testWaitForToolsReturnsImmediatelyWhenTheToolIsAlreadyThere() async throws {
        let polls = FakeCounter()
        let rig = try await rig(responder: { request in
            polls.increment()
            return request.method == "worker.call" ? .result(["tools": [["name": "mcp_tmax_ready"]]]) : nil
        })
        let found = try await rig.client.waitForTools(sessionId: "s1", projectId: "p1", prefix: "mcp_tmax_")
        XCTAssertEqual(found.map(\.name), ["mcp_tmax_ready"])
        XCTAssertEqual(polls.value, 1)
    }

    func testWaitForToolsTimesOutWhenNothingMatches() async throws {
        let polls = FakeCounter()
        let rig = try await rig(responder: { request in
            guard request.method == "worker.call" else { return nil }
            polls.increment()
            return .result(["tools": [["name": "read"], ["name": "write"]]])
        })
        let client = rig.client
        let started = Date()
        let error = await failure { try await client.waitForTools(sessionId: "s1", projectId: "p1", prefix: "mcp_tmax_", timeout: 0.4, pollInterval: 0.05) }
        XCTAssertEqual(error, .timeout(operation: "the tools starting with mcp_tmax_", after: 0.4))
        XCTAssertGreaterThanOrEqual(Date().timeIntervalSince(started), 0.35)
        XCTAssertLessThan(Date().timeIntervalSince(started), 3)
        XCTAssertGreaterThanOrEqual(polls.value, 2)
        XCTAssertLessThanOrEqual(polls.value, 9)
    }

    func testWaitForToolsGivesUpWhenTheGatewayStopsAnswering() async throws {
        let rig = try await rig(timeout: 30)
        let client = rig.client
        let started = Date()
        let error = await failure { try await client.waitForTools(sessionId: "s1", projectId: "p1", prefix: "mcp_", timeout: 0.3) }
        XCTAssertEqual(error, .timeout(operation: "the tools starting with mcp_", after: 0.3))
        XCTAssertLessThan(Date().timeIntervalSince(started), 3)
    }

    func testWaitForToolsSurfacesGatewayErrorsWithoutPolling() async throws {
        let polls = FakeCounter()
        let rig = try await rig(responder: { _ in
            polls.increment()
            return .failure(code: "not_found", message: "session does not belong to project")
        })
        let client = rig.client
        let error = await failure { try await client.waitForTools(sessionId: "s1", projectId: "p1", prefix: "mcp_", timeout: 5, pollInterval: 0.01) }
        XCTAssertEqual(error, .remote(code: "not_found", message: "session does not belong to project", details: nil))
        XCTAssertEqual(polls.value, 1)
    }

    func testWaitForToolsCanBeCancelled() async throws {
        let polls = FakeCounter()
        let rig = try await rig(responder: { request in
            guard request.method == "worker.call" else { return nil }
            polls.increment()
            return .result(["tools": []])
        })
        let client = rig.client
        let task = Task { try await client.waitForTools(sessionId: "s1", projectId: "p1", prefix: "mcp_", timeout: 30, pollInterval: 0.02) }
        let deadline = Date().addingTimeInterval(5)
        while polls.value < 2 && Date() < deadline { try await Task.sleep(nanoseconds: 5_000_000) }
        XCTAssertGreaterThanOrEqual(polls.value, 2)
        task.cancel()
        let error = await outcome(of: task)
        XCTAssertEqual(error, .cancelled)
    }

    func testCreateSessionUsesTheCallersIdentifier() async throws {
        let rig = try await rig(responder: { request in
            switch request.method {
            case "sessions.save": return .result(request.params["session"])
            case "sessions.claim": return .result(leaseJSON)
            default: return nil
            }
        })
        let id = try await rig.client.createSession(projectId: "p1", title: "Coach", sessionId: "chat-42")
        XCTAssertEqual(id, "chat-42")
        XCTAssertEqual(rig.connection.receivedRequests[0].params["session"]["id"], "chat-42")
        XCTAssertEqual(rig.connection.receivedRequests[1].params["sessionId"], "chat-42")
    }

    func testEnsureSessionResumesAKnownSessionWithoutSavingAgain() async throws {
        let rig = try await rig(responder: script(["sessions.get": transcriptJSON, "sessions.claim": leaseJSON]))
        try await rig.client.ensureSession(sessionId: "s-1", projectId: "p1", title: "Coach")
        XCTAssertEqual(rig.connection.receivedRequests.map(\.method), ["sessions.get", "sessions.claim"])
    }

    func testEnsureSessionCreatesAnUnknownSessionWithTheSameIdentifier() async throws {
        let rig = try await rig(responder: { request in
            switch request.method {
            case "sessions.get": return .failure(code: "not_found", message: "session not found")
            case "sessions.save": return .result(request.params["session"])
            case "sessions.claim": return .result(leaseJSON)
            default: return nil
            }
        })
        try await rig.client.ensureSession(sessionId: "chat-7", projectId: "p1", title: "Coach")
        let requests = rig.connection.receivedRequests
        XCTAssertEqual(requests.map(\.method), ["sessions.get", "sessions.save", "sessions.claim"])
        XCTAssertEqual(requests[1].params["session"]["id"], "chat-7")
    }

    func testEnsureSessionDoesNotTurnOtherFailuresIntoANewSession() async throws {
        let rig = try await rig(responder: { request in
            if request.method == "sessions.get" { return .failure(code: "unavailable", message: "gateway starting") }
            return nil
        })
        let client = rig.client
        let error = await failure { try await client.ensureSession(sessionId: "chat-7", projectId: "p1", title: "Coach") }
        XCTAssertEqual(error, .remote(code: "unavailable", message: "gateway starting", details: nil))
        XCTAssertEqual(rig.connection.receivedRequests.map(\.method), ["sessions.get"])
    }
}
#endif
