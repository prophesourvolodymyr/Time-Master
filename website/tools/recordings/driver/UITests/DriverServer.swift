import XCTest

struct DriverError: Error, CustomStringConvertible {
    let description: String
}

/// Executes JSON commands dropped into `<root>/inbox` and answers in `<root>/outbox`.
@MainActor
final class DriverServer {
    private let inbox: URL
    private let outbox: URL
    private let readyFile: URL
    private let app: XCUIApplication
    private let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
    private let fileManager = FileManager.default
    private var serving = true

    init(root: URL, app: XCUIApplication) {
        inbox = root.appendingPathComponent("inbox", isDirectory: true)
        outbox = root.appendingPathComponent("outbox", isDirectory: true)
        readyFile = root.appendingPathComponent("ready")
        self.app = app
    }

    func run() throws {
        for directory in [inbox, outbox] {
            try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        }
        try Data("\(ProcessInfo.processInfo.processIdentifier)".utf8).write(to: readyFile)
        defer { try? fileManager.removeItem(at: readyFile) }
        while serving {
            let names = pendingCommands()
            if names.isEmpty {
                spin(0.02)
                continue
            }
            for name in names where serving {
                handle(name)
            }
        }
    }

    private func pendingCommands() -> [String] {
        let names = (try? fileManager.contentsOfDirectory(atPath: inbox.path)) ?? []
        return names.filter { $0.hasSuffix(".json") && !$0.hasPrefix(".") }.sorted()
    }

    private func handle(_ name: String) {
        let source = inbox.appendingPathComponent(name)
        let started = Date().timeIntervalSince1970
        var response: [String: Any]
        do {
            let data = try Data(contentsOf: source)
            try? fileManager.removeItem(at: source)
            guard let command = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                throw DriverError(description: "Command is not a JSON object")
            }
            response = ["ok": true, "value": try execute(command) ?? NSNull()]
        } catch {
            try? fileManager.removeItem(at: source)
            response = ["ok": false, "error": String(describing: error)]
        }
        response["started"] = started
        response["finished"] = Date().timeIntervalSince1970
        let temporary = outbox.appendingPathComponent(".\(name)")
        let data = (try? JSONSerialization.data(withJSONObject: response))
            ?? Data(#"{"ok":false,"error":"Response is not serializable"}"#.utf8)
        try? data.write(to: temporary)
        try? fileManager.moveItem(at: temporary, to: outbox.appendingPathComponent(name))
    }

    private func execute(_ command: [String: Any]) throws -> Any? {
        let op = command["op"] as? String ?? ""
        switch op {
        case "ping":
            return "pong"
        case "launch":
            app.launchArguments = command["arguments"] as? [String] ?? []
            app.launchEnvironment = command["environment"] as? [String: String] ?? [:]
            app.launch()
            return nil
        case "activate":
            app.activate()
            return nil
        case "terminate":
            app.terminate()
            return nil
        case "state":
            return app.state.rawValue
        case "tap":
            try coordinate(command).tap()
            return nil
        case "doubleTap":
            try coordinate(command).doubleTap()
            return nil
        case "press":
            try coordinate(command).press(forDuration: number(command["duration"]) ?? 0.8)
            return nil
        case "drag":
            guard let destination = command["to"] as? [String: Any] else {
                throw DriverError(description: "drag needs a `to` target")
            }
            try coordinate(command).press(
                forDuration: number(command["duration"]) ?? 0.05,
                thenDragTo: try coordinate(destination),
                withVelocity: XCUIGestureVelocity(rawValue: CGFloat(number(command["velocity"]) ?? 900)),
                thenHoldForDuration: number(command["hold"]) ?? 0
            )
            return nil
        case "swipe":
            try swipe(command)
            return nil
        case "type":
            try type(command)
            return nil
        case "wait":
            let gone = command["gone"] as? Bool == true
            let timeout = number(command["timeout"]) ?? 10
            let match = try poll(command, until: gone ? .absent : .present, timeout: timeout)
            return match.map { frame($0.frame) }
        case "exists":
            return try element(command).exists
        case "frame":
            return try poll(command, until: .present, timeout: number(command["timeout"]) ?? 5).map { frame($0.frame) }
        case "query":
            return try query(command)
        case "dump":
            return command["app"] as? String == "springboard" ? springboard.debugDescription : app.debugDescription
        case "screenshot":
            guard let path = command["path"] as? String else {
                throw DriverError(description: "screenshot needs a path")
            }
            try XCUIScreen.main.screenshot().pngRepresentation.write(to: URL(fileURLWithPath: path))
            return path
        case "quiescence":
            Quiescence.install()
            Quiescence.enabled = command["enabled"] as? Bool ?? true
            return Quiescence.enabled
        case "sleep":
            spin(number(command["seconds"]) ?? 0)
            return nil
        case "script":
            return try script(command)
        case "stop":
            serving = false
            return nil
        default:
            throw DriverError(description: "Unknown op `\(op)`")
        }
    }

