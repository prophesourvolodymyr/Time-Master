import XCTest
import TimeMasterCore
@testable import TimeMaster

@MainActor
final class QuickPreviewTests: XCTestCase {
    private let squat = UUID()
    private let sprawl = UUID()
    private let shoot = UUID()
    private let stretch = UUID()
    private let wrist = UUID()

    private func page(_ id: UUID, _ title: String, type: PageType? = .exercise) -> ExercisePage {
        ExercisePage(manifest: ExercisePageManifest(
            id: id.uuidString, title: title, pageKind: type == nil ? .container : .leaf, pageType: type
        ))
    }

    private func lookup(_ pages: [ExercisePage]) -> (UUID) -> ExercisePage? {
        let byID = Dictionary(uniqueKeysWithValues: pages.map { ($0.id, $0) })
        return { byID[$0] }
    }

    private func step(_ id: String, block: String) -> QuickPreviewStep {
        QuickPreviewStep(
            id: id, pageID: UUID(), title: id, detail: nil, isRest: false, note: nil,
            blockID: block, blockKind: .single, blockTitle: "Block \(block)"
        )
    }

    private struct Fixture {
        let workout: Workout
        let single: Section
        let bundle: Section
        let first: SetSlot
        let second: SetSlot
        let stretchContent: RestContent
        let noteContent: RestContent
        let children: [SetSlot]
    }

    private func fixture() -> Fixture {
        let first = SetSlot(exercisePageID: squat, name: "Squat", duration: 40, restAfter: 60, restExercisePageID: wrist)
        let second = SetSlot(exercisePageID: squat, name: "Squat", duration: 40, restAfter: 0)
        let stretchContent = RestContent(kind: .stretch, pageID: stretch, text: "")
        let noteContent = RestContent(kind: .note, text: "Shake out")
        let big = RestRow(kind: .big, duration: 45, contents: [stretchContent, noteContent])
        let single = Section(name: "Squats", slots: [first, second], bigRestRow: big)
        let children = [
            SetSlot(exercisePageID: sprawl, name: "Sprawl", duration: 20),
            SetSlot(exercisePageID: shoot, name: "Shoot", duration: 20),
        ]
        let round = SetSlot(name: "Round", restAfter: 0, children: children)
        let bundle = Section(name: "Drills", mode: .bundle, slots: [round])
        return Fixture(
            workout: Workout(name: "Day", sections: [single, bundle]), single: single, bundle: bundle,
            first: first, second: second, stretchContent: stretchContent, noteContent: noteContent, children: children
        )
    }

    private var pages: [ExercisePage] {
        [page(squat, "Squat"), page(sprawl, "Sprawl"), page(shoot, "Shoot"), page(stretch, "Hamstring stretch"), page(wrist, "Wrist circles")]
    }

    func testAWorkoutPreviewsInBuilderOrderWithRestsAndStretchesBetween() {
        let f = fixture()

        let steps = QuickPreviewSteps.steps(for: f.workout, page: lookup(pages))

        XCTAssertEqual(steps.map(\.id), [
            "set-\(f.first.id)",
            "rest-exercise-\(f.first.id.uuidString)",
            "set-\(f.second.id)",
            "rest-content-\(f.stretchContent.id)",
            "rest-content-\(f.noteContent.id)",
            "set-\(f.children[0].id)",
            "set-\(f.children[1].id)",
        ])
        XCTAssertEqual(steps[1].pageID, wrist)
        XCTAssertTrue(steps[1].isRest)
        XCTAssertTrue(steps[1].detail?.contains("1:00") == true)
        XCTAssertEqual(steps[3].title, "Hamstring stretch")
        XCTAssertEqual(steps[4].note, "Shake out")
        XCTAssertNil(steps[4].pageID)
    }

