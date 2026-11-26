import XCTest
import CoreGraphics
@testable import TimeMaster

final class PageWheelGeometryTests: XCTestCase {
    private let wheel = PageWheelGeometry(count: 12, center: CGPoint(x: 200, y: 400), radius: 160, hubRadius: 54)

    func testTheSliceAtTheTopIsTheRotationAndTheOthersFollowClockwise() {
        XCTAssertEqual(wheel.top(rotation: 3), 3)
        XCTAssertEqual(wheel.top(rotation: 2.6), 3)
        XCTAssertEqual(wheel.top(rotation: -1), 11)
        XCTAssertEqual(wheel.slice(at: CGPoint(x: 200, y: 280), rotation: 3), 3, "straight up is the top slice")
        XCTAssertEqual(wheel.slice(at: CGPoint(x: 320, y: 400), rotation: 3), 6, "three o'clock is a quarter turn on")
        XCTAssertEqual(wheel.slice(at: CGPoint(x: 80, y: 400), rotation: 3), 0, "nine o'clock is a quarter turn back")
        XCTAssertEqual(wheel.slice(at: CGPoint(x: 200, y: 520), rotation: 3), 9, "the bottom wraps around")
    }

    func testThePressOnTheHubNamesNoSlice() {
        XCTAssertNil(wheel.slice(at: CGPoint(x: 210, y: 390), rotation: 0))
        XCTAssertNotNil(wheel.slice(at: CGPoint(x: 200, y: 300), rotation: 0))
    }

    func testBringingASliceToTheTopTakesTheShortWayRound() {
        XCTAssertEqual(wheel.rotation(bringing: 11, near: 0), -1)
        XCTAssertEqual(wheel.rotation(bringing: 2, near: 11), 14)
        XCTAssertEqual(wheel.rotation(bringing: 5, near: 5.4), 5, accuracy: 0.0001)
        XCTAssertEqual(wheel.offset(of: 6, rotation: 0), -6, "the slice opposite the top sits half a turn away")
    }

    func testTurningClockwiseBringsTheEarlierSlicesUp() {
        let start = wheel.point(angle: 0, distance: 120)
        let end = wheel.point(angle: wheel.spacing, distance: 120)
        XCTAssertEqual(wheel.slices(turnedFrom: start, to: end), -1, accuracy: 0.0001)
        let across = wheel.point(angle: -.pi + 0.1, distance: 120)
        let back = wheel.point(angle: .pi - 0.1, distance: 120)
        XCTAssertEqual(wheel.slices(turnedFrom: across, to: back), 0.2 / wheel.spacing, accuracy: 0.0001,
                       "crossing the bottom of the wheel is a small turn, not a full one")
    }

    func testTheArcIsTheTopOfTheShrinkingCircleAndTheWheelIsItsEnd() {
        let circle = PageWheelMorph.arcCircle(width: 390, peak: CGPoint(x: 195, y: 700), sag: 43)
        XCTAssertEqual(circle.center.y - circle.radius, 700, accuracy: 0.001)
        XCTAssertEqual(circle.radius, (195 * 195 + 43 * 43) / 86, accuracy: 0.001)
        let morph = PageWheelMorph(count: 12, arcCenter: circle.center, arcRadius: circle.radius, arcPitch: 86, arcInset: 18,
                                   wheelCenter: CGPoint(x: 195, y: 330), wheelRadius: 165)
        let start = morph.geometry(at: 0)
        XCTAssertEqual(start.center.y - start.radius, 700, accuracy: 0.001, "at rest the circle's top is the arc line")
        XCTAssertEqual(start.hubRadius, 0, accuracy: 0.001)
        XCTAssertEqual(start.spacing * (start.radius - 18), 86, accuracy: 0.001, "pages keep the bar's spacing")
        let end = morph.geometry(at: 1)
        XCTAssertEqual(end.center.x, 195, accuracy: 0.001)
        XCTAssertEqual(end.center.y, 330, accuracy: 0.001)
        XCTAssertEqual(end.radius, 165, accuracy: 0.001)
        XCTAssertEqual(end.spacing, 2 * .pi / 12, accuracy: 0.0001)
        let middle = morph.geometry(at: 0.5)
        XCTAssertLessThan(middle.radius, start.radius)
        XCTAssertGreaterThan(middle.radius, end.radius)
        XCTAssertLessThan(middle.center.y - middle.radius, 700)
    }

