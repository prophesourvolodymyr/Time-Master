import Combine
import SwiftUI
import XCTest
@testable import TimeMaster

final class PageSiblingSequenceTests: XCTestCase {
    private let folder = "folder"

    private func sequence(_ ids: [String], in container: String = "folder") -> PageSiblingSequence {
        PageSiblingSequence(containerID: container, pageIDs: ids)
    }

    // MARK: - Sequence

    func testARepeatedPageKeepsItsFirstPlace() {
        XCTAssertEqual(sequence(["a", "b", "a", "c", "b"]).pageIDs, ["a", "b", "c"])
    }

    func testPositionCountsFromOneAndKnowsTheEnds() {
        let pages = sequence(["a", "b", "c", "d", "e"])
        XCTAssertEqual(pages.position(of: "a"), PageSiblingPosition(index: 0, count: 5))
        XCTAssertEqual(pages.position(of: "e")?.label, "5 / 5")
        XCTAssertEqual(pages.position(of: "c")?.spokenLabel, "Page 3 of 5")
        XCTAssertEqual(pages.position(of: "a")?.hasPrevious, false)
        XCTAssertEqual(pages.position(of: "a")?.hasNext, true)
        XCTAssertEqual(pages.position(of: "e")?.hasPrevious, true)
        XCTAssertEqual(pages.position(of: "e")?.hasNext, false)
        XCTAssertNil(pages.position(of: "z"))
    }

    func testNeighboursStopAtTheEndsWithoutWrapping() {
        let pages = sequence(["a", "b", "c"])
        XCTAssertEqual(pages.neighbour(of: "b", step: 1), "c")
        XCTAssertEqual(pages.neighbour(of: "b", step: -1), "a")
        XCTAssertNil(pages.neighbour(of: "c", step: 1))
        XCTAssertNil(pages.neighbour(of: "a", step: -1))
        XCTAssertNil(pages.neighbour(of: "z", step: 1))
    }

    func testOnePageHasNowhereToStep() {
        XCTAssertFalse(sequence(["a"]).isSteppable)
        XCTAssertTrue(sequence(["a", "b"]).isSteppable)
    }

    // MARK: - Offers and frozen sequences

    func testAPageFreezesTheOfferOfTheScreenBelowIt() {
        var book = PageSiblingBook()
        book.offer(["a", "b", "c"], containerID: folder, surface: "browser", depth: 1)
        let found = book.sequence(for: "b", depth: 2) { nil }
        XCTAssertEqual(found, sequence(["a", "b", "c"]))
        XCTAssertEqual(book.frozenSequence(at: 2), found)
    }

    func testOffersOfOtherDepthsDoNotCount() {
        var book = PageSiblingBook()
        book.offer(["a", "b"], containerID: folder, surface: "browser", depth: 2)
        XCTAssertNil(book.sequence(for: "a", depth: 2) { nil })
        XCTAssertNil(book.frozenSequence(at: 2))
    }

    func testTheNewestSurfaceThatListsThePageWins() {
        var book = PageSiblingBook()
        book.offer(["a", "b", "c"], containerID: folder, surface: "browser", depth: 1)
        book.offer(["c", "a"], containerID: folder, surface: "board", depth: 1)
        XCTAssertEqual(book.offer(containing: "a", at: 1), sequence(["c", "a"]))
        XCTAssertEqual(book.offer(containing: "b", at: 1), sequence(["a", "b", "c"]))
        book.offer(["b", "a", "c"], containerID: folder, surface: "browser", depth: 1)
        XCTAssertEqual(book.offer(containing: "a", at: 1), sequence(["b", "a", "c"]))
    }

    func testASurfaceReplacesItsOwnListAndAnEmptyOneWithdrawsIt() {
        var book = PageSiblingBook()
        book.offer(["a", "b"], containerID: folder, surface: "browser", depth: 1)
        book.offer(["b"], containerID: folder, surface: "browser", depth: 1)
        XCTAssertNil(book.offer(containing: "a", at: 1))
        book.offer([], containerID: folder, surface: "browser", depth: 1)
        XCTAssertNil(book.offer(containing: "b", at: 1))
    }

