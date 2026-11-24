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
    private var tint: Color { Color(hex: HomeColor.accentHex(workout.typeColorHex)) }
    private var detail: String { HomePickCopy.detailLine(for: option) }

    var body: some View {
        switch footprint {
        case .compact: compact
        case .wide: wide
        case .square: square
        }
    }

    private var kickerLabel: some View {
        HomeKicker(text: kicker, systemImage: "sparkles", tint: tint)
    }

    private var wide: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .center, spacing: 12) {
                HomeWorkoutTile(systemImage: workout.typeIcon, colorHex: workout.typeColorHex, side: 56)
                VStack(alignment: .leading, spacing: 3) {
                    kickerLabel
                    Text(workout.name)
                        .font(TimeMasterFont.heading())
                        .foregroundStyle(Theme.textPrimary)
                        .lineLimit(2)
                        .minimumScaleFactor(0.8)
                    if showsDetails {
                        Text(detail)
                            .font(TimeMasterFont.caption())
                            .foregroundStyle(Theme.textSecondary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                startCircle(diameter: 52)
            }
            HStack(spacing: 8) {
                if canCycle {
                    secondaryPill(title: "Another", systemImage: "arrow.triangle.2.circlepath", hint: "Shows a different workout", action: onAnother)
                }
                secondaryPill(title: "Plan", systemImage: "calendar.badge.plus", hint: "Chooses a day for \(workout.name)", action: onPlan)
                Spacer(minLength: 0)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var compact: some View {
        VStack(alignment: .leading, spacing: 6) {
            kickerLabel
            Text(workout.name)
                .font(TimeMasterFont.black(17, relativeTo: .headline))
                .foregroundStyle(Theme.textPrimary)
                .lineLimit(2)
                .minimumScaleFactor(0.8)
            if showsDetails {
                Text(HomeText.duration(seconds: workout.durationSeconds))
                    .font(TimeMasterFont.caption())
                    .foregroundStyle(Theme.textSecondary)
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
            HomePillButton(
                title: "Start",
                systemImage: "play.fill",
                fillsWidth: true,
                hint: "Starts \(workout.name). \(detail)",
                action: onStart
            )
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var square: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 14) {
                HomeWorkoutTile(systemImage: workout.typeIcon, colorHex: workout.typeColorHex, side: 72)
                VStack(alignment: .leading, spacing: 6) {
                    kickerLabel
                    Text(workout.name)
                        .font(TimeMasterFont.black(26, relativeTo: .title))
                        .foregroundStyle(Theme.textPrimary)
                        .lineLimit(2)
                        .minimumScaleFactor(0.75)
                    Text(detail)
                        .font(TimeMasterFont.secondary())
                        .foregroundStyle(Theme.textSecondary)
                        .lineLimit(2)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            if showsDetails, !workout.preview.isEmpty {
                previewList
            }
            Spacer(minLength: 0)
            HStack(spacing: 10) {
                HomePillButton(
                    title: "Start",
                    systemImage: "play.fill",
                    fillsWidth: true,
                    hint: "Starts \(workout.name)",
                    action: onStart
                )
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
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var previewList: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(Array(workout.preview.enumerated()), id: \.offset) { index, name in
                HStack(spacing: 10) {
                    Text("\(index + 1)")
                        .font(TimeMasterFont.black(12, relativeTo: .caption))
                        .monospacedDigit()
                        .foregroundStyle(tint)
                        .frame(width: 22, height: 22)
                        .background(tint.opacity(0.16), in: Circle())
                    Text(name)
                        .font(TimeMasterFont.secondary())
                        .foregroundStyle(Theme.textPrimary.opacity(0.9))
                        .lineLimit(1)
                }
            }
            if workout.sectionCount > workout.preview.count {
                Text("+\(workout.sectionCount - workout.preview.count) more")
                    .font(TimeMasterFont.caption())
                    .foregroundStyle(Theme.textSecondary)
                    .padding(.leading, 32)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Starts with \(workout.preview.joined(separator: ", "))")
    }

    private func startCircle(diameter: CGFloat) -> some View {
        Button(action: onStart) {
            Image(systemName: "play.fill")
                .font(.system(size: diameter * 0.36, weight: .bold))
                .foregroundStyle(Color.black)
                .frame(width: diameter, height: diameter)
                .background(Color.white, in: Circle())
                .contentShape(Circle())
        }
        .buttonStyle(SkillsPressStyle(cornerRadius: diameter / 2))
        .accessibilityLabel("Start \(workout.name)")
        .accessibilityHint(detail)
    }

    private func secondaryPill(title: String, systemImage: String, hint: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .font(TimeMasterFont.black(12, relativeTo: .caption))
                .foregroundStyle(Theme.textPrimary.opacity(0.9))
                .padding(.horizontal, 12)
                .frame(minHeight: 40)
                .background(Color.white.opacity(0.1), in: Capsule())
                .contentShape(Capsule())
        }
        .buttonStyle(SkillsPressStyle(cornerRadius: 20))
        .accessibilityLabel(title)
        .accessibilityHint(hint)
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
            HomeWidgetChrome(title: nil, accent: Color(hex: HomeColor.accentHex(option.workout.typeColorHex))) {
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
            HomeWidgetChrome(title: nil) {
                HomeInvite(
                    footprint: footprint,
                    systemImage: "dumbbell.fill",
                    headline: "Build your first workout",
                    detail: "Add a few exercises and Tmax will suggest one for you every day.",
                    action: HomeInviteAction(title: "Create", run: actions.createWorkout)
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

    var body: some View {
        HomeWidgetChrome(title: nil) {
            VStack(alignment: .leading, spacing: 10) {
                HomeCardHeader(
                    title: "Week Ahead",
                    systemImage: "calendar.badge.clock",
                    trailing: HomeWeekCopy.summary(days)
                )
                HStack(spacing: 0) {
                    ForEach(days) { day in
                        dayButton(day)
                    }
                }
                if footprint == .square {
                    comingUp
                } else if days.allSatisfy(\.isOpen) {
                    Text("Tap a day to plan a workout")
                        .font(TimeMasterFont.caption())
                        .foregroundStyle(Theme.textSecondary)
                        .frame(maxWidth: .infinity)
                }
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
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
                    .foregroundStyle(day.isToday ? Theme.toolbarOrange : Theme.textSecondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                Text("\(day.dayNumber)")
                    .font(TimeMasterFont.black(15, relativeTo: .subheadline))
                    .monospacedDigit()
                    .foregroundStyle(day.isToday ? Color.black : Theme.textPrimary)
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
        if day.isToday { return Theme.toolbarOrange }
        return Color.white.opacity(day.isOpen ? 0.06 : 0.14)
    }

    @ViewBuilder
    private func marker(_ day: HomeWeekDay) -> some View {
        if day.isDone {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(Color.green)
        } else if day.isOpen {
            Image(systemName: "plus")
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(Theme.textSecondary)
        } else {
            HStack(spacing: 3) {
                ForEach(0..<min(day.pending, 3), id: \.self) { _ in
                    Circle()
                        .fill(Theme.toolbarOrange)
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
            Text("Coming up")
                .font(TimeMasterFont.black(12, relativeTo: .caption))
                .foregroundStyle(Theme.textSecondary)
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
                } else {
                    Text("Every day this week has something planned.")
                        .font(TimeMasterFont.secondary())
                        .foregroundStyle(Theme.textSecondary)
                }
            } else {
                ForEach(upcoming) { day in
                    Button {
                        HomeNavigation.open(.schedule)
                    } label: {
                        HStack(spacing: 10) {
                            Text(day.relativeLabel)
                                .font(TimeMasterFont.rowTitle())
                                .foregroundStyle(Theme.textPrimary)
                                .lineLimit(1)
                            Spacer(minLength: 6)
                            Text(day.titles.joined(separator: ", "))
                                .font(TimeMasterFont.caption())
                                .foregroundStyle(Theme.textSecondary)
                                .lineLimit(1)
                            Image(systemName: "chevron.right")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundStyle(Theme.textSecondary)
                        }
                        .padding(.horizontal, 12)
                        .frame(minHeight: 44)
                        .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .contentShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                    .buttonStyle(SkillsPressStyle(cornerRadius: 12))
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

    var body: some View {
        if progress.isComplete {
            HomeWidgetChrome(title: nil, accent: Color.green) {
                HomeInvite(
                    footprint: footprint,
                    systemImage: "checkmark.seal.fill",
                    headline: "You're all set",
                    detail: "Every first step is done. This card will clear itself.",
                    tint: Color.green,
                    action: HomeInviteAction(title: "Clear", systemImage: "xmark", hint: "Removes this card from Home", run: actions.removeWidget)
                )
            }
        } else {
            HomeWidgetChrome(title: nil, accent: Theme.toolbarOrange) {
                if footprint == .square {
                    square
                } else {
                    summary
                }
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

    private var ring: some View {
        HomeRingBadge(
            fraction: progress.fraction,
            label: "\(progress.doneCount)/\(progress.total)",
            diameter: footprint == .compact ? 52 : 64
        )
    }

    @ViewBuilder
    private var summary: some View {
        if let next = progress.next {
            HStack(spacing: 14) {
                ring
                VStack(alignment: .leading, spacing: 4) {
                    HomeKicker(text: "First steps", systemImage: "checklist")
                    Text(next.title)
                        .font(TimeMasterFont.black(17, relativeTo: .headline))
                        .foregroundStyle(Theme.textPrimary)
                        .lineLimit(2)
                        .minimumScaleFactor(0.8)
                    Text(next.detail)
                        .font(TimeMasterFont.caption())
                        .foregroundStyle(Theme.textSecondary)
                        .lineLimit(2)
                    dots
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                HomePillButton(
                    title: actionTitle(next),
                    systemImage: actionImage(next),
                    hint: next.title
                ) {
                    perform(next)
                }
                .fixedSize()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .accessibilityElement(children: .contain)
        }
    }

    private var dots: some View {
        HStack(spacing: 6) {
            ForEach(HomeFirstStep.allCases) { step in
                Circle()
                    .fill(progress.isDone(step) ? Theme.toolbarOrange : Color.white.opacity(0.18))
                    .frame(width: 8, height: 8)
            }
        }
        .accessibilityHidden(true)
    }

    private var square: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 14) {
                ring
                VStack(alignment: .leading, spacing: 3) {
                    HomeKicker(text: "First steps", systemImage: "checklist")
                    Text("\(progress.doneCount) of \(progress.total) done")
                        .font(TimeMasterFont.black(20, relativeTo: .title3))
                        .foregroundStyle(Theme.textPrimary)
                    Text("Each one switches on by itself.")
                        .font(TimeMasterFont.caption())
                        .foregroundStyle(Theme.textSecondary)
                }
                Spacer(minLength: 0)
            }
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
            .buttonStyle(SkillsPressStyle(cornerRadius: 12))
            .accessibilityLabel(step.title)
            .accessibilityHint(step.detail)
        }
    }

    private func rowLabel(_ step: HomeFirstStep, done: Bool) -> some View {
        HStack(spacing: 10) {
            Image(systemName: done ? "checkmark.circle.fill" : step.systemImage)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(done ? Color.green : Theme.toolbarOrange)
                .frame(width: 24)
                .scaleEffect(done ? 1 : 0.92)
                .animation(reduceMotion ? nil : .spring(response: 0.3, dampingFraction: 0.6), value: done)
            Text(step.title)
                .font(TimeMasterFont.rowTitle())
                .foregroundStyle(done ? Theme.textSecondary : Theme.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            Spacer(minLength: 6)
            if !done {
                Text(actionTitle(step))
                    .font(TimeMasterFont.black(12, relativeTo: .caption))
                    .foregroundStyle(Theme.textPrimary.opacity(0.85))
                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(Theme.textSecondary)
            }
        }
        .padding(.horizontal, 12)
        .frame(maxWidth: .infinity, minHeight: 44)
        .background(Color.white.opacity(done ? 0.03 : 0.07), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .contentShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}