    func testTheSearchLayoutZoomsTheWheelAboveTheKeyboard() {
        let bounds = CGRect(x: 0, y: 0, width: 393, height: 760)
        let resting = PageWheelLayout(bounds: bounds, searching: false, keyboardUp: false)
        let typing = PageWheelLayout(bounds: CGRect(x: 0, y: 0, width: 393, height: 457), searching: true, keyboardUp: true)
        XCTAssertGreaterThan(typing.radius, resting.radius, "the wheel grows while typing")
        XCTAssertLessThan(typing.searchBar.maxY, 457, "the field stays above the keyboard")
        XCTAssertLessThan(typing.center.y, typing.searchBar.minY, "the wheel sits above the field")
        XCTAssertGreaterThan(typing.bubble.height, 60, "there is room for the bubble above the wheel")
        XCTAssertGreaterThan(resting.searchBar.minY, resting.center.y + resting.radius, "the field sits below the wheel")
    }
}

final class PageWheelSpinTests: XCTestCase {
    func testAFlickCoastsOnAndRestsExactlyOnASlice() {
        var spin = PageWheelSpin(rotation: 2)
        var time = 10.0
        spin.grab(at: time)
        for _ in 0..<8 {
            time += 1.0 / 120
            spin.track(by: 0.12, at: time)
        }
        spin.release(at: time + 0.001)
        XCTAssertEqual(spin.phase, .settling)
        let target = try? XCTUnwrap(spin.target)
        XCTAssertGreaterThan(target ?? 0, spin.rotation, "the wheel carries on the way it was turned")
        var frames = 0
        while spin.step(by: 1.0 / 120), frames < 2000 { frames += 1 }
        XCTAssertEqual(spin.phase, .resting)
        XCTAssertEqual(spin.rotation, spin.rotation.rounded(), "it rests with a slice at the top")
        XCTAssertEqual(spin.rotation, target ?? -1)
    }

    func testAPausedFingerLetsGoWithoutCoasting() {
        var spin = PageWheelSpin(rotation: 0)
        spin.grab(at: 1)
        spin.track(by: 0.4, at: 1.01)
        spin.track(by: 0.3, at: 1.02)
        spin.release(at: 1.5)
        XCTAssertEqual(spin.target, 1, "a still finger lands on the nearest slice")
    }

    func testSettlingOnASliceTurnsTheWheelThere() {
        var spin = PageWheelSpin(rotation: 4)
        spin.settle(on: 7)
        while spin.step(by: 1.0 / 60) {}
        XCTAssertEqual(spin.rotation, 7)
        spin.place(-2)
        XCTAssertEqual(spin.rotation, -2)
        XCTAssertEqual(spin.phase, .resting)
    }
}

final class NavigationSearchTests: XCTestCase {
    private let weekOne = UUID()
    private let mondayAM = UUID()
    private let mondayPM = UUID()

    private var index: NavigationSearchIndex {
        let group = NavigationSearchCrumb(id: "group:\(weekOne)", title: "Week 1 · Foundation",
                                          symbol: "square.stack.3d.up.fill", target: .workoutGroup(weekOne))
        let folder = NavigationSearchCrumb(id: "library:calisthenics", title: "Calisthenics", symbol: "folder.fill",
                                           target: .libraryPage("calisthenics", destination: .database))
        return NavigationSearchIndex(entries: [
            NavigationSearchEntry(id: "page:workouts", target: .page(.workouts), title: "Workouts", detail: "Page",
                                  symbol: "figure", aliases: ["Training"], weight: 1.3),
            NavigationSearchEntry(id: "page:coach", target: .page(.coach), title: "AI Coach", detail: "Page",
                                  symbol: "sparkles", aliases: ["Chat", "Assistant"], weight: 1.3),
            NavigationSearchEntry(id: "page:schedule", target: .page(.schedule), title: "Schedule", detail: "Page",
                                  symbol: "calendar", weight: 1.3),
            NavigationSearchEntry(id: "group:\(weekOne)", target: .workoutGroup(weekOne), title: "Week 1 · Foundation",
                                  detail: "2 workouts", symbol: "square.stack.3d.up.fill", hasChildren: true, weight: 1.05),
            NavigationSearchEntry(id: "workout:\(mondayAM)", target: .workout(mondayAM), title: "W1 Mon AM · Gymnastics",
                                  detail: "Workout", symbol: "figure", trail: [group], weight: 1.1),
            NavigationSearchEntry(id: "workout:\(mondayPM)", target: .workout(mondayPM), title: "W1 Mon PM · Boxing",
                                  detail: "Workout", symbol: "figure", trail: [group], weight: 1.1),
            NavigationSearchEntry(id: "library:planche", target: .libraryPage("planche", destination: .database),
                                  title: "Tuck Planché Hold", detail: "Exercise", symbol: "figure", trail: [folder])
        ])
    }

