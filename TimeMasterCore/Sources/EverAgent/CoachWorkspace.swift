#if os(macOS)
import Foundation

public enum CoachWorkspace {
    public static let folderName = CoachConstants.projectName
    public static let toolServerFile = ".mcp.json"
    public static let instructionsFile = "AGENTS.md"
    public static let toolServerName = "tmax"
    public static let toolPrefix = CoachConstants.toolPrefix

    public static func defaultDirectory() -> URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent(folderName, isDirectory: true)
    }

    public static func toolServerConfiguration(helperPath: String) throws -> String {
        let document: [String: Any] = [
            "mcpServers": [
                toolServerName: [
                    "type": "stdio",
                    "command": helperPath,
                    "args": ["mcp"],
                ] as [String: Any],
            ] as [String: Any],
        ]
        let data = try JSONSerialization.data(withJSONObject: document, options: [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes])
        return String(decoding: data, as: UTF8.self) + "\n"
    }

    public static func instructions(persona: String, guidance: String, knowledgePath: String?) -> String {
        var sections = [
            "# Tmax Coach",
            persona.trimmingCharacters(in: .whitespacesAndNewlines),
            """
            You work inside the Tmax workout app's assistant. The exercise library, workouts and stats live only behind the Tmax tools: the tools whose names start with \(toolPrefix). Call the context tool first in a new conversation. Never read or edit the Tmax library files directly; always go through the Tmax tools, which validate every change and can be undone.
            """,
            guidance.trimmingCharacters(in: .whitespacesAndNewlines),
        ]
        if let knowledgePath, !knowledgePath.isEmpty {
            sections.append("The user's own knowledge notes for you are files in \(knowledgePath). Read the relevant ones before giving advice that depends on them.")
        }
        sections.append("You are also a full agent on this Mac. Read and write files, run commands and search the web when the user asks for it or when it clearly serves their training, and say plainly what you did.")
        return sections.filter { !$0.isEmpty }.joined(separator: "\n\n") + "\n"
    }

    @discardableResult
    public static func provision(
        at directory: URL,
        helperPath: String,
        persona: String,
        guidance: String,
        knowledgePath: String?
    ) throws -> Bool {
        let manager = FileManager.default
        try manager.createDirectory(at: directory, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
        let files = [
            (toolServerFile, try toolServerConfiguration(helperPath: helperPath)),
            (instructionsFile, instructions(persona: persona, guidance: guidance, knowledgePath: knowledgePath)),
        ]
        var changed = false
        for (name, contents) in files {
            let url = directory.appendingPathComponent(name)
            if let existing = try? String(contentsOf: url, encoding: .utf8), existing == contents { continue }
            try contents.write(to: url, atomically: true, encoding: .utf8)
            changed = true
        }
        return changed
    }
}
#endif
