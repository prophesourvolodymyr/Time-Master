#if os(macOS)
import Foundation
import AppKit
import Combine
import TimeMasterCore

enum AgentDecision {
    case allow
    case approve
    case deny
}

enum AgentAccessLevel: String, CaseIterable, Identifiable {
    case off
    case readOnly
    case standard
    case full

    static let defaultsKey = "tm.agent.access"

    static var current: AgentAccessLevel {
        UserDefaults.standard.string(forKey: defaultsKey).flatMap(AgentAccessLevel.init(rawValue:)) ?? .standard
    }

    var id: String { rawValue }

    var title: String {
        switch self {
        case .off: "Off"
        case .readOnly: "Read only"
        case .standard: "Standard"
        case .full: "Full"
        }
    }

    var detail: String {
        switch self {
        case .off: "No agent or command-line access."
        case .readOnly: "Agents can look at your library but change nothing."
        case .standard: "Agents can add, edit and move things freely. Deleting asks you first."
        case .full: "Agents can do anything without asking. Deleted items still go to the trash."
        }
    }

    func decision(for risk: AgentToolRisk) -> AgentDecision {
        switch self {
        case .off: .deny
        case .readOnly: risk == .read ? .allow : .deny
        case .standard: risk == .delete ? .approve : .allow
        case .full: .allow
        }
    }
}

@MainActor
final class AgentAccessPreferences: ObservableObject {
    static let shared = AgentAccessPreferences()

    @Published var level: AgentAccessLevel {
        didSet { UserDefaults.standard.set(level.rawValue, forKey: AgentAccessLevel.defaultsKey) }
    }

    private init() {
        level = AgentAccessLevel.current
    }
}

enum AgentApprovalOutcome {
    case allowed
    case denied
    case timedOut
}

private actor AgentApprovalGate {
    private var busy = false
    private var waiters: [CheckedContinuation<Void, Never>] = []

    func acquire() async {
        if busy {
            await withCheckedContinuation { waiters.append($0) }
        } else {
            busy = true
        }
    }

    func release() {
        if waiters.isEmpty { busy = false } else { waiters.removeFirst().resume() }
    }
}

private final class AgentApprovalFlag {
    var timedOut = false
}

@MainActor
final class AgentApprovalPresenter {
    static let shared = AgentApprovalPresenter()
    private let gate = AgentApprovalGate()

    func request(summary: String, details: [String: String], timeout: TimeInterval) async -> AgentApprovalOutcome {
        await gate.acquire()
        let outcome = present(summary: summary, details: details, timeout: timeout)
        await gate.release()
        return outcome
    }

    private func present(summary: String, details: [String: String], timeout: TimeInterval) -> AgentApprovalOutcome {
        NSApp.activate(ignoringOtherApps: true)
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = "An agent wants to delete something"
        let lines = details.keys.sorted().prefix(8).map { "\($0): \(details[$0] ?? "")" }
        alert.informativeText = ([summary] + lines + ["Deleted items go to the trash and can be restored."]).joined(separator: "\n")
        alert.addButton(withTitle: "Cancel")
        let confirm = alert.addButton(withTitle: "Delete")
        confirm.hasDestructiveAction = true
        let flag = AgentApprovalFlag()
        let timer = Timer(timeInterval: timeout, repeats: false) { _ in
            flag.timedOut = true
            NSApp.abortModal()
        }
        RunLoop.main.add(timer, forMode: .common)
        let response = alert.runModal()
        timer.invalidate()
        if flag.timedOut { return .timedOut }
        return response == .alertSecondButtonReturn ? .allowed : .denied
    }
}

enum AgentCLIInstaller {
    enum Status: Equatable {
        case notBundled
        case notInstalled
        case installed
        case foreign
    }

    static var bundled: URL? {
        let url = Bundle.main.bundleURL.appendingPathComponent("Contents/Helpers/tmax")
        return FileManager.default.isExecutableFile(atPath: url.path) ? url : nil
    }

    static var link: URL {
        FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".local/bin/tmax")
    }

    static var status: Status {
        guard let bundled else { return .notBundled }
        let destination = try? FileManager.default.destinationOfSymbolicLink(atPath: link.path)
        if destination == bundled.path { return .installed }
        return FileManager.default.fileExists(atPath: link.path) || destination != nil ? .foreign : .notInstalled
    }

    static func install() throws {
        guard let bundled else {
            throw AgentToolError("not_bundled", "This build of Tmax does not include the tmax command.")
        }
        let manager = FileManager.default
        try manager.createDirectory(at: link.deletingLastPathComponent(), withIntermediateDirectories: true)
        if let existing = try? manager.destinationOfSymbolicLink(atPath: link.path) {
            if existing != bundled.path { try manager.removeItem(at: link) }
            else { return }
        } else if manager.fileExists(atPath: link.path) {
            throw AgentToolError("already_exists", "\(link.path) already exists and is not a link to Tmax.")
        }
        try manager.createSymbolicLink(at: link, withDestinationURL: bundled)
    }
}
#endif