    func testANameOrAWordForAPageTurnsTheWheelToThatPage() {
        XCTAssertEqual(index.search("sched").destination, .schedule)
        XCTAssertEqual(index.search("chat").destination, .coach)
        XCTAssertEqual(index.search("Workouts").best?.id, "page:workouts")
        XCTAssertTrue(index.search("sched").tree.isEmpty, "a page match needs no bubble")
    }

    func testAWorkoutTurnsTheWheelToWorkoutsAndShowsWhereItLivesAsATree() {
        let results = index.search("w1 mon")
        XCTAssertEqual(results.destination, .workouts)
        XCTAssertEqual(results.tree.map(\.title), ["Workouts"])
        let section = try? XCTUnwrap(results.tree.first?.children.first)
        XCTAssertEqual(section?.title, "Week 1 · Foundation")
        XCTAssertEqual(Set(section?.children.map(\.title) ?? []), ["W1 Mon AM · Gymnastics", "W1 Mon PM · Boxing"])
        XCTAssertTrue(section?.children.allSatisfy(\.isMatch) ?? false)
    }

    func testAccentsCaseAndPunctuationDoNotMatter() {
        XCTAssertEqual(NavigationSearchIndex.normalize("Tuck  Planché—Hold!"), "tuck planche hold")
        XCTAssertEqual(index.search("PLANCHE").best?.id, "library:planche")
        XCTAssertEqual(index.search("planche").destination, .database)
    }

    func testLettersInOrderFindTheirPageWhenNothingBetterMatches() {
        XCTAssertEqual(index.search("tph").best?.id, "library:planche")
        XCTAssertNil(index.search("zzz").best)
        XCTAssertTrue(index.search("   ").isEmpty)
    }

    func testAnExactNameBeatsAPrefixAndAPrefixBeatsAWordInside() {
        let exact = NavigationSearchIndex.score("schedule", tokens: ["schedule"], in: "schedule") ?? 0
        let prefix = NavigationSearchIndex.score("sched", tokens: ["sched"], in: "schedule") ?? 0
        let word = NavigationSearchIndex.score("mon", tokens: ["mon"], in: "w1 mon am") ?? 0
        let inside = NavigationSearchIndex.score("edul", tokens: ["edul"], in: "schedule") ?? 0
        XCTAssertGreaterThan(exact, prefix)
        XCTAssertGreaterThan(prefix, word)
        XCTAssertGreaterThan(word, inside)
    }
}

@MainActor
final class PageDeckTests: XCTestCase {
    private let order = ["coach", "profile", "workouts", "home", "database"]

    func testScrubbingTheBarSlidesTheTwoPagesAroundThePosition() {
        let deck = PageDeck(page: "workouts")
        deck.scrub(to: 2.25, order: order)
        XCTAssertEqual(deck.left, "workouts")
        XCTAssertEqual(deck.right, "home")
        XCTAssertEqual(deck.split, 0.25, accuracy: 0.0001)
        XCTAssertEqual(deck.place(of: "workouts") ?? 0, -0.25, accuracy: 0.0001)
        XCTAssertEqual(deck.place(of: "home") ?? 0, 0.75, accuracy: 0.0001)
        XCTAssertNil(deck.place(of: "coach"))
        XCTAssertEqual(deck.target, "workouts")
        deck.scrub(to: 2.7, order: order)
        XCTAssertEqual(deck.target, "home", "the page nearest the bar's centre is the one the deck heads for")
        deck.scrub(to: -0.5, order: order)
        XCTAssertEqual(deck.left, "coach")
        XCTAssertNil(deck.right)
        XCTAssertLessThan(deck.split, 0, "past the first page the page only leans")
    }

