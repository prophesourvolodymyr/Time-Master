import XCTest

/// The Mobility & Flexibility board on the iPhone: a card dropped on the next column's visible edge lands there, a chip
/// of the drop tray reaches a far column, a drag let go over nothing moves nothing and frees the board (by the next touch,
/// or by itself after the timeout), and a long column opens 25 cards at a time. Runs against the library copy at
/// `/tmp/tm-sim-root` (see `CampWalkthroughTests`); without it the tests are skipped. Tags the tests change are put back on
/// disk afterwards. The measured times print as `TBTIMING` lines.
final class TypeBoardDragTests: XCTestCase {
    private static let dataRoot = "/tmp/tm-sim-root"
    private static let folderTitle = "Mobility & Flexibility"
    private static let firstMorningCard = "Deep Squat Thoracic Rotation"
    /// The first launch after an install is slow and its first drag may not lift a card: one throwaway pass over the board
    /// before the first test gets the app and the simulator past that.
    private static var isWarm = false
    private let app = XCUIApplication(bundleIdentifier: "com.timemaster.TimeMaster")

    private var folderID = ""
    private var tagIDs: [String: String] = [:]
    /// Pages of the folder (at any depth) by title: their manifest file.
    private var pageFiles: [String: URL] = [:]
    /// The tag id each page wore when the test started (nil = none), to put back afterwards.
    private var originalTags: [URL: String?] = [:]

    override func setUpWithError() throws {
        try XCTSkipUnless(FileManager.default.fileExists(atPath: Self.dataRoot), "No library copy at \(Self.dataRoot)")
        continueAfterFailure = false
        try readLibrary()
        launch()
        if !Self.isWarm {
            Self.isWarm = true
            openBoard()
            let source = card(Self.firstMorningCard, in: "Morning flow")
            if source.waitForExistence(timeout: 10) {
                drag(source, to: CGPoint(x: source.frame.midX + 20, y: source.frame.midY + 30), holdAtEnd: 0.5)
            }
            relaunch(pinningTray: false)
        }
    }

    override func tearDownWithError() throws {
        app.terminate()
        for (url, tag) in originalTags {
            guard var json = try JSONSerialization.jsonObject(with: Data(contentsOf: url)) as? [String: Any],
                  json["typeID"] as? String != tag else { continue }
            json["typeID"] = tag
            try JSONSerialization.data(withJSONObject: json, options: [.prettyPrinted, .sortedKeys]).write(to: url)
        }
    }

    // MARK: Tests

    func testACardDroppedOnTheNextColumnsVisibleEdgeLandsInThatColumn() throws {
        openBoard()
        let source = card(Self.firstMorningCard, in: "Morning flow")
        XCTAssertTrue(source.waitForExistence(timeout: 10), "the first Morning flow card")
        let strip = column("Between sets").frame.intersection(app.windows.firstMatch.frame)
        XCTAssertGreaterThan(strip.width, 30, "part of Between sets shows at the right: \(strip)")
        drag(source, to: CGPoint(x: strip.midX, y: source.frame.midY), holdAtEnd: 1.0)
        XCTAssertEqual(waitForTag(of: Self.firstMorningCard, toBe: "Between sets"), "Between sets")
    }

    func testATrayChipTakesACardToAFarColumn() throws {
        relaunch(pinningTray: true)
        openBoard()
        let chip = app.descendants(matching: .any)["type-board-tray-\(tagID("Skip for now"))"]
        XCTAssertTrue(chip.waitForExistence(timeout: 10), "the drop tray, pinned open to read where its chips sit")
        let point = CGPoint(x: chip.frame.midX, y: chip.frame.midY)

        relaunch(pinningTray: false)
        openBoard()
        XCTAssertTrue(tray.waitForNonExistence(timeout: 4), "no tray before a drag")
        let source = card("Forward Fold Overhead Reach", in: "Morning flow")
        XCTAssertTrue(source.waitForExistence(timeout: 10), "a Morning flow card")
        drag(source, to: point, holdAtEnd: 0.8)
        XCTAssertEqual(waitForTag(of: "Forward Fold Overhead Reach", toBe: "Skip for now"), "Skip for now")
        XCTAssertTrue(tray.waitForNonExistence(timeout: 4), "the tray went away with the drop")
    }

