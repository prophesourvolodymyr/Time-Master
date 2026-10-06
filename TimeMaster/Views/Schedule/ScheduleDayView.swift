import SwiftUI
import TimeMasterCore

struct ScheduleDayView: View {
    @EnvironmentObject private var store: WorkoutStore
    let date: Date
    let now: Date
    let items: [WeeklyWorkoutSchedule.Occurrence]
    let isVacation: Bool
    let isChallengeDay: Bool
    let onAdd: (Bool) -> Void
    let onEdit: (WeeklyWorkoutSchedule.Entry) -> Void
    let onStart: (Workout) -> Void
    @State private var pendingRemoval: WeeklyWorkoutSchedule.Entry?
    @ScaledMetric(relativeTo: .body) private var statusSize = 44.0
    @ScaledMetric(relativeTo: .body) private var branchInset = 24.0

    private var isToday: Bool { Calendar.current.isDate(date, inSameDayAs: now) }
    private var isFuture: Bool { Calendar.current.startOfDay(for: date) > Calendar.current.startOfDay(for: now) }
    private var isPast: Bool { Calendar.current.startOfDay(for: date) < Calendar.current.startOfDay(for: now) }
    private var complete: Bool { !items.isEmpty && items.allSatisfy(\.isComplete) }
    private var missed: Bool { isPast && !items.isEmpty && !complete && !isVacation }
    private var minutes: Int { items.reduce(0) { $0 + ($1.entry.durationSeconds ?? 0) } / 60 }

    var body: some View {
        VStack(spacing: 0) {
            dayHeader
            if isVacation {
                Label("Vacation", systemImage: "beach.umbrella")
                    .font(.subheadline).foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.leading, branchInset).padding(.vertical, 16)
            } else {
                VStack(spacing: 8) {
                    ForEach(items) { item in
                        branch { workoutRow(item) }
                    }
                    if !isPast {
                        branch { addControl }
                    } else if items.isEmpty {
                        Text(isChallengeDay ? "No workout logged" : "Rest day")
                            .font(.subheadline).foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading).padding(.vertical, 12)
                    }
                }
                .padding(.leading, branchInset)
                .padding(.top, 8)
            }
        }
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
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 12) { dayIdentity.fixedSize(horizontal: true, vertical: false); Spacer(minLength: 8); metrics }
            VStack(alignment: .leading, spacing: 12) { dayIdentity; metrics }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: 16))
        .overlay {
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(isToday ? Color.white.opacity(0.8) : Theme.separator, lineWidth: isToday ? 1.5 : 1)
        }
    }

    private var dayIdentity: some View {
        HStack(spacing: 12) {
            Group {
                if isVacation { Image(systemName: "pause.fill") }
                else if complete { Image(systemName: "checkmark") }
                else if missed { Image(systemName: "xmark") }
                else { Text(date.formatted(.dateTime.day())).monospacedDigit() }
            }
            .font(.title3.weight(.semibold))
            .foregroundStyle(complete ? .green : missed ? .red : .white)
            .frame(width: statusSize, height: statusSize)
            .background(Theme.surface2, in: RoundedRectangle(cornerRadius: 12))
            .accessibilityLabel(complete ? "Day complete" : missed ? "Day missed" : isVacation ? "Paused" : "Not completed")
            VStack(alignment: .leading, spacing: 4) {
                Text(date.formatted(.dateTime.weekday(.wide))).font(.title3.weight(.semibold))
                HStack(spacing: 6) {
                    Text(isToday ? "TODAY" : date.formatted(.dateTime.month(.abbreviated).day()))
                    if isChallengeDay && !isVacation { Text("· Streak day") }
                }
                .font(.caption.weight(isToday ? .bold : .regular)).foregroundStyle(.secondary)
            }
            .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var metrics: some View {
        HStack(spacing: 8) {
            metric("\(items.count)", label: "Workouts")
            metric("\(minutes)", label: "Minutes")
        }
    }

    private func metric(_ value: String, label: String) -> some View {
        VStack(spacing: 3) {
            Text(value).font(.headline.monospacedDigit())
            Text(label).font(.caption2).foregroundStyle(.secondary)
        }
        .padding(8)
        .background(Theme.surface2, in: RoundedRectangle(cornerRadius: 10))
        .accessibilityElement(children: .combine)
    }

    private func branch<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        content()
            .overlay(alignment: .leading) {
                Rectangle().fill(Theme.separator)
                    .frame(width: branchInset / 2, height: 1)
                    .offset(x: -branchInset / 2)
                    .accessibilityHidden(true)
            }
            .background(alignment: .leading) {
                Rectangle().fill(Theme.separator)
                    .frame(width: 1)
                    .padding(.vertical, -4)
                    .offset(x: -branchInset / 2)
            }
    }

    private func workoutRow(_ item: WeeklyWorkoutSchedule.Occurrence) -> some View {
        HStack(alignment: .center, spacing: 10) {
            Button {
                store.changeWeeklySchedule { $0.setComplete(!item.isComplete, entryID: item.entry.id, on: date) }
            } label: {
                Image(systemName: item.isComplete ? "checkmark.square.fill" : "square")
                    .font(.title2)
                    .foregroundStyle(item.isComplete ? .green : .secondary)
                    .frame(minWidth: statusSize, minHeight: statusSize)
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
                VStack(alignment: .leading, spacing: 5) {
                    Text(item.entry.title).font(.subheadline.weight(.semibold)).foregroundStyle(.white)
                        .multilineTextAlignment(.leading)
                    Text(timeLabel(item)).font(.caption.monospacedDigit()).foregroundStyle(.secondary)
                    if item.entry.workoutID == nil {
                        Text("Custom workout\(item.entry.exerciseCount.map { " · \($0) exercises" } ?? "")")
                            .font(.caption2).foregroundStyle(.secondary)
                    } else if item.isComplete {
                        Text(item.isManual ? "Completed manually" : "Completed in app")
                            .font(.caption2).foregroundStyle(.green)
                    }
                    if !item.entry.notes.isEmpty {
                        Text(item.entry.notes).font(.caption).foregroundStyle(.secondary).lineLimit(3)
                    }
                }.frame(maxWidth: .infinity, alignment: .leading)
            }.buttonStyle(.plain)
            if isToday, !item.isComplete, let id = item.entry.workoutID, let workout = store.workout(id: id), !workout.sections.isEmpty {
                Button { onStart(workout) } label: {
                    Image(systemName: "play.fill").padding(12)
                }.buttonStyle(.plain)
                    .accessibilityLabel("Start \(item.entry.title)")
            }
        }
        .padding(10)
        .background(Color(hex: item.entry.colorHex).opacity(0.07), in: RoundedRectangle(cornerRadius: 14))
        .overlay { RoundedRectangle(cornerRadius: 14).strokeBorder(Theme.separator) }
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
            .accessibilityLabel("Add workout for today")
            .accessibilityIdentifier("schedule.today.add")
        } else {
            Button { onAdd(false) } label: { addLabel }
                .buttonStyle(.plain)
                .accessibilityLabel("Add workout for \(date.formatted(.dateTime.weekday(.wide)))")
        }
    }

    private var addLabel: some View {
        Label("Add workout", systemImage: "plus")
            .font(.subheadline.weight(.medium))
            .foregroundStyle(Theme.textSecondary)
            .frame(maxWidth: .infinity, minHeight: statusSize)
            .background {
                RoundedRectangle(cornerRadius: 14).strokeBorder(Theme.separator, style: StrokeStyle(lineWidth: 1, dash: [5, 4]))
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
