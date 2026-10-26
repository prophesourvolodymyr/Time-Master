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
            MenuBarCard(emphasized: true) {
                HStack(spacing: 12) {
                    Image(systemName: "checkmark.seal.fill")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundStyle(Color(hex: "34C759"))
                        .accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Nice work")
                            .font(TimeMasterFont.heading())
                            .foregroundStyle(Theme.textPrimary)
                        Text("\(finish.workoutName) · \(MenuBarFormat.clock(finish.elapsedSeconds))")
                            .font(TimeMasterFont.secondary())
                            .foregroundStyle(Theme.textSecondary)
                            .lineLimit(1)
                    }
                    Spacer(minLength: 0)
                }
                .accessibilityElement(children: .combine)
            }
        }
    }

    private var todayItems: [ScheduledWorkout] {
        store.scheduledWorkouts(for: Date())
    }

    private var upNext: (workout: Workout, caption: String)? {
        if let scheduled = todayItems.first(where: { $0.status == .pending && !$0.workout.sections.isEmpty }) {
            return (scheduled.workout, "Up next · \(scheduled.timeRangeText)")
        }
        if let first = store.workouts.first(where: { !$0.sections.isEmpty }) {
            return (first, "Quick start")
        }
        return nil
    }

    @ViewBuilder
    private var launcher: some View {
        if resume.hasResumableWorkout, let saved = resume.resumeState, store.workout(id: saved.workoutId) != nil {
            MenuBarCard(emphasized: true, padding: 16) {
                VStack(alignment: .leading, spacing: 10) {
                    Text("CONTINUE")
                        .font(TimeMasterFont.black(11, relativeTo: .caption2))
                        .foregroundStyle(Theme.toolbarOrange)
                    Text(saved.workoutName)
                        .font(TimeMasterFont.heading())
                        .foregroundStyle(Theme.textPrimary)
                        .lineLimit(2)
                    Text("\(MenuBarFormat.clock(saved.elapsedSeconds)) in · \(saved.sectionName)")
                        .font(TimeMasterFont.secondary())
                        .foregroundStyle(Theme.textSecondary)
                    MenuBarCompactButton(title: "Resume", symbol: "play.fill", prominent: true, fillsWidth: true) {
                        actions.startWorkout(saved.workoutId)
                    }
                }
            }
        } else if let next = upNext {
            MenuBarCard(emphasized: true, padding: 16) {
                VStack(alignment: .leading, spacing: 10) {
                    Text(next.caption.uppercased())
                        .font(TimeMasterFont.black(11, relativeTo: .caption2))
                        .foregroundStyle(Theme.toolbarOrange)
                    HStack(spacing: 12) {
                        MenuBarTypeTile(colorHex: next.workout.type.colorHex, symbol: next.workout.type.iconName, size: 44)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(next.workout.name)
                                .font(TimeMasterFont.heading())
                                .foregroundStyle(Theme.textPrimary)
                                .lineLimit(2)
                            Text("\(MenuBarFormat.minutes(next.workout.totalDuration)) · \(next.workout.sections.count) sections")
                                .font(TimeMasterFont.secondary())
                                .foregroundStyle(Theme.textSecondary)
                        }
                        Spacer(minLength: 0)
                    }
                    MenuBarCompactButton(title: "Start workout", symbol: "play.fill", prominent: true, fillsWidth: true) {
                        actions.startWorkout(next.workout.id)
                    }
                }
            }
        } else {
            MenuBarCard {
                VStack(spacing: 10) {
                    MenuBarEmptyState(
                        symbol: "dumbbell.fill",
                        title: "No workouts yet",
                        message: "Create a workout in Tmax."
                    )
                    MenuBarCompactButton(title: "New workout", symbol: "plus", prominent: true) {
                        actions.newWorkout()
                    }
                }
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
            let suggestions = MenuBarSuggestionEngine.make(.make(store: store)).prefix(2)
            ForEach(Array(suggestions)) { suggestion in
                MenuBarSuggestionCard(suggestion: suggestion)
            }
        }
    }

    @ViewBuilder
    private var quoteSection: some View {
        if preferences.showsQuotes {
            let quote = MenuBarQuotes.daily()
            MenuBarCard {
                VStack(alignment: .leading, spacing: 6) {
                    Text("“\(quote.text)”")
                        .font(TimeMasterFont.blackItalic(14, relativeTo: .subheadline))
                        .foregroundStyle(Theme.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(quote.author)
                        .font(TimeMasterFont.caption())
                        .foregroundStyle(Theme.textSecondary)
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
        MenuBarCard(padding: 12) {
            HStack(spacing: 10) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(suggestion.title)
                        .font(TimeMasterFont.rowTitle())
                        .foregroundStyle(Theme.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(suggestion.message)
                        .font(TimeMasterFont.caption())
                        .foregroundStyle(Theme.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 4)
                if let actionTitle = suggestion.actionTitle {
                    Button(actionTitle) { perform() }
                        .font(TimeMasterFont.black(13, relativeTo: .subheadline))
                        .buttonStyle(TimeMasterActionButtonStyle(minimumSize: 36, tint: Theme.surface2))
                }
            }
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

struct MenuBarLiveCard: View {
    let state: WorkoutLiveState
    @State private var confirmingEnd = false
    @Environment(\.menuBarActions) private var actions

    private var tint: Color { state.isRest ? Theme.accent : Theme.toolbarOrange }

    private var phaseName: String {
        if state.isPaused { return "Paused" }
        switch state.phase {
        case .warmUp: return "Warm up"
        case .prepare: return "Get ready"
        case .active: return "Work"
        case .setRest, .sectionRest: return "Rest"
        }
    }

    var body: some View {
        MenuBarCard(emphasized: true, padding: 16) {
            VStack(spacing: 12) {
                HStack {
                    Text(state.workoutName.uppercased())
                        .font(TimeMasterFont.black(11, relativeTo: .caption2))
                        .foregroundStyle(Theme.textSecondary)
                        .lineLimit(1)
                    Spacer(minLength: 8)
                }
                MenuBarRing(progress: state.phaseProgress, lineWidth: 10, tint: tint) {
                    VStack(spacing: 2) {
                        Text(MenuBarFormat.clock(state.remainingSeconds))
                            .font(TimeMasterFont.black(42, relativeTo: .largeTitle))
                            .monospacedDigit()
                            .foregroundStyle(Theme.textPrimary)
                        Text(phaseName.uppercased())
                            .font(TimeMasterFont.black(11, relativeTo: .caption2))
                            .foregroundStyle(tint)
                    }
                }
                .frame(width: 150, height: 150)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("\(phaseName), \(MenuBarFormat.clock(state.remainingSeconds)) left")
                VStack(spacing: 3) {
                    Text(state.title)
                        .font(TimeMasterFont.heading())
                        .foregroundStyle(Theme.textPrimary)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                    if !state.subtitle.isEmpty {
                        Text(state.subtitle)
                            .font(TimeMasterFont.secondary())
                            .foregroundStyle(Theme.textSecondary)
                    }
                }
                if let next = state.nextTitle, !next.isEmpty {
                    HStack(spacing: 8) {
                        MenuBarChip(text: "NEXT", tint: tint)
                        Text(next)
                            .font(TimeMasterFont.rowTitle())
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
                    Capsule().fill(Theme.separator)
                    Capsule()
                        .fill(tint)
                        .frame(width: proxy.size.width * (state.workoutProgress ?? 0))
                }
            }
            .frame(height: 6)
            HStack {
                Text("\(MenuBarFormat.clock(state.elapsedSeconds)) elapsed")
                Spacer()
                if let left = state.remainingWorkoutSeconds {
                    Text("\(MenuBarFormat.clock(left)) left")
                }
            }
            .font(TimeMasterFont.caption())
            .foregroundStyle(Theme.textSecondary)
        }
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private var controls: some View {
        if confirmingEnd {
            VStack(spacing: 8) {
                Text("End this workout?")
                    .font(TimeMasterFont.secondary())
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
                            .font(TimeMasterFont.black(14, relativeTo: .subheadline))
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(TimeMasterActionButtonStyle(prominent: true, minimumSize: 40, fillsWidth: true))
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
                    Button {
                        confirmingEnd = true
                    } label: {
                        Image(systemName: "stop.fill")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(Theme.textPrimary)
                    }
                    .buttonStyle(TimeMasterActionButtonStyle(circular: true, minimumSize: 40, tint: Theme.surface2))
                    .accessibilityLabel("End workout")
                }
                MenuBarCompactButton(title: "Open in Tmax", symbol: "macwindow", fillsWidth: true) {
                    actions.showMainWindow()
                }
            }
        }
    }
}