    func testEveryStepKnowsItsBlockAndWhetherItIsASingleExerciseOrABundle() {
        let f = fixture()

        let steps = QuickPreviewSteps.steps(for: f.workout, page: lookup(pages))

        XCTAssertEqual(steps.prefix(5).map(\.blockKind), Array(repeating: .single, count: 5))
        XCTAssertEqual(steps.suffix(2).map(\.blockKind), [.bundle, .bundle])
        XCTAssertEqual(Set(steps.prefix(5).map(\.blockID)), [f.single.id.uuidString])
        XCTAssertEqual(steps.map(\.blockNumber), [1, 1, 1, 1, 1, 2, 2])
        XCTAssertTrue(steps.allSatisfy { $0.blockCount == 2 })
        XCTAssertEqual(steps.last?.blockTitle, "Drills")
        XCTAssertTrue(steps.last?.detail?.hasPrefix("Round 1 of 1") == true)
    }

    func testARestWithNothingToShowAddsNoStep() {
        let plain = Section(name: "Plank", slots: [SetSlot(exercisePageID: squat, name: "Plank", duration: 30, restAfter: 30)])

        let steps = QuickPreviewSteps.steps(for: Workout(name: "Core", sections: [plain]), page: lookup(pages))

        XCTAssertEqual(steps.count, 1)
    }

    func testEveryRestExerciseChoiceGetsAStepWithTheDefaultFirst() {
        var first = SetSlot(exercisePageID: squat, name: "Squat", duration: 40, restAfter: 60)
        first.restExercisePageIDs = [wrist, stretch]
        let section = Section(name: "Squats", slots: [first, SetSlot(exercisePageID: squat, name: "Squat", duration: 40, restAfter: 0)])

        let steps = QuickPreviewSteps.steps(for: Workout(name: "Legs", sections: [section]), page: lookup(pages))

        XCTAssertEqual(steps.map(\.title), ["Squat", "Rest exercise: Wrist circles", "Rest option: Hamstring stretch", "Squat"])
        XCTAssertEqual(steps.filter(\.isRest).map(\.pageID), [wrist, stretch])
        XCTAssertEqual(steps[1].id, "rest-exercise-\(first.id.uuidString)")
        XCTAssertEqual(Set(steps.map(\.id)).count, steps.count)
    }

    func testATapFindsItsStepByRowKeySectionOrPage() {
        let f = fixture()
        let steps = QuickPreviewSteps.steps(for: f.workout, page: lookup(pages))

        XCTAssertEqual(QuickPreviewSteps.index(of: "set-\(f.second.id)", pageID: squat, in: steps), 2)
        XCTAssertEqual(QuickPreviewSteps.index(of: "section-\(f.bundle.id)", pageID: nil, in: steps), 5)
        XCTAssertEqual(QuickPreviewSteps.index(of: nil, pageID: shoot, blockID: f.bundle.id.uuidString, in: steps), 6)
        XCTAssertNil(QuickPreviewSteps.index(of: nil, pageID: UUID(), in: steps))
    }

    func testTheLibraryPreviewsContentPagesOnly() {
        let list = [page(squat, "Squat"), page(UUID(), "Notes", type: .note), page(UUID(), "Folder", type: nil), page(stretch, "Stretch", type: .skill)]

        let steps = QuickPreviewSteps.steps(for: list)

        XCTAssertEqual(steps.map(\.pageID), [squat, stretch])
        XCTAssertTrue(steps.allSatisfy { $0.blockKind == .library })
    }

    func testSteppingAcrossABlockSaysSoAndStaysInsideTheList() {
        let controller = QuickPreviewController()
        controller.present([step("a", block: "1"), step("b", block: "1"), step("c", block: "2")], at: 0)

        controller.move(1)
        XCTAssertNil(controller.crossing, "inside one block")
        controller.move(1)
        XCTAssertEqual(controller.crossing?.blockID, "2")
        XCTAssertEqual(controller.direction, 1)
        controller.move(1)
        XCTAssertEqual(controller.index, 2, "no step past the end")
        XCTAssertFalse(controller.canGoForward)
        controller.move(-1)
        XCTAssertEqual(controller.index, 1)
        XCTAssertEqual(controller.crossing?.blockID, "1")
        XCTAssertEqual(controller.direction, -1)

        controller.close()
        XCTAssertNil(controller.step)
    }

    func testPresentingNeedsAStepToShow() {
        let controller = QuickPreviewController()

        controller.present([], at: 0)
        controller.present([step("a", block: "1")], at: 3)

        XCTAssertFalse(controller.isPresented)
    }
}