    func testTheSameSurfaceOfTwoContainersKeepsBothLists() {
        var book = PageSiblingBook()
        book.offer(["a", "b"], containerID: "skill", surface: "children", depth: 1)
        book.offer(["x", "y"], containerID: "other", surface: "children", depth: 1)
        XCTAssertEqual(book.offer(containing: "a", at: 1)?.containerID, "skill")
        XCTAssertEqual(book.offer(containing: "y", at: 1)?.containerID, "other")
    }

    func testAFrozenSequenceDoesNotMoveWhenTheListUnderneathChanges() {
        var book = PageSiblingBook()
        book.offer(["a", "b", "c"], containerID: folder, surface: "browser", depth: 1)
        _ = book.sequence(for: "b", depth: 2) { nil }
        book.offer(["c", "b", "a"], containerID: folder, surface: "browser", depth: 1)
        XCTAssertEqual(book.sequence(for: "b", depth: 2) { nil }, sequence(["a", "b", "c"]))
    }

    func testTheFallbackServesAPageNoSurfaceOffered() {
        var book = PageSiblingBook()
        let order = sequence(["x", "y", "z"])
        XCTAssertEqual(book.sequence(for: "y", depth: 1) { order }, order)
        XCTAssertEqual(book.frozenSequence(at: 1), order)
    }

    func testAFallbackThatDoesNotHoldThePageIsDropped() {
        var book = PageSiblingBook()
        XCTAssertNil(book.sequence(for: "q", depth: 1) { self.sequence(["x", "y"]) })
        XCTAssertNil(book.frozenSequence(at: 1))
    }

    func testAnOfferBeatsTheFallback() {
        var book = PageSiblingBook()
        book.offer(["b", "a"], containerID: folder, surface: "browser", depth: 1)
        var askedForFallback = false
        let found = book.sequence(for: "a", depth: 2) {
            askedForFallback = true
            return self.sequence(["a", "b"])
        }
        XCTAssertEqual(found, sequence(["b", "a"]))
        XCTAssertFalse(askedForFallback)
    }

    func testPoppingDropsEverythingAboveTheNewTop() {
        var book = PageSiblingBook()
        book.offer(["a", "b"], containerID: folder, surface: "browser", depth: 1)
        _ = book.sequence(for: "a", depth: 2) { nil }
        book.offer(["s1", "s2"], containerID: "a", surface: "children", depth: 2)
        _ = book.sequence(for: "s1", depth: 3) { nil }

        book.pop(toDepth: 2)
        XCTAssertNil(book.frozenSequence(at: 3))
        XCTAssertNotNil(book.frozenSequence(at: 2))
        XCTAssertNotNil(book.offer(containing: "s1", at: 2))

        book.pop(toDepth: 1)
        XCTAssertNil(book.frozenSequence(at: 2))
        XCTAssertNil(book.offer(containing: "s1", at: 2))
        XCTAssertNotNil(book.offer(containing: "a", at: 1))
    }

    func testAPageOpenedAgainAfterBackFreezesTheNewOrder() {
        var book = PageSiblingBook()
        book.offer(["a", "b", "c"], containerID: folder, surface: "browser", depth: 1)
        _ = book.sequence(for: "a", depth: 2) { nil }
        book.pop(toDepth: 1)
        book.offer(["c", "b", "a"], containerID: folder, surface: "browser", depth: 1)
        XCTAssertEqual(book.sequence(for: "a", depth: 2) { nil }, sequence(["c", "b", "a"]))
    }

    func testASwapKeepsTheSequenceForTheSiblingAndDropsTheOldScreensOffers() {
        var book = PageSiblingBook()
        book.offer(["a", "b", "c"], containerID: folder, surface: "browser", depth: 1)
        _ = book.sequence(for: "a", depth: 2) { nil }
        book.offer(["s1"], containerID: "a", surface: "children", depth: 2)

        book.swapTop(atDepth: 2)
        XCTAssertNil(book.offer(containing: "s1", at: 2))
        XCTAssertEqual(book.sequence(for: "b", depth: 2) { nil }, sequence(["a", "b", "c"]))
        XCTAssertNotNil(book.offer(containing: "b", at: 1))
    }

    // MARK: - Fallback order