    /// A cancelled drag gives the board no end signal: its tray and the held columns last until the next touch. A tap on the
    /// board's background is that touch.
    func testADragLetGoOverNothingMovesNothingAndATapFreesTheBoard() throws {
        openBoard()
        letGoOverNothing()
        XCTAssertEqual(tagTitle(of: Self.firstMorningCard), "Morning flow", "a drag let go over nothing moves nothing")

        let first = column("Morning flow")
        let gap = app.coordinate(withNormalizedOffset: .zero)
            .withOffset(CGVector(dx: first.frame.maxX + 6, dy: app.windows.firstMatch.frame.midY))
        gap.tap()
        let tapReturned = Date()
        let gone = tray.waitForNonExistence(timeout: 1)
        print("TBTIMING tap on the board background -> tray gone: \(gone), \(seconds(since: tapReturned)) s after the tap returned")
        XCTAssertTrue(gone, "one tap on the board's background makes the tray vanish within a second")

        let tries = swipesUntilTheBoardScrolls(maxTries: 2)
        print("TBTIMING first swipe after the tap: the board scrolled after \(tries.map { "\($0) swipe(s)" } ?? "no swipe")")
        XCTAssertNotNil(tries, "a sideways swipe scrolls the board after the tap")
    }

    /// With the tray still lingering, the swipe is the first touch: it frees the board, but the scroll may need a second try.
    func testASwipeRightAfterACancelledDragScrollsTheBoardWithinTwoTries() throws {
        openBoard()
        letGoOverNothing()
        XCTAssertEqual(tagTitle(of: Self.firstMorningCard), "Morning flow", "a drag let go over nothing moves nothing")

        let tries = swipesUntilTheBoardScrolls(maxTries: 2)
        print("TBTIMING first touch after a cancelled drag is a swipe: the board scrolled after \(tries.map { "\($0) swipe(s)" } ?? "no swipe")")
        XCTAssertNotNil(tries, "a sideways swipe scrolls the board within two tries")
        XCTAssertTrue(tray.waitForNonExistence(timeout: 1), "the swipe's touch freed the tray")
    }

    /// Nothing touches the screen: the session times out by itself (12 s after the drag was felt).
    func testACancelledDragFreesTheBoardByItselfWithinTheTimeout() throws {
        openBoard()
        letGoOverNothing()
        let released = Date()
        let gone = tray.waitForNonExistence(timeout: 14)
        print("TBTIMING no touch after a cancelled drag -> tray gone: \(gone), \(seconds(since: released)) s after the release")
        XCTAssertTrue(gone, "the tray went away by itself within 14 s")

        let tries = swipesUntilTheBoardScrolls(maxTries: 1)
        print("TBTIMING first swipe after the timeout: the board scrolled after \(tries.map { "\($0) swipe(s)" } ?? "no swipe")")
        XCTAssertEqual(tries, 1, "a sideways swipe scrolls the board at the first try")
    }

    func testShowNextOpensALongColumnTwentyFiveCardsAtATime() throws {
        openBoard()
        let skip = column("Skip for now")
        let window = app.windows.firstMatch.frame
        for _ in 0..<12 where skip.frame.minX > window.midX {
            swipeBoard(at: window.midY, by: -240)
        }
        XCTAssertLessThanOrEqual(skip.frame.minX, window.midX, "Skip for now came on screen")
        let skipID = tagID("Skip for now")
        let more = app.buttons["type-board-more-\(skipID)"]
        XCTAssertTrue(more.waitForExistence(timeout: 5), "Show next under the first cards")
        XCTAssertEqual(cardCount(in: "Skip for now"), 10)
        XCTAssertEqual(more.label, "Show next 25, 35 more")

        tapScrollingTo(more)
        XCTAssertTrue(waitForCardCount(35, in: "Skip for now"), "one tap shows 25 more")
        XCTAssertEqual(more.label, "Show next 10, 10 more")

        tapScrollingTo(more)
        XCTAssertTrue(waitForCardCount(45, in: "Skip for now"), "the second shows the rest")
        let fewer = app.buttons["type-board-fewer-\(skipID)"]
        XCTAssertTrue(fewer.waitForExistence(timeout: 5), "Show fewer once every card shows")

        tapScrollingTo(fewer)
        XCTAssertTrue(waitForCardCount(10, in: "Skip for now"), "Show fewer goes back to the first 10")
    }

