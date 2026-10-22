import SwiftUI
import TimeMasterCore

struct ScheduleDayView: View {
    @EnvironmentObject private var store: WorkoutStore
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    let date: Date
    let now: Date
    let items: [WeeklyWorkoutSchedule.Occurrence]
    let isVacation: Bool
    let isChallengeDay: Bool
    let onAdd: (Bool) -> Void
    let onEdit: (WeeklyWorkoutSchedule.Entry) -> Void
    let onStart: (Workout) -> Void
    @State private var pendingRemoval: WeeklyWorkoutSchedule.Entry?
    @State private var expanded: Bool?
    @ScaledMetric(relativeTo: .body) private var statusSize = 44.0
    @ScaledMetric(relativeTo: .largeTitle) private var branchInset = 24.0

    private var isToday: Bool { Calendar.current.isDate(date, inSameDayAs: now) }
    private var isFuture: Bool { Calendar.current.startOfDay(for: date) > Calendar.current.startOfDay(for: now) }
    private var isPast: Bool { Calendar.current.startOfDay(for: date) < Calendar.current.startOfDay(for: now) }
    private var complete: Bool { !items.isEmpty && items.allSatisfy(\.isComplete) }
    private var missed: Bool { isPast && !items.isEmpty && !complete && !isVacation }
    private var minutes: Int { items.reduce(0) { $0 + ($1.entry.durationSeconds ?? 0) } / 60 }
    private var isExpanded: Bool { expanded ?? isToday }

