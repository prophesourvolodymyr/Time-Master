import SwiftUI

struct MenuBarHomePage: View {
    @ObservedObject var store: WorkoutStore
    @ObservedObject private var live = WorkoutLiveSession.shared
    @ObservedObject private var resume = WorkoutResumeManager.shared
    @ObservedObject private var preferences = MenuBarPreferences.shared
    @Environment(\.menuBarActions) private var actions

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                if let state = live.state {
                    MenuBarLiveCard(state: state)
                } else {
                    finishCard
                    launcher
                    todaySection
                    suggestionSection
                }
                quoteSection
                quickActions
            }
            .padding(14)
        }
        .scrollIndicators(.hidden)
    }

    @ViewBuilder
    private var finishCard: some View {
        if let finish = live.lastFinish, Date().timeIntervalSince(finish.finishedAt) < 600 {
            WidgetCard(art: .trophy, spot: .side) {
                VStack(alignment: .leading, spacing: 2) {
                    WidgetTitle(text: "Nice work", size: 24, lines: 1)
                    WidgetLabel(text: "\(WorkoutTitle.short(finish.workoutName)) · \(MenuBarFormat.clock(finish.elapsedSeconds))")
                }
                .padding(.trailing, 96)
                .padding(16)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            }
            .frame(height: 96)
            .clipShape(MenuBarMetrics.shape)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Nice work. \(finish.workoutName), \(MenuBarFormat.clock(finish.elapsedSeconds))")
        }
    }

    private var todayItems: [ScheduledWorkout] {
        store.scheduledWorkouts(for: Date())
    }

    private var upNext: (workout: Workout, caption: String)? {
        if let scheduled = todayItems.first(where: { $0.status == .pending && !$0.workout.sections.isEmpty }) {
            return (scheduled.workout, "Up next · \(scheduled.timeRangeText)")
        }
        if let first = store.workouts.first(where: { !$0.sections.isEmpty && !store.isArchived($0) }) {
            return (first, "Quick start")
        }
        return nil
    }

    private var showsContinue: Bool {
        guard resume.hasResumableWorkout, let saved = resume.resumeState else { return false }
        return store.workout(id: saved.workoutId) != nil
    }

    @ViewBuilder
    private var launcher: some View {
        if resume.hasResumableWorkout, let saved = resume.resumeState, store.workout(id: saved.workoutId) != nil {
            MenuBarHeroCard(
                art: .stopwatch,
                label: "Continue",
                title: WorkoutTitle.short(saved.workoutName),
                meta: "\(MenuBarFormat.clock(saved.elapsedSeconds)) in"
            ) {
                HomePillButton(
                    title: "Resume",
                    systemImage: "play.fill",
                    hint: "\(saved.workoutName), \(saved.sectionName)"
                ) {
                    actions.startWorkout(saved.workoutId)
                }
                .fixedSize()
            }
        } else if let next = upNext {
            MenuBarHeroCard(
                art: .forWorkout(next.workout),
                label: next.caption,
                title: WorkoutTitle.short(next.workout.name),
                meta: MenuBarFormat.minutes(next.workout.totalDuration)
            ) {
                HomePillButton(
                    title: "Start",
                    systemImage: "play.fill",
                    hint: "Starts \(next.workout.name)"
                ) {
                    actions.startWorkout(next.workout.id)
                }
                .fixedSize()
            }
        } else {
            MenuBarHeroCard(art: .dumbbell, title: "No workouts yet") {
                HomePillButton(title: "New workout", systemImage: "plus", hint: "Creates a workout in Tmax") {
                    actions.newWorkout()
                }
                .fixedSize()
            }
        }
    }

    @ViewBuilder
    private var todaySection: some View {
        let items = todayItems.filter { !$0.workout.sections.isEmpty }
        if !items.isEmpty {
            let done = items.filter { $0.status == .completed }.count
            VStack(spacing: 8) {
                MenuBarSectionTitle(title: "Today", trailing: "\(done) of \(items.count) done")
                MenuBarCard(padding: 12) {
                    VStack(spacing: 10) {
                        ForEach(items) { item in
                            MenuBarScheduledRow(item: item)
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var suggestionSection: some View {
        if preferences.showsSuggestions {
            let suggestions = MenuBarSuggestionEngine.make(.make(store: store))
                .filter { !(showsContinue && $0.kind == .resume) }
                .prefix(2)
            ForEach(Array(suggestions)) { suggestion in
                MenuBarSuggestionCard(suggestion: suggestion)
            }
        }
    }

    @ViewBuilder
    private var quoteSection: some View {
        if preferences.showsQuotes {
            let quote = MenuBarQuotes.daily()
            MenuBarCard(padding: 16) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("“\(quote.text)”")
                        .font(TimeMasterFont.blackItalic(15, relativeTo: .subheadline))
                        .foregroundStyle(Theme.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                    WidgetLabel(text: quote.author)
                }
                .accessibilityElement(children: .combine)
            }
        }
    }

    private var quickActions: some View {
        HStack(spacing: 8) {
            MenuBarCompactButton(title: "New", symbol: "plus", fillsWidth: true) { actions.newWorkout() }
            MenuBarCompactButton(title: "Coach", symbol: "brain.head.profile", fillsWidth: true) {
                actions.openPage(.coach, nil)
            }
            MenuBarCompactButton(title: "Open", symbol: "macwindow", fillsWidth: true) { actions.showMainWindow() }
        }
    }
}

private struct MenuBarSuggestionCard: View {
    let suggestion: MenuBarSuggestion
    @Environment(\.menuBarActions) private var actions

    var body: some View {
        MenuBarCard(padding: 14) {
            HStack(spacing: 10) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(suggestion.title)
                        .font(TimeMasterFont.black(15, relativeTo: .subheadline))
                        .foregroundStyle(Theme.textPrimary)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(suggestion.message)
                        .font(WidgetFont.label())
                        .foregroundStyle(WidgetTint.graphite.secondaryInk)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                if let actionTitle = suggestion.actionTitle {
                    MenuBarCompactButton(title: actionTitle, symbol: symbol, prominent: suggestion.isStart) { perform() }
                        .fixedSize()
                }
            }
        }
    }

    private var symbol: String {
        switch suggestion.action {
        case .startWorkout: "play.fill"
        case .openPage: "arrow.up.right"
        case .none: "circle"
        }
    }

    private func perform() {
        switch suggestion.action {
        case .startWorkout(let id): actions.startWorkout(id)
        case .openPage(let destination): actions.openPage(destination, nil)
        case .none: break
        }
    }
}

private extension MenuBarSuggestion {
    var isStart: Bool {
        if case .startWorkout = action { return true }
        return false
    }
}

struct MenuBarLiveCard: View {
    let state: WorkoutLiveState
    @State private var confirmingEnd = false
    @Environment(\.menuBarActions) private var actions

    private var tint: Color { state.isRest ? WidgetTint.peach.base : Theme.toolbarOrange }

    private var phaseName: String {
        if state.isPaused { return "Paused" }
        switch state.phase {
        case .warmUp: return "Warm up"
        case .prepare: return "Get ready"
        case .active: return state.isUntimed ? "Until Done" : "Work"
        case .setRest, .sectionRest: return "Rest"
        }
    }

    var body: some View {
        MenuBarCard(emphasized: true, padding: 16) {
            VStack(spacing: 12) {
                WidgetLabel(text: WorkoutTitle.short(state.workoutName))
                    .frame(maxWidth: .infinity, alignment: .leading)
                MenuBarRing(progress: state.phaseProgress, lineWidth: 10, tint: tint) {
                    VStack(spacing: 0) {
                        Text(MenuBarFormat.clock(state.untimedSeconds ?? state.remainingSeconds))
                            .font(WidgetFont.hero(42))
                            .foregroundStyle(Theme.textPrimary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.6)
                        Text(phaseName)
                            .font(TimeMasterFont.black(13, relativeTo: .caption))
                            .foregroundStyle(tint)
                    }
                    .padding(.horizontal, 18)
                }
                .frame(width: 156, height: 156)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(state.untimedSeconds.map { "\(phaseName), \(MenuBarFormat.clock($0)) in this set" }
                    ?? "\(phaseName), \(MenuBarFormat.clock(state.remainingSeconds)) left")
                VStack(spacing: 2) {
                    WidgetTitle(text: state.title, size: 20, lines: 2)
                        .multilineTextAlignment(.center)
                    if !state.subtitle.isEmpty {
                        WidgetLabel(text: state.subtitle)
                    }
                }
                if let next = state.nextTitle, !next.isEmpty {
                    HStack(spacing: 8) {
                        MenuBarChip(text: "NEXT", tint: tint)
                        Text(next)
                            .font(TimeMasterFont.black(14, relativeTo: .subheadline))
                            .foregroundStyle(Theme.textPrimary)
                            .lineLimit(1)
                    }
                    .accessibilityElement(children: .combine)
                }
                progressBar
                controls
            }
        }
    }

    private var progressBar: some View {
        VStack(spacing: 4) {
            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule().fill(WidgetTint.graphite.track)
                    Capsule()
                        .fill(tint)
                        .frame(width: proxy.size.width * (state.workoutProgress ?? 0))
                }
            }
            .frame(height: 6)
            HStack {
                Text("\(MenuBarFormat.clock(state.elapsedSeconds)) in")
                Spacer()
                if let left = state.remainingWorkoutSeconds {
                    Text("\(MenuBarFormat.clock(left)) left")
                }
            }
            .font(WidgetFont.label())
            .monospacedDigit()
            .foregroundStyle(WidgetTint.graphite.secondaryInk)
        }
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private var controls: some View {
        if confirmingEnd {
            VStack(spacing: 8) {
                Text("End this workout?")
                    .font(TimeMasterFont.black(15, relativeTo: .subheadline))
                    .foregroundStyle(Theme.textPrimary)
                    .multilineTextAlignment(.center)
                HStack(spacing: 8) {
                    MenuBarCompactButton(title: "Keep going", symbol: "arrow.uturn.backward", fillsWidth: true) {
                        confirmingEnd = false
                    }
                    Button(role: .destructive) {
                        WorkoutLiveSession.shared.send(.endWorkout)
                    } label: {
                        Label("End", systemImage: "stop.fill")
                            .font(TimeMasterFont.black(15, relativeTo: .subheadline))
                            .foregroundStyle(WidgetTint.peach.ink)
                            .frame(maxWidth: .infinity, minHeight: MenuBarMetrics.buttonHeight)
                            .background(WidgetTint.peach.base, in: Capsule())
                            .contentShape(Capsule())
                    }
                    .buttonStyle(SkillsPressStyle(cornerRadius: MenuBarMetrics.buttonHeight / 2))
                }
            }
        } else {
            VStack(spacing: 8) {
                HStack(spacing: 8) {
                    MenuBarCompactButton(
                        title: state.isPaused ? "Resume" : "Pause",
                        symbol: state.isPaused ? "play.fill" : "pause.fill",
                        prominent: true,
                        fillsWidth: true
                    ) {
                        WorkoutLiveSession.shared.send(.togglePause)
                    }
                    MenuBarCompactButton(title: "Skip", symbol: "forward.end.fill", fillsWidth: true) {
                        WorkoutLiveSession.shared.send(.skipPhase)
                    }
                    HomeIconButton(systemImage: "stop.fill", label: "End workout", diameter: MenuBarMetrics.buttonHeight) {
                        confirmingEnd = true
                    }
                }
                MenuBarCompactButton(title: "Open in Tmax", symbol: "macwindow", fillsWidth: true) {
                    actions.showMainWindow()
                }
            }
        }
    }
}