    func testAFolderFallsBackToTheTabThatListsThePage() {
        let tabs = [["e1", "n1", "f1"], ["s1", "s2"]]
        XCTAssertEqual(PageSiblingOrder.folder(folder, tabs: tabs, holding: "n1")?.pageIDs, ["e1", "n1", "f1"])
        XCTAssertEqual(PageSiblingOrder.folder(folder, tabs: tabs, holding: "s2")?.pageIDs, ["s1", "s2"])
        XCTAssertNil(PageSiblingOrder.folder(folder, tabs: tabs, holding: "zz"))
    }

    func testASkillFallsBackToItsBoardThenItsOtherPages() {
        let order = PageSiblingOrder.skill("skill", board: ["s2", "s1"], children: ["e1", "s1", "n1", "s2"])
        XCTAssertEqual(order.pageIDs, ["s2", "s1", "e1", "n1"])
        XCTAssertEqual(order.containerID, "skill")
    }

    // MARK: - Two-finger swipe

    func testASwipeFarEnoughToTheLeftGoesToTheNextPage() {
        XCTAssertEqual(PageSiblingSwipe.step(translation: CGSize(width: -90, height: 10), velocity: .zero), 1)
        XCTAssertEqual(PageSiblingSwipe.step(translation: CGSize(width: 90, height: -10), velocity: .zero), -1)
    }

    func testAShortSlowSwipeStaysPut() {
        XCTAssertNil(PageSiblingSwipe.step(translation: CGSize(width: -40, height: 0), velocity: CGSize(width: -100, height: 0)))
    }

    func testAQuickFlickSteps() {
        XCTAssertEqual(PageSiblingSwipe.step(translation: CGSize(width: -36, height: 4), velocity: CGSize(width: -900, height: 0)), 1)
        XCTAssertNil(PageSiblingSwipe.step(translation: CGSize(width: -36, height: 4), velocity: CGSize(width: 900, height: 0)))
        XCTAssertNil(PageSiblingSwipe.step(translation: CGSize(width: -12, height: 0), velocity: CGSize(width: -2000, height: 0)))
    }

    func testAMostlyVerticalSwipeNeverSteps() {
        XCTAssertNil(PageSiblingSwipe.step(translation: CGSize(width: -120, height: 100), velocity: CGSize(width: -900, height: 0)))
    }

    // MARK: - Mac trackpad gesture

    func testATrackpadGestureStepsOnceWhenItIsFarEnoughSideways() {
        var tracker = PageSiblingScrollTracker()
        XCTAssertNil(tracker.receive(.began(eligible: true), dx: -10, dy: 0))
        XCTAssertNil(tracker.receive(.changed, dx: -30, dy: 2))
        XCTAssertEqual(tracker.receive(.changed, dx: -40, dy: 0), 1)
        XCTAssertNil(tracker.receive(.changed, dx: -200, dy: 0))
        XCTAssertNil(tracker.receive(.ended, dx: 0, dy: 0))

        XCTAssertNil(tracker.receive(.began(eligible: true), dx: 30, dy: 0))
        XCTAssertEqual(tracker.receive(.changed, dx: 50, dy: 0), -1)
    }

    func testMomentumNeverSteps() {
        var tracker = PageSiblingScrollTracker()
        XCTAssertNil(tracker.receive(.began(eligible: true), dx: -10, dy: 0))
        XCTAssertNil(tracker.receive(.ended, dx: 0, dy: 0))
        XCTAssertNil(tracker.receive(.momentum, dx: -300, dy: 0))
        XCTAssertNil(tracker.receive(.changed, dx: -300, dy: 0))
    }

    func testAGestureThatBeganWhereItMayNotStepIsIgnoredWhole() {
        var tracker = PageSiblingScrollTracker()
        XCTAssertNil(tracker.receive(.began(eligible: false), dx: -10, dy: 0))
        XCTAssertNil(tracker.receive(.began(eligible: true), dx: -10, dy: 0))
        XCTAssertNil(tracker.receive(.changed, dx: -300, dy: 0))
    }

    func testAMostlyVerticalTrackpadGestureNeverSteps() {
        var tracker = PageSiblingScrollTracker()
        XCTAssertNil(tracker.receive(.began(eligible: true), dx: 0, dy: 0))
        XCTAssertNil(tracker.receive(.changed, dx: -40, dy: 40))
        XCTAssertNil(tracker.receive(.changed, dx: -40, dy: -40))
    }
}

