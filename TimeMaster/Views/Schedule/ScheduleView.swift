import SwiftUI
import Combine
import TimeMasterCore

struct ScheduleView: View {
    @EnvironmentObject private var store: WorkoutStore
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.slotNavigationContentBounds) private var navigationBounds
    @Binding var week: Date
    @State private var sheet: Sheet?
    @State private var now = Date()
    @State private var askedForChallenge = false
    @State private var pullArmed = false
    @State private var pullFired = false
    @ScaledMetric(relativeTo: .largeTitle) private var flameSize = 56.0

    private enum Sheet: Identifiable {
        case challenge, calendar, plans
        case entry(Date, WeeklyWorkoutSchedule.Entry?, Bool)
        case player(Workout)

        var id: String {
            switch self {
            case .challenge: "challenge"
            case .calendar: "calendar"
            case .plans: "plans"
            case .entry(let date, let entry, let custom): "entry-\(date)-\(entry?.id.uuidString ?? "new")-\(custom)"
            case .player(let workout): "player-\(workout.id)"
            }
        }
    }

    private var currentWeek: Date { WeeklyWorkoutSchedule.weekStart(now) }
    private var selection: WeeklyWorkoutSchedule.Selection? { store.weeklySchedule.selection(for: week) }
    private var isVacation: Bool { selection?.isVacation == true }
    private var challenge: WeeklyWorkoutSchedule.Challenge { store.weeklySchedule.challenge(for: week) }
    private var days: [Date] { (0..<7).compactMap { Calendar.current.date(byAdding: .day, value: $0, to: week) } }

    var body: some View {
        NavigationStack {
            GeometryReader { proxy in
                let visibleHeight = navigationBounds.map {
                    min(proxy.size.height, max(0, $0.maxY - proxy.frame(in: .global).minY))
                } ?? proxy.size.height
                VStack(spacing: 0) {
                    pageToolbar
                    if !store.scheduleIsLoaded {
                        loadError
                    } else {
                        timeline
                    }
                }
                .frame(height: visibleHeight, alignment: .top)
            }
            .background(Theme.background)
            .navigationTitle("")
            #if os(iOS)
            .toolbar(.hidden, for: .navigationBar)
            #endif
            .sheet(item: $sheet) { destination in
                switch destination {
                case .challenge:
                    ScheduleChallengeSheet(week: currentWeek, weekdays: store.weeklySchedule.challenge(for: currentWeek).weekdays)
                case .plans:
                    SchedulePlansSheet(week: week)
                case .calendar:
                    CalendarPage(entries: store.historyEntries, selectedWeek: week) { selected in
                        move(to: selected)
                    }
                case .entry(let date, let entry, let custom):
                    ScheduleEntryEditor(date: date, entry: entry, custom: custom, showsRepeat: date >= currentWeek) { updated, repeats in
                        store.saveScheduleEntry(updated, on: date, repeats: repeats,
                                                completed: updated.workoutID == nil && entry == nil)
                    }
                case .player(let workout):
                    WorkoutPlayerView(workout: workout)
                        .environmentObject(store)
                        .environmentObject(DatabaseStore.shared)
                }
            }
            .onAppear {
                now = Date()
                if !askedForChallenge && store.scheduleIsLoaded {
                    askedForChallenge = true
                    sheet = .challenge
                }
            }
            .onReceive(Timer.publish(every: 60, on: .main, in: .common).autoconnect()) { now = $0 }
            .onChange(of: scenePhase) { phase in if phase == .active { now = Date() } }
        }
        .preferredColorScheme(.dark)
        .accessibilityIdentifier("schedule.page")
    }

    private var pageToolbar: some View {
        HStack(spacing: 12) {
            Text("Schedule").font(.title2.bold())
            Spacer()
            Button { sheet = .calendar } label: { Image(systemName: "calendar") }
                .buttonStyle(TimeMasterToolbarIconButtonStyle())
                .accessibilityLabel("Open schedule calendar")
                .accessibilityIdentifier("schedule.calendar")
            Button { sheet = .plans } label: { Image(systemName: "square.stack.3d.up") }
                .buttonStyle(TimeMasterToolbarIconButtonStyle())
                .disabled(week < currentWeek || !store.scheduleIsLoaded)
                .accessibilityLabel("Choose Plan or Vacation")
                .accessibilityIdentifier("schedule.plans")
        }
        .padding(.horizontal, 20).padding(.vertical, 12)
        .frame(maxWidth: 980)
        .frame(maxWidth: .infinity)
    }

    private var timeline: some View {
        ScrollViewReader { scroll in
            ScrollView {
                VStack(spacing: 24) {
                    weekHeader.id("scheduleTop")
                    if let error = store.scheduleError {
                        Text(error).font(.footnote).foregroundStyle(.red).frame(maxWidth: .infinity, alignment: .leading)
                    }
                    if isVacation {
                        VStack(spacing: 8) {
                            Label("Your streak is frozen", systemImage: "snowflake").font(.headline)
                            Text("No workouts are scheduled. Choose a Plan to resume.")
                                .font(.subheadline).foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity).padding(20)
                        .background(Theme.surface, in: RoundedRectangle(cornerRadius: 16))
                    } else if selection == nil && week >= currentWeek {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Make room for your workouts").font(.headline)
                            Text("Add a workout below to build a repeating week, or choose a saved Plan. Today also lets you log workouts done outside the app.")
                                .font(.subheadline).foregroundStyle(.secondary)
                        }.frame(maxWidth: .infinity, alignment: .leading)
                    }
                    LazyVStack(spacing: 24) {
                        ForEach(days, id: \.self) { day in
                            ScheduleDayView(date: day, now: now, items: store.scheduleOccurrences(on: day),
                                            isVacation: isVacation, isChallengeDay: challenge.weekdays.contains(WeeklyWorkoutSchedule.weekday(day)),
                                            onAdd: { sheet = .entry(day, nil, $0) },
                                            onEdit: { sheet = .entry(day, $0, $0.workoutID == nil) },
                                            onStart: { sheet = .player($0) })
                        }
                    }
                }
                .padding(.horizontal, 20).padding(.bottom, 24)
                .frame(maxWidth: 980)
                .frame(maxWidth: .infinity)
                .onGeometryChange(for: CGFloat.self) { geometry in
                    geometry.frame(in: .named("scheduleScroll")).minY
                } action: { offset in
                    pullArmed = offset > 88 && !pullFired
                }
            }
            .coordinateSpace(name: "scheduleScroll")
            .onChange(of: week) { _ in scroll.scrollTo("scheduleTop", anchor: .top) }
            .task(id: pullArmed) {
                guard pullArmed else { return }
                do { try await Task.sleep(nanoseconds: 650_000_000) } catch { return }
                guard !Task.isCancelled else { return }
                pullFired = true
                moveWeek(-1)
            }
            .simultaneousGesture(
                DragGesture(minimumDistance: 12).onEnded { _ in
                    pullArmed = false
                    pullFired = false
                }
            )
            .accessibilityAction(named: "Previous week") { moveWeek(-1) }
            .accessibilityAction(named: "Next week") { moveWeek(1) }
        }
    }

    private var weekHeader: some View {
        let progress = store.weeklySchedule.progress(through: week, now: now, activity: store.scheduleActivity)
        return VStack(spacing: 12) {
            Text(pullArmed ? "Hold to open the previous week" : "Pull and hold for the previous week")
                .font(.caption).foregroundStyle(.secondary)
                .padding(.top, 8)
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 12) {
                    previousWeekButton
                    Spacer(minLength: 0)
                    weekIdentity(progress.weekNumber).fixedSize(horizontal: true, vertical: false)
                    Spacer(minLength: 0)
                    nextWeekButton
                }
                VStack(spacing: 12) {
                    weekIdentity(progress.weekNumber, stacked: true)
                    HStack {
                        previousWeekButton
                        Spacer()
                        nextWeekButton
                    }
                }
            }
            .buttonStyle(.plain)
            Text(weekRange).font(.subheadline.monospacedDigit()).foregroundStyle(.secondary)
            HStack(spacing: 8) {
                Label(selection?.plan?.name ?? (isVacation ? "Vacation" : "No Plan"),
                      systemImage: selection?.plan?.icon ?? (isVacation ? "beach.umbrella.fill" : "square.stack.3d.up"))
                    .font(.caption.weight(.semibold))
                Text("·").foregroundStyle(.secondary)
                Button { sheet = .challenge } label: {
                    Text("\(challenge.weekdays.count)-day challenge").font(.caption.weight(.semibold))
                }.buttonStyle(.plain)
            }
            if week <= currentWeek && !isVacation {
                Text(progress.isBroken ? "Streak reset · next week is a fresh start" : "\(progress.completedDays) of \(progress.requiredDays) streak days complete")
                    .font(.caption).foregroundStyle(progress.isBroken ? .red : .secondary)
            }
            if week != currentWeek {
                Button("Back to this week") { move(to: currentWeek) }
                    .font(.caption.weight(.semibold)).buttonStyle(.bordered)
            }
        }
    }

    private func weekIdentity(_ number: Int, stacked: Bool = false) -> some View {
        let layout = stacked ? AnyLayout(VStackLayout(spacing: 8)) : AnyLayout(HStackLayout(spacing: 4))
        return layout {
            Text(week > currentWeek ? "Upcoming" : "Week \(number)")
                .font(.largeTitle.weight(.bold)).monospacedDigit()
                .contentTransition(.numericText())
            if isVacation {
                Image(systemName: "snowflake").font(.largeTitle).foregroundStyle(.cyan)
            } else {
                ScheduleFlame(difficulty: challenge.weekdays.count, isBurning: number > 0)
                    .frame(width: flameSize, height: flameSize)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(week > currentWeek ? "Upcoming week" : "Streak week \(number)\(isVacation ? ", frozen" : "")")
    }

    private var previousWeekButton: some View {
        Button { moveWeek(-1) } label: { Image(systemName: "chevron.left").padding(14) }
            .accessibilityLabel("Previous week")
    }

    private var nextWeekButton: some View {
        Button { moveWeek(1) } label: { Image(systemName: "chevron.right").padding(14) }
            .accessibilityLabel("Next week")
    }

    private var weekRange: String {
        let end = Calendar.current.date(byAdding: .day, value: 6, to: week) ?? week
        return "\(week.formatted(.dateTime.month(.abbreviated).day())) – \(end.formatted(.dateTime.month(.abbreviated).day().year()))"
    }

    private var loadError: some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.icloud").font(.largeTitle)
            Text("Schedule unavailable").font(.title2.bold())
            Text(store.scheduleError ?? "Your saved schedule could not be loaded.")
                .foregroundStyle(.secondary).multilineTextAlignment(.center)
            Button("Try again") {
                store.loadWeeklySchedule()
                if store.scheduleIsLoaded && !askedForChallenge {
                    askedForChallenge = true
                    sheet = .challenge
                }
            }.buttonStyle(.bordered)
        }.padding(24).frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func moveWeek(_ offset: Int) {
        guard let date = Calendar.current.date(byAdding: .day, value: offset * 7, to: week) else { return }
        move(to: date)
    }

    private func move(to date: Date) {
        withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.24)) {
            week = WeeklyWorkoutSchedule.weekStart(date)
        }
    }
}
