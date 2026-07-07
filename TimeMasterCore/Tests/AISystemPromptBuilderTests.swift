import XCTest
@testable import TimeMasterCore

final class AISystemPromptBuilderTests: XCTestCase {
    var builder: AISystemPromptBuilder!
    var fs: FileSystemHelper!
    var tempDir: URL!

    override func setUp() {
        super.setUp()
        tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        fs = FileSystemHelper(dataRoot: tempDir)
        builder = AISystemPromptBuilder(fs: fs)
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: tempDir)
        super.tearDown()
    }

    func testListKnowledgeFilesEmptyWhenDirMissing() {
        let files = builder.listKnowledgeFiles()
        XCTAssertTrue(files.isEmpty)
    }

    func testListKnowledgeFilesEmptyWhenNoMdFiles() throws {
        try fs.ensureDirectory(fs.knowledgeDirectory)
        let txtFile = fs.knowledgeDirectory.appendingPathComponent("notes.txt")
        try "hello".write(to: txtFile, atomically: true, encoding: .utf8)
        let files = builder.listKnowledgeFiles()
        XCTAssertTrue(files.isEmpty)
    }

    func testListKnowledgeFilesSkipsHiddenFiles() throws {
        try fs.ensureDirectory(fs.knowledgeDirectory)
        let hidden = fs.knowledgeDirectory.appendingPathComponent(".hidden.md")
        let normal = fs.knowledgeDirectory.appendingPathComponent("visible.md")
        try "hidden".write(to: hidden, atomically: true, encoding: .utf8)
        try "visible".write(to: normal, atomically: true, encoding: .utf8)
        let files = builder.listKnowledgeFiles()
        XCTAssertEqual(files.count, 1)
        XCTAssertEqual(files[0].lastPathComponent, "visible.md")
    }

    func testListKnowledgeFilesSortedAlphabetically() throws {
        try fs.ensureDirectory(fs.knowledgeDirectory)
        try "ccc".write(to: fs.knowledgeDirectory.appendingPathComponent("ccc.md"), atomically: true, encoding: .utf8)
        try "aaa".write(to: fs.knowledgeDirectory.appendingPathComponent("aaa.md"), atomically: true, encoding: .utf8)
        try "bbb".write(to: fs.knowledgeDirectory.appendingPathComponent("bbb.md"), atomically: true, encoding: .utf8)
        let files = builder.listKnowledgeFiles()
        XCTAssertEqual(files.count, 3)
        XCTAssertEqual(files[0].lastPathComponent, "aaa.md")
        XCTAssertEqual(files[1].lastPathComponent, "bbb.md")
        XCTAssertEqual(files[2].lastPathComponent, "ccc.md")
    }

    func testBuildSystemPromptEmptyWhenKnowledgeEmpty() throws {
        try fs.ensureDirectory(fs.knowledgeDirectory)
        let prompt = builder.buildSystemPrompt()
        XCTAssertEqual(prompt, "")
    }

    func testBuildSystemPromptEmptyWhenKnowledgeDirMissing() {
        let prompt = builder.buildSystemPrompt()
        XCTAssertEqual(prompt, "")
    }

    func testBuildSystemPromptConcatenatesFiles() throws {
        try fs.ensureDirectory(fs.knowledgeDirectory)

        let file1 = fs.knowledgeDirectory.appendingPathComponent("a-philosophy.md")
        let file2 = fs.knowledgeDirectory.appendingPathComponent("b-nutrition.md")
        try "Fitness content here".write(to: file1, atomically: true, encoding: .utf8)
        try "Nutrition content here".write(to: file2, atomically: true, encoding: .utf8)

        let prompt = builder.buildSystemPrompt()
        XCTAssertTrue(prompt.contains("Fitness content here"))
        XCTAssertTrue(prompt.contains("Nutrition content here"))
        XCTAssertTrue(prompt.contains("\n\n---\n\n"))
    }

    func testBuildSystemPromptFromBootstrapKnowledge() throws {
        let db = DatabaseManager(fs: fs)
        try db.bootstrapIfNeeded()

        let prompt = builder.buildSystemPrompt()
        XCTAssertTrue(prompt.contains("# Fitness Philosophy"))
        XCTAssertTrue(prompt.contains("# Nutrition Rules"))
        XCTAssertTrue(prompt.contains("# Recovery Protocols"))
        let separators = prompt.components(separatedBy: "\n\n---\n\n")
        XCTAssertEqual(separators.count, 3)
    }
}
