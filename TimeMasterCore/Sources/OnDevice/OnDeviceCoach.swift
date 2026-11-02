#if canImport(FoundationModels)
import Foundation
import FoundationModels

@available(iOS 26.0, macOS 26.0, *)
public final class OnDeviceCoach: Sendable {
    public struct Request: Sendable {
        public var message: String
        public var history: [OnDeviceMessage]
        public var persona: String
        public var today: Date

        public init(message: String, history: [OnDeviceMessage] = [], persona: String = "", today: Date = Date()) {
            self.message = message
            self.history = history
            self.persona = persona
            self.today = today
        }
    }

    static let reservedTokens = 1_900
    static let outputLimit = 1_400
    static let maximumCalls = 6

    private let execute: @Sendable (String, String) async -> String

    public init(execute: @escaping @Sendable (String, String) async -> String) {
        self.execute = execute
    }

    public static func availability() -> OnDeviceAvailability {
        let model = SystemLanguageModel.default
        switch model.availability {
        case .available:
            return model.supportsLocale() ? .ready : .unavailable("The on-device helper does not support this language yet.")
        case .unavailable(let reason):
            switch reason {
            case .deviceNotEligible:
                return .unavailable("This device does not support Apple Intelligence.")
            case .appleIntelligenceNotEnabled:
                return .unavailable("Turn on Apple Intelligence in Settings to use the on-device helper.")
            case .modelNotReady:
                return .unavailable("The on-device model is still getting ready. Try again in a few minutes.")
            @unknown default:
                return .unavailable("The on-device model is not available.")
            }
        }
    }

