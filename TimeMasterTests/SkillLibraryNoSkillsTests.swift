import XCTest
import TimeMasterCore
@testable import TimeMaster

/// A page flagged `noSkills` is no skill anywhere: it and everything below it stay out of the sub-skill walks.
final class SkillLibraryNoSkillsTests: XCTestCase {
    func testAPageThatNeedsNoSkillsStaysOutOfItsParentsSubSkillsAndProgressWithEverythingBelowIt() throws {
        let library = SkillLibrary(pages: pages)
        let wrestling = try XCTUnwrap(library.page("Wrestling"))

        XCTAssertEqual(library.subSkills(below: wrestling).map(\.title), ["Shot", "Sprawl"])
        let progress = library.progress(of: wrestling)
        XCTAssertEqual(progress.total, 2)
        XCTAssertEqual(progress.completed, 1)
        XCTAssertEqual(progress.learning, 1)
    }

    func testAPageThatNeedsNoSkillsHasNoneOfItsOwn() throws {
        let library = SkillLibrary(pages: pages)
        let reel = try XCTUnwrap(library.page("Reel"))

        XCTAssertTrue(library.subSkills(below: reel).isEmpty)
        XCTAssertTrue(library.progress(of: reel).isEmpty)
        XCTAssertFalse(SkillLibrary.isSkill(reel))
        XCTAssertTrue(SkillLibrary.isSkill(try XCTUnwrap(library.page("Shot"))))
        XCTAssertFalse(SkillLibrary.isSkill(try XCTUnwrap(library.page("Drills"))))
    }

    func testASkillBelowAPageThatNeedsNoSkillsIsTopLevelUnlessASkillSitsHigherUp() throws {
        let library = SkillLibrary(pages: pages)

        XCTAssertEqual(library.topLevelEntries().map(\.page.title), ["Wrestling", "Pivot"])
        XCTAssertFalse(library.isInsideSkill(try XCTUnwrap(library.page("Pivot"))))
        XCTAssertTrue(library.isInsideSkill(try XCTUnwrap(library.page("Inside reel"))))
    }

    // MARK: Helpers

    /// Wrestling (skill) holds Shot, the Reel (a tutorial that needs no skills, holding a skill of its own) and the
    /// Drills folder with Sprawl; the Footwork reels (needing no skills) sit at the top and hold Pivot.
    private var pages: [ExercisePage] {
        [
            page("Wrestling", .skill, children: ["Shot", "Reel", "Drills"]),
            page("Shot", .skill, parent: "Wrestling", status: .completed),
            page("Reel", .tutorial, parent: "Wrestling", children: ["Inside reel"], status: .learning, noSkills: true),
            page("Inside reel", .skill, parent: "Reel", status: .completed),
            page("Drills", nil, parent: "Wrestling", children: ["Sprawl"]),
            page("Sprawl", .skill, parent: "Drills", status: .learning),
            page("Footwork reels", .tutorial, children: ["Pivot"], noSkills: true),
            page("Pivot", .skill, parent: "Footwork reels", status: .completed),
        ]
    }

    private func page(
        _ id: String,
        _ type: PageType?,
        parent: String? = nil,
        children: [String] = [],
        status: SkillStatus? = nil,
        noSkills: Bool = false
    ) -> ExercisePage {
        ExercisePage(manifest: ExercisePageManifest(
            id: id,
            title: id,
            pageType: type,
            noSkills: noSkills,
            skillStatus: status,
            childIDs: children,
            parentID: parent
        ))
    }
}
