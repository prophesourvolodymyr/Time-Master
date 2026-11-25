import XCTest
@testable import TimeMaster

final class SkillArtTests: XCTestCase {
    func testSlugLowercasesAndJoinsRunsOfOtherCharactersWithOneDash() {
        XCTAssertEqual(SkillArt.slug(forTitle: "Press to Handstand"), "press-to-handstand")
        XCTAssertEqual(SkillArt.slug(forTitle: "Push-Up"), "push-up")
        XCTAssertEqual(SkillArt.slug(forTitle: "  Muscle  -  Up!! "), "muscle-up")
        XCTAssertEqual(SkillArt.slug(forTitle: "L-Sit (Floor) 2.0"), "l-sit-floor-2-0")
        XCTAssertEqual(SkillArt.slug(forTitle: "---"), "")
        XCTAssertEqual(SkillArt.slug(forTitle: ""), "")
    }

    func testLookupNeedsTheSlugInTheIndex() {
        let available: Set<String> = ["push-up", "press-to-handstand"]
        XCTAssertEqual(SkillArt.assetName(forTitle: "Push-Up", available: available), "skillart_push-up")
        XCTAssertEqual(SkillArt.assetName(forTitle: "press to handstand", available: available), "skillart_press-to-handstand")
        XCTAssertNil(SkillArt.assetName(forTitle: "Pull-Up", available: available))
        XCTAssertNil(SkillArt.assetName(forTitle: "!!!", available: available))
        XCTAssertNil(SkillArt.assetName(forTitle: "Push-Up", available: []))
    }

    func testTheLoadedIndexHoldsOnlyUsableSlugs() {
        for slug in SkillArt.available {
            XCTAssertEqual(SkillArt.slug(forTitle: slug), slug)
        }
    }
}
