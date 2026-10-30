import CoreGraphics
import XCTest
@testable import TimeMaster

final class KeyNavGeometryTests: XCTestCase {
    private typealias Geometry = KeyNavGeometry

    private func item(_ id: String, _ x: CGFloat, _ y: CGFloat, _ width: CGFloat = 100, _ height: CGFloat = 60) -> KeyNavItem<String> {
        KeyNavItem(id: id, frame: CGRect(x: x, y: y, width: width, height: height))
    }

    private func node(_ id: String, _ x: CGFloat, _ y: CGFloat, _ width: CGFloat = 100, _ height: CGFloat = 60,
                      parent: String? = nil, enabled: Bool = true) -> KeyNavNode<String> {
        KeyNavNode(id: id, frame: CGRect(x: x, y: y, width: width, height: height), parent: parent, isEnabled: enabled)
    }

    /// 3 × 3 cells named "r0c0"…"r2c2": 100 × 60, 20 pt gaps.
    private var grid: [KeyNavItem<String>] {
        (0..<3).flatMap { row in
            (0..<3).map { column in item("r\(row)c\(column)", CGFloat(column) * 120, CGFloat(row) * 80) }
        }
    }

    // MARK: Nearest in a direction

    func testNearestInEachDirectionOnAGrid() {
        let items = grid
        XCTAssertEqual(Geometry.step(from: "r1c1", direction: .up, among: items), "r0c1")
        XCTAssertEqual(Geometry.step(from: "r1c1", direction: .down, among: items), "r2c1")
        XCTAssertEqual(Geometry.step(from: "r1c1", direction: .left, among: items), "r1c0")
        XCTAssertEqual(Geometry.step(from: "r1c1", direction: .right, among: items), "r1c2")
    }

    func testTargetInTheBeamBeatsACloserDiagonalOne() {
        let items = [
            item("source", 0, 100),
            item("sameRowFar", 400, 100),
            item("diagonalNear", 130, 190),
        ]
        XCTAssertEqual(Geometry.step(from: "source", direction: .right, among: items), "sameRowFar")
    }

    func testShorterNextRowGoesToItsNearestCell() {
        let items = [
            item("a0", 0, 0), item("a1", 120, 0), item("a2", 240, 0), item("a3", 360, 0),
            item("b0", 0, 80), item("b1", 120, 80),
            item("c0", 0, 160), item("c1", 120, 160), item("c2", 240, 160), item("c3", 360, 160),
        ]
        XCTAssertEqual(Geometry.step(from: "a3", direction: .down, among: items), "b1")
    }

    func testWideRowDirectlyBelowWinsOverAnOffsetButton() {
        let items = [
            item("button", 0, 0, 44, 44),
            item("row", 0, 70, 600, 60),
            item("offset", 200, 60, 44, 44),
        ]
        XCTAssertEqual(Geometry.step(from: "button", direction: .down, among: items), "row")
    }

    func testSubpixelOffsetsStayInOneRow() {
        let items = [item("left", 0, 100), item("right", 120, 100.4), item("above", 120, 0)]
        XCTAssertEqual(Geometry.step(from: "right", direction: .up, among: items), "above")
        XCTAssertNil(Geometry.step(from: "left", direction: .up, among: [items[0], items[1]]))
    }

    // MARK: Shift = 3 steps, edges

    func testShiftMovesThreeTargetsAndStopsAtTheEdge() {
        let row = (0..<6).map { item("t\($0)", CGFloat($0) * 120, 0) }
        XCTAssertEqual(Geometry.step(from: "t0", direction: .right, count: Geometry.bigStep, among: row), "t3")
        XCTAssertEqual(Geometry.step(from: "t4", direction: .right, count: Geometry.bigStep, among: row), "t5")
        XCTAssertNil(Geometry.step(from: "t5", direction: .right, count: Geometry.bigStep, among: row))
        XCTAssertEqual(Geometry.step(from: "t5", direction: .left, count: Geometry.bigStep, among: row), "t2")
    }

