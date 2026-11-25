import XCTest
@testable import TimeMaster

final class WidgetPaletteRulesTests: XCTestCase {
    func testAnyTypeColourBecomesAnAllowedPaletteTint() {
        XCTAssertEqual(WidgetTint.forTypeColor(hex: "007AFF"), .peach, "blue")
        XCTAssertEqual(WidgetTint.forTypeColor(hex: "#5AC8FA"), .peach, "light blue")
        XCTAssertEqual(WidgetTint.forTypeColor(hex: "34C759"), .peach, "green")
        XCTAssertEqual(WidgetTint.forTypeColor(hex: "C2DF7A"), .peach, "lime")
        XCTAssertEqual(WidgetTint.forTypeColor(hex: "AF52DE"), .peach, "purple")
        XCTAssertEqual(WidgetTint.forTypeColor(hex: "D4B7F6"), .peach, "lilac")
        XCTAssertEqual(WidgetTint.forTypeColor(hex: "30B0C7"), .peach, "teal")
        XCTAssertEqual(WidgetTint.forTypeColor(hex: "FF3B30"), .orange, "red")
        XCTAssertEqual(WidgetTint.forTypeColor(hex: "FF9500"), .orange, "orange")
        XCTAssertEqual(WidgetTint.forTypeColor(hex: "FFCC00"), .orange, "yellow")
        XCTAssertEqual(WidgetTint.forTypeColor(hex: "FF2D55"), .orange, "pink")
        XCTAssertEqual(WidgetTint.forTypeColor(hex: "FFFFFF"), .graphite, "white")
        XCTAssertEqual(WidgetTint.forTypeColor(hex: "1C1C1E"), .graphite, "near black")
        XCTAssertEqual(WidgetTint.forTypeColor(hex: "not a colour"), .graphite)
        XCTAssertEqual(Set(WidgetTint.allCases), [.graphite, .orange, .peach])
    }

    func testAWorkoutTypeShowsItsObjectNotItsHue() {
        let gymnastics = WidgetArt.forWorkout(type: "Gymnastics", symbol: "figure.gymnastics")
        XCTAssertEqual(gymnastics, .gymRings)
        XCTAssertEqual(gymnastics.tint, .orange)
        XCTAssertEqual(WidgetArt.forWorkout(type: "Wrestling", symbol: "figure.wrestling"), .boxingGlove)
        XCTAssertEqual(WidgetArt.forWorkout(type: "Yoga", symbol: "figure.mind.and.body").tint, .peach)
        for art in WidgetArt.allCases {
            XCTAssertTrue([WidgetTint.graphite, .orange, .peach].contains(art.tint), "\(art) sits on an allowed card colour")
        }
    }

    func testArchivedWorkoutsAreNeverSuggested() {
        XCTAssertTrue(WorkoutTitle.isArchived("v1 · W2 Wed PM · Wrestling technique + mobility"))
        XCTAssertTrue(WorkoutTitle.isArchived("V2 · Legs"))
        XCTAssertTrue(WorkoutTitle.isArchived("Legs", groupTitle: "v1 · Week 2 · Foundation"))
        XCTAssertTrue(WorkoutTitle.isArchived("Legs", groupTitle: "Archive"))
        XCTAssertTrue(WorkoutTitle.isArchived("Legs", groupTitle: "Old camp (archived)"))
        XCTAssertFalse(WorkoutTitle.isArchived("W2 Wed PM · Wrestling technique"))
        XCTAssertFalse(WorkoutTitle.isArchived("Legs", groupTitle: "Week 1 · Foundation"))
        XCTAssertFalse(WorkoutTitle.isArchived("Vortex · Core"))
        XCTAssertFalse(WorkoutTitle.isArchived("v1"))

        let library = ["v1 · W8 Wed AM · D-3: Handstand taper", "v1 · W2 Wed PM · Wrestling technique", "W1 Mon AM · Boxing basics", "Legs"]
        XCTAssertEqual(library.first { !WorkoutTitle.isArchived($0) }, "W1 Mon AM · Boxing basics")
    }

    func testPlanCodesAreTrimmedFromTheTitleOnly() {
        XCTAssertEqual(WorkoutTitle.short("v1 · W2 Wed PM · Wrestling technique + mobility"), "Wrestling technique + mobility")
        XCTAssertEqual(WorkoutTitle.short("W8 Wed AM · D-3: Handstand taper"), "D-3: Handstand taper")
        XCTAssertEqual(WorkoutTitle.short("W1 Mon AM · Boxing · Plyos A"), "Boxing · Plyos A")
        XCTAssertEqual(WorkoutTitle.short("Morning HIIT"), "Morning HIIT")
        XCTAssertEqual(WorkoutTitle.short("Week 1 · Foundation"), "Week 1 · Foundation")
        XCTAssertEqual(WorkoutTitle.short("W2 Wed PM"), "W2 Wed PM")
    }
}