    public func run(_ request: Request) -> AsyncStream<CoachProgress> {
        AsyncStream { continuation in
            let task = Task {
                let tracker = OnDeviceTracker(emit: { continuation.yield($0) })
                await respond(to: request, tracker: tracker, attempt: 1)
                continuation.finish()
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    private func respond(to request: Request, tracker: OnDeviceTracker, attempt: Int) async {
        tracker.reset()
        do {
            let names = OnDeviceToolRouting.tools(for: request.message).prefix(attempt == 1 ? OnDeviceToolRouting.maximumTools : 2)
            var tools = try names.compactMap { name -> OnDeviceTool? in
                guard OnDeviceToolRouting.toolNames.contains(name), let tool = AgentToolRegistry.tool(named: name), tool.coach else { return nil }
                return try OnDeviceSchema.tool(for: tool, parameters: OnDeviceToolRouting.parameters[name] ?? []) { [execute] name, json in
                    try await tracker.run(name: name, json: json, execute: execute)
                }
            }
            let instructions = Self.instructions(for: request)
            tools = await Self.fitting(tools, instructions: instructions)
            let session = LanguageModelSession(model: .default, tools: tools, instructions: instructions)
            let digest = attempt == 1 ? OnDeviceHistory.digest(request.history) : ""
            let prompt = digest.isEmpty ? request.message : digest + "\n\nNew message from the user: " + request.message
            let stream = session.streamResponse(
                to: prompt,
                options: GenerationOptions(temperature: 0.3, maximumResponseTokens: 600)
            )
            for try await snapshot in stream {
                try Task.checkCancellation()
                tracker.update(text: snapshot.content)
            }
            tracker.finish()
        } catch is CancellationError {
            tracker.finish()
        } catch let error as LanguageModelSession.GenerationError {
            if case .exceededContextWindowSize = error, attempt == 1 {
                await respond(to: request, tracker: tracker, attempt: 2)
            } else {
                tracker.fail(Self.message(for: error))
            }
        } catch let error as LanguageModelSession.ToolCallError {
            if error.underlyingError is OnDeviceLimit {
                await conclude(request, tracker: tracker)
            } else {
                tracker.fail(error.underlyingError.localizedDescription)
            }
        } catch {
            tracker.fail(Self.message(for: error))
        }
    }

    private func conclude(_ request: Request, tracker: OnDeviceTracker) async {
        do {
            let instructions = Instructions("Answer the user in at most three short sentences using only the notes below. If a lookup failed, say plainly what could not be found. You cannot create, change or delete anything on this device.")
            let session = LanguageModelSession(model: .default, instructions: instructions)
            let prompt = "User asked: \(request.message)\n\nNotes from the app:\n\(tracker.notes())"
            let stream = session.streamResponse(to: prompt, options: GenerationOptions(temperature: 0.2, maximumResponseTokens: 300))
            for try await snapshot in stream {
                try Task.checkCancellation()
                tracker.update(text: snapshot.content)
            }
            tracker.finish()
        } catch is CancellationError {
            tracker.finish()
        } catch {
            tracker.fail(tracker.stuckMessage())
        }
    }

    static func instructions(for request: Request) -> Instructions {
        let day = request.today.formatted(date: .complete, time: .omitted)
        var text = "You are the coach inside Tmax, a workout app. Today is \(day). Answer in at most four short sentences. For questions about the user's exercises, workouts or history, call a tool first and answer from what it returns; never invent names or ids. You can read the library and add notes to exercise pages; you cannot create, change, move or delete anything on this device, so say so if asked."
        let persona = OnDeviceHistory.clipped(request.persona, to: 360)
        if !persona.isEmpty { text += " " + persona }
        return Instructions(text)
    }

    static func fitting(_ tools: [OnDeviceTool], instructions: Instructions) async -> [OnDeviceTool] {
        guard #available(iOS 26.4, macOS 26.4, *) else { return tools }
        let model = SystemLanguageModel.default
        var kept = tools
        while kept.count > 1 {
            let used = ((try? await model.tokenCount(for: instructions)) ?? 0) + ((try? await model.tokenCount(for: kept)) ?? 0)
            if used + reservedTokens <= model.contextSize { break }
            kept.removeLast()
        }
        return kept
    }

    static func message(for error: Error) -> String {
        if let generation = error as? LanguageModelSession.GenerationError {
            switch generation {
            case .exceededContextWindowSize:
                return "This chat got too long for the on-device helper. Start a new chat and ask again."
            case .guardrailViolation, .refusal:
                return "The on-device model can't help with that request."
            case .unsupportedLanguageOrLocale:
                return "The on-device helper does not support this language yet."
            case .assetsUnavailable:
                return "The on-device model is not ready yet. Try again in a moment."
            case .rateLimited, .concurrentRequests:
                return "The on-device model is busy. Try again in a moment."
            default:
                return generation.errorDescription ?? generation.localizedDescription
            }
        }
        return error.localizedDescription
    }
}

enum OnDeviceLimit: Error {
    case tooManyCalls
    case repeatedCall
}

@available(iOS 26.0, macOS 26.0, *)
final class OnDeviceTracker: @unchecked Sendable {
    private let lock = NSLock()
    private let emit: @Sendable (CoachProgress) -> Void
    private var progress = CoachProgress()
    private var counter = 0
    private var repeats = 0
    private var earlier: [String: String] = [:]
    private var log: [String] = []
    private var lastError: String?

    init(emit: @escaping @Sendable (CoachProgress) -> Void) {
        self.emit = emit
    }

    func reset() {
        lock.lock()
        progress = CoachProgress()
        counter = 0
        repeats = 0
        earlier = [:]
        log = []
        lastError = nil
        lock.unlock()
        emit(CoachProgress())
    }

    func update(text: String) {
        publish { $0.text = text }
    }

    func finish() {
        publish {
            $0.isFinished = true
            $0.statusTitle = nil
            for index in $0.activities.indices where $0.activities[index].status == .running {
                $0.activities[index].status = .done
            }
        }
    }

    func fail(_ message: String) {
        publish {
            $0.isFinished = true
            $0.failure = message
            $0.statusTitle = nil
            for index in $0.activities.indices where $0.activities[index].status == .running {
                $0.activities[index].status = .failed
            }
        }
    }

    func stuckMessage() -> String {
        lock.lock()
        defer { lock.unlock() }
        guard let lastError else { return "The on-device helper got stuck on this request." }
        return "The on-device helper could not finish this: " + lastError
    }

    func notes() -> String {
        lock.lock()
        defer { lock.unlock() }
        return log.isEmpty ? "No lookups were made." : log.suffix(5).joined(separator: "\n")
    }

    func run(name: String, json: String, execute: @Sendable (String, String) async -> String) async throws -> String {
        var arguments = (try? JSONSerialization.jsonObject(with: Data(json.utf8))) as? [String: Any] ?? [:]
        for (field, value) in OnDeviceToolRouting.defaults[name] ?? [:] where arguments[field] == nil {
            arguments[field] = value
        }
        let key = name + "|" + Self.canonical(arguments)
        let id: String
        switch admit(key) {
        case .stop:
            throw OnDeviceLimit.tooManyCalls
        case .repeated(let result, let exhausted):
            if exhausted { throw OnDeviceLimit.repeatedCall }
            return "You already made this exact call and got: \(result) Do not call it again; answer the user now."
        case .go(let assigned):
            id = assigned
        }
        let label = OnDeviceActivityLabel.make(tool: name, arguments: arguments)
        publish {
            $0.activities.append(CoachActivity(id: id, title: label.title, detail: label.detail, status: .running))
            $0.statusTitle = label.title
        }
        let output = await execute(name, Self.canonical(arguments))
        let failed = output.hasPrefix("TOOL ERROR") || output.hasPrefix("TOOL REJECTED")
        let shortened = Self.shortened(output)
        remember(name, key, shortened, failed: failed)
        publish {
            if let index = $0.activities.firstIndex(where: { $0.id == id }) {
                $0.activities[index].status = failed ? .failed : .done
            }
            $0.statusTitle = nil
        }
        return shortened
    }

    static func shortened(_ output: String) -> String {
        guard output.count > OnDeviceCoach.outputLimit else { return output }
        let kept = output.prefix(OnDeviceCoach.outputLimit)
        return kept + "\n[Cut off after \(OnDeviceCoach.outputLimit) characters; ask for less to see the rest.]"
    }

    static func canonical(_ arguments: [String: Any]) -> String {
        guard JSONSerialization.isValidJSONObject(arguments),
              let data = try? JSONSerialization.data(withJSONObject: arguments, options: [.sortedKeys]) else { return "" }
        return String(decoding: data, as: UTF8.self)
    }

    private enum Admission {
        case go(String)
        case stop
        case repeated(String, exhausted: Bool)
    }

    private func admit(_ key: String) -> Admission {
        lock.lock()
        defer { lock.unlock() }
        counter += 1
        if counter > OnDeviceCoach.maximumCalls { return .stop }
        if let result = earlier[key] {
            repeats += 1
            return .repeated(result, exhausted: repeats >= 2)
        }
        return .go("tool-\(counter)")
    }

    private func remember(_ name: String, _ key: String, _ output: String, failed: Bool) {
        lock.lock()
        earlier[key] = output
        log.append("- \(name): " + OnDeviceHistory.clipped(output, to: 320))
        if failed { lastError = output }
        lock.unlock()
    }

    private func publish(_ change: (inout CoachProgress) -> Void) {
        lock.lock()
        change(&progress)
        let snapshot = progress
        lock.unlock()
        emit(snapshot)
    }
}
#endif