    func testNoWrapAtEdgesByDefault() {
        let items = grid
        XCTAssertNil(Geometry.step(from: "r1c2", direction: .right, among: items))
        XCTAssertNil(Geometry.step(from: "r0c1", direction: .up, among: items))
    }

    func testWrapContinuesOnTheFarSideOfTheSameRowOrColumn() {
        let items = grid
        XCTAssertEqual(Geometry.step(from: "r1c2", direction: .right, among: items, wraps: true), "r1c0")
        XCTAssertEqual(Geometry.step(from: "r1c0", direction: .left, among: items, wraps: true), "r1c2")
        XCTAssertEqual(Geometry.step(from: "r2c1", direction: .down, among: items, wraps: true), "r0c1")
        XCTAssertNil(Geometry.step(from: "only", direction: .right, among: [item("only", 0, 0)], wraps: true))
    }

    // MARK: Ties

    func testTiesGoToReadingOrder() {
        let below = [item("source", 120, 0), item("left", 60, 100), item("right", 180, 100)]
        XCTAssertEqual(Geometry.step(from: "source", direction: .down, among: below), "left")

        let beside = [item("source", 0, 100), item("upper", 200, 40), item("lower", 200, 160)]
        XCTAssertEqual(Geometry.step(from: "source", direction: .right, among: beside), "upper")
    }

    // MARK: Disabled targets

    func testDisabledTargetsAreSkipped() {
        let nodes = [node("a", 0, 0), node("b", 120, 0, enabled: false), node("c", 240, 0)]
        let start = KeyNavFocus<String>(focused: "a", entered: nil)
        XCTAssertEqual(Geometry.move(start, direction: .right, in: nodes).focused, "c")
        XCTAssertNil(Geometry.focus(at: CGPoint(x: 150, y: 30), in: nodes))
    }

    // MARK: Primary and secondary levels

    func testArrowsNeverReachSecondaryTargets() {
        let nodes = [
            node("cardA", 0, 0, 200, 120),
            node("cardB", 400, 0, 200, 120),
            node("buttonOfB", 410, 10, 30, 30, parent: "cardB"),
            node("strayChild", 250, 40, 30, 30, parent: "cardA"),
        ]
        let start = KeyNavFocus<String>(focused: "cardA", entered: nil)
        XCTAssertEqual(Geometry.move(start, direction: .right, in: nodes).focused, "cardB")
    }

    func testSpaceEntersAndArrowsStayInsideUntilEscape() {
        let nodes = [
            node("card", 0, 0, 300, 120),
            node("done", 10, 10, 30, 30, parent: "card"),
            node("play", 60, 10, 30, 30, parent: "card"),
            node("next", 0, 200, 300, 120),
        ]
        let entered = Geometry.toggleEntry(KeyNavFocus(focused: "card", entered: nil), in: nodes)
        XCTAssertEqual(entered, KeyNavFocus(focused: "done", entered: "card"))

        let moved = Geometry.move(entered, direction: .right, in: nodes)
        XCTAssertEqual(moved, KeyNavFocus(focused: "play", entered: "card"))
        XCTAssertEqual(Geometry.move(moved, direction: .down, in: nodes), moved, "the next card is out of reach while inside")

        XCTAssertEqual(Geometry.exit(moved), KeyNavFocus(focused: "card", entered: nil))
        XCTAssertNil(Geometry.exit(KeyNavFocus(focused: "card", entered: nil)))
        XCTAssertEqual(Geometry.toggleEntry(moved, in: nodes), KeyNavFocus(focused: "card", entered: nil), "Space again leaves")
    }

    func testEnteringAPrimaryWithoutSecondariesChangesNothing() {
        let nodes = [node("plain", 0, 0), node("other", 120, 0)]
        let focus = KeyNavFocus<String>(focused: "plain", entered: nil)
        XCTAssertEqual(Geometry.toggleEntry(focus, in: nodes), focus)
        XCTAssertFalse(Geometry.hasChildren("plain", in: nodes))
    }