@MainActor
final class DatabaseNavigationSiblingTests: XCTestCase {
    private func state(_ pages: [String]) -> DatabaseNavigationState {
        let navigation = DatabaseNavigationState()
        for page in pages { navigation.path.append(DatabasePageRoute(pageID: page)) }
        return navigation
    }

    private func path(_ pages: [String]) -> NavigationPath {
        var route = NavigationPath()
        for page in pages { route.append(DatabasePageRoute(pageID: page)) }
        return route
    }

    func testOfferingAndFreezingSiblingsNeverPublishes() {
        let navigation = state(["folder"])
        var changes = 0
        let watch = navigation.objectWillChange.sink { changes += 1 }
        navigation.offerSiblings(["a", "b"], containerID: "folder", surface: "browser", depth: 1)
        _ = navigation.siblingSequence(for: "a", depth: 2) { nil }
        watch.cancel()
        XCTAssertEqual(changes, 0)
    }

    func testGoingToASiblingReplacesTheTopInOneChange() {
        let navigation = state(["folder", "a"])
        var changes = 0
        let watch = navigation.objectWillChange.sink { changes += 1 }
        navigation.goToSibling("b", direction: 1)
        watch.cancel()
        XCTAssertEqual(navigation.path, path(["folder", "b"]))
        XCTAssertEqual(changes, 1)
    }

    func testBackAfterSwapsReturnsToTheContainerInOneStep() {
        let navigation = state(["folder", "a"])
        navigation.goToSibling("b", direction: 1)
        navigation.goToSibling("c", direction: 1)
        navigation.goToSibling("b", direction: -1)
        navigation.path.removeLast()
        XCTAssertEqual(navigation.path, path(["folder"]))
    }

    func testTheSiblingKeepsTheSequenceThePageFroze() {
        let navigation = state(["folder"])
        navigation.offerSiblings(["a", "b", "c"], containerID: "folder", surface: "browser", depth: 1)
        navigation.path.append(DatabasePageRoute(pageID: "a"))
        let frozen = navigation.siblingSequence(for: "a", depth: 2) { nil }
        XCTAssertEqual(frozen?.pageIDs, ["a", "b", "c"])
        navigation.offerSiblings(["c", "b", "a"], containerID: "folder", surface: "browser", depth: 1)
        navigation.goToSibling("b", direction: 1)
        XCTAssertEqual(navigation.siblingSequence(for: "b", depth: 2) { nil }, frozen)
    }

    func testBackToTheContainerDropsTheFrozenSequence() {
        let navigation = state(["folder"])
        navigation.offerSiblings(["a", "b", "c"], containerID: "folder", surface: "browser", depth: 1)
        navigation.path.append(DatabasePageRoute(pageID: "a"))
        _ = navigation.siblingSequence(for: "a", depth: 2) { nil }
        navigation.path.removeLast()
        navigation.offerSiblings(["c", "a"], containerID: "folder", surface: "browser", depth: 1)
        navigation.path.append(DatabasePageRoute(pageID: "a"))
        XCTAssertEqual(navigation.siblingSequence(for: "a", depth: 2) { nil }?.pageIDs, ["c", "a"])
    }

    func testThePopupStackOffersNoSiblings() {
        let navigation = DatabaseNavigationState(siblingNavigation: false)
        navigation.offerSiblings(["a", "b"], containerID: "folder", surface: "browser", depth: 0)
        XCTAssertNil(navigation.siblingSequence(for: "a", depth: 1) { nil })
    }

    func testOnlyTheSwappedInPageTakesItsArrivalOnce() {
        let navigation = state(["folder", "a"])
        navigation.goToSibling("b", direction: -1)
        XCTAssertNil(navigation.takeSiblingArrival(for: "a"))
        XCTAssertEqual(navigation.pendingSiblingArrival(for: "b"), -1)
        XCTAssertEqual(navigation.takeSiblingArrival(for: "b"), -1)
        XCTAssertNil(navigation.takeSiblingArrival(for: "b"))
    }

    func testAnOrdinaryChangeForgetsAnArrivalNoPageTookUp() {
        let navigation = state(["folder", "a"])
        navigation.goToSibling("b", direction: 1)
        navigation.path.append(DatabasePageRoute(pageID: "c"))
        XCTAssertNil(navigation.pendingSiblingArrival(for: "b"))
    }
}
