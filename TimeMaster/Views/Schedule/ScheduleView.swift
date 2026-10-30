import SwiftUI
import Combine
import TimeMasterCore

struct ScheduleView: View {
    @EnvironmentObject private var store: WorkoutStore
    @EnvironmentObject private var outdoorStore: OutdoorActivityStore
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    @Binding var week: Date
    @State private var sheet: Sheet?
    @State private var playerWorkout: Workout?
    @State private var now = Date()
    @State private var askedForChallenge = false
    @State private var pullArmed = false
    @State private var pullFired = false
    @ScaledMetric(relativeTo: .largeTitle) private var flameSize = 56.0

    private enum Sheet: Identifiable {
        case challenge, calendar, plans
        case entry(Date, WeeklyWorkoutSchedule.Entry?, Bool)

        var id: String {
            switch self {
            case .challenge: "challenge"
            case .calendar: "calendar"
            case .plans: "plans"
            case .entry(let date, let entry, let custom): "entry-\(date)-\(entry?.id.uuidString ?? "new")-\(custom)"
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
            Group {
                if store.scheduleIsLoaded {
                    timeline
                } else {
                    loadError
                }
            }
            .font(TimeMasterFont.body())
            .background(Theme.background)
            .navigationTitle("")
            #if os(iOS)
            .toolbar(.hidden, for: .navigationBar)
            #endif
            .oneHandedActions(id: "schedule", actions: oneHandedActions)
            .sheet(item: $sheet) { destination in
                switch destination {
                case .challenge:
                    ScheduleChallengeSheet(week: currentWeek, weekdays: store.weeklySchedule.challenge(for: currentWeek).weekdays)
                        .keyNavHost()
                case .plans:
                    SchedulePlansSheet(week: week)
                        .keyNavHost()
                case .calendar:
                    CalendarPage(entries: store.historyEntries, outdoorActivities: outdoorStore.establishedActivities, selectedWeek: week) { selected in
                        move(to: selected)
                    }
                    .keyNavHost()
                case .entry(let date, let entry, let custom):
                    ScheduleEntryEditor(date: date, entry: entry, custom: custom, showsRepeat: date >= currentWeek) { updated, repeats in
                        store.saveScheduleEntry(updated, on: date, repeats: repeats,
                                                completed: updated.workoutID == nil && entry == nil)
                    }
                    .keyNavHost()
                }
            }
            .workoutPlayerPage(item: $playerWorkout) { workout in
                WorkoutPlayerView(workout: workout)
                    .environmentObject(store)
                    .environmentObject(DatabaseStore.shared)
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

    private var oneHandedActions: [ReachabilityAction] {
        [
            ReachabilityAction("calendar", title: "Calendar") {
                pageControl("Calendar", icon: "calendar", destination: .calendar,
                            progress: 1, width: 48, height: 48)
            },
            ReachabilityAction("plans", title: "Plans") {
                pageControl("Plans", icon: "square.stack.3d.up", destination: .plans,
                            progress: 1, width: 48, height: 48)
                    .disabled(week < currentWeek || !store.scheduleIsLoaded)
                    .opacity(week < currentWeek ? 0.4 : 1)
                    .accessibilityValue(selection?.plan?.name ?? (isVacation ? "Vacation" : "No Plan"))
            },
            ReachabilityAction("challenge", title: "Streak") {
                pageControl("Streak", icon: "flame", destination: .challenge,
                            progress: 1, width: 48, height: 48)
                    .accessibilityValue("\(challenge.weekdays.count)-day challenge")
            }
        ]
    }

    private func pageToolbar(progress: CGFloat, metrics: ScrollingChromeMetrics) -> some View {
        let morph = metrics.morph(progress)
        let buttonWidth = metrics.controlWidth(morph)
        let buttonHeight = metrics.controlHeight(morph)

        return ScrollingChromeHeader(title: "Schedule", progress: morph, metrics: metrics) {
            HStack(spacing: metrics.controlSpacing) {
                pageControl("Calendar", icon: "calendar", destination: .calendar,
                            progress: morph, width: buttonWidth, height: buttonHeight)
                    .accessibilityIdentifier("schedule.calendar")
                pageControl("Plans", icon: "square.stack.3d.up", destination: .plans,
                            progress: morph, width: buttonWidth, height: buttonHeight)
                    .disabled(week < currentWeek || !store.scheduleIsLoaded)
                    .opacity(week < currentWeek ? 0.4 : 1)
                    .accessibilityValue(selection?.plan?.name ?? (isVacation ? "Vacation" : "No Plan"))
                    .accessibilityIdentifier("schedule.plans")
                pageControl("Streak", icon: "flame", destination: .challenge,
                            progress: morph, width: buttonWidth, height: buttonHeight)
                    .accessibilityValue("\(challenge.weekdays.count)-day challenge")
                    .accessibilityIdentifier("schedule.challenge")
            }
        }
        .background(Theme.background)
    }

    private func pageControl(_ title: String, icon: String, destination: Sheet,
                             progress: CGFloat, width: CGFloat, height: CGFloat) -> some View {
        Button { sheet = destination } label: {
            ScrollingChromeControl(systemImage: icon, title: title, progress: progress, width: width, height: height)
                .contentShape(Rectangle())
        }
        .buttonStyle(TimeMasterCardButtonStyle())
        .scrollingChromeRing(progress: progress, width: width, height: height)
        .accessibilityLabel(title)
        .help(title)
    }

    private var timeline: some View {
        ScrollViewReader { scroll in
            ScrollingChrome(onScrollOffset: { offset in
                pullArmed = offset < -88 && !pullFired
            }, metrics: { width in
                ScrollingChromeMetrics(width: min(width, 980))
            }) { _ in
                VStack(spacing: 24) {
                    weekHeader.id("scheduleTop")
                    if let error = store.scheduleError {
                        Text(error).font(TimeMasterFont.body(13, relativeTo: .footnote)).foregroundStyle(.red).frame(maxWidth: .infinity, alignment: .leading)
                    }
                    VStack(spacing: 12) {
                        ForEach(days, id: \.self) { day in
                            ScheduleDayView(date: day, now: now, items: store.scheduleOccurrences(on: day),
                                            isVacation: isVacation, isChallengeDay: challenge.weekdays.contains(WeeklyWorkoutSchedule.weekday(day)),
                                            onAdd: { sheet = .entry(day, nil, $0) },
                                            onEdit: { sheet = .entry(day, $0, $0.workoutID == nil) },
                                            onStart: { playerWorkout = $0 })
                        }
                    }
                }
                .padding(.horizontal, 20).padding(.top, 24).padding(.bottom, 24)
                .frame(maxWidth: 980)
                .frame(maxWidth: .infinity)
            } header: { progress, metrics in
                pageToolbar(progress: progress, metrics: metrics)
                    .frame(maxWidth: .infinity)
            }
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
            if pullArmed {
                Image(systemName: "arrow.up")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .accessibilityLabel("Hold for previous week")
            }
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
            Text(weekRange).font(TimeMasterFont.black(15, relativeTo: .subheadline)).monospacedDigit().foregroundStyle(.secondary)
            if week != currentWeek {
                Button("This week", systemImage: "arrow.uturn.backward") { move(to: currentWeek) }
                    .font(TimeMasterFont.black(12, relativeTo: .caption))
                    .buttonStyle(TimeMasterToolbarWideButtonStyle())
            }
        }
    }

    private func weekIdentity(_ number: Int, stacked: Bool = false) -> some View {
        let layout = stacked ? AnyLayout(VStackLayout(spacing: 8)) : AnyLayout(HStackLayout(spacing: 4))
        return layout {
            Text(week > currentWeek ? "Upcoming" : "Week \(number)")
                .font(TimeMasterFont.black(34, relativeTo: .largeTitle)).monospacedDigit()
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
        Button("Previous week", systemImage: "chevron.left") { moveWeek(-1) }
            .labelStyle(.iconOnly)
            .buttonStyle(TimeMasterToolbarIconButtonStyle())
    }

    private var nextWeekButton: some View {
        Button("Next week", systemImage: "chevron.right") { moveWeek(1) }
            .labelStyle(.iconOnly)
            .buttonStyle(TimeMasterToolbarIconButtonStyle())
    }

    private var weekRange: String {
        let end = Calendar.current.date(byAdding: .day, value: 6, to: week) ?? week
        return "\(week.formatted(.dateTime.month(.abbreviated).day())) – \(end.formatted(.dateTime.month(.abbreviated).day().year()))"
    }

    private var loadError: some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.icloud").font(.largeTitle)
            Text("Schedule unavailable").font(TimeMasterFont.black(22, relativeTo: .title2))
            Text(store.scheduleError ?? "Your saved schedule could not be loaded.")
                .foregroundStyle(.secondary).multilineTextAlignment(.center)
            Button("Try again") {
                store.loadWeeklySchedule()
                if store.scheduleIsLoaded && !askedForChallenge {
                    askedForChallenge = true
                    sheet = .challenge
                }
            }.buttonStyle(TimeMasterToolbarWideButtonStyle())
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
