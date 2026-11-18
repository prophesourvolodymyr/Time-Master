import XCTest
@testable import TimeMaster

@MainActor
final class EverPageBackTests: XCTestCase {
    private func stack(depth: Int, owner: UUID = UUID(), pop: @escaping () -> Void = {}) -> EverPageBackStack {
        .stack(owner: owner, depth: depth, pop: pop, around: nil)
    }

    private func route(_ depth: Int?, _ title: String) -> EverPageRoute {
        EverPageRoute(depth: depth, title: title)
    }

    // MARK: - Escape

    func testEscapeIsOnlyConsideredForAPlainKeyInAFreeKeyWindow() {
        XCTAssertTrue(EverEscapeRoute.isCandidate(plainKey: true, windowIsKey: true, windowIsBusy: false, responderUsesEscape: false))
        XCTAssertFalse(EverEscapeRoute.isCandidate(plainKey: false, windowIsKey: true, windowIsBusy: false, responderUsesEscape: false))
        XCTAssertFalse(EverEscapeRoute.isCandidate(plainKey: true, windowIsKey: false, windowIsBusy: false, responderUsesEscape: false))
        XCTAssertFalse(EverEscapeRoute.isCandidate(plainKey: true, windowIsKey: true, windowIsBusy: true, responderUsesEscape: false))
        XCTAssertFalse(EverEscapeRoute.isCandidate(plainKey: true, windowIsKey: true, windowIsBusy: false, responderUsesEscape: true))
    }

    func testEscapeStepsBackAStackAbovePage() {
        XCTAssertEqual(EverEscapeRoute.outcome(claim: nil, holds: false, stack: stack(depth: 2), quietAtRoot: true), .pop)
        XCTAssertEqual(EverEscapeRoute.outcome(claim: nil, holds: false, stack: stack(depth: 1), quietAtRoot: false), .pop)
    }

    func testEscapeAtARootStopsWithoutABeep() {
        let root = stack(depth: 0)
        XCTAssertFalse(root.canPop)
        XCTAssertEqual(EverEscapeRoute.outcome(claim: nil, holds: false, stack: root, quietAtRoot: false), .swallow)
        XCTAssertEqual(EverEscapeRoute.outcome(claim: nil, holds: false, stack: nil, quietAtRoot: true), .swallow)
    }

    func testEscapeGoesOnToContentThatAnswersItItself() {
        XCTAssertEqual(EverEscapeRoute.outcome(claim: nil, holds: false, stack: nil, quietAtRoot: false), .passThrough)
    }

    func testAMoreOpenClaimAnswersBeforeTheStack() {
        let claim = EverEscapeClaim(id: "navigation-editing", action: {})
        XCTAssertEqual(EverEscapeRoute.outcome(claim: claim, holds: true, stack: stack(depth: 1), quietAtRoot: true), .claim)
        XCTAssertEqual(EverEscapeRoute.outcome(claim: claim, holds: false, stack: nil, quietAtRoot: false), .claim)
    }

    func testSomethingImmersiveOverThePageKeepsEscapeFromSteppingBack() {
        XCTAssertEqual(EverEscapeRoute.outcome(claim: nil, holds: true, stack: stack(depth: 1), quietAtRoot: true), .passThrough)
        XCTAssertEqual(EverEscapeRoute.outcome(claim: nil, holds: true, stack: stack(depth: 0), quietAtRoot: true), .passThrough)
    }

    // MARK: - Stack reports

    func testAStackStepsBackThroughItsOwnPop() {
        var popped = 0
        let report = stack(depth: 3) { popped += 1 }
        XCTAssertTrue(report.canPop)
        XCTAssertEqual(report.depth, 3)
        report.pop?()
        XCTAssertEqual(popped, 1)
    }

    func testAStackInsideAPageStepsBackFirst() {
        var steps: [String] = []
        let innerOwner = UUID()
        let inner = EverPageBackStack.stack(owner: innerOwner, depth: 1, pop: { steps.append("inner") }, around: nil)
        let outer = EverPageBackStack.stack(owner: UUID(), depth: 2, pop: { steps.append("outer") }, around: inner)
        XCTAssertEqual(outer.depth, 3)
        XCTAssertEqual(outer.owner, innerOwner)
        outer.pop?()
        XCTAssertEqual(steps, ["inner"])
    }

    func testAStackAtItsRootInsideAPageLeavesTheStepToTheOuterStack() {
        var steps: [String] = []
        let outerOwner = UUID()
        let inner = EverPageBackStack.stack(owner: UUID(), depth: 0, pop: { steps.append("inner") }, around: nil)
        let outer = EverPageBackStack.stack(owner: outerOwner, depth: 2, pop: { steps.append("outer") }, around: inner)
        XCTAssertEqual(outer.depth, 2)
        XCTAssertEqual(outer.owner, outerOwner)
        outer.pop?()
        XCTAssertEqual(steps, ["outer"])
    }

    func testTheDeepestPageShownStepsBackWhereverTheStackListsIt() {
        var steps: [String] = []
        let topOwner = UUID()
        let first = EverPageBackStack.page(owner: UUID(), depth: 1, pop: { steps.append("first") }, around: nil)
        let second = EverPageBackStack.page(owner: topOwner, depth: 2, pop: { steps.append("second") }, around: nil)
        for merged in [EverPageBackStack.merging(first, second), EverPageBackStack.merging(second, first)] {
            XCTAssertEqual(merged?.depth, 2)
            XCTAssertEqual(merged?.owner, topOwner)
            merged?.pop?()
        }
        XCTAssertEqual(steps, ["second", "second"])
        XCTAssertEqual(EverPageBackStack.merging(nil, first), first)
        XCTAssertEqual(EverPageBackStack.merging(first, nil), first)
        XCTAssertNil(EverPageBackStack.merging(nil, nil))
    }

