import Foundation
import TimeMasterCore

enum AgentOrigin: String {
    case coach
    case external
}

struct AgentRouterResult {
    var value: [String: Any]
    var effects: [AgentEffect]
    var batchID: String?
}

struct AgentUnchecked<Value>: @unchecked Sendable {
    let value: Value
}

@MainActor
final class AgentRuntime {
    static let shared = AgentRuntime()
    weak var workoutStore: WorkoutStore?
    private init() {}
}

final class AgentToolRouter: @unchecked Sendable {
    static let shared = AgentToolRouter()
    private let toolbox: AgentToolbox

    private init() {
        toolbox = AgentToolbox(database: DatabaseManager.shared)
    }

    func execute(_ name: String, arguments: [String: Any], dryRun: Bool = false, origin: AgentOrigin) async throws -> AgentRouterResult {
        guard let tool = AgentToolRegistry.tool(named: name) else {
            let close = AgentToolRegistry.suggestions(for: name)
            throw AgentToolError("unknown_tool", "Unknown tool '\(name)'.", hint: close.isEmpty ? "Run tools to list what is available." : "Did you mean: \(close.joined(separator: ", "))?")
        }
        if origin == .coach, !tool.coach {
            throw AgentToolError("not_available", "'\(name)' is not available in chat.")
        }
        try DatabaseManager.shared.bootstrapIfNeeded()
        let output: AgentToolOutput
        do {
            switch name {
            case "get_settings":
                output = try await MainActor.run { try AgentSettingsTools.snapshot() }
            case "update_settings":
                let validated = try AgentToolRegistry.validate(name, arguments: arguments)
                output = try await MainActor.run { try AgentSettingsTools.apply(validated, dryRun: dryRun) }
            case "import_video":
                output = try await AgentVideoImporter.run(arguments: arguments, dryRun: dryRun, router: self)
            case "undo":
                output = try await undo(arguments: arguments, dryRun: dryRun)
            default:
                output = try await runCore(name, arguments: arguments, dryRun: dryRun)
            }
        } catch {
            throw AgentToolError.translating(error)
        }
        var batchID: String?
        if !dryRun, tool.risk.isWrite {
            await refreshStores()
            batchID = AgentJournal.shared.record(origin: origin, tool: name, effects: output.effects)
        }
        return AgentRouterResult(value: output.value, effects: output.effects, batchID: batchID)
    }

    func runCore(_ name: String, arguments: [String: Any], dryRun: Bool = false) async throws -> AgentToolOutput {
        let token = ExerciseLibraryAccess.shared.capture()
        let toolbox = toolbox
        let request = AgentUnchecked(value: (name, arguments))
        let result = try await Task.detached(priority: .userInitiated) { () throws -> AgentUnchecked<AgentToolOutput> in
            do {
                return try ExerciseLibraryAccess.shared.perform(token: token) {
                    AgentUnchecked(value: try toolbox.call(request.value.0, arguments: request.value.1, dryRun: dryRun))
                }
            } catch let error as ExerciseLibraryAccess.AccessError {
                throw AgentToolError("library_busy", error.localizedDescription)
            }
        }.value
        return result.value
    }

    func revertCore(_ effects: [AgentEffect]) async throws -> [String] {
        let token = ExerciseLibraryAccess.shared.capture()
        let toolbox = toolbox
        return try await Task.detached(priority: .userInitiated) { () throws -> [String] in
            do {
                return try ExerciseLibraryAccess.shared.perform(token: token) { toolbox.revert(effects) }
            } catch let error as ExerciseLibraryAccess.AccessError {
                throw AgentToolError("library_busy", error.localizedDescription)
            }
        }.value
    }

    private func undo(arguments: [String: Any], dryRun: Bool) async throws -> AgentToolOutput {
        let validated = try AgentToolRegistry.validate("undo", arguments: arguments)
        guard let entry = AgentJournal.shared.undoable(id: validated["batch"] as? String) else {
            throw AgentToolError("nothing_to_undo", "There are no agent changes to undo.", hint: "Only creations, attachments and notes from agent calls can be undone.")
        }
        if dryRun {
            return AgentToolOutput(value: ["dryRun": true, "batch": entry.id, "tool": entry.tool, "changes": entry.effects.count])
        }
        let notes = try await revertCore(entry.effects)
        AgentJournal.shared.markUndone(entry.id)
        return AgentToolOutput(value: ["batch": entry.id, "tool": entry.tool, "reverted": notes])
    }

    @MainActor
    private func refreshStores() {
        DatabaseStore.shared.reload()
        AgentRuntime.shared.workoutStore?.reload()
    }
}