    var body: some View {
        VStack(spacing: 0) {
            dayHeader
                .zIndex(1)
            if isExpanded {
                VStack(spacing: 8) {
                    if isVacation {
                        branch { Label("Vacation", systemImage: "beach.umbrella").padding(.vertical, 16) }
                    } else {
                        ForEach(items) { item in
                            branch { workoutRow(item) }
                        }
                        if !isPast {
                            branch { addControl }
                        } else if items.isEmpty {
                            branch {
                                Text(isChallengeDay ? "No workouts" : "Rest day").padding(.vertical, 16)
                            }
                        }
                    }
                }
                .font(TimeMasterFont.secondary())
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.leading, branchInset)
                .padding(.top, 8)
                .transition(reduceMotion ? .identity : .asymmetric(
                    insertion: .offset(y: -8).combined(with: .opacity),
                    removal: .opacity
                ))
            }
        }
        .clipped()
        .accessibilityElement(children: .contain)
        .accessibilityLabel(date.formatted(.dateTime.weekday(.wide).month().day()))
        .confirmationDialog("Remove workout from this date?", isPresented: Binding(get: { pendingRemoval != nil }, set: { if !$0 { pendingRemoval = nil } }), titleVisibility: .visible) {
            Button("Remove from this date", role: .destructive) {
                guard let pendingRemoval else { return }
                store.changeWeeklySchedule { $0.removeEntry(pendingRemoval, on: date) }
                self.pendingRemoval = nil
            }
        } message: { Text("The repeating Plan and other dates stay unchanged.") }
    }

    private var dayHeader: some View {
        Button {
            withAnimation(reduceMotion ? nil : .spring(response: 0.42, dampingFraction: 0.88)) {
                expanded = !isExpanded
            }
        } label: {
            HStack(spacing: 12) {
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 12) { dayIdentity.fixedSize(horizontal: true, vertical: false); Spacer(minLength: 8); metrics }
                    VStack(alignment: .leading, spacing: 12) { dayIdentity; metrics }
                }
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(isExpanded ? Theme.toolbarOrange : .secondary)
                    .rotationEffect(.degrees(isExpanded ? 90 : 0))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(14)
            .modifier(TimeMasterCardSurface(emphasized: isToday || isExpanded))
            .contentShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        }
        .buttonStyle(TimeMasterCardButtonStyle())
        .accessibilityLabel("\(date.formatted(.dateTime.weekday(.wide).month().day()))\(isToday ? ", Today" : ""), \(items.count) workouts, \(minutes) minutes")
        .accessibilityValue("\(isExpanded ? "Expanded" : "Collapsed"), \(isVacation ? "Vacation" : complete ? "Complete" : missed ? "Missed" : "Not completed")")
        .accessibilityHint(isExpanded ? "Collapse workouts" : "Expand workouts")
        .accessibilityIdentifier("schedule.day.\(WeeklyWorkoutSchedule.weekday(date))")
    }

    private var dayIdentity: some View {
        let layout = dynamicTypeSize.isAccessibilitySize ? AnyLayout(VStackLayout(alignment: .leading, spacing: 12)) : AnyLayout(HStackLayout(spacing: 12))
        return layout {
            Group {
                if isVacation { Image(systemName: "pause.fill") }
                else if complete { Image(systemName: "checkmark") }
                else if missed { Image(systemName: "xmark") }
                else { Text(date.formatted(.dateTime.day())).font(TimeMasterFont.heading()).monospacedDigit() }
            }
            .font(.title3.weight(.semibold))
            .foregroundStyle(complete ? .green : missed ? .red : isToday ? Theme.toolbarOrange : .white)
            .frame(width: statusSize, height: statusSize)
            .modifier(TimeMasterCardSurface(cornerRadius: 12,
                                           accent: complete ? .green : missed ? .red : Theme.toolbarOrange,
                                           emphasized: isToday || complete || missed))
            Text(date.formatted(.dateTime.weekday(.wide)))
                .font(TimeMasterFont.heading())
                .foregroundStyle(.white)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    @ViewBuilder
    private var metrics: some View {
        if dynamicTypeSize.isAccessibilitySize {
            VStack(alignment: .leading, spacing: 6) {
                Text("\(items.count) Workouts")
                Text("\(minutes) Minutes")
            }
            .font(TimeMasterFont.black(15, relativeTo: .subheadline)).monospacedDigit()
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
        } else {
            HStack(spacing: 8) {
                metric("\(items.count)", label: "Workouts")
                metric("\(minutes)", label: "Minutes")
            }
        }
    }

    private func metric(_ value: String, label: String) -> some View {
        VStack(spacing: 3) {
            Text(value).font(TimeMasterFont.sectionTitle()).monospacedDigit()
                .frame(minWidth: statusSize, minHeight: statusSize)
                .background(.black.opacity(0.18), in: RoundedRectangle(cornerRadius: 10))
                .overlay { RoundedRectangle(cornerRadius: 10).strokeBorder(Theme.separator) }
            Text(label).font(TimeMasterFont.micro()).foregroundStyle(.secondary)
        }
        .accessibilityElement(children: .combine)
    }

    private func branch<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        content()
            .overlay(alignment: .leading) {
                Rectangle().fill(Theme.toolbarOrange.opacity(0.25))
                    .frame(width: branchInset / 2, height: 1)
                    .offset(x: -branchInset / 2)
                    .accessibilityHidden(true)
            }
            .background(alignment: .leading) {
                Rectangle().fill(Theme.toolbarOrange.opacity(0.25))
                    .frame(width: 1)
                    .padding(.vertical, -4)
                    .offset(x: -branchInset / 2)
            }
    }

    private func workoutRow(_ item: WeeklyWorkoutSchedule.Occurrence) -> some View {
        let layout = dynamicTypeSize.isAccessibilitySize ? AnyLayout(VStackLayout(alignment: .leading, spacing: 10)) : AnyLayout(HStackLayout(alignment: .center, spacing: 10))
        return layout {
            Button {
                store.changeWeeklySchedule { $0.setComplete(!item.isComplete, entryID: item.entry.id, on: date) }
            } label: {
                Image(systemName: item.isComplete ? "checkmark.square.fill" : "square")
                    .font(.title2)
                    .foregroundStyle(item.isComplete ? .green : .secondary)
                    .frame(minWidth: statusSize, minHeight: statusSize)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(isFuture || !store.scheduleIsLoaded)
            .accessibilityLabel("\(item.isComplete ? "Mark incomplete" : "Mark complete"): \(item.entry.title)")
            .accessibilityValue(item.isComplete ? "Completed" : "Not completed")
            .contextMenu {
                if item.isManual && item.entry.workoutID != nil {
                    Button("Use automatic status") {
                        store.changeWeeklySchedule { $0.setComplete(nil, entryID: item.entry.id, on: date) }
                    }
                }
            }
            Button { onEdit(item.entry) } label: {
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 12) {
                        Text(item.entry.title).font(TimeMasterFont.rowTitle()).foregroundStyle(.white)
                            .fixedSize()
                        Spacer(minLength: 0)
                        Text(timeLabel(item))
                            .font(item.start == nil && item.entry.durationSeconds == nil ? TimeMasterFont.caption() : TimeMasterFont.black(12, relativeTo: .caption))
                            .monospacedDigit().foregroundStyle(.secondary)
                            .fixedSize()
                    }
                    VStack(alignment: .leading, spacing: 5) {
                        Text(item.entry.title).font(TimeMasterFont.rowTitle()).foregroundStyle(.white)
                            .multilineTextAlignment(.leading)
                        Text(timeLabel(item))
                            .font(item.start == nil && item.entry.durationSeconds == nil ? TimeMasterFont.caption() : TimeMasterFont.black(12, relativeTo: .caption))
                            .monospacedDigit().foregroundStyle(.secondary)
                    }.frame(maxWidth: .infinity, alignment: .leading)
                }
                .contentShape(Rectangle())
            }.buttonStyle(.plain)
            if isToday, !item.isComplete, let id = item.entry.workoutID, let workout = store.workout(id: id), !workout.sections.isEmpty {
                Button { onStart(workout) } label: {
                    Image(systemName: "play.fill")
                }.buttonStyle(TimeMasterToolbarIconButtonStyle())
                    .accessibilityLabel("Start \(item.entry.title)")
            }
        }
        .padding(10)
        .modifier(TimeMasterCardSurface(cornerRadius: 16, accent: .green, emphasized: item.isComplete))
        .contextMenu {
            Button("Edit time and details") { onEdit(item.entry) }
            Button("Remove from this date", role: .destructive) { pendingRemoval = item.entry }
        }
    }

    @ViewBuilder
    private var addControl: some View {
        if isToday {
            Menu {
                Button { onAdd(false) } label: { Label("Schedule a workout", systemImage: "calendar.badge.plus") }
                Button { onAdd(true) } label: { Label("Log custom workout", systemImage: "square.and.pencil") }
            } label: { addLabel }
            .buttonStyle(.plain)
            .accessibilityLabel("Add workout for today")
            .accessibilityIdentifier("schedule.today.add")
        } else {
            Button { onAdd(false) } label: { addLabel }
                .buttonStyle(.plain)
                .accessibilityLabel("Add workout for \(date.formatted(.dateTime.weekday(.wide)))")
                .accessibilityIdentifier("schedule.add.\(WeeklyWorkoutSchedule.weekday(date))")
        }
    }

    private var addLabel: some View {
        Label("Add workout", systemImage: "plus")
            .labelStyle(.iconOnly)
            .font(.title3.weight(.semibold))
            .foregroundStyle(Theme.toolbarOrange)
            .frame(maxWidth: .infinity, minHeight: statusSize)
            .background(Theme.surface.opacity(0.65), in: RoundedRectangle(cornerRadius: 16))
            .background {
                RoundedRectangle(cornerRadius: 16).strokeBorder(Theme.toolbarOrange.opacity(0.3), style: StrokeStyle(lineWidth: 1, dash: [5, 4]))
            }
    }

    private func timeLabel(_ item: WeeklyWorkoutSchedule.Occurrence) -> String {
        if let start = item.start {
            let text = start.formatted(date: .omitted, time: .shortened)
            if let finish = item.finish {
                let nextDay = Calendar.current.isDate(start, inSameDayAs: finish) ? "" : " (+1 day)"
                return "\(text) – \(finish.formatted(date: .omitted, time: .shortened))\(nextDay)"
            }
            return text
        }
        if let duration = item.entry.durationSeconds { return "\(duration / 60) min" }
        return "No time set"
    }
}