    // MARK: Board

    private var tray: XCUIElement { app.descendants(matching: .any)["type-board-tray"] }

    private func launch() {
        app.launchEnvironment["TIMEMASTER_DATA_ROOT"] = Self.dataRoot
        app.launch()
        app.discardSavedWorkoutIfOffered()
    }

    private func relaunch(pinningTray: Bool) {
        app.terminate()
        app.launchEnvironment["TIMEMASTER_UITEST_PIN_DROP_TRAY"] = pinningTray ? "1" : nil
        launch()
    }

    private func openBoard() {
        let tab = app.buttons["navigation-item-database"].firstMatch
        XCTAssertTrue(tab.waitForExistence(timeout: 30), "Database tab")
        let open = app.buttons["database-open-\(folderID)"]
        for _ in 0..<4 {
            tab.tap()
            if app.buttons["database-row-\(folderID)"].waitForExistence(timeout: 2) || open.exists { break }
        }
        for _ in 0..<12 where !(open.exists && open.isHittable) {
            app.swipeUp()
        }
        XCTAssertTrue(open.isHittable, "the open button of \(Self.folderTitle)")
        open.tap()
        let boardLayout = app.buttons.matching(NSPredicate(format: "label == 'Board'")).firstMatch
        XCTAssertTrue(boardLayout.waitForExistence(timeout: 10), "the Board layout of the Exercises tab")
        boardLayout.tap()
        XCTAssertTrue(column("Morning flow").waitForExistence(timeout: 10), "the Morning flow column")
        liftBoard()
    }

