import SwiftUI
import TimeMasterCore

struct ScheduleEntryEditor: View {
    @EnvironmentObject private var store: WorkoutStore
    @Environment(\.dismiss) private var dismiss
    let date: Date
    let original: WeeklyWorkoutSchedule.Entry?
    let showsRepeat: Bool
    let onSave: (WeeklyWorkoutSchedule.Entry, Bool) -> Bool
    @State private var workoutID: UUID?
    @State private var configuring: Bool
    @State private var custom: Bool
    @State private var title: String
    @State private var notes: String
    @State private var exerciseCount: String
    @State private var hasTime: Bool
    @State private var hasDuration: Bool
    @State private var time: Date
    @State private var duration: Int
    @State private var repeats: Bool
    @State private var search = ""
    @State private var error: String?

    init(date: Date, entry: WeeklyWorkoutSchedule.Entry? = nil, custom: Bool = false,
         showsRepeat: Bool = true, onSave: @escaping (WeeklyWorkoutSchedule.Entry, Bool) -> Bool) {
        self.date = date
        original = entry
        self.showsRepeat = showsRepeat
        self.onSave = onSave
        let isCustom = entry.map { $0.workoutID == nil } ?? custom
        _workoutID = State(initialValue: entry?.workoutID)
        _configuring = State(initialValue: entry != nil || custom)
        _custom = State(initialValue: isCustom)
        _title = State(initialValue: entry?.title ?? "")
        _notes = State(initialValue: entry?.notes ?? "")
        _exerciseCount = State(initialValue: entry?.exerciseCount.map(String.init) ?? "")
        _hasTime = State(initialValue: entry?.startMinute != nil || !isCustom)
        _hasDuration = State(initialValue: entry?.durationSeconds != nil || !isCustom)
        let minute = entry?.startMinute ?? 18 * 60
        _time = State(initialValue: Calendar.current.date(bySettingHour: minute / 60, minute: minute % 60, second: 0, of: date) ?? date)
        _duration = State(initialValue: entry?.durationSeconds ?? 1800)
        _repeats = State(initialValue: !isCustom && entry == nil)
    }

    var body: some View {
        NavigationStack {
            Group {
                if configuring { configuration }
                else { workoutPicker }
            }
            .background(Theme.background)
            .navigationTitle(configuring ? (custom ? "Custom workout" : "Set workout time") : "Choose workout")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                if configuring {
                    ToolbarItem(placement: .confirmationAction) {
                        Button(custom && original == nil ? "Log workout" : "Save", action: save)
                            .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                            .accessibilityIdentifier("schedule.entry.save")
                    }
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    private var workoutPicker: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                TextField("Search workouts", text: $search)
                    .textFieldStyle(.roundedBorder)
                    .accessibilityLabel("Search workouts")
                if store.workouts.isEmpty {
                    VStack(spacing: 8) {
                        Image(systemName: "dumbbell").font(.largeTitle)
                        Text("No workouts yet").font(.headline)
                        Text("Create a workout in Workouts, then add it to your plan.")
                            .foregroundStyle(.secondary).multilineTextAlignment(.center)
                    }.padding(.vertical, 24)
                } else {
                    ForEach(store.workouts.filter { search.isEmpty || $0.name.localizedCaseInsensitiveContains(search) }) { workout in
                        Button {
                            workoutID = workout.id
                            title = workout.name
                            duration = workout.totalDuration
                            exerciseCount = String(workout.sections.count)
                            configuring = true
                        } label: {
                            WorkoutCard(workout: workout)
                        }
                        .buttonStyle(.plain)
                    }
                    if !search.isEmpty && !store.workouts.contains(where: { $0.name.localizedCaseInsensitiveContains(search) }) {
                        Text("No workouts match your search.").foregroundStyle(.secondary).padding()
                    }
                }
            }.padding(20)
        }
    }