    private func script(_ command: [String: Any]) throws -> [[String: Any]] {
        guard let steps = command["steps"] as? [[String: Any]] else {
            throw DriverError(description: "script needs `steps`")
        }
        let origin = Date()
        var timings: [[String: Any]] = []
        for (index, step) in steps.enumerated() {
            if let at = number(step["at"]) {
                spin(origin.addingTimeInterval(at).timeIntervalSinceNow)
            }
            if let before = number(step["before"]) {
                spin(before)
            }
            let started = Date().timeIntervalSince1970
            do {
                _ = try execute(step)
            } catch {
                throw DriverError(description: "Step \(index) `\(step["op"] as? String ?? "")` failed: \(error)")
            }
            timings.append(["index": index, "op": step["op"] as? String ?? "", "started": started, "finished": Date().timeIntervalSince1970])
            if let after = number(step["after"]) {
                spin(after)
            }
        }
        return timings
    }

    private func swipe(_ command: [String: Any]) throws {
        let target: XCUIElement = hasElementSpec(command) ? try element(command) : app
        let velocity = number(command["velocity"]).map { XCUIGestureVelocity(rawValue: CGFloat($0)) } ?? .default
        switch command["direction"] as? String {
        case "up": target.swipeUp(velocity: velocity)
        case "down": target.swipeDown(velocity: velocity)
        case "left": target.swipeLeft(velocity: velocity)
        case "right": target.swipeRight(velocity: velocity)
        default: throw DriverError(description: "swipe needs direction up, down, left or right")
        }
    }

    private func type(_ command: [String: Any]) throws {
        let text = command["text"] as? String ?? ""
        let delay = number(command["delay"]) ?? 0
        let target: XCUIElement = hasElementSpec(command) ? try element(command) : app
        if delay <= 0 {
            target.typeText(text)
            return
        }
        for character in text {
            target.typeText(String(character))
            spin(delay)
        }
    }

    private struct Match {
        let type: XCUIElement.ElementType
        let id: String
        let label: String
        let value: String
        let frame: CGRect
    }

    private func query(_ command: [String: Any]) throws -> [[String: Any]] {
        try matches(command, limit: command["limit"] as? Int ?? 60).map { match in
            ["type": match.type.rawValue, "id": match.id, "label": match.label, "value": match.value, "frame": frame(match.frame)]
        }
    }

    /// Matches against one accessibility snapshot: fast, and a screen that changes mid-query cannot fail the test.
    private func matches(_ spec: [String: Any], limit: Int) throws -> [Match] {
        let root = spec["app"] as? String == "springboard" ? springboard : app
        let type = elementType(spec["type"] as? String)
        let predicates = try specPredicates(spec)
        let predicate = predicates.isEmpty ? nil : NSCompoundPredicate(andPredicateWithSubpredicates: predicates)
        var found: [Match] = []
        func visit(_ node: XCUIElementSnapshot) {
            guard found.count < limit else { return }
            let value = (node.value as? CustomStringConvertible)?.description ?? ""
            let fields: [String: Any] = ["identifier": node.identifier, "label": node.label, "value": value]
            if (type == .any || node.elementType == type) && (predicate?.evaluate(with: fields) ?? true) {
                found.append(Match(type: node.elementType, id: node.identifier, label: node.label, value: value, frame: node.frame))
            }
            node.children.forEach(visit)
        }
        visit(try root.snapshot())
        return found
    }

    private enum Presence { case present, absent }

    /// Polls snapshots until the spec's match (at `index`) is present or absent; returns the present match.
    private func poll(_ spec: [String: Any], until presence: Presence, timeout: TimeInterval) throws -> Match? {
        let index = spec["index"] as? Int ?? 0
        let deadline = Date().addingTimeInterval(timeout)
        while true {
            let found = try matches(spec, limit: index + 1)
            let match = found.count > index ? found[index] : nil
            if (match != nil) == (presence == .present) { return match }
            if Date() >= deadline {
                throw DriverError(description: "\(presence == .present ? "Not found" : "Still present") after \(timeout)s: \(describe(spec))")
            }
            spin(0.1)
        }
    }

