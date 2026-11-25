import SwiftUI

struct HomePickContent: View {
    let option: HomePickOption
    let footprint: HomeWidgetFootprint
    let showsDetails: Bool
    let kicker: String
    let canCycle: Bool
    let onStart: () -> Void
    let onPlan: () -> Void
    let onAnother: () -> Void

    private var workout: HomeWorkoutOption { option.workout }
    private var detail: String { HomePickCopy.detailLine(for: option) }

    var body: some View {
        HomeFeatureLayout(
            footprint: footprint,
            label: kicker,
            title: workout.name,
            meta: showsDetails ? HomeText.duration(seconds: workout.durationSeconds) : nil
        ) {
            switch footprint {
            case .compact:
                HomeIconButton(
                    systemImage: "play.fill",
                    label: "Start \(workout.name)",
                    hint: detail,
                    prominent: true,
                    action: onStart
                )
            case .wide:
                HomePillButton(title: "Start", systemImage: "play.fill", hint: "Starts \(workout.name). \(detail)", action: onStart)
                    .fixedSize()
                secondaryButtons
            case .square:
                HomePillButton(
                    title: "Start",
                    systemImage: "play.fill",
                    fillsWidth: true,
                    hint: "Starts \(workout.name). \(detail)",
                    action: onStart
                )
                secondaryButtons
            }
        }
    }

    @ViewBuilder
    private var secondaryButtons: some View {
        if canCycle {
            HomeIconButton(
                systemImage: "arrow.triangle.2.circlepath",
                label: "Another workout",
                hint: "Shows a different workout",
                action: onAnother
            )
        }
        HomeIconButton(
            systemImage: "calendar.badge.plus",
            label: "Plan \(workout.name)",
            hint: "Chooses a day for this workout",
            action: onPlan
        )
    }
}

struct HomeTodaysPickCard: View {
    let options: [HomePickOption]
    let footprint: HomeWidgetFootprint
    let showsDetails: Bool
    let planDate: Date
    var kickerOverride: String?
    let actions: HomeWidgetActions

    @State private var offset = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var current: HomePickOption? {
        guard !options.isEmpty else { return nil }
        return options[HomeDay.wrapped(offset, count: options.count)]
    }

    var body: some View {
        if let option = current {
            HomeWidgetChrome(art: .forWorkout(option.workout), spot: .home(footprint)) {
                HomePickContent(
                    option: option,
                    footprint: footprint,
                    showsDetails: showsDetails,
                    kicker: kickerOverride ?? option.kicker,
                    canCycle: options.count > 1,
                    onStart: { actions.startWorkout(option.workout.id) },
                    onPlan: { actions.planWorkout(planDate, option.workout.id) },
                    onAnother: cycle
                )
                .id(option.id)
                .transition(.opacity)
            }
        } else {
            HomeWidgetChrome(art: .dumbbell, spot: .home(footprint)) {
                HomeInvite(
                    footprint: footprint,
                    headline: "Build your first workout",
                    action: HomeInviteAction(
                        title: "Create",
                        hint: "Add a few exercises and Tmax will suggest one for you every day",
                        run: actions.createWorkout
                    )
                )
            }
        }
    }

    private func cycle() {
        EverHaptic.selection()
        withAnimation(reduceMotion ? nil : EverMotion.state) {
            offset = HomeDay.wrapped(offset + 1, count: options.count)
        }
    }
}

struct HomeWeekAheadCard: View {
    let days: [HomeWeekDay]
    let footprint: HomeWidgetFootprint
    let suggestion: HomeWorkoutOption?
    let actions: HomeWidgetActions

    private static let tint = WidgetTint.orange