    func testEnteringStartsOnTheSecondaryUnderThePointer() {
        let nodes = [
            node("card", 0, 0, 300, 120),
            node("done", 10, 10, 30, 30, parent: "card"),
            node("menu", 250, 10, 30, 30, parent: "card"),
        ]
        let focus = Geometry.toggleEntry(KeyNavFocus(focused: "card", entered: nil), in: nodes, pointer: CGPoint(x: 260, y: 20))
        XCTAssertEqual(focus, KeyNavFocus(focused: "menu", entered: "card"))
    }

    func testSecondaryWithoutItsPrimaryCountsAsPrimary() {
        let nodes = [node("orphan", 0, 0, parent: "gone"), node("b", 120, 0)]
        XCTAssertEqual(Set(Geometry.level(nil, in: nodes).map(\.id)), ["orphan", "b"])
        XCTAssertEqual(Geometry.move(KeyNavFocus(focused: "b", entered: nil), direction: .left, in: nodes).focused, "orphan")
    }

    func testVanishedTargetsAreDropped() {
        let nodes = [node("card", 0, 0, 300, 120), node("other", 0, 200)]
        XCTAssertEqual(Geometry.sanitized(KeyNavFocus(focused: "child", entered: "card"), in: nodes),
                       KeyNavFocus(focused: "card", entered: nil), "an entered card without secondaries takes the focus back")
        XCTAssertEqual(Geometry.sanitized(KeyNavFocus(focused: "child", entered: "gone"), in: nodes), .none)
        XCTAssertEqual(Geometry.sanitized(KeyNavFocus(focused: "gone", entered: nil), in: nodes), .none)
    }

    // MARK: Pointer start

    func testWithoutFocusNavigationStartsFromThePointer() {
        let nodes = [node("topLeft", 0, 0), node("topRight", 300, 0), node("belowPointer", 280, 200)]
        let focus = Geometry.move(.none, direction: .down, in: nodes, pointer: CGPoint(x: 320, y: 120))
        XCTAssertEqual(focus.focused, "belowPointer")
    }

    func testPointerWithNothingInTheDirectionFallsBackToTheNearestTarget() {
        let nodes = [node("a", 0, 0), node("b", 300, 0)]
        let focus = Geometry.move(.none, direction: .down, in: nodes, pointer: CGPoint(x: 330, y: 300))
        XCTAssertEqual(focus.focused, "b")
    }

    func testWithoutFocusOrPointerNavigationStartsTopLeft() {
        let row = (0..<5).map { node("t\($0)", CGFloat($0) * 120, 0) } + [node("below", 0, 100)]
        XCTAssertEqual(Geometry.move(.none, direction: .right, in: row).focused, "t0")
        XCTAssertEqual(Geometry.move(.none, direction: .right, count: Geometry.bigStep, in: row).focused, "t2")
    }

    func testPointerOverASecondaryFocusesItInsideItsPrimary() {
        let nodes = [node("card", 0, 0, 300, 120), node("play", 250, 80, 30, 30, parent: "card")]
        XCTAssertEqual(Geometry.focus(at: CGPoint(x: 260, y: 90), in: nodes), KeyNavFocus(focused: "play", entered: "card"))
        XCTAssertEqual(Geometry.focus(at: CGPoint(x: 260, y: 90), in: nodes, primaryOnly: true),
                       KeyNavFocus(focused: "card", entered: nil))
        XCTAssertEqual(Geometry.focus(at: CGPoint(x: 20, y: 20), in: nodes), KeyNavFocus(focused: "card", entered: nil))
        XCTAssertNil(Geometry.focus(at: CGPoint(x: 500, y: 500), in: nodes))
    }

    func testPointerPicksTheMostSpecificTarget() {
        let items = [item("big", 0, 0, 400, 400), item("small", 100, 100, 50, 50)]
        XCTAssertEqual(Geometry.item(at: CGPoint(x: 120, y: 120), among: items)?.id, "small")
        XCTAssertEqual(Geometry.nearest(to: CGPoint(x: 500, y: 120), among: [items[1], item("far", 900, 900)])?.id, "small")
    }
}
