import XCTest
import TimeMasterCore
@testable import TimeMaster

final class ComboCallTests: XCTestCase {
    func testACallReadsTheSameWhateverWayItIsWritten() {
        XCTAssertEqual(ComboCall.tokens(in: "1-2-3"), ["1", "2", "3"])
        XCTAssertEqual(ComboCall.tokens(in: "1 2 3"), ["1", "2", "3"])
        XCTAssertEqual(ComboCall.tokens(in: "123"), ["1", "2", "3"])
        XCTAssertEqual(ComboCall.tokens(in: "1, 2, slip, 2"), ["1", "2", "slip", "2"])
        XCTAssertEqual(ComboCall.tokens(in: "1-2-Slip"), ["1", "2", "slip"])
        XCTAssertEqual(ComboCall.tokens(in: " -- "), [])
    }

    func testTheVoiceSaysNumbersAsWordsWithAPauseBetweenMoves() {
        XCTAssertEqual(ComboCall.spoken(["1", "2", "3"]), "one, two, three")
        XCTAssertEqual(ComboCall.spoken("1-2-slip-2"), "one, two, slip, two")
        XCTAssertEqual(ComboCall.name(for: ["1", "2", "3"]), "1-2-3")
    }

    func testEveryMoveTheWheelOffersHasAnIconAndIsReadBackByItsToken() {
        XCTAssertGreaterThanOrEqual(ComboMoves.all.count, 6)
        XCTAssertEqual(Set(ComboMoves.all.map(\.token)).count, ComboMoves.all.count)
        for move in ComboMoves.all {
            XCTAssertFalse(move.symbol.isEmpty, move.token)
            XCTAssertEqual(ComboMoves.move(for: move.token), move)
            XCTAssertEqual(ComboCall.tokens(in: move.token), [move.token])
        }
    }

    func testANewComboIsABundleOfCallsInRounds() {
        let combo = WorkoutSectionBuilder.makeCombo(calls: [["1", "2"], ["1", "2", "3"]], rounds: 2)
        XCTAssertTrue(combo.isCombo)
        XCTAssertEqual(combo.mode, .bundle)
        XCTAssertTrue(combo.bundleVoiceEnabled)
        XCTAssertEqual(combo.bundleSets.count, 2)
        XCTAssertEqual(combo.bundleSets[0].children.map(\.name), ["1-2", "1-2-3"])
        XCTAssertTrue(combo.bundleSets.allSatisfy { $0.children.allSatisfy { $0.exercisePageID == nil } })
    }

    func testTheQuickPreviewListsEveryCallOfAComboAsARedStepWithItsSpokenText() {
        let combo = WorkoutSectionBuilder.makeCombo(calls: [["1", "2"], ["1", "2", "3"]], rounds: 1)
        let steps = QuickPreviewSteps.steps(for: Workout(name: "Boxing", sections: [combo]), page: { _ in nil })
        XCTAssertEqual(steps.map(\.title), ["1-2", "1-2-3"])
        XCTAssertEqual(steps.map(\.note), ["one, two", "one, two, three"])
        XCTAssertTrue(steps.allSatisfy { $0.blockKind == .combo })
    }

    func testAComboKeepsItsFlagAndIconThroughSavingAndOlderFilesReadAsPlainBundles() throws {
        var combo = WorkoutSectionBuilder.makeCombo()
        combo.iconName = "flame.fill"
        combo.iconType = .system

        let stored = combo.coreManifest
        XCTAssertTrue(stored.isCombo)
        XCTAssertEqual(stored.iconName, "flame.fill")
        XCTAssertEqual(stored.iconType, "system")

        let back = stored.toAppSection()
        XCTAssertTrue(back.isCombo)
        XCTAssertEqual(back.iconName, "flame.fill")
        XCTAssertEqual(back.iconType, .system)

        let encoded = try JSONEncoder().encode(WorkoutSectionBuilder.makeCombo())
        var object = try XCTUnwrap(try JSONSerialization.jsonObject(with: encoded) as? [String: Any])
        object["isCombo"] = nil
        object["iconName"] = nil
        object["iconType"] = nil
        let older = try JSONDecoder().decode(Section.self, from: JSONSerialization.data(withJSONObject: object))
        XCTAssertFalse(older.isCombo)
        XCTAssertNil(older.iconName)
        XCTAssertEqual(older.mode, .bundle)
    }
}