    var body: some View {
        HomeWidgetChrome(tint: Self.tint) {
            VStack(alignment: .leading, spacing: 10) {
                header
                HStack(spacing: 0) {
                    ForEach(days) { day in
                        dayButton(day)
                    }
                }
                if footprint == .square {
                    comingUp
                }
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
    }

    @ViewBuilder
    private var header: some View {
        let planned = days.reduce(0) { $0 + $1.planned }
        let pending = days.reduce(0) { $0 + $1.pending }
        Group {
            if planned == 0 {
                WidgetTitle(text: "Free week", size: 26, lines: 1)
            } else {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    WidgetHero(text: "\(pending == 0 ? planned : pending)", size: 34)
                        .fixedSize()
                    WidgetLabel(text: pending == 0 ? "done" : "planned")
                }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Week ahead, \(HomeWeekCopy.summary(days))")
        .accessibilityAddTraits(.isHeader)
    }

    private func dayButton(_ day: HomeWeekDay) -> some View {
        Button {
            if day.isOpen {
                actions.planWorkout(day.date, nil)
            } else {
                HomeNavigation.open(.schedule)
            }
        } label: {
            VStack(spacing: 4) {
                Text(day.weekdayShort)
                    .font(TimeMasterFont.black(11, relativeTo: .caption2))
                    .foregroundStyle(day.isToday ? Self.tint.ink : Self.tint.secondaryInk)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                Text("\(day.dayNumber)")
                    .font(TimeMasterFont.black(15, relativeTo: .subheadline))
                    .monospacedDigit()
                    .foregroundStyle(day.isToday ? Self.tint.pillInk : Self.tint.ink)
                    .frame(width: 34, height: 34)
                    .background(dayFill(day), in: Circle())
                marker(day)
                    .frame(height: 12)
            }
            .frame(maxWidth: .infinity, minHeight: 68)
            .contentShape(Rectangle())
        }
        .buttonStyle(SkillsPressStyle(cornerRadius: 14))
        .accessibilityLabel(accessibilityLabel(day))
        .accessibilityHint(day.isOpen ? "Plans a workout for this day" : "Opens your schedule")
    }

    private func dayFill(_ day: HomeWeekDay) -> Color {
        if day.isToday { return Self.tint.pillFill }
        return Color.white.opacity(day.isOpen ? 0.3 : 0.62)
    }

    @ViewBuilder
    private func marker(_ day: HomeWeekDay) -> some View {
        if day.isDone {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(Self.tint.ink)
        } else if day.isOpen {
            Image(systemName: "plus")
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(Self.tint.secondaryInk)
        } else {
            HStack(spacing: 3) {
                ForEach(0..<min(day.pending, 3), id: \.self) { _ in
                    Circle()
                        .fill(Self.tint.ink)
                        .frame(width: 5, height: 5)
                }
            }
        }
    }

    private func accessibilityLabel(_ day: HomeWeekDay) -> String {
        let title = "\(day.relativeLabel), \(day.dayNumber)"
        if day.isOpen { return "\(title), nothing planned" }
        if day.isDone { return "\(title), all done" }
        return "\(title), \(HomeText.count(day.pending, "workout", "workouts")) planned: \(day.titles.joined(separator: ", "))"
    }

    @ViewBuilder
    private var comingUp: some View {
        let upcoming = HomeWeekCopy.upcoming(days, limit: 3)
        VStack(alignment: .leading, spacing: 8) {
            if upcoming.isEmpty {
                if let suggestion, let open = HomeWeekCopy.firstOpenDay(days) {
                    HomePillButton(
                        title: "Plan \(suggestion.name)",
                        systemImage: "calendar.badge.plus",
                        fillsWidth: true,
                        hint: "Chooses a time on \(open.relativeLabel)"
                    ) {
                        actions.planWorkout(open.date, suggestion.id)
                    }
                }
            } else {
                ForEach(upcoming) { day in
                    Button {
                        HomeNavigation.open(.schedule)
                    } label: {
                        HStack(spacing: 10) {
                            Text(day.relativeLabel)
                                .font(TimeMasterFont.rowTitle())
                                .foregroundStyle(Self.tint.ink)
                                .lineLimit(1)
                            Spacer(minLength: 6)
                            Text(day.titles.joined(separator: ", "))
                                .font(WidgetFont.label())
                                .foregroundStyle(Self.tint.secondaryInk)
                                .lineLimit(1)
                        }
                        .padding(.horizontal, 16)
                        .frame(minHeight: 44)
                        .background(Self.tint.softFill, in: Capsule())
                        .contentShape(Capsule())
                    }
                    .buttonStyle(SkillsPressStyle(cornerRadius: 22))
                    .accessibilityLabel("\(day.relativeLabel): \(day.titles.joined(separator: ", "))")
                    .accessibilityHint("Opens your schedule")
                }
            }
        }
    }
}

struct HomeFirstStepsCard: View {
    let progress: HomeFirstStepsProgress
    let footprint: HomeWidgetFootprint
    let pick: HomePickOption?
    let planDate: Date
    let actions: HomeWidgetActions

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private static let tint = WidgetTint.peach

    var body: some View {
        if progress.isComplete {
            HomeWidgetChrome(art: .trophy, spot: .home(footprint)) {
                HomeInvite(
                    footprint: footprint,
                    headline: "You're all set",
                    action: HomeInviteAction(title: "Clear", systemImage: "xmark", hint: "Removes this card from Home", run: actions.removeWidget)
                )
            }
        } else if footprint == .square {
            HomeWidgetChrome(tint: Self.tint) {
                square
            }
        } else {
            HomeWidgetChrome(art: .medal, spot: .home(footprint)) {
                summary
            }
        }
    }

    private func perform(_ step: HomeFirstStep) {
        switch step {
        case .workoutReady:
            actions.createWorkout()
        case .finishSession, .buildStreak:
            if let pick {
                actions.startWorkout(pick.workout.id)
            } else {
                actions.createWorkout()
            }
        case .planSomething:
            actions.planWorkout(planDate, pick?.workout.id)
        case .addSkill:
            actions.addSkill()
        }
    }

    private func actionTitle(_ step: HomeFirstStep) -> String {
        switch step {
        case .workoutReady: "Create"
        case .finishSession, .buildStreak: "Start"
        case .planSomething: "Plan"
        case .addSkill: "Add"
        }
    }

    private func actionImage(_ step: HomeFirstStep) -> String {
        switch step {
        case .workoutReady: "plus"
        case .finishSession, .buildStreak: "play.fill"
        case .planSomething: "calendar.badge.plus"
        case .addSkill: "plus"
        }
    }

    private var count: some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            WidgetHero(text: "\(progress.doneCount)/\(progress.total)", size: 32)
                .fixedSize()
            WidgetLabel(text: "first steps")
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("First steps, \(progress.doneCount) of \(progress.total) done")
    }

    @ViewBuilder
    private var summary: some View {
        if let next = progress.next {
            GeometryReader { proxy in
                VStack(alignment: .leading, spacing: 4) {
                    count
                    WidgetTitle(text: next.title, size: 17, lines: 2)
                    Spacer(minLength: 0)
                    HomePillButton(
                        title: actionTitle(next),
                        systemImage: actionImage(next),
                        hint: "\(next.title). \(next.detail)"
                    ) {
                        perform(next)
                    }
                    .fixedSize()
                }
                .frame(width: max(0, proxy.size.width - WidgetArtSpot.sideRoom(forHeight: proxy.size.height)), alignment: .leading)
                .frame(maxHeight: .infinity, alignment: .topLeading)
            }
            .accessibilityElement(children: .contain)
        }
    }

    private var square: some View {
        VStack(alignment: .leading, spacing: 12) {
            count
            VStack(spacing: 6) {
                ForEach(HomeFirstStep.allCases) { step in
                    row(step)
                }
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .accessibilityElement(children: .contain)
    }

    @ViewBuilder
    private func row(_ step: HomeFirstStep) -> some View {
        let done = progress.isDone(step)
        if done {
            rowLabel(step, done: true)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("\(step.title), done")
        } else {
            Button {
                perform(step)
            } label: {
                rowLabel(step, done: false)
            }
            .buttonStyle(SkillsPressStyle(cornerRadius: 22))
            .accessibilityLabel(step.title)
            .accessibilityHint(step.detail)
        }
    }

    private func rowLabel(_ step: HomeFirstStep, done: Bool) -> some View {
        HStack(spacing: 10) {
            Image(systemName: done ? "checkmark.circle.fill" : step.systemImage)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(done ? Self.tint.secondaryInk : Self.tint.ink)
                .frame(width: 24)
                .scaleEffect(done ? 1 : 0.92)
                .animation(reduceMotion ? nil : .spring(response: 0.3, dampingFraction: 0.6), value: done)
            Text(step.title)
                .font(TimeMasterFont.rowTitle())
                .strikethrough(done, color: Self.tint.secondaryInk)
                .foregroundStyle(done ? Self.tint.secondaryInk : Self.tint.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            Spacer(minLength: 6)
        }
        .padding(.horizontal, 14)
        .frame(maxWidth: .infinity, minHeight: 44)
        .background(Self.tint.ink.opacity(done ? 0.04 : 0.09), in: Capsule())
        .contentShape(Capsule())
    }
}
