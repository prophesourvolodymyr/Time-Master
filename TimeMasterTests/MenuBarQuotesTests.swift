import XCTest
@testable import TimeMaster

final class MenuBarQuotesTests: XCTestCase {
    private let calendar = Calendar(identifier: .gregorian)

    func testAnySeedIncludingNegativeOnesLandsInsideTheSet() {
        for seed in [-1_000_003, -1, 0, 1, TmaxQuotes.all.count, TmaxQuotes.all.count * 7 + 3, Int.max, Int.min + 1] {
            XCTAssertTrue(TmaxQuotes.all.contains(MenuBarQuotes.quote(seed: seed)))
        }
    }

    func testSeedsWrapAroundTheWholeSet() {
        let count = TmaxQuotes.all.count
        XCTAssertEqual(MenuBarQuotes.quote(seed: 3), MenuBarQuotes.quote(seed: 3 + count))
        XCTAssertEqual(MenuBarQuotes.quote(seed: -1), TmaxQuotes.all[count - 1])
    }

    func testTheDailyQuoteIsTheSameAllDayAndChangesTheNextDay() {
        let morning = calendar.date(from: DateComponents(year: 2026, month: 10, day: 26, hour: 6))!
        let night = calendar.date(from: DateComponents(year: 2026, month: 10, day: 26, hour: 23, minute: 59))!
        let tomorrow = calendar.date(from: DateComponents(year: 2026, month: 10, day: 27, hour: 6))!
        XCTAssertEqual(MenuBarQuotes.daily(morning, calendar: calendar), MenuBarQuotes.daily(night, calendar: calendar))
        XCTAssertNotEqual(MenuBarQuotes.daily(morning, calendar: calendar), MenuBarQuotes.daily(tomorrow, calendar: calendar))
    }
}
