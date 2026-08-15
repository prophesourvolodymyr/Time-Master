import XCTest
@testable import TimeMasterCore

final class WorkoutPreparationTests: XCTestCase {
    func testSetSlotPreparationRoundTripsNilZeroAndPositiveValues() throws {
        let slots = [
            WorkoutSetSlotManifest(id: "inherit", exerciseID: "exercise", name: "Inherit", prepareTime: nil),
            WorkoutSetSlotManifest(id: "removed", exerciseID: "exercise", name: "Removed", prepareTime: 0),
            WorkoutSetSlotManifest(id: "custom", exerciseID: "exercise", name: "Custom", prepareTime: 12),
        ]

        let decoded = try JSONDecoder().decode(
            [WorkoutSetSlotManifest].self,
            from: JSONEncoder().encode(slots)
        )

        XCTAssertNil(decoded[0].prepareTime)
        XCTAssertEqual(decoded[1].prepareTime, 0)
        XCTAssertEqual(decoded[2].prepareTime, 12)
    }

    func testOldSlotWithoutPreparationInheritsSectionDefault() throws {
        let data = try XCTUnwrap(
            """
            {"id":"legacy","exerciseID":"exercise","name":"Legacy","duration":30,"restAfter":10}
            """.data(using: .utf8)
        )
        let slot = try JSONDecoder().decode(WorkoutSetSlotManifest.self, from: data)
        let section = WorkoutSectionManifest(
            exerciseID: "exercise",
            name: "Legacy section",
            prepareTime: 4,
            slots: [slot]
        )

        XCTAssertNil(slot.prepareTime)
        XCTAssertEqual(slot.prepareTime ?? section.prepareTime, 4)
    }

    func testTotalDurationCountsPreparationDropsAndRestWithoutBundleWork() {
        let timedSlot = WorkoutSetSlotManifest(
            id: "timed",
            exerciseID: "timed-exercise",
            name: "Timed",
            duration: 10,
            restAfter: 8,
            prepareTime: nil,
            drops: [
                WorkoutDropSetManifest(
                    id: "timed-drop",
                    exerciseID: "drop-exercise",
                    name: "Drop",
                    duration: 5,
                    restAfter: 3
                ),
            ]
        )
        let removedPreparationSlot = WorkoutSetSlotManifest(
            id: "removed-preparation",
            exerciseID: "timed-exercise",
            name: "Removed preparation",
            duration: 12,
            restAfter: 0,
            prepareTime: 0
        )
        let bundleSlot = WorkoutSetSlotManifest(
            id: "bundle",
            exerciseID: "bundle-exercise",
            name: "Bundle",
            duration: 20,
            restAfter: 5,
            prepareTime: nil,
            drops: [
                WorkoutDropSetManifest(
                    id: "bundle-drop",
                    exerciseID: "bundle-drop-exercise",
                    name: "Bundle drop",
                    duration: 7,
                    restAfter: 2
                ),
            ]
        )
        let bundleRemovedPreparationSlot = WorkoutSetSlotManifest(
            id: "bundle-removed-preparation",
            exerciseID: "bundle-exercise",
            name: "Bundle removed preparation",
            duration: 20,
            restAfter: 0,
            prepareTime: 0
        )
        let manifest = WorkoutManifest(
            id: "workout",
            name: "Preparation duration",
            sections: [
                WorkoutSectionManifest(
                    exerciseID: "timed-exercise",
                    name: "Timed section",
                    prepareTime: 4,
                    mode: .timed,
                    slots: [timedSlot, removedPreparationSlot],
                    bigRestRow: WorkoutRestRowManifest(kind: .big, duration: 7)
                ),
                WorkoutSectionManifest(
                    exerciseID: "bundle-exercise",
                    name: "Bundle section",
                    prepareTime: 3,
                    mode: .bundle,
                    slots: [bundleSlot, bundleRemovedPreparationSlot],
                    bigRestRow: WorkoutRestRowManifest(kind: .big, duration: 4)
                ),
            ],
            restBetweenSections: 0
        )

        XCTAssertEqual(manifest.totalDuration, 63)
    }

    func testPageDropTemplatesRemainBoundToTheirSetIndex() throws {
        let page = ExercisePageManifest(
            id: "page",
            title: "Exercise",
            pageKind: .leaf,
            duration: 30,
            dropSetTemplates: [
                PageDropSetTemplate(
                    id: "first-set-drop",
                    setIndex: 0,
                    exerciseID: "drop-a",
                    name: "First set drop",
                    duration: 10,
                    restAfter: 2
                ),
                PageDropSetTemplate(
                    id: "second-set-drop",
                    setIndex: 1,
                    exerciseID: "drop-b",
                    name: "Second set drop",
                    duration: 15,
                    restAfter: 3
                ),
            ]
        )

        let decoded = try JSONDecoder().decode(
            ExercisePageManifest.self,
            from: JSONEncoder().encode(page)
        )
        let templatesBySet = Dictionary(grouping: decoded.dropSetTemplates, by: \.setIndex)

        XCTAssertEqual(templatesBySet[0]?.map(\.id), ["first-set-drop"])
        XCTAssertEqual(templatesBySet[1]?.map(\.id), ["second-set-drop"])
    }
    func testExercisePagePreparationRoundTripsAndLegacyPagesRemainNil() throws {
        let page = ExercisePageManifest(
            id: "page-with-preparation",
            title: "Prepared exercise",
            pageKind: .leaf,
            duration: 30,
            prepareTime: 12
        )

        let decoded = try JSONDecoder().decode(
            ExercisePageManifest.self,
            from: JSONEncoder().encode(page)
        )
        XCTAssertEqual(decoded.prepareTime, 12)

        let legacyData = try XCTUnwrap(
            """
            {"id":"legacy-page","title":"Legacy exercise","duration":30}
            """.data(using: .utf8)
        )
        let legacy = try JSONDecoder().decode(ExercisePageManifest.self, from: legacyData)
        XCTAssertNil(legacy.prepareTime)
    }
    func testTotalDurationSkipsTerminalSetRestAndDeletedSectionRest() {
        let manifest = WorkoutManifest(
            id: "terminal-rest",
            name: "Terminal rest",
            sections: [
                WorkoutSectionManifest(
                    exerciseID: "exercise",
                    name: "Two sets",
                    duration: 10,
                    prepareTime: 0,
                    customRestAfter: 0,
                    slots: [
                        WorkoutSetSlotManifest(
                            id: "first",
                            exerciseID: "exercise",
                            name: "First",
                            duration: 10,
                            restAfter: 8,
                            prepareTime: 0
                        ),
                        WorkoutSetSlotManifest(
                            id: "last",
                            exerciseID: "exercise",
                            name: "Last",
                            duration: 10,
                            restAfter: 13,
                            prepareTime: 0
                        ),
                    ]
                ),
            ],
            restBetweenSections: 30
        )

        XCTAssertEqual(manifest.totalDuration, 28)
    }

    func testDeletedBigRestRoundTripsAsAbsentWithExplicitZero() throws {
        let section = WorkoutSectionManifest(
            id: "section",
            exerciseID: "exercise",
            name: "No section rest",
            customRestAfter: 0,
            bigRestRow: nil
        )

        let decoded = try JSONDecoder().decode(
            WorkoutSectionManifest.self,
            from: JSONEncoder().encode(section)
        )

        XCTAssertEqual(decoded.customRestAfter, 0)
        XCTAssertNil(decoded.bigRestRow)
    }
}
