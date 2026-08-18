import XCTest
@testable import TimeMasterCore

final class SchemaValidationTests: XCTestCase {
    var tmpDir: URL!
    var fs: FileSystemHelper!
    var schemaManager: SchemaManager!

    override func setUp() {
        super.setUp()
        tmpDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        fs = FileSystemHelper(dataRoot: tmpDir)
        schemaManager = SchemaManager(fs: fs)
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: tmpDir)
        super.tearDown()
    }

    func testGenerateSchemaProducesValidJSON() throws {
        let schema = try schemaManager.generateSchema()
        XCTAssertEqual(schema.version, "1.1.0")

        let data = try JSONEncoder().encode(schema)
        let json = String(data: data, encoding: .utf8)!
        XCTAssertTrue(json.contains("exercise"))
        XCTAssertTrue(json.contains("workout"))
        XCTAssertTrue(json.contains("historyEntry"))
        XCTAssertTrue(json.contains("outdoorActivity"))

        let obj = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        XCTAssertNotNil(obj["version"])
        XCTAssertNotNil(obj["objects"])
        XCTAssertNotNil(obj["tools"])
        XCTAssertNotNil(obj["filesystem"])
    }

    func testSchemaToolsIncludeAllCommands() throws {
        let schema = try schemaManager.generateSchema()
        let toolNames = Set(schema.tools.map { $0.name })
        XCTAssertTrue(toolNames.contains("listExercises"))
        XCTAssertTrue(toolNames.contains("getExercise"))
        XCTAssertTrue(toolNames.contains("searchExercises"))
        XCTAssertTrue(toolNames.contains("createExercise"))
        XCTAssertTrue(toolNames.contains("deleteExercise"))
        XCTAssertTrue(toolNames.contains("listWorkouts"))
        XCTAssertTrue(toolNames.contains("createWorkout"))
        XCTAssertTrue(toolNames.contains("getStats"))
    }

    func testWriteSchemaCreatesFile() throws {
        try schemaManager.writeSchema()
        XCTAssertTrue(fs.fileExists(at: fs.schemaURL))

        let data = try fs.readRawData(from: fs.schemaURL)
        let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        let objects = json["objects"] as! [String: Any]
        XCTAssertNotNil(objects["exercise"])
        XCTAssertNotNil(objects["workout"])
    }

    func testValidateRejectsMissingRequiredFields() throws {
        let schema = SchemaDefinition(
            version: "1.0",
            objects: [
                "test": ObjectSchema(
                    description: "test",
                    folderPath: "test",
                    required: ["id", "name"],
                    properties: [
                        "id": PropertySchema(type: "string", description: "id"),
                        "name": PropertySchema(type: "string", description: "name"),
                    ]
                )
            ],
            tools: [],
            filesystem: FilesystemSchema()
        )

        struct BadManifest: Codable {
            var name: String?
        }

        let validation = schemaManager.validate(manifest: BadManifest(name: "hi"), type: "test", schema: schema)
        XCTAssertFalse(validation.valid)
        XCTAssertTrue(validation.errors.contains { $0.contains("Missing required field: id") })
    }

    func testValidateUnknownType() throws {
        let result = schemaManager.validate(manifest: ExerciseManifest(
            id: "test", name: "test"
        ), type: "nonexistent_type")
        XCTAssertFalse(result.valid)
        XCTAssertTrue(result.errors.contains { $0.contains("Unknown object type") })
    }

    func testValidateAcceptsValidManifest() throws {
        let manifest = ExerciseManifest(
            id: UUID().uuidString,
            name: "Valid Exercise",
            duration: 30,
            restAfter: 10
        )
        let result = schemaManager.validate(manifest: manifest, type: "exercise")
        XCTAssertTrue(result.valid, "Valid manifest should pass validation. Errors: \(result.errors)")
    }

    func testValidateAllAcceptsPageManifests() throws {
        let pageFolder = fs.exercisesDatabaseDirectory.appendingPathComponent("Container")
        try FileManager.default.createDirectory(at: pageFolder, withIntermediateDirectories: true)

        let manifest = ExercisePageManifest(
            id: UUID().uuidString,
            title: "Page Exercise",
            pageKind: .leaf,
            markdownBody: "A page.",
            duration: 30,
            restAfter: 10
        )
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        try encoder.encode(manifest).write(to: pageFolder.appendingPathComponent("manifest.json"))

        let results = schemaManager.validateAll()
        XCTAssertEqual(results.count, 1)
        XCTAssertTrue(results[0].valid, "Page manifest should pass validation. Errors: \(results[0].errors)")
    }

    func testWriteSchemaProducesReadableFile() throws {
        try schemaManager.writeSchema()
        let data = try fs.readRawData(from: fs.schemaURL)
        let schema = try JSONDecoder().decode(SchemaDefinition.self, from: data)

        XCTAssertEqual(schema.version, "1.1.0")
        XCTAssertEqual(schema.objects.count, 7)
        XCTAssertEqual(schema.tools.count, 20)
        XCTAssertTrue(schema.tools.contains { $0.name == "create_container_page" })
        XCTAssertTrue(schema.tools.contains { $0.name == "create_exercise_page" })
        XCTAssertEqual(schema.filesystem.directories.count, 12)
        XCTAssertEqual(schema.filesystem.root, "TimeMaster")
    }

    func testGenerateSchemaRoundtrip() throws {
        let schema1 = try schemaManager.generateSchema()
        let data = try JSONEncoder().encode(schema1)
        let schema2 = try JSONDecoder().decode(SchemaDefinition.self, from: data)

        XCTAssertEqual(schema1.version, schema2.version)
        XCTAssertEqual(schema1.objects.count, schema2.objects.count)
        XCTAssertEqual(schema1.tools.count, schema2.tools.count)
    }
}