    /// Screen point for a spec: a literal `point`, or the matched element's frame at `anchor` (default centre)
    /// plus `offset`. Elements resolve through snapshots (about 0.2 s) rather than XCUIElement queries (about 1 s),
    /// so taps land at a human pace.
    private func coordinate(_ spec: [String: Any]) throws -> XCUICoordinate {
        let origin = app.coordinate(withNormalizedOffset: .zero)
        if let point = spec["point"] as? [Any], point.count == 2, let x = number(point[0]), let y = number(point[1]) {
            return origin.withOffset(CGVector(dx: x, dy: y))
        }
        guard let rect = try poll(spec, until: .present, timeout: number(spec["timeout"]) ?? 10)?.frame else {
            throw DriverError(description: "Not found: \(describe(spec))")
        }
        let anchor = spec["anchor"] as? [Any]
        let offset = spec["offset"] as? [Any]
        return origin.withOffset(CGVector(
            dx: rect.minX + rect.width * (anchor.flatMap { number($0.first) } ?? 0.5) + (offset.flatMap { number($0.first) } ?? 0),
            dy: rect.minY + rect.height * (anchor.flatMap { number($0.last) } ?? 0.5) + (offset.flatMap { number($0.last) } ?? 0)
        ))
    }

    private func element(_ spec: [String: Any]) throws -> XCUIElement {
        let query = try baseQuery(spec)
        let index = spec["index"] as? Int ?? 0
        return index == 0 ? query.firstMatch : query.element(boundBy: index)
    }

    private func baseQuery(_ spec: [String: Any]) throws -> XCUIElementQuery {
        let root = spec["app"] as? String == "springboard" ? springboard : app
        let query = root.descendants(matching: elementType(spec["type"] as? String))
        let predicates = try specPredicates(spec)
        return predicates.isEmpty ? query : query.matching(NSCompoundPredicate(andPredicateWithSubpredicates: predicates))
    }

    private func specPredicates(_ spec: [String: Any]) throws -> [NSPredicate] {
        var predicates: [NSPredicate] = []
        if let id = spec["id"] as? String { predicates.append(NSPredicate(format: "identifier == %@", id)) }
        if let prefix = spec["idPrefix"] as? String { predicates.append(NSPredicate(format: "identifier BEGINSWITH %@", prefix)) }
        if let label = spec["label"] as? String { predicates.append(NSPredicate(format: "label == %@", label)) }
        if let text = spec["labelContains"] as? String { predicates.append(NSPredicate(format: "label CONTAINS[c] %@", text)) }
        if let format = spec["predicate"] as? String { predicates.append(NSPredicate(format: format)) }
        if predicates.isEmpty && spec["type"] == nil {
            throw DriverError(description: "Element spec needs id, idPrefix, label, labelContains, predicate or type")
        }
        return predicates
    }

    private func hasElementSpec(_ spec: [String: Any]) -> Bool {
        ["id", "idPrefix", "label", "labelContains", "predicate", "type"].contains { spec[$0] != nil }
    }

    private func elementType(_ name: String?) -> XCUIElement.ElementType {
        switch name {
        case "button": return .button
        case "staticText", "text": return .staticText
        case "image": return .image
        case "cell": return .cell
        case "textField": return .textField
        case "secureTextField": return .secureTextField
        case "textView": return .textView
        case "searchField": return .searchField
        case "scrollView": return .scrollView
        case "collectionView": return .collectionView
        case "table": return .table
        case "switch", "toggle": return .switch
        case "slider": return .slider
        case "other": return .other
        case "link": return .link
        case "map": return .map
        case "window": return .window
        case "sheet": return .sheet
        case "alert": return .alert
        case "segmentedControl": return .segmentedControl
        case "navigationBar": return .navigationBar
        case "menuItem": return .menuItem
        case "keyboard": return .keyboard
        case "key": return .key
        default: return .any
        }
    }

    private func describe(_ spec: [String: Any]) -> String {
        ["app", "type", "id", "idPrefix", "label", "labelContains", "predicate", "index"]
            .compactMap { key in spec[key].map { "\(key)=\($0)" } }
            .joined(separator: " ")
    }

    private func frame(_ rect: CGRect) -> [String: Double] {
        ["x": Double(rect.minX), "y": Double(rect.minY), "width": Double(rect.width), "height": Double(rect.height)]
    }

    private func number(_ value: Any?) -> Double? {
        switch value {
        case let number as NSNumber: return number.doubleValue
        case let text as String: return Double(text)
        default: return nil
        }
    }

    private func spin(_ seconds: TimeInterval) {
        guard seconds > 0 else { return }
        RunLoop.current.run(until: Date().addingTimeInterval(seconds))
    }
}
