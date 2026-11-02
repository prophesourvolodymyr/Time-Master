#if os(macOS)
import XCTest
@testable import TimeMasterCore

final class CoachWorkspaceTests: XCTestCase {
    private var directory: URL!

    override func setUpWithError() throws {
        directory = FileManager.default.temporaryDirectory.appendingPathComponent("coach-\(UUID().uuidString)", isDirectory: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: directory)
    }

    private func provision(helper: String = "/Applications/Tmax.app/Contents/Helpers/tmax", persona: String = "Be concise.", knowledge: String? = nil) throws -> Bool {
        try CoachWorkspace.provision(at: directory, helperPath: helper, persona: persona, guidance: "## Tool use\n- Look before you write.", knowledgePath: knowledge)
    }

    private func read(_ name: String) throws -> String {
        try String(contentsOf: directory.appendingPathComponent(name), encoding: .utf8)
    }

    func testTheToolServerFileNamesTheHelperAndStartsItInMcpMode() throws {
        _ = try provision()
        let document = try JSONSerialization.jsonObject(with: Data(read(".mcp.json").utf8)) as? [String: Any]
        let servers = document?["mcpServers"] as? [String: Any]
        let tmax = servers?["tmax"] as? [String: Any]
        XCTAssertEqual(tmax?["type"] as? String, "stdio")
        XCTAssertEqual(tmax?["command"] as? String, "/Applications/Tmax.app/Contents/Helpers/tmax")
        XCTAssertEqual(tmax?["args"] as? [String], ["mcp"])
        XCTAssertEqual(servers?.count, 1)
    }

    func testAHelperPathWithSpacesAndQuotesSurvivesTheRoundTrip() throws {
        let path = "/Users/me/My \"Apps\"/Tmax 2.app/Contents/Helpers/tmax"
        _ = try provision(helper: path)
        let document = try JSONSerialization.jsonObject(with: Data(read(".mcp.json").utf8)) as? [String: Any]
        let command = ((document?["mcpServers"] as? [String: Any])?["tmax"] as? [String: Any])?["command"] as? String
        XCTAssertEqual(command, path)
    }

    func testProvisioningTwiceChangesNothingTheSecondTime() throws {
        XCTAssertTrue(try provision())
        let first = try FileManager.default.attributesOfItem(atPath: directory.appendingPathComponent("AGENTS.md").path)[.modificationDate] as? Date
        Thread.sleep(forTimeInterval: 0.05)
        XCTAssertFalse(try provision())
        let second = try FileManager.default.attributesOfItem(atPath: directory.appendingPathComponent("AGENTS.md").path)[.modificationDate] as? Date
        XCTAssertEqual(first, second)
    }

    func testChangingThePersonaRewritesOnlyTheInstructions() throws {
        _ = try provision(persona: "Be concise.")
        let toolServer = try read(".mcp.json")
        XCTAssertTrue(try provision(persona: "Be warm and brief."))
        XCTAssertTrue(try read("AGENTS.md").contains("Be warm and brief."))
        XCTAssertFalse(try read("AGENTS.md").contains("Be concise."))
        XCTAssertEqual(try read(".mcp.json"), toolServer)
    }

    func testAMovedAppRewritesTheToolServerFile() throws {
        _ = try provision(helper: "/Applications/Tmax.app/Contents/Helpers/tmax")
        XCTAssertTrue(try provision(helper: "/Users/me/Applications/Tmax.app/Contents/Helpers/tmax"))
        XCTAssertTrue(try read(".mcp.json").contains("/Users/me/Applications/Tmax.app"))
    }

    func testProvisioningKeepsEverythingElseInTheFolder() throws {
        _ = try provision()
        let note = directory.appendingPathComponent("my-notes.md")
        try "keep me".write(to: note, atomically: true, encoding: .utf8)
        _ = try provision(persona: "Different.")
        XCTAssertEqual(try String(contentsOf: note, encoding: .utf8), "keep me")
    }

    func testTheFolderIsPrivateToTheUser() throws {
        _ = try provision()
        let permissions = try FileManager.default.attributesOfItem(atPath: directory.path)[.posixPermissions] as? Int
        XCTAssertEqual(permissions, 0o700)
    }

