import XCTest
@testable import TimeMaster

final class PageDropPlacementTests: XCTestCase {
    func testASiblingTakesThePlaceOnTheHalfItIsDroppedOn() {
        XCTAssertEqual(PageDropPlacement.resolve(fraction: 0.1, reorders: true, holds: false), .before)
        XCTAssertEqual(PageDropPlacement.resolve(fraction: 0.49, reorders: true, holds: false), .before)
        XCTAssertEqual(PageDropPlacement.resolve(fraction: 0.5, reorders: true, holds: false), .after)
        XCTAssertEqual(PageDropPlacement.resolve(fraction: 0.95, reorders: true, holds: false), .after)
    }

    func testAContainerKeepsItsMiddleForMovingInsideAndItsEdgesForPlaces() {
        XCTAssertEqual(PageDropPlacement.resolve(fraction: 0.2, reorders: true, holds: true), .before)
        XCTAssertEqual(PageDropPlacement.resolve(fraction: 0.5, reorders: true, holds: true), .inside)
        XCTAssertEqual(PageDropPlacement.resolve(fraction: 0.8, reorders: true, holds: true), .after)
    }

    func testOutsideTheManualOrderOnlyContainersTakeDrops() {
        XCTAssertEqual(PageDropPlacement.resolve(fraction: 0.1, reorders: false, holds: true), .inside)
        XCTAssertEqual(PageDropPlacement.resolve(fraction: 0.9, reorders: false, holds: true), .inside)
        XCTAssertNil(PageDropPlacement.resolve(fraction: 0.5, reorders: false, holds: false))
    }
}
