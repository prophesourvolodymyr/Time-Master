import XCTest
@testable import TimeMasterCore

private func remoteProfile(url: String) -> EverAgentRemoteProfile {
    EverAgentRemoteProfile(
        serverId: "srv-1",
        name: "Mac",
        url: url,
        certificateSHA256: String(repeating: "ab", count: 32),
        deviceId: "dev-1",
        keyTag: "device.srv-1.tag",
        development: true
    )
}

final class EverAgentRemoteClientTests: XCTestCase {
    private var clients: [EverAgentClient] = []

    override func tearDown() async throws {
        for client in clients { await client.close() }
        clients = []
    }

    private func connected(
        remote: Bool,
        timeout: TimeInterval = 3,
        responder: (@Sendable (FakeRequest) -> FakeReply?)? = nil
    ) async throws -> (client: EverAgentClient, link: MemoryLink) {
        let link = MemoryLink(responder: responder)
        let client = EverAgentClient(isRemote: remote, requestTimeout: timeout, requestLimitBytes: EverAgentClient.gatewayRequestLimitBytes) { link }
        clients.append(client)
        try await client.connect()
        return (client, link)
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

    private func sequences(_ reader: EventReader, count: Int, file: StaticString = #filePath, line: UInt = #line) async throws -> [Int] {
        var found: [Int] = []
        for _ in 0..<count { found.append(try await reader.expectEvent().sequence) }
        return found
    }

    private func subscribeRemotely(_ client: EverAgentClient, _ link: MemoryLink, sessionId: String? = nil, topics: [String]? = nil) async throws -> EventReader {
        let reader = EventReader(try await client.subscribe(sessionId: sessionId, topics: topics))
        XCTAssertFalse(link.receivedRequests.contains { $0.method == "events.subscribe" })
        return reader
    }

    func testClientsReportWhereTheyConnect() async {
        let remote = EverAgentClient(remote: remoteProfile(url: "https://192.168.1.20:8443"))
        XCTAssertTrue(remote.isRemote)
        XCTAssertEqual(remote.requestTimeout, EverAgentClient.defaultRequestTimeout)
        XCTAssertEqual(remote.requestLimitBytes, EverAgentClient.remoteRequestLimitBytes)
        XCTAssertEqual(EverAgentClient.remoteRequestLimitBytes, 16 * 1024 * 1024)
        XCTAssertLessThan(EverAgentClient.remoteRequestLimitBytes, EverAgentClient.gatewayRequestLimitBytes)
        let patient = EverAgentClient(remote: remoteProfile(url: "https://192.168.1.20:8443"), identity: MemoryIdentity(), requestTimeout: 12)
        XCTAssertEqual(patient.requestTimeout, 12)
        let connected = await remote.isConnected
        XCTAssertFalse(connected)
        #if os(macOS)
        let local = EverAgentClient(socketPath: "/tmp/tmax-ea-none.sock")
        XCTAssertFalse(local.isRemote)
        XCTAssertEqual(local.socketPath, "/tmp/tmax-ea-none.sock")
        XCTAssertFalse(EverAgentClient().isRemote)
        #endif
    }

    func testAnOversizedRemoteRequestIsRefusedWithoutDroppingTheLink() async throws {
        let link = MemoryLink()
        let client = EverAgentClient(isRemote: true, requestTimeout: 3, requestLimitBytes: EverAgentClient.remoteRequestLimitBytes) { link }
        clients.append(client)
        try await client.connect()
        let limit = EverAgentClient.remoteRequestLimitBytes
        let error = await failure { try await client.request("sessions.save", params: ["blob": .string(String(repeating: "x", count: limit))]) }
        guard case .requestTooLarge(let bytes, let reported)? = error else { return XCTFail("Wrong error: \(String(describing: error))") }
        XCTAssertEqual(reported, limit)
        XCTAssertGreaterThan(bytes, limit)
        XCTAssertTrue(link.receivedRequests.isEmpty)
        let isConnected = await client.isConnected
        XCTAssertTrue(isConnected)
        let fitting = Task { try await client.request("sessions.save", params: ["blob": .string(String(repeating: "x", count: limit - 200))]) }
        let request = try await link.nextRequest(timeout: 10)
        XCTAssertEqual(request.method, "sessions.save")
        XCTAssertEqual(request.params["blob"].text.utf8.count, limit - 200)
        link.respond(to: request, result: "saved")
        let saved = try await fitting.value
        XCTAssertEqual(saved, "saved")
    }

    func testRemoteSubscribeSendsNothingAndYieldsPushedEvents() async throws {
        let (client, link) = try await connected(remote: true)
        let events = try await subscribeRemotely(client, link, sessionId: "s1")
        let probe = Task { try await client.request("probe") }
        let request = try await link.nextRequest()
        XCTAssertEqual(request.method, "probe")
        link.respond(to: request, result: "ok")
        let answer = try await probe.value
        XCTAssertEqual(answer, "ok")
        XCTAssertEqual(link.receivedRequests.map(\.method), ["probe"])
        link.push(topic: "ui.request", sequence: 42, sessionId: "s1", projectId: "p1", data: ["requestId": "r1", "kind": "confirm", "title": "Allow?"])
        let event = try await events.expectEvent()
        XCTAssertEqual(event, EverAgentEvent(sequence: 42, topic: "ui.request", projectId: "p1", sessionId: "s1", data: ["requestId": "r1", "kind": "confirm", "title": "Allow?"]))
        XCTAssertEqual(event.uiRequest?.requestId, "r1")
    }

    func testRemoteEventsAreFilteredByTheRequestedSession() async throws {
        let (client, link) = try await connected(remote: true)
        let events = try await subscribeRemotely(client, link, sessionId: "s1")
        link.push(topic: "agent", sequence: 1, sessionId: "s1")
        link.push(topic: "agent", sequence: 2, sessionId: "other")
        link.push(topic: "session.updated", sequence: 3)
        link.push(topic: "agent", sequence: 4, sessionId: "S1")
        link.push(topic: "project.updated", sequence: 5, projectId: "p1")
        link.push(topic: "agent", sequence: 6, sessionId: "s1", projectId: "p1")
        let found = try await sequences(events, count: 2)
        XCTAssertEqual(found, [1, 6])
    }

    func testRemoteEventsAreFilteredByTheRequestedTopics() async throws {
        let (client, link) = try await connected(remote: true)
        let events = try await subscribeRemotely(client, link, topics: ["agent", "ui.request"])
        link.push(topic: "agent", sequence: 1, sessionId: "s1")
        link.push(topic: "session.updated", sequence: 2, sessionId: "s1")
        link.push(topic: "agent.error", sequence: 3, sessionId: "s1")
        link.push(topic: "ui.request", sequence: 4, sessionId: "s2")
        link.push(topic: "agent", sequence: 5)
        link.push(topic: "Agent", sequence: 6)
        link.push(topic: "ui.request.closed", sequence: 7)
        let found = try await sequences(events, count: 3)
        XCTAssertEqual(found, [1, 4, 5])
    }

    func testRemoteEventsCanBeFilteredByBothSessionAndTopic() async throws {
        let (client, link) = try await connected(remote: true)
        let events = try await subscribeRemotely(client, link, sessionId: "s1", topics: ["ui.request"])
        link.push(topic: "ui.request", sequence: 1, sessionId: "s2")
        link.push(topic: "agent", sequence: 2, sessionId: "s1")
        link.push(topic: "ui.request", sequence: 3)
        link.push(topic: "ui.request", sequence: 4, sessionId: "s1")
        let found = try await sequences(events, count: 1)
        XCTAssertEqual(found, [4])
    }

    func testAResyncAlwaysPassesTheRemoteFilter() async throws {
        let (client, link) = try await connected(remote: true)
        let events = try await subscribeRemotely(client, link, sessionId: "s1", topics: ["ui.request"])
        link.deliverLine(#"{"type":"event","sequence":0,"topic":"events.resync","data":{"reason":"backpressure"}}"#)
        link.push(topic: "agent", sequence: 9, sessionId: "s1")
        link.push(topic: EverAgentTopic.resync, sequence: 0, sessionId: "other", data: ["reason": "backpressure"])
        link.push(topic: "ui.request", sequence: 10, sessionId: "s1")
        let first = try await events.expectEvent()
        XCTAssertTrue(first.resync)
        XCTAssertEqual(first.data["reason"], "backpressure")
        XCTAssertNil(first.sessionId)
        let second = try await events.expectEvent()
        XCTAssertTrue(second.resync)
        let third = try await events.expectEvent()
        XCTAssertEqual(third.sequence, 10)
        XCTAssertFalse(third.resync)
    }

    func testWithoutFiltersARemoteSubscriptionSeesEverything() async throws {
        let (client, link) = try await connected(remote: true)
        let events = try await subscribeRemotely(client, link)
        link.push(topic: "agent", sequence: 1, sessionId: "s1")
        link.push(topic: "session.updated", sequence: 2)
        link.push(topic: "project.updated", sequence: 3, projectId: "p1")
        let found = try await sequences(events, count: 3)
        XCTAssertEqual(found, [1, 2, 3])
    }

    func testRemoteEventsPushedBeforeASubscriptionAreDropped() async throws {
        let (client, link) = try await connected(remote: true)
        link.push(topic: "agent", sequence: 1, sessionId: "s1")
        let probe = Task { try await client.request("probe") }
        let request = try await link.nextRequest()
        link.respond(to: request, result: 1)
        _ = try await probe.value
        let events = try await subscribeRemotely(client, link, sessionId: "s1")
        link.push(topic: "agent", sequence: 2, sessionId: "s1")
        let found = try await sequences(events, count: 1)
        XCTAssertEqual(found, [2])
    }

    func testANewerRemoteSubscriptionReplacesTheOlderOne() async throws {
        let (client, link) = try await connected(remote: true)
        let first = try await subscribeRemotely(client, link, sessionId: "a")
        link.push(topic: "agent", sequence: 1, sessionId: "a")
        let before = try await first.expectEvent()
        XCTAssertEqual(before.sequence, 1)
        let second = try await subscribeRemotely(client, link, sessionId: "b")
        let finished = try await first.next()
        XCTAssertNil(finished)
        link.push(topic: "agent", sequence: 2, sessionId: "a")
        link.push(topic: "agent", sequence: 3, sessionId: "b")
        let found = try await sequences(second, count: 1)
        XCTAssertEqual(found, [3])
        XCTAssertTrue(link.receivedRequests.isEmpty)
    }

    func testStoppingToIterateEndsARemoteSubscriptionWithoutDisturbingTheLink() async throws {
        let (client, link) = try await connected(remote: true)
        do {
            let events = try await subscribeRemotely(client, link)
            link.push(topic: "agent", sequence: 1)
            _ = try await events.expectEvent()
        }
        link.push(topic: "agent", sequence: 2)
        let task = Task { try await client.request("still") }
        let request = try await link.nextRequest()
        link.respond(to: request, result: "alive")
        let result = try await task.value
        XCTAssertEqual(result, "alive")
        let isConnected = await client.isConnected
        XCTAssertTrue(isConnected)
    }

    func testARemoteSubscriptionEndsWhenTheLinkDrops() async throws {
        let (client, link) = try await connected(remote: true)
        let events = try await subscribeRemotely(client, link, sessionId: "s1")
        let pending = Task { try await client.request("pending") }
        _ = try await link.nextRequest()
        link.drop()
        let error = await failure { try await pending.value }
        XCTAssertEqual(error, .connectionClosed)
        let finished = try await events.next()
        XCTAssertNil(finished)
        let isConnected = await client.isConnected
        XCTAssertFalse(isConnected)
        let again = await failure { try await client.subscribe(sessionId: "s1") }
        XCTAssertEqual(again, .connectionClosed)
        let request = await failure { try await client.request("late") }
        XCTAssertEqual(request, .connectionClosed)
    }

    func testClosingEndsARemoteSubscriptionAndShutsTheLinkDown() async throws {
        let (client, link) = try await connected(remote: true)
        let events = try await subscribeRemotely(client, link)
        await client.close()
        let finished = try await events.next()
        XCTAssertNil(finished)
        XCTAssertTrue(link.isShutDown)
        let isConnected = await client.isConnected
        XCTAssertFalse(isConnected)
    }

    func testFramesThatAreNeitherEventsNorResponsesAreIgnored() async throws {
        let (client, link) = try await connected(remote: true)
        let events = try await subscribeRemotely(client, link, sessionId: "s1")
        let junk = [
            "", "   ", "\t", "null", "true", "7", "\"text\"", "[1,2,3]", "{}",
            #"{"type":"challenge","nonce":"x","serverId":"srv-1"}"#,
            #"{"type":"authenticated","deviceId":"dev-1","serverId":"srv-1"}"#,
            #"{"type":"event"}"#,
            #"{"type":"event","sequence":1,"data":{}}"#,
            #"{"type":"weird","id":"x"}"#,
            #"{"id":5,"result":1}"#,
            #"{"topic":"agent","sequence":2,"sessionId":"s1","data":{}}"#,
            #"{"id":"tmax-9999","result":"nobody asked"}"#,
            #"{"id":"","error":{"code":"invalid_request","message":"nobody is waiting"}}"#,
        ]
        for line in junk { link.deliverLine(line) }
        link.push(topic: "agent", sequence: 6, sessionId: "s1")
        let marker = try await sequences(events, count: 1)
        XCTAssertEqual(marker, [6])
        let task = Task { try await client.request("after-noise") }
        let request = try await link.nextRequest()
        XCTAssertEqual(request.method, "after-noise")
        link.respond(to: request, result: "ok")
        let answer = try await task.value
        XCTAssertEqual(answer, "ok")
        link.push(topic: "agent", sequence: 7, sessionId: "s1")
        let found = try await sequences(events, count: 1)
        XCTAssertEqual(found, [7])
        let isConnected = await client.isConnected
        XCTAssertTrue(isConnected)
    }

    func testAMalformedFrameClosesTheRemoteLinkWithAProtocolError() async throws {
        let (client, link) = try await connected(remote: true)
        let events = try await subscribeRemotely(client, link)
        let task = Task { try await client.request("doomed") }
        _ = try await link.nextRequest()
        link.deliverLine("this is not json")
        let error = await failure { try await task.value }
        guard case .protocol? = error else { return XCTFail("Wrong error: \(String(describing: error))") }
        let finished = try await events.next()
        XCTAssertNil(finished)
        let isConnected = await client.isConnected
        XCTAssertFalse(isConnected)
    }

    func testARemoteLinkAnswersRequestsLikeALocalOne() async throws {
        let (client, link) = try await connected(remote: true, responder: { request in
            switch request.method {
            case "server.info":
                .result(["serverId": "srv-1", "name": "Studio Mac", "platform": "macos", "protocolVersion": 1, "capabilities": ["containers", "projects", "sessions", "events.after", "worker"]])
            case "projects.attach":
                .failure(code: "not_found", message: "unknown RPC method")
            default:
                nil
            }
        })
        let info = try await client.serverInfo()
        XCTAssertEqual(info.name, "Studio Mac")
        XCTAssertFalse(info.supportsEventSubscription)
        XCTAssertTrue(client.isRemote)
        let attach = await failure { try await client.attachProject(root: "/Users/me/Tmax") }
        XCTAssertEqual(attach, .remote(code: "not_found", message: "unknown RPC method", details: nil))
        XCTAssertEqual(link.receivedRequests.map(\.method), ["server.info", "projects.attach"])
    }

    func testALocalLinkStillAsksTheGatewayToFilterAndPassesEverythingThrough() async throws {
        let (client, link) = try await connected(remote: false)
        let task = Task { try await client.subscribe(sessionId: "s9", topics: ["agent", "ui.request"]) }
        let request = try await link.nextRequest()
        XCTAssertEqual(request.method, "events.subscribe")
        XCTAssertEqual(request.params, ["sessionId": "s9", "topics": ["agent", "ui.request"]])
        link.respond(to: request, result: ["subscribed": true, "sequence": 41])
        let events = EventReader(try await task.value)
        link.push(topic: "agent", sequence: 1, sessionId: "other")
        link.push(topic: "session.updated", sequence: 2)
        link.push(topic: "agent", sequence: 3, sessionId: "s9")
        let found = try await sequences(events, count: 3)
        XCTAssertEqual(found, [1, 2, 3])
        let unfiltered = Task { try await client.subscribe() }
        let second = try await link.nextRequest()
        XCTAssertEqual(second.params, [:])
        link.respond(to: second, result: ["subscribed": true, "sequence": 43])
        _ = try await unfiltered.value
        let finished = try await events.next()
        XCTAssertNil(finished)
    }

    func testALocalLinkStillMapsAnUnknownSubscribeMethodToAnOldGateway() async throws {
        let (client, _) = try await connected(remote: false, responder: { _ in .failure(code: "not_found", message: "unknown RPC method") })
        let error = await failure { try await client.subscribe(sessionId: "s1") }
        XCTAssertEqual(error, .gatewayTooOld)
        let other = await failure { try await client.getSession(sessionId: "missing") }
        XCTAssertEqual(other, .remote(code: "not_found", message: "unknown RPC method", details: nil))
    }

    func testALocalLinkStillRequiresTheSubscriptionToBeAcknowledged() async throws {
        let (client, _) = try await connected(remote: false, responder: { _ in .result([:]) })
        let error = await failure { try await client.subscribe() }
        guard case .protocol? = error else { return XCTFail("Wrong error: \(String(describing: error))") }
        let isConnected = await client.isConnected
        XCTAssertTrue(isConnected)
    }

    func testAConcurrentConnectKeepsOneLinkAndShutsTheOtherDown() async throws {
        let gate = OpeningGate()
        let opened = FakeBox<[MemoryLink]>([])
        let client = EverAgentClient(isRemote: true, requestTimeout: 3, requestLimitBytes: 1_000_000) {
            await gate.pass()
            let link = MemoryLink()
            opened.update { $0.append(link) }
            return link
        }
        clients.append(client)
        let first = Task { try await client.connect() }
        let second = Task { try await client.connect() }
        let deadline = Date().addingTimeInterval(3)
        while await gate.arrivals < 2 && Date() < deadline { try await Task.sleep(nanoseconds: 2_000_000) }
        await gate.open()
        try await first.value
        try await second.value
        let links = opened.value
        XCTAssertEqual(links.count, 2)
        XCTAssertEqual(links.filter(\.isShutDown).count, 1)
        let isConnected = await client.isConnected
        XCTAssertTrue(isConnected)
        let live = try XCTUnwrap(links.first { !$0.isShutDown })
        let task = Task { try await client.request("alive") }
        let request = try await live.nextRequest()
        live.respond(to: request, result: "yes")
        let answer = try await task.value
        XCTAssertEqual(answer, "yes")
    }

    func testClosingWhileConnectingAbandonsTheNewLink() async throws {
        let gate = OpeningGate()
        let link = MemoryLink()
        let client = EverAgentClient(isRemote: true, requestTimeout: 3, requestLimitBytes: 1_000_000) {
            await gate.pass()
            return link
        }
        clients.append(client)
        let connecting = Task { try await client.connect() }
        let deadline = Date().addingTimeInterval(3)
        while await gate.arrivals < 1 && Date() < deadline { try await Task.sleep(nanoseconds: 2_000_000) }
        await client.close()
        await gate.open()
        let error = await failure { try await connecting.value }
        XCTAssertEqual(error, .connectionClosed)
        XCTAssertTrue(link.isShutDown)
        let isConnected = await client.isConnected
        XCTAssertFalse(isConnected)
    }

    func testAFailedConnectLeavesTheClientFreeToTryAgain() async throws {
        let link = MemoryLink()
        let attempts = FakeCounter()
        let client = EverAgentClient(isRemote: true, requestTimeout: 3, requestLimitBytes: 1_000_000) {
            if attempts.increment() == 1 { throw EverAgentError.unauthorizedDevice }
            return link
        }
        clients.append(client)
        let error = await failure { try await client.connect() }
        XCTAssertEqual(error, .unauthorizedDevice)
        var isConnected = await client.isConnected
        XCTAssertFalse(isConnected)
        let request = await failure { try await client.request("early") }
        XCTAssertEqual(request, .connectionClosed)
        try await client.connect()
        isConnected = await client.isConnected
        XCTAssertTrue(isConnected)
        XCTAssertEqual(attempts.value, 2)
    }

    func testConnectingTwiceOpensOneLinkAndAClosedLinkCanBeReplaced() async throws {
        let opened = FakeBox<[MemoryLink]>([])
        let client = EverAgentClient(isRemote: true, requestTimeout: 3, requestLimitBytes: 1_000_000) {
            let link = MemoryLink()
            opened.update { $0.append(link) }
            return link
        }
        clients.append(client)
        try await client.connect()
        try await client.connect()
        XCTAssertEqual(opened.value.count, 1)
        opened.value[0].drop()
        let deadline = Date().addingTimeInterval(3)
        while await client.isConnected && Date() < deadline { try await Task.sleep(nanoseconds: 2_000_000) }
        var isConnected = await client.isConnected
        XCTAssertFalse(isConnected)
        try await client.connect()
        XCTAssertEqual(opened.value.count, 2)
        isConnected = await client.isConnected
        XCTAssertTrue(isConnected)
        await client.close()
        await client.close()
        XCTAssertTrue(opened.value[1].isShutDown)
    }

    func testDroppingTheClientShutsTheLinkDown() async throws {
        let link = MemoryLink()
        var client: EverAgentClient? = EverAgentClient(isRemote: true, requestTimeout: 3, requestLimitBytes: 1_000_000) { link }
        try await client?.connect()
        XCTAssertFalse(link.isShutDown)
        client = nil
        let deadline = Date().addingTimeInterval(3)
        while !link.isShutDown && Date() < deadline { try await Task.sleep(nanoseconds: 2_000_000) }
        XCTAssertTrue(link.isShutDown)
    }

    func testAnAddressThatIsNotHTTPSNeverReachesTheNetwork() async {
        let client = EverAgentClient(remote: remoteProfile(url: "http://127.0.0.1:1"), identity: MemoryIdentity())
        clients.append(client)
        let error = await failure { try await client.connect() }
        XCTAssertEqual(error, .gatewayNotRunning(path: "http://127.0.0.1:1"))
        let isConnected = await client.isConnected
        XCTAssertFalse(isConnected)
    }

    func testAnUnreachableGatewayIsReportedAsNotRunning() async {
        let address = "https://127.0.0.1:\(closedLoopbackPort())"
        let client = EverAgentClient(remote: remoteProfile(url: address), identity: MemoryIdentity())
        clients.append(client)
        let started = Date()
        let error = await failure { try await client.connect() }
        XCTAssertEqual(error, .gatewayNotRunning(path: address))
        XCTAssertLessThan(Date().timeIntervalSince(started), 10)
        let isConnected = await client.isConnected
        XCTAssertFalse(isConnected)
        let request = await failure { try await client.request("server.info") }
        XCTAssertEqual(request, .connectionClosed)
    }

    func testCancellingAConnectStopsItWithoutALink() async throws {
        let address = "https://127.0.0.1:\(closedLoopbackPort())"
        let client = EverAgentClient(remote: remoteProfile(url: address), identity: MemoryIdentity())
        clients.append(client)
        let task = Task { try await client.connect() }
        task.cancel()
        let error = await failure { try await task.value }
        XCTAssertTrue(error == .cancelled || error == .gatewayNotRunning(path: address), "\(String(describing: error))")
        let isConnected = await client.isConnected
        XCTAssertFalse(isConnected)
    }
}
