import Foundation
@testable import TimeMasterCore

struct FakeGatewayFailure: Error, CustomStringConvertible {
    let description: String
}

struct FakeRequest: Sendable {
    let id: String
    let method: String
    let params: JSONValue
    let raw: JSONValue
}

enum FakeReply {
    case result(JSONValue)
    case failure(code: String, message: String, details: JSONValue? = nil)
}

final class FakeCounter: @unchecked Sendable {
    private let lock = NSLock()
    private var stored = 0

    var value: Int { lock.withLock { stored } }

    @discardableResult
    func increment() -> Int {
        lock.withLock {
            stored += 1
            return stored
        }
    }
}

final class FakeBox<Value: Sendable>: @unchecked Sendable {
    private let lock = NSLock()
    private var stored: Value

    init(_ value: Value) {
        stored = value
    }

    var value: Value {
        get { lock.withLock { stored } }
        set { lock.withLock { stored = newValue } }
    }

    func update(_ change: (inout Value) -> Void) {
        lock.withLock { change(&stored) }
    }
}

private enum Race<Value: Sendable>: Sendable {
    case finished(Value)
    case expired
    case timerStopped
}

func withTimeout<Value: Sendable>(_ seconds: TimeInterval, _ what: String, _ body: @escaping @Sendable () async throws -> Value) async throws -> Value {
    try await withThrowingTaskGroup(of: Race<Value>.self) { group in
        group.addTask { .finished(try await body()) }
        group.addTask {
            do { try await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000)) } catch { return .timerStopped }
            return .expired
        }
        defer { group.cancelAll() }
        while let result = try await group.next() {
            switch result {
            case .finished(let value): return value
            case .expired: throw FakeGatewayFailure(description: "Timed out after \(seconds) s waiting for \(what)")
            case .timerStopped: continue
            }
        }
        throw FakeGatewayFailure(description: "No result for \(what)")
    }
}

final class EventReader: @unchecked Sendable {
    private var iterator: AsyncStream<EverAgentEvent>.AsyncIterator

    init(_ stream: AsyncStream<EverAgentEvent>) {
        iterator = stream.makeAsyncIterator()
    }

    func next(timeout: TimeInterval = 3) async throws -> EverAgentEvent? {
        try await withTimeout(timeout, "an event") { await self.iterator.next() }
    }

    func expectEvent(timeout: TimeInterval = 3) async throws -> EverAgentEvent {
        guard let event = try await next(timeout: timeout) else { throw FakeGatewayFailure(description: "The event stream finished early") }
        return event
    }
}