    func testAnEdgeDragBringsTheNeighbourInFromItsSide() {
        let deck = PageDeck(page: "workouts")
        deck.beginDrag(to: "profile", direction: -1)
        XCTAssertEqual(deck.left, "profile")
        XCTAssertEqual(deck.right, "workouts")
        deck.drag(fraction: 0.4)
        XCTAssertEqual(deck.place(of: "profile") ?? 0, -0.6, accuracy: 0.0001)
        XCTAssertEqual(deck.place(of: "workouts") ?? 0, 0.4, accuracy: 0.0001)
    }

    func testGoingToAPageShowsItsShellBuildsItAndLetsTheOldPageGo() async throws {
        let deck = PageDeck(page: "workouts")
        var rested: [String] = []
        deck.onRest = { rested.append($0) }
        deck.go(to: "database", order: order)
        XCTAssertEqual(deck.target, "database")
        XCTAssertFalse(deck.revealed.contains("database"), "the new page starts as its shell")
        XCTAssertEqual(deck.roster.live, ["workouts"], "nothing is built at the first frame")
        try await Task.sleep(nanoseconds: 600_000_000)
        XCTAssertEqual(rested, ["database"])
        XCTAssertEqual(deck.roster.live, ["database"], "the page left behind is let go")
        XCTAssertEqual(deck.left, "database")
        XCTAssertNil(deck.right)
        XCTAssertTrue(deck.isResting)
    }
}

@MainActor
final class SlotReelWheelPullTests: XCTestCase {
    private func event(_ phase: SlotReelScrollEvent.Phase, dx: CGFloat = 0, dy: CGFloat = 0, at time: TimeInterval,
                       inside: Bool = true, inverted: Bool = true) -> SlotReelScrollEvent {
        SlotReelScrollEvent(phase: phase, deltaX: dx, deltaY: dy, time: time, inside: inside, inverted: inverted)
    }

    func testTwoFingersSwipingUpOverTheBarPullTheWheelAndSwallowTheScroll() {
        let reel = SlotReel(count: 6, slot: 2)
        var pulls: [SlotReelWheelPull] = []
        var router = SlotReelScrollRouter()
        router.onWheelPull = { pulls.append($0) }
        var time: TimeInterval = 10
        XCTAssertFalse(router.route(event(.began, dy: -3, at: time), reel: reel, pitch: 90))
        time += 0.01
        XCTAssertTrue(router.route(event(.changed, dy: -6, at: time), reel: reel, pitch: 90))
        time += 0.01
        XCTAssertTrue(router.route(event(.changed, dy: -10, at: time), reel: reel, pitch: 90))
        XCTAssertTrue(router.route(event(.ended, at: time + 0.01), reel: reel, pitch: 90))
        XCTAssertEqual(pulls.first, .began)
        XCTAssertEqual(pulls.last, .ended(19))
        XCTAssertEqual(reel.position, 2, "the strip did not move")
    }

    func testTheSwipeIsReadFromTheFingersWhateverTheScrollDirectionSetting() {
        let reel = SlotReel(count: 6, slot: 2)
        var pulls: [SlotReelWheelPull] = []
        var router = SlotReelScrollRouter()
        router.onWheelPull = { pulls.append($0) }
        XCTAssertFalse(router.route(event(.began, dy: 4, at: 1, inverted: false), reel: reel, pitch: 90))
        XCTAssertTrue(router.route(event(.changed, dy: 5, at: 1.01, inverted: false), reel: reel, pitch: 90))
        XCTAssertEqual(pulls.first, .began)
    }

    func testSwipingDownOverTheBarStillScrollsThePage() {
        let reel = SlotReel(count: 6, slot: 2)
        var pulls: [SlotReelWheelPull] = []
        var router = SlotReelScrollRouter()
        router.onWheelPull = { pulls.append($0) }
        XCTAssertFalse(router.route(event(.began, dy: 3, at: 1), reel: reel, pitch: 90))
        XCTAssertFalse(router.route(event(.changed, dy: 8, at: 1.01), reel: reel, pitch: 90))
        XCTAssertTrue(pulls.isEmpty)
    }
}
