import XCTest
import TimeMasterCore
@testable import TimeMaster

final class SkillCategoryTests: XCTestCase {
    func testRootFolderTitlesNameTheirCategoryIgnoringCase() {
        let expected: [String: SkillCategory] = [
            "Calisthenics": .calisthenics,
            "kir_martysiuk — Mobility & Calisthenics": .calisthenics,
            "Boxing": .boxing,
            "Kickboxing": .boxing,
            "Wrestling": .wrestling,
            "Core & Wrestling": .wrestling,
            "Gymnastics": .gymnastics,
            "GYMNASTIC rings": .gymnastics,
            "Cardio": .other,
            "Core": .other,
            "Lower Body": .other,
            "Upper Body": .other,
            "Mobility & Flexibility": .other,
            "Strength & Conditioning": .other,
            "8-Week Camp": .other,
            "Knowledge": .other,
            "": .other
        ]
        for (title, category) in expected {
            XCTAssertEqual(SkillCategory(rootTitle: title), category, title)
        }
    }

    func testAFolderNamingTwoCategoriesTakesTheFirstInPageOrder() {
        XCTAssertEqual(SkillCategory(rootTitle: "Wrestling for Boxing"), .boxing)
        XCTAssertEqual(SkillCategory(rootTitle: "Gymnastics & Calisthenics"), .calisthenics)
    }

    func testASkillTakesTheCategoryOfItsRootFolderNotOfItsOwnTitle() {
        let wrestling = page("Core & Wrestling")
        let takedowns = page("Takedowns", in: wrestling)
        let doubleLeg = page("Double Leg Takedown", type: .skill, in: takedowns)
        let camp = page("8-Week Camp")
        let campBoxing = page("Boxing: Zero to Fight-Ready", type: .skill, in: camp)
        let topLevelBoxing = page("Boxing: Zero to Fight-Ready", type: .skill)
        let index = PageIndex(pages: [wrestling, takedowns, doubleLeg, camp, campBoxing, topLevelBoxing])

        XCTAssertEqual(SkillCategory.root(of: doubleLeg, in: index).manifest.id, wrestling.manifest.id)
        XCTAssertEqual(SkillCategory.of(doubleLeg, in: index), .wrestling)
        XCTAssertEqual(SkillCategory.of(campBoxing, in: index), .other, "the root folder decides, not the skill's title")
        XCTAssertEqual(SkillCategory.of(topLevelBoxing, in: index), .boxing, "a skill at the top level is its own root")
    }

    func testAMissingOrLoopingParentChainStillEnds() {
        let orphan = page("Underhook", type: .skill, parentID: UUID().uuidString)
        let firstID = UUID().uuidString
        let secondID = UUID().uuidString
        let first = page("Gymnastics", id: firstID, parentID: secondID)
        let second = page("Boxing", id: secondID, parentID: firstID)
        let index = PageIndex(pages: [orphan, first, second])

        XCTAssertEqual(SkillCategory.root(of: orphan, in: index).manifest.id, orphan.manifest.id)
        XCTAssertEqual(SkillCategory.of(orphan, in: index), .other)
        XCTAssertEqual(SkillCategory.root(of: first, in: index).manifest.id, secondID, "the walk stops where it loops")
        XCTAssertEqual(SkillCategory.of(first, in: index), .boxing)
    }

    func testSectionsComeInPageOrderKeepTheGivenOrderAndLeaveEmptyOnesOut() {
        let calisthenics = page("Calisthenics")
        let kickboxing = page("Kickboxing")
        let knowledge = page("Knowledge")
        let planche = page("Planche", type: .skill, in: calisthenics)
        let handstand = page("Handstand", type: .skill, in: calisthenics)
        let jab = page("Jab", type: .skill, in: kickboxing)
        let pacing = page("Pacing", type: .tutorial, in: knowledge)
        let index = PageIndex(pages: [calisthenics, kickboxing, knowledge, planche, handstand, jab, pacing])

        let sections = SkillShelf.sections(of: [pacing, planche, jab, handstand].map(entry), index: index)

        XCTAssertEqual(sections.map(\.category), [.calisthenics, .boxing, .other])
        XCTAssertEqual(sections.map { $0.entries.map(\.page.title) }, [["Planche", "Handstand"], ["Jab"], ["Pacing"]])
    }

    func testSortingBeforeGroupingSortsEverySection() {
        let wrestling = page("Wrestling")
        let gymnastics = page("Gymnastics")
        let skills = [
            page("Underhook", type: .skill, in: wrestling),
            page("Ring muscle-up", type: .skill, in: gymnastics),
            page("Double Leg Takedown", type: .skill, in: wrestling),
            page("Back lever", type: .skill, in: gymnastics)
        ]
        let index = PageIndex(pages: [wrestling, gymnastics] + skills)

        let sections = SkillShelf.sections(of: SkillSortOption.name.ordered(skills.map(entry)), index: index)

        XCTAssertEqual(sections.map(\.category), [.wrestling, .gymnastics])
        XCTAssertEqual(
            sections.map { $0.entries.map(\.page.title) },
            [["Double Leg Takedown", "Underhook"], ["Back lever", "Ring muscle-up"]]
        )
    }

    func testPagesFlaggedNoSkillsAreNotListed() {
        let reel = page("Lateral switch step", type: .tutorial, noSkills: true)
        let skill = page("Double Leg Takedown", type: .skill)

        XCTAssertEqual(SkillShelf.listed([reel, skill].map(entry)).map(\.page.title), ["Double Leg Takedown"])
    }

    func testOnlyASkillWithNothingBelowItHasEmptyProgress() {
        XCTAssertTrue(SkillProgress(counting: []).isEmpty)
        let abandoned = SkillProgress(counting: [page("Spinning back fist", type: .skill, status: .abandoned)])
        XCTAssertFalse(abandoned.isEmpty, "abandoned sub-skills still say something")
        XCTAssertEqual(abandoned.summary, "1 abandoned")
        XCTAssertFalse(SkillProgress(counting: [page("Jab", type: .skill)]).isEmpty)
    }

    // MARK: Helpers

    private func page(
        _ title: String,
        type: PageType? = nil,
        id: String = UUID().uuidString,
        parentID: String? = nil,
        noSkills: Bool = false,
        status: SkillStatus? = nil
    ) -> ExercisePage {
        ExercisePage(manifest: ExercisePageManifest(
            id: id,
            title: title,
            pageType: type,
            noSkills: noSkills,
            skillStatus: status,
            parentID: parentID
        ))
    }

    private func page(_ title: String, type: PageType? = nil, in parent: ExercisePage) -> ExercisePage {
        page(title, type: type, parentID: parent.manifest.id)
    }

    private func entry(_ page: ExercisePage) -> SkillLibraryEntry {
        SkillLibraryEntry(page: page, progress: SkillProgress(), lastChange: Date(timeIntervalSince1970: 0))
    }
}
