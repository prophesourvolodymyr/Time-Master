import XCTest
@testable import TimeMaster

final class HomeWidgetDayOneTests: XCTestCase {
    private let a = UUID()
    private let b = UUID()
    private let c = UUID()
    private let d = UUID()

    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .current
        return calendar
    }

    private func date(_ day: Int, hour: Int = 12) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: 3, day: day, hour: hour)) ?? Date()
    }

    private func option(_ id: UUID, sections: Int = 3, last: Date? = nil) -> HomeWorkoutOption {
        HomeWorkoutOption(
            id: id, name: "Workout \(id.uuidString.prefix(4))", typeName: "Strength", typeIcon: "dumbbell.fill",
            typeColorHex: "FF6A00", sectionCount: sections, durationSeconds: 1800, lastCompletedAt: last, preview: []
        )
    }

    func testNewWorkoutsComeFirstThenTheOnesNotDoneForTheLongest() {
        let inputs = [
            HomeRankInput(id: a, lastCompletedAt: date(10)),
            HomeRankInput(id: b, lastCompletedAt: nil),
            HomeRankInput(id: c, lastCompletedAt: date(2)),
            HomeRankInput(id: d, lastCompletedAt: nil),
        ]

        XCTAssertEqual(HomeWorkoutRanking.ranked(inputs, rotation: 0), [b, d, c, a])
    }

    func testTheLeadingPickChangesEachDayAndRepeatsAfterThree() {
        let inputs = [a, b, c, d].map { HomeRankInput(id: $0, lastCompletedAt: nil) }

        XCTAssertEqual(HomeWorkoutRanking.ranked(inputs, rotation: 0), [a, b, c, d])
        XCTAssertEqual(HomeWorkoutRanking.ranked(inputs, rotation: 1), [b, c, a, d])
        XCTAssertEqual(HomeWorkoutRanking.ranked(inputs, rotation: 2), [c, a, b, d])
        XCTAssertEqual(HomeWorkoutRanking.ranked(inputs, rotation: 3), [a, b, c, d])
        XCTAssertEqual(HomeWorkoutRanking.ranked(inputs, rotation: -1), [c, a, b, d])
    }

    func testTheRotationRestsTheDayAfterTrainingAndFollowsTheDateBeforeAnyTraining() {
        XCTAssertEqual(HomeWorkoutRanking.rotation(lastTrainedAt: date(9), now: date(10), dayIndex: 40, calendar: calendar), 0)
        XCTAssertEqual(HomeWorkoutRanking.rotation(lastTrainedAt: date(5), now: date(10), dayIndex: 40, calendar: calendar), 4)
        XCTAssertEqual(HomeWorkoutRanking.rotation(lastTrainedAt: nil, now: date(10), dayIndex: 40, calendar: calendar), 40)
    }

    func testAPlannedWorkoutIsOfferedBeforeTheRotationAndASkippedOneIsNot() {
        let planned = HomeTodayItem(id: "plan-1", workout: option(c), start: date(10, hour: 18), timeText: "6 PM", status: .pending)
        let ranked = [option(a), option(b)]

        let offered = HomePickResolver.options(planned: [planned], skipped: [], ranked: ranked, now: date(10), calendar: calendar)
        XCTAssertEqual(offered.map(\.id), [c, a, b])
        XCTAssertEqual(offered.first?.kicker, "Up next")

        let skipped = HomePickResolver.options(planned: [planned], skipped: ["plan-1"], ranked: ranked, now: date(10), calendar: calendar)
        XCTAssertEqual(skipped.map(\.id), [a, b])
    }

    func testADoneOrEmptyWorkoutIsNeverOffered() {
        let done = HomeTodayItem(id: "plan-2", workout: option(c), start: nil, timeText: "Today", status: .completed)

        let offered = HomePickResolver.options(planned: [done], skipped: [], ranked: [option(a, sections: 0), option(b)], now: date(10), calendar: calendar)

        XCTAssertEqual(offered.map(\.id), [b])
    }

    func testAPinnedWorkoutLeadsAndIsNotRepeated() {
        let offered = HomePickResolver.options(planned: [], skipped: [], ranked: [option(a), option(b)], pinned: option(b), now: date(10), calendar: calendar)

        XCTAssertEqual(offered.map(\.id), [b, a])
        XCTAssertEqual(offered.first?.reason, .pinned)
        XCTAssertEqual(offered.first?.kicker, "Your pick")
    }

    func testThePickSaysWhyItWasChosen() {
        XCTAssertEqual(HomePickCopy.reasonText(.neverDone), "New for you")
        XCTAssertEqual(HomePickCopy.reasonText(.lastDone(daysAgo: 0)), "Done earlier today")
        XCTAssertEqual(HomePickCopy.reasonText(.lastDone(daysAgo: 1)), "Last done yesterday")
        XCTAssertEqual(HomePickCopy.reasonText(.lastDone(daysAgo: 6)), "Last done 6 days ago")
        XCTAssertEqual(HomePickCopy.reasonText(.scheduled(nil)), "On today's plan")
        XCTAssertEqual(HomePickCopy.reasonText(.scheduled(date(10)), timeText: { _ in "6:00 PM" }), "Planned for 6:00 PM")
    }

    func testFirstStepsSwitchOnFromRealState() {
        let none = HomeFirstStepsProgress(readyWorkouts: 0, finishedSessions: 0, hasPlan: false, skills: 0, bestStreak: 0)
        XCTAssertEqual(none.doneCount, 0)
        XCTAssertEqual(none.next, .workoutReady)

        let some = HomeFirstStepsProgress(readyWorkouts: 4, finishedSessions: 0, hasPlan: false, skills: 2, bestStreak: 1)
        XCTAssertEqual(some.done, [.workoutReady, .addSkill])
        XCTAssertEqual(some.next, .finishSession)
        XCTAssertEqual(some.fraction, 0.4, accuracy: 0.0001)
        XCTAssertFalse(some.isComplete)

        let all = HomeFirstStepsProgress(readyWorkouts: 1, finishedSessions: 3, hasPlan: true, skills: 1, bestStreak: 2)
        XCTAssertTrue(all.isComplete)
        XCTAssertNil(all.next)
    }

    func testTheFirstSessionStartsTheRingAndTheCopyCountsWhatIsLeft() {
        var progress = HomeProgressSnapshot(weeklyGoal: 4)
        XCTAssertEqual(HomeProgressCopy.message(for: progress).headline, "Your first session starts the ring")
        XCTAssertTrue(HomeProgressCopy.message(for: progress).detail.contains("4 sessions"))

        progress = HomeProgressSnapshot(sessionsThisWeek: 1, weeklyGoal: 4, totalSessions: 5)
        XCTAssertEqual(HomeProgressCopy.message(for: progress).headline, "3 more sessions fill your ring")
        XCTAssertEqual(HomeProgressCopy.message(for: progress).detail, "1 of 4 done this week.")
        XCTAssertEqual(progress.goalFraction, 0.25, accuracy: 0.0001)
        XCTAssertEqual(HomeProgressCopy.ringLabel(for: progress), "1/4")

        progress.sessionsThisWeek = 3
        XCTAssertEqual(HomeProgressCopy.message(for: progress).headline, "One more session fills your ring")

        progress.sessionsThisWeek = 5
        XCTAssertEqual(HomeProgressCopy.message(for: progress).headline, "Weekly goal reached")
        XCTAssertEqual(progress.goalFraction, 1)

        progress = HomeProgressSnapshot(sessionsThisWeek: 0, weeklyGoal: 0, totalSessions: 9)
        XCTAssertEqual(HomeProgressCopy.message(for: progress).headline, "A fresh week")
    }

    func testTheWeekAheadSaysWhatIsPlannedAndWhereTheOpenDaysAre() {
        func day(_ number: Int, planned: Int, done: Int = 0) -> HomeWeekDay {
            HomeWeekDay(
                date: date(number), weekdayShort: "D\(number)", relativeLabel: "Day \(number)", dayNumber: number,
                isToday: number == 10, planned: planned, done: done, titles: planned > 0 ? ["Legs"] : []
            )
        }
        let empty = (10...16).map { day($0, planned: 0) }
        XCTAssertEqual(HomeWeekCopy.summary(empty), "Nothing planned yet")
        XCTAssertEqual(HomeWeekCopy.firstOpenDay(empty)?.dayNumber, 10)

        let busy = [day(10, planned: 1, done: 1), day(11, planned: 2), day(12, planned: 0)]
        XCTAssertEqual(HomeWeekCopy.summary(busy), "2 sessions planned")
        XCTAssertEqual(HomeWeekCopy.upcoming(busy, limit: 3).map(\.dayNumber), [11])
        XCTAssertEqual(HomeWeekCopy.firstOpenDay(busy)?.dayNumber, 12)
        XCTAssertTrue(busy[0].isDone)

        let finished = [day(10, planned: 1, done: 1)]
        XCTAssertEqual(HomeWeekCopy.summary(finished), "All planned sessions done")
    }

    func testTheLibraryInvitesTheNextUsefulThingAndOnlyWhatExists() {
        XCTAssertEqual(HomeLibraryCopy.invite(HomeLibraryCounts(), canRecordOutdoor: true), "Build your first workout.")
        XCTAssertEqual(HomeLibraryCopy.invite(HomeLibraryCounts(workouts: 1), canRecordOutdoor: true), "Add exercises to build richer workouts.")
        XCTAssertEqual(HomeLibraryCopy.invite(HomeLibraryCounts(exercises: 9, workouts: 1), canRecordOutdoor: true), "Add a skill to learn it step by step.")
        XCTAssertEqual(
            HomeLibraryCopy.invite(HomeLibraryCounts(exercises: 9, skills: 2, workouts: 1), canRecordOutdoor: true),
            "Plan a route and it will show up here."
        )
        XCTAssertNil(HomeLibraryCopy.invite(HomeLibraryCounts(exercises: 9, skills: 2, workouts: 1), canRecordOutdoor: false))

        let stats = HomeLibraryCopy.stats(HomeLibraryCounts(exercises: 12, skills: 0, workouts: 1, notes: 4, routes: 0), kinds: [.exercises, .skills, .workouts])
        XCTAssertEqual(HomeLibraryCopy.summary(stats), "12 exercises · 1 workout")
    }

    func testAnAccentThatWouldVanishOnTheDarkCardFallsBackToOrange() {
        XCTAssertEqual(HomeColor.accentHex("FFFFFF"), HomeColor.fallbackHex)
        XCTAssertEqual(HomeColor.accentHex("000000"), HomeColor.fallbackHex)
        XCTAssertEqual(HomeColor.accentHex("#34D399"), "34D399")
    }
}

