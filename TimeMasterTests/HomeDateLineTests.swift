import XCTest
@testable import TimeMaster

final class HomeDateLineTests: XCTestCase {
    func testTheFlameBurnsHotterTheLongerTheStreak() {
        XCTAssertNil(HomeDateLine.flameTier(forStreak: 0), "no streak is an empty flame")
        XCTAssertNil(HomeDateLine.flameTier(forStreak: -3))
        let tiers = [1, 2, 3, 6, 7, 13, 14, 29, 30, 400].map { HomeDateLine.flameTier(forStreak: $0) }
        XCTAssertEqual(tiers, [3, 3, 4, 4, 5, 5, 6, 6, 7, 7])
        for days in 1..<60 {
            XCTAssertLessThanOrEqual(HomeDateLine.flameTier(forStreak: days) ?? 0, HomeDateLine.flameTier(forStreak: days + 1) ?? 0)
        }
    }

    func testTheDateSplitsAtTheDayNumberWithoutChangingTheText() throws {
        for day in [1, 9, 11, 28] {
            let date = try XCTUnwrap(Calendar.current.date(from: DateComponents(year: 2026, month: 11, day: day, hour: 12)))
            let pieces = HomeDateLine.pieces(of: date)
            XCTAssertEqual(pieces.day, date.formatted(.dateTime.day()), "day \(day)")
            let joined = (pieces.before + pieces.day + pieces.after).replacingOccurrences(of: "\u{00A0}", with: " ")
            XCTAssertEqual(joined, date.formatted(.dateTime.weekday(.wide).month(.wide).day()), "day \(day)")
        }
    }

    func testTheGlintCrossesTheLineOncePerCycleAndRestsBetween() throws {
        XCTAssertEqual(HomeDateLine.glint(at: 0), 0)
        XCTAssertEqual(try XCTUnwrap(HomeDateLine.glint(at: HomeDateLine.glintDuration / 2)), 0.5, accuracy: 0.0001)
        XCTAssertNil(HomeDateLine.glint(at: HomeDateLine.glintDuration))
        XCTAssertNil(HomeDateLine.glint(at: HomeDateLine.glintCycle - 0.01))
        XCTAssertEqual(HomeDateLine.glint(at: HomeDateLine.glintCycle * 40), 0, "the next cycle starts over")
    }

    func testTheGlintScheduleOnlyTicksWhileTheGlintMoves() {
        let fps = GlintSchedule.framesPerSecond
        let framesPerPass = Int(HomeDateLine.glintDuration * fps)
        let cycleStart = Date(timeIntervalSinceReferenceDate: HomeDateLine.glintCycle * 100)
        let ticks = GlintSchedule().entries(from: cycleStart, mode: .normal).prefix(framesPerPass * 2 + 2).map { $0.timeIntervalSince(cycleStart) }
        XCTAssertEqual(ticks[0], 0, "the first tick is the start itself")
        for index in 1..<framesPerPass {
            XCTAssertEqual(ticks[index] - ticks[index - 1], 1 / fps, accuracy: 1e-6)
        }
        XCTAssertEqual(ticks[framesPerPass], HomeDateLine.glintCycle, accuracy: 1e-6, "nothing ticks between two glints")
        XCTAssertEqual(ticks[framesPerPass + 1] - ticks[framesPerPass], 1 / fps, accuracy: 1e-6)

        let resting = Date(timeIntervalSinceReferenceDate: HomeDateLine.glintCycle * 100 + 5)
        let restingTicks = GlintSchedule().entries(from: resting, mode: .normal).prefix(2).map(\.timeIntervalSinceReferenceDate)
        XCTAssertEqual(restingTicks[0], resting.timeIntervalSinceReferenceDate)
        XCTAssertEqual(restingTicks[1], HomeDateLine.glintCycle * 101, accuracy: 1e-6, "starting between glints waits for the next one")
    }
}