    private var configuration: some View {
        Form {
            SwiftUI.Section {
                if custom {
                    TextField("Title (required)", text: $title)
                        .accessibilityIdentifier("schedule.custom.title")
                } else if let workoutID, let workout = store.workout(id: workoutID) {
                    Label(workout.name, systemImage: workout.type.iconName)
                        .font(.headline)
                        .fixedSize(horizontal: false, vertical: true)
                    if original == nil {
                        Button("Choose a different workout") { configuring = false }
                    }
                } else {
                    Label(title, systemImage: original?.icon ?? "dumbbell.fill")
                    Text("This workout is no longer in your library. Its schedule and completion record are preserved.")
                        .font(.footnote).foregroundStyle(.secondary)
                }
            } header: {
                Text(date.formatted(.dateTime.weekday(.wide).month(.abbreviated).day()))
            } footer: {
                if custom { Text("Only a title is required. This logs what you did outside the app; it does not create a library workout.") }
            }
            SwiftUI.Section {
                if custom { Toggle("Add start time", isOn: $hasTime) }
                if hasTime {
                    #if os(iOS)
                    DatePicker("Start time", selection: $time, displayedComponents: .hourAndMinute)
                        .datePickerStyle(.wheel)
                        .labelsHidden()
                        .accessibilityLabel("Start time")
                    #else
                    DatePicker("Start time", selection: $time, displayedComponents: .hourAndMinute)
                    #endif
                }
                if custom { Toggle("Add duration", isOn: $hasDuration) }
                if hasDuration {
                    Stepper("Hours: \(duration / 3600)", value: Binding(
                        get: { duration / 3600 },
                        set: { duration = min(86400, $0 * 3600 + duration % 3600) }
                    ), in: 0...24)
                    DurationPickerView(seconds: Binding(
                        get: { duration % 3600 },
                        set: { duration = duration / 3600 * 3600 + $0 }
                    ), range: 0...3599, step: 1)
                    .disabled(duration == 86400)
                    if hasTime {
                        LabeledContent("Finishes", value: time.addingTimeInterval(Double(duration)).formatted(date: .omitted, time: .shortened))
                    }
                }
            } header: { Text("Time") }
            if custom {
                SwiftUI.Section("Optional details") {
                    TextField("Description", text: $notes, axis: .vertical)
                        .lineLimit(3...6)
                    TextField("Exercise count", text: $exerciseCount)
                        #if os(iOS)
                        .keyboardType(.numberPad)
                        #endif
                }
            } else if showsRepeat {
                SwiftUI.Section {
                    Toggle("Repeat in this Plan", isOn: $repeats)
                } footer: {
                    Text(repeats ? "Updates the Plan from this week onward. Previous weeks stay unchanged." : "Changes only this date. The repeating Plan stays unchanged.")
                }
            }
            if let error {
                SwiftUI.Section { Text(error).foregroundStyle(.red) }
            }
        }
        .scrollContentBackground(.hidden)
    }

    private func save() {
        let cleanTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanTitle.isEmpty else { return }
        let countText = exerciseCount.trimmingCharacters(in: .whitespacesAndNewlines)
        if !countText.isEmpty && (Int(countText) == nil || (Int(countText) ?? -1) < 0) {
            error = "Exercise count must be a whole number, or leave it empty."
            return
        }
        let workout = workoutID.flatMap { store.workout(id: $0) }
        let entry = WeeklyWorkoutSchedule.Entry(
            id: original?.id ?? UUID(), workoutID: custom ? nil : workoutID, title: cleanTitle,
            weekday: WeeklyWorkoutSchedule.weekday(date),
            startMinute: hasTime ? Calendar.current.component(.hour, from: time) * 60 + Calendar.current.component(.minute, from: time) : nil,
            durationSeconds: hasDuration ? duration : nil, exerciseCount: Int(countText), notes: notes,
            icon: workout?.type.iconName ?? original?.icon ?? "figure.mixed.cardio",
            colorHex: workout?.type.colorHex ?? original?.colorHex ?? "FFFFFF")
        if onSave(entry, !custom && showsRepeat && repeats) { dismiss() }
        else { error = store.scheduleError ?? "Your changes could not be saved. Please try again." }
    }
}