    /// Scrolls the folder page up until the board's columns start near the top of the screen: the board opens low, with
    /// its first cards under the navigation bar, where no press or drop reaches them.
    private func liftBoard() {
        let window = app.windows.firstMatch.frame
        let first = column("Morning flow")
        for _ in 0..<8 where first.frame.minY > window.minY + 220 {
            app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.62)).press(
                forDuration: 0.05,
                thenDragTo: app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.40)),
                withVelocity: .slow,
                thenHoldForDuration: 0.3
            )
        }
    }

    private func column(_ tag: String) -> XCUIElement {
        app.descendants(matching: .any)["type-board-column-\(tagID(tag))"]
    }

    private func card(_ title: String, in tag: String) -> XCUIElement {
        app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "\(title), \(tag)")).firstMatch
    }

    private func cardCount(in tag: String) -> Int {
        app.buttons.matching(NSPredicate(format: "label CONTAINS %@", ", \(tag), in ")).count
    }

    private func waitForCardCount(_ count: Int, in tag: String) -> Bool {
        for _ in 0..<40 {
            if cardCount(in: tag) == count { return true }
            sleep(1)
        }
        return false
    }

    /// A long press that lifts the card, a slow move to `point` (screen points), a hold there, then the release.
    private func drag(_ element: XCUIElement, to point: CGPoint, holdAtEnd: TimeInterval) {
        let origin = app.coordinate(withNormalizedOffset: .zero)
        element.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).press(
            forDuration: 1.0,
            thenDragTo: origin.withOffset(CGVector(dx: point.x, dy: point.y)),
            withVelocity: .slow,
            thenHoldForDuration: holdAtEnd
        )
    }

    /// Lifts the first Morning flow card and lets go of it over the bar at the top of the page: above the board, over no
    /// column and no chip. Returns once the finger is up.
    private func letGoOverNothing() {
        let source = card(Self.firstMorningCard, in: "Morning flow")
        XCTAssertTrue(source.waitForExistence(timeout: 10), "the first Morning flow card")
        let window = app.windows.firstMatch.frame
        drag(source, to: CGPoint(x: window.midX, y: window.minY + 70), holdAtEnd: 0.5)
    }

    private func swipeBoard(at y: CGFloat, by dx: CGFloat) {
        let window = app.windows.firstMatch.frame
        let origin = app.coordinate(withNormalizedOffset: .zero)
        let start = origin.withOffset(CGVector(dx: window.midX + (dx < 0 ? 110 : -110), dy: y))
        start.press(forDuration: 0.05, thenDragTo: start.withOffset(CGVector(dx: dx, dy: 0)), withVelocity: .default, thenHoldForDuration: 0.2)
    }

    /// Swipes the board sideways until its first column has moved, at most `maxTries` times: how many swipes it took, nil
    /// when none moved it.
    private func swipesUntilTheBoardScrolls(maxTries: Int) -> Int? {
        let window = app.windows.firstMatch.frame
        let first = column("Morning flow")
        let before = first.frame.minX
        for attempt in 1...maxTries {
            swipeBoard(at: window.midY, by: -220)
            if first.frame.minX < before - 60 { return attempt }
        }
        return nil
    }

    private func seconds(since start: Date) -> String {
        String(format: "%.1f", Date().timeIntervalSince(start))
    }

    /// Scrolls the page until `element` sits clear of the navigation bar, lets it settle, and taps it.
    private func tapScrollingTo(_ element: XCUIElement) {
        let bar = app.descendants(matching: .any)["carousel-navigation"]
        let limit = bar.exists ? bar.frame.minY : app.windows.firstMatch.frame.maxY - 140
        for _ in 0..<24 {
            if element.isHittable, element.frame.maxY < limit - 8 { break }
            app.swipeUp()
        }
        var last = element.frame
        for _ in 0..<10 {
            usleep(400_000)
            let now = element.frame
            if now == last { break }
            last = now
        }
        element.tap()
    }

    // MARK: Library on disk

    private func tagID(_ title: String) -> String { tagIDs[title] ?? "missing-\(title)" }

    private func readLibrary() throws {
        let base = URL(fileURLWithPath: Self.dataRoot).appendingPathComponent("Exercises Database", isDirectory: true)
        var byID: [String: (url: URL, json: [String: Any])] = [:]
        let files = FileManager.default.enumerator(at: base, includingPropertiesForKeys: nil)
        while let url = files?.nextObject() as? URL {
            guard url.lastPathComponent == "manifest.json",
                  let json = try JSONSerialization.jsonObject(with: Data(contentsOf: url)) as? [String: Any],
                  let id = json["id"] as? String else { continue }
            byID[id] = (url, json)
        }
        guard let folder = byID.values.first(where: { $0.json["title"] as? String == Self.folderTitle && $0.json["parentID"] == nil })
        else { throw XCTSkip("No \(Self.folderTitle) folder in the library copy") }
        folderID = folder.json["id"] as? String ?? ""
        for preset in folder.json["typePresets"] as? [[String: Any]] ?? [] {
            for type in preset["types"] as? [[String: Any]] ?? [] {
                if let title = type["title"] as? String, let id = type["id"] as? String { tagIDs[title] = id }
            }
        }
        var pending = folder.json["childIDs"] as? [String] ?? []
        while let id = pending.popLast() {
            guard let page = byID[id] else { continue }
            if let title = page.json["title"] as? String { pageFiles[title] = page.url }
            originalTags[page.url] = page.json["typeID"] as? String
            pending.append(contentsOf: page.json["childIDs"] as? [String] ?? [])
        }
    }

    private func tagTitle(of title: String) -> String? {
        guard let url = pageFiles[title],
              let json = try? JSONSerialization.jsonObject(with: Data(contentsOf: url)) as? [String: Any] else { return nil }
        guard let id = json["typeID"] as? String else { return "Untagged" }
        return tagIDs.first { $0.value == id }?.key
    }

    private func waitForTag(of title: String, toBe expected: String) -> String? {
        var seen = tagTitle(of: title)
        for _ in 0..<60 where seen != expected {
            usleep(250_000)
            seen = tagTitle(of: title)
        }
        return seen
    }
}
