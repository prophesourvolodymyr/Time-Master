import XCTest
@testable import TimeMasterCore

/// Presets are like a Notion Select property: a name, an optional icon and their types.
final class SkillTypePresetTests: XCTestCase {
    private func makeSkill() throws -> (database: DatabaseManager, fs: FileSystemHelper, skill: ExercisePageManifest, cleanup: () -> Void) {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let fs = FileSystemHelper(dataRoot: root)
        let database = DatabaseManager(fs: fs)
        try database.bootstrapIfNeeded()
        let skill = ExercisePageManifest(title: "Cards", pageType: .skill)
        try database.createPage(manifest: skill)
        return (database, fs, skill, { try? FileManager.default.removeItem(at: root) })
    }

    func testAPresetIconSurvivesReloadAndUpdateKeepsIdOrderAndTypes() throws {
        let (database, fs, skill, cleanup) = try makeSkill()
        defer { cleanup() }

        let kind = try database.addSkillTypePreset(to: skill.id, title: "Kind", iconName: "hand.draw", iconType: .system)
        let level = try database.addSkillTypePreset(to: skill.id, title: "Level", iconName: "🎚️", iconType: .emoji)
        let move = try database.addSkillType(to: skill.id, presetID: kind.id, title: "Move")

        let reloaded = DatabaseManager(fs: fs)
        let presets = try reloaded.skillTypePresets(for: skill.id)
        XCTAssertEqual(presets.map(\.title), ["Kind", "Level"])
        XCTAssertEqual(presets.map(\.iconName), ["hand.draw", "🎚️"])
        XCTAssertEqual(presets.map(\.iconType), [.system, .emoji])

        let updated = try reloaded.updateSkillTypePreset(kind.id, in: skill.id) { preset in
            preset.title = "  Kinds of trick "
            preset.iconName = "sparkles"
            preset.id = "hijack"
            preset.order = 9
            preset.types = []
        }
        XCTAssertEqual(updated.id, kind.id, "the id never changes")
        XCTAssertEqual(updated.order, 0)
        XCTAssertEqual(updated.title, "Kinds of trick")
        XCTAssertEqual(updated.iconName, "sparkles")
        XCTAssertEqual(updated.types.map(\.id), [move.id], "the types stay")
        XCTAssertEqual(try reloaded.skillTypePresets(for: skill.id).map(\.id), [kind.id, level.id])
    }

    func testAnEmptyIconMeansNoIconAndAnEmptyNameIsRefused() throws {
        let (database, _, skill, cleanup) = try makeSkill()
        defer { cleanup() }

        let preset = try database.addSkillTypePreset(to: skill.id, title: "Kind", iconName: "  ", iconType: .emoji)
        XCTAssertNil(preset.iconName, "a blank icon is no icon")
        XCTAssertEqual(preset.iconType, .system, "and then the type goes back to its default")

        let withIcon = try database.updateSkillTypePreset(preset.id, in: skill.id) { $0.iconName = "🃏"; $0.iconType = .emoji }
        XCTAssertEqual(withIcon.iconName, "🃏")
        let cleared = try database.updateSkillTypePreset(preset.id, in: skill.id) { $0.iconName = "" }
        XCTAssertNil(cleared.iconName)
        XCTAssertEqual(cleared.iconType, .system)

        XCTAssertThrowsError(try database.updateSkillTypePreset(preset.id, in: skill.id) { $0.title = "   " })
        XCTAssertThrowsError(try database.updateSkillTypePreset("missing", in: skill.id) { $0.title = "x" })
    }

    func testAPresetWithoutAnIconWritesNoIconKeysAndOldManifestsStillDecode() throws {
        let plain = SkillTypePreset(id: "p1", title: "Kind", order: 0, types: [])
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let bytes = String(decoding: try encoder.encode(plain), as: UTF8.self)
        XCTAssertFalse(bytes.contains("iconName"), bytes)
        XCTAssertFalse(bytes.contains("iconType"), bytes)

        let old = Data(#"{"id":"p2","title":"Old","order":1,"types":[]}"#.utf8)
        let decoded = try JSONDecoder().decode(SkillTypePreset.self, from: old)
        XCTAssertNil(decoded.iconName)
        XCTAssertEqual(decoded.iconType, .system)

        let icon = SkillTypePreset(id: "p3", title: "New", iconName: "tag", iconType: .system)
        let roundTrip = try JSONDecoder().decode(SkillTypePreset.self, from: try encoder.encode(icon))
        XCTAssertEqual(roundTrip, icon)
    }
}