    func testAPageSwappedForAnotherAtTheSameDepthStepsBackThroughTheLaterOne() {
        let laterOwner = UUID()
        let leaving = EverPageBackStack.page(owner: UUID(), depth: 1, pop: {}, around: nil)
        let arriving = EverPageBackStack.page(owner: laterOwner, depth: 1, pop: {}, around: nil)
        XCTAssertEqual(EverPageBackStack.merging(leaving, arriving)?.owner, laterOwner)
    }

    func testAStackInsideAPushedPageStepsBackFirst() {
        var steps: [String] = []
        let inner = EverPageBackStack.stack(owner: UUID(), depth: 2, pop: { steps.append("inner") }, around: nil)
        let page = EverPageBackStack.page(owner: UUID(), depth: 1, pop: { steps.append("page") }, around: inner)
        XCTAssertEqual(page.depth, 3)
        page.pop?()
        let atRoot = EverPageBackStack.stack(owner: UUID(), depth: 0, pop: { steps.append("inner") }, around: nil)
        let plainPage = EverPageBackStack.page(owner: UUID(), depth: 1, pop: { steps.append("page") }, around: atRoot)
        XCTAssertEqual(plainPage.depth, 1)
        plainPage.pop?()
        XCTAssertEqual(steps, ["inner", "page"])
    }

    func testANewOwnerIsANewAnswerEvenAtTheSameDepth() {
        let owner = UUID()
        XCTAssertNotEqual(stack(depth: 1), stack(depth: 1))
        XCTAssertEqual(stack(depth: 1, owner: owner, pop: {}), stack(depth: 1, owner: owner, pop: { print("other") }))
        XCTAssertNotEqual(stack(depth: 1, owner: owner), stack(depth: 2, owner: owner))
    }

    // MARK: - Page travel

    func testAPushTravelsForwardAndAPopTravelsBack() {
        XCTAssertEqual(EverPageTravel.stackDirection(from: 0, to: 1), 1)
        XCTAssertEqual(EverPageTravel.stackDirection(from: 2, to: 1), -1)
        XCTAssertEqual(EverPageTravel.stackDirection(from: 3, to: 0), -1)
        XCTAssertEqual(EverPageTravel.stackDirection(from: 1, to: 1), 1)
    }

    func testBarPagesTravelByTheirPlaceOnTheBar() {
        XCTAssertEqual(EverPageTravel.barDirection(from: 1, to: 3), 1)
        XCTAssertEqual(EverPageTravel.barDirection(from: 3, to: 1), -1)
        XCTAssertEqual(EverPageTravel.barDirection(from: 2, to: 2), 0)
    }

    func testAStackThatChangesDepthTravelsEvenWhenTheTitleStays() {
        let trail = EverPageTrail(route(1, "Untitled"))
        XCTAssertEqual(trail.direction(from: route(1, "Untitled"), to: route(2, "Untitled")), 1)
        XCTAssertEqual(trail.direction(from: route(2, "Untitled"), to: route(1, "Untitled")), -1)
    }

    func testARenamedPageOfAStackStays() {
        let trail = EverPageTrail(route(1, "Push-ups"))
        XCTAssertNil(trail.direction(from: route(1, "Push-ups"), to: route(1, "Wide Push-ups")))
    }

    func testAnAncestorPushedAgainTravelsForward() {
        var trail = EverPageTrail(route(0, "Database"))
        trail.visit(route(1, "Boxing"))
        trail.visit(route(2, "Jab"))
        XCTAssertEqual(trail.direction(from: route(2, "Jab"), to: route(3, "Boxing")), 1)
        XCTAssertEqual(trail.direction(from: route(3, "Boxing"), to: route(2, "Jab")), -1)
    }

    func testContentWithoutAStackFollowsItsTitles() {
        var trail = EverPageTrail(route(nil, "Lobby"))
        XCTAssertEqual(trail.direction(from: route(nil, "Lobby"), to: route(nil, "Match")), 1)
        trail.visit(route(nil, "Match"))
        XCTAssertEqual(trail.direction(from: route(nil, "Match"), to: route(nil, "Result")), 1)
        trail.visit(route(nil, "Result"))
        XCTAssertEqual(trail.direction(from: route(nil, "Result"), to: route(nil, "Lobby")), -1)
        trail.visit(route(nil, "Lobby"))
        XCTAssertEqual(trail.titles, ["Lobby"])
        XCTAssertEqual(trail.direction(from: route(nil, "Lobby"), to: route(nil, "Match")), 1)
        XCTAssertNil(trail.direction(from: route(nil, "Lobby"), to: route(nil, "Lobby")))
    }

    func testAStackThatStartsOrStopsReportingStays() {
        let trail = EverPageTrail(route(nil, "Home"))
        XCTAssertNil(trail.direction(from: route(nil, "Home"), to: route(0, "Database")))
        XCTAssertNil(trail.direction(from: route(0, "Database"), to: route(nil, "Home")))
    }
}