@MainActor
final class HomeWidgetLayoutMigrationTests: XCTestCase {
    private var suite = ""
    private var defaults: UserDefaults!

    override func setUp() {
        suite = "home-layout-\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suite)
        defaults.set(true, forKey: "home_greeting_strip_migration_v1")
        defaults.set(true, forKey: "home_map_opener_migration_v1")
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suite)
    }

    private func save(_ kinds: [HomeWidgetKind]) throws {
        let widgets = kinds.map { HomeWidgetInstance(kind: $0) }
        defaults.set(try JSONEncoder().encode(widgets), forKey: "home_widget_layout_v1")
    }

    func testAnExistingLayoutGainsFirstStepsWeekAheadAndTheActivityGridOnce() throws {
        try save([.greeting, .today, .quickStart, .metrics, .activityShortcuts])

        let first = HomeWidgetStore(defaults: defaults)
        XCTAssertEqual(first.widgets.map(\.kind), [.greeting, .today, .quickStart, .firstSteps, .weekAhead, .metrics, .activityHeatmap, .activityShortcuts])

        let second = HomeWidgetStore(defaults: defaults)
        XCTAssertEqual(second.widgets.map(\.kind), first.widgets.map(\.kind))
    }

    func testAWidgetTheUserRemovesLaterStaysRemoved() throws {
        try save([.greeting, .today, .quickStart])
        let store = HomeWidgetStore(defaults: defaults)
        let weekAhead = try XCTUnwrap(store.widgets.first { $0.kind == .weekAhead })

        store.remove(id: weekAhead.id)

        let reopened = HomeWidgetStore(defaults: defaults)
        XCTAssertFalse(reopened.widgets.contains { $0.kind == .weekAhead })
        XCTAssertTrue(reopened.widgets.contains { $0.kind == .firstSteps })
    }

    func testAFreshInstallStartsWithTheDayOneWidgetsAndNoDuplicates() {
        let store = HomeWidgetStore(defaults: defaults)

        let kinds = store.widgets.map(\.kind)
        XCTAssertTrue(kinds.contains(.todaysPick))
        XCTAssertTrue(kinds.contains(.firstSteps))
        XCTAssertTrue(kinds.contains(.weekAhead))
        XCTAssertEqual(Set(kinds).count, kinds.count)
    }

    func testALayoutSavedByANewerBuildWithAnUnknownWidgetStillOpens() throws {
        let known = try JSONEncoder().encode([HomeWidgetInstance(kind: .greeting), HomeWidgetInstance(kind: .metrics)])
        var objects = try XCTUnwrap(try JSONSerialization.jsonObject(with: known) as? [[String: Any]])
        objects.insert(["id": UUID().uuidString, "kind": "somethingFromTheFuture"], at: 1)
        defaults.set(try JSONSerialization.data(withJSONObject: objects), forKey: "home_widget_layout_v1")

        let store = HomeWidgetStore(defaults: defaults)

        XCTAssertEqual(store.widgets.map(\.kind).filter { $0 == .greeting || $0 == .metrics }, [.greeting, .metrics])
        XCTAssertFalse(store.widgets.isEmpty)
    }

    func testFirstStepsClearsItselfOnTheNextLaunchAfterEverythingIsDone() throws {
        try save([.greeting, .firstSteps])
        let thisLaunch = HomeWidgetStore(defaults: defaults)

        thisLaunch.settleFirstSteps(isComplete: true)
        XCTAssertTrue(thisLaunch.widgets.contains { $0.kind == .firstSteps }, "the card celebrates for the rest of this launch")

        defaults.set("an-earlier-launch", forKey: "home_first_steps_celebrated_v1")
        thisLaunch.settleFirstSteps(isComplete: true)
        XCTAssertFalse(thisLaunch.widgets.contains { $0.kind == .firstSteps })
    }

    func testFirstStepsStaysWhileAStepIsStillOpen() throws {
        try save([.greeting, .firstSteps])
        let store = HomeWidgetStore(defaults: defaults)
        defaults.set("an-earlier-launch", forKey: "home_first_steps_celebrated_v1")

        store.settleFirstSteps(isComplete: false)

        XCTAssertTrue(store.widgets.contains { $0.kind == .firstSteps })
    }
}