    func testTheInstructionsCarryPersonaGuidanceAndTheToolRules() {
        let text = CoachWorkspace.instructions(persona: "  You are a calm coach.  ", guidance: "## Tool use\n- Look before you write.", knowledgePath: nil)
        XCTAssertTrue(text.hasPrefix("# Tmax Coach\n\nYou are a calm coach.\n\n"))
        XCTAssertTrue(text.contains("mcp__tmax_"))
        XCTAssertTrue(text.contains("Call the context tool first"))
        XCTAssertTrue(text.contains("Never read or edit the Tmax library files directly"))
        XCTAssertTrue(text.contains("## Tool use\n- Look before you write."))
        XCTAssertFalse(text.contains("knowledge notes"))
        XCTAssertTrue(text.hasSuffix("\n"))
    }

    func testKnowledgeNotesAreMentionedOnlyWhenTheFolderIsKnown() {
        let withNotes = CoachWorkspace.instructions(persona: "Coach.", guidance: "", knowledgePath: "/Users/me/Documents/AIKnowledge")
        XCTAssertTrue(withNotes.contains("/Users/me/Documents/AIKnowledge"))
        XCTAssertFalse(CoachWorkspace.instructions(persona: "Coach.", guidance: "", knowledgePath: "").contains("knowledge notes"))
        XCTAssertFalse(withNotes.contains("\n\n\n"))
    }
}

final class CoachActivityLabelTests: XCTestCase {
    func testTmaxToolsCalledThroughADeviceReadAsTmaxActions() {
        let label = CoachActivityLabel.make(toolName: "write", arguments: ["path": "xd://mcp__tmax_list_pages", "content": "{}"])
        XCTAssertEqual(label.title, "Tmax: list pages")
        XCTAssertNil(label.detail)
    }

    func testTheAgentsOwnIntentWinsOverTheDerivedTitle() {
        XCTAssertEqual(CoachActivityLabel.make(toolName: "bash", arguments: ["command": "ls -la"], intent: "Checking the folder").title, "Checking the folder")
        XCTAssertEqual(CoachActivityLabel.make(toolName: "bash", arguments: ["command": "ls -la", "i": "Looking around"]).title, "Looking around")
        XCTAssertEqual(CoachActivityLabel.make(toolName: "bash", arguments: ["command": "ls -la"], intent: "   ").title, "Running a command")
    }

    func testCommandsShowTheirFirstLineAndLongOnesAreCut() {
        XCTAssertEqual(CoachActivityLabel.make(toolName: "bash", arguments: ["command": "echo one\necho two"]).detail, "echo one")
        let long = String(repeating: "x", count: 200)
        let detail = CoachActivityLabel.make(toolName: "bash", arguments: ["command": .string(long)]).detail
        XCTAssertEqual(detail?.count, 91)
        XCTAssertTrue(detail?.hasSuffix("…") ?? false)
    }

    func testFileToolsNameTheFileNotTheWholePath() {
        XCTAssertEqual(CoachActivityLabel.make(toolName: "read", arguments: ["path": "/Users/me/notes/plan.md"]).title, "Reading plan.md")
        XCTAssertEqual(CoachActivityLabel.make(toolName: "write", arguments: ["path": "/tmp/out.txt", "content": "x"]).title, "Writing out.txt")
        XCTAssertEqual(CoachActivityLabel.make(toolName: "edit", arguments: [:]).title, "Editing a file")
    }

    func testOtherDevicesAndUnknownToolsGetASentenceTitle() {
        XCTAssertEqual(CoachActivityLabel.make(toolName: "write", arguments: ["path": "xd://mcp__notes_add_entry"]).title, "Notes: add entry")
        XCTAssertEqual(CoachActivityLabel.make(toolName: "write", arguments: ["path": "xd://lsp"]).title, "Lsp")
        XCTAssertEqual(CoachActivityLabel.make(toolName: "log_experiment", arguments: [:]).title, "Log experiment")
    }

    func testSearchAndDelegationLabels() {
        XCTAssertEqual(CoachActivityLabel.make(toolName: "web_search", arguments: ["query": "best hip mobility drills"]).detail, "best hip mobility drills")
        XCTAssertEqual(CoachActivityLabel.make(toolName: "task", arguments: [:]).title, "Delegating to a sub-agent")
        XCTAssertEqual(CoachActivityLabel.make(toolName: "grep", arguments: ["pattern": "squat"]).title, "Searching the project")
    }
}
#endif
