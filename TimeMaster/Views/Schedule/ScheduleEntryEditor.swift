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
    @FocusState private var focusedField: Field?

    private enum Field: Hashable {
        case search, title, notes, exerciseCount
    }

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
            .font(TimeMasterFont.body())
            .timeMasterNavigationTitle(configuring ? (custom ? "Custom workout" : "Set workout time") : "Choose workout")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                AppToolbar.item(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .accessibilityIdentifier("schedule.entry.cancel")
                }
                if configuring {
                    AppToolbar.item(placement: .confirmationAction) {
                        Button(custom && original == nil ? "Log workout" : "Save", action: save)
                            .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                            .accessibilityIdentifier("schedule.entry.save")
                    }
                }
            }
            .tint(Theme.toolbarOrange)
            .foregroundStyle(Theme.textPrimary)
            .onSubmit { focusedField = nil }
            #if os(iOS)
            .toolbar {
                if focusedField != nil {
                    AppToolbar.item(placement: .keyboard) {
                        Button("Done") { focusedField = nil }
                    }
                }
            }
            #endif
        }
        .preferredColorScheme(.dark)
    }

    private var workoutPicker: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                TextField("Search workouts", text: $search,
                          prompt: Text("Search workouts").foregroundColor(Theme.textSecondary))
                    .focused($focusedField, equals: .search)
                    .modifier(ScheduleEntryFieldSurface(isFocused: focusedField == .search))
                    .accessibilityLabel("Search workouts")
                    .accessibilityIdentifier("schedule.entry.search")
                if store.workouts.isEmpty {
                    VStack(spacing: 8) {
                        Image(systemName: "dumbbell").font(.largeTitle)
                        Text("No workouts yet").font(TimeMasterFont.sectionTitle())
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
        .scrollDismissesKeyboard(.interactively)
    }

    private var configuration: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                VStack(alignment: .leading, spacing: 12) {
                    sectionHeading(date.formatted(.dateTime.weekday(.wide).month(.abbreviated).day()))
                    if custom {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Title (required)")
                                .font(TimeMasterFont.body(15, relativeTo: .subheadline))
                            TextField("Title (required)", text: $title,
                                      prompt: Text("Workout title").foregroundColor(Theme.textSecondary))
                                .focused($focusedField, equals: .title)
                                .submitLabel(.done)
                                .modifier(ScheduleEntryFieldSurface(isFocused: focusedField == .title))
                                .accessibilityIdentifier("schedule.custom.title")
                        }
                        Text("Only a title is required. This logs what you did outside the app; it does not create a library workout.")
                            .font(TimeMasterFont.body(13, relativeTo: .footnote))
                            .foregroundStyle(Theme.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    } else if let workoutID, let workout = store.workout(id: workoutID) {
                        Label(workout.name, systemImage: workout.type.iconName)
                            .font(TimeMasterFont.sectionTitle())
                            .fixedSize(horizontal: false, vertical: true)
                        if original == nil {
                            Button("Choose a different workout") { configuring = false }
                                .buttonStyle(TimeMasterSelectionButtonStyle())
                                .accessibilityIdentifier("schedule.entry.changeWorkout")
                        }
                    } else {
                        Label(title, systemImage: original?.icon ?? "dumbbell.fill")
                            .font(TimeMasterFont.sectionTitle())
                            .fixedSize(horizontal: false, vertical: true)
                        Text("This workout is no longer in your library. Its schedule and completion record are preserved.")
                            .font(TimeMasterFont.body(13, relativeTo: .footnote))
                            .foregroundStyle(Theme.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                VStack(alignment: .leading, spacing: 12) {
                    sectionHeading("Time")
                    if custom {
                        Toggle(isOn: $hasTime) {
                            Text("Add start time")
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .modifier(ScheduleEntryFieldSurface())
                        .accessibilityIdentifier("schedule.entry.hasTime")
                    }
                    if hasTime {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Start time")
                                .font(TimeMasterFont.secondary())
                                .foregroundStyle(Theme.textSecondary)
                            DatePicker("Start time", selection: $time, displayedComponents: .hourAndMinute)
                                #if os(iOS)
                                .datePickerStyle(.wheel)
                                #endif
                                .labelsHidden()
                                .monospacedDigit()
                                .accessibilityLabel("Start time")
                                .accessibilityIdentifier("schedule.entry.startTime")
                        }
                        .modifier(ScheduleEntryFieldSurface())
                    }
                    if custom {
                        Toggle(isOn: $hasDuration) {
                            Text("Add duration")
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .modifier(ScheduleEntryFieldSurface())
                        .accessibilityIdentifier("schedule.entry.hasDuration")
                    }
                    if hasDuration {
                        VStack(alignment: .leading, spacing: 12) {
                            Stepper(value: Binding(
                                get: { duration / 3600 },
                                set: { duration = min(86400, $0 * 3600 + duration % 3600) }
                            ), in: 0...24) {
                                Text("Hours: \(duration / 3600)")
                                    .font(TimeMasterFont.label())
                                    .monospacedDigit()
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            .frame(minHeight: 44)
                            .accessibilityIdentifier("schedule.entry.hours")
                            DurationPickerView(seconds: Binding(
                                get: { duration % 3600 },
                                set: { duration = duration / 3600 * 3600 + $0 }
                            ), range: 0...3599, step: 1)
                            .disabled(duration == 86400)
                            if hasTime {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Finishes")
                                        .font(TimeMasterFont.secondary())
                                        .foregroundStyle(Theme.textSecondary)
                                    Text(time.addingTimeInterval(Double(duration)).formatted(date: .omitted, time: .shortened))
                                        .font(TimeMasterFont.label())
                                        .monospacedDigit()
                                }
                                .accessibilityElement(children: .combine)
                            }
                        }
                        .modifier(ScheduleEntryFieldSurface())
                    }
                }

                if custom {
                    VStack(alignment: .leading, spacing: 12) {
                        sectionHeading("Optional details")
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Description")
                                .font(TimeMasterFont.body(15, relativeTo: .subheadline))
                            TextField("Description", text: $notes, axis: .vertical)
                                .lineLimit(3...6)
                                .focused($focusedField, equals: .notes)
                                .modifier(ScheduleEntryFieldSurface(isFocused: focusedField == .notes))
                                .accessibilityIdentifier("schedule.custom.description")
                        }
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Exercise count")
                                .font(TimeMasterFont.body(15, relativeTo: .subheadline))
                            TextField("Exercise count", text: $exerciseCount,
                                      prompt: Text("Optional").foregroundColor(Theme.textSecondary))
                                .font(TimeMasterFont.label())
                                .monospacedDigit()
                                #if os(iOS)
                                .keyboardType(.numberPad)
                                #endif
                                .focused($focusedField, equals: .exerciseCount)
                                .submitLabel(.done)
                                .modifier(ScheduleEntryFieldSurface(isFocused: focusedField == .exerciseCount))
                                .accessibilityIdentifier("schedule.custom.exerciseCount")
                        }
                    }
                } else if showsRepeat {
                    VStack(alignment: .leading, spacing: 12) {
                        Toggle(isOn: $repeats) {
                            Text("Repeat in this Plan")
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .modifier(ScheduleEntryFieldSurface())
                        .accessibilityIdentifier("schedule.entry.repeats")
                        Text(repeats ? "Updates the Plan from this week onward. Previous weeks stay unchanged." : "Changes only this date. The repeating Plan stays unchanged.")
                            .font(TimeMasterFont.body(13, relativeTo: .footnote))
                            .foregroundStyle(Theme.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                if let error {
                    Label(error, systemImage: "exclamationmark.circle")
                        .foregroundStyle(.red)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityIdentifier("schedule.entry.error")
                }
            }
            .padding(20)
            .frame(maxWidth: 640, alignment: .leading)
            .frame(maxWidth: .infinity)
        }
        .scrollDismissesKeyboard(.interactively)
    }

    private func sectionHeading(_ title: String) -> some View {
        Text(title)
            .font(TimeMasterFont.rowTitle())
            .monospacedDigit()
            .foregroundStyle(Theme.textSecondary)
            .fixedSize(horizontal: false, vertical: true)
            .accessibilityAddTraits(.isHeader)
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

private struct ScheduleEntryFieldSurface: ViewModifier {
    @Environment(\.colorSchemeContrast) private var contrast
    var isFocused = false

    func body(content: Content) -> some View {
        content
            .textFieldStyle(.plain)
            .foregroundStyle(Theme.textPrimary)
            .padding(12)
            .frame(minHeight: 44)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.surface, in: RoundedRectangle(cornerRadius: Theme.controlCornerRadius, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: Theme.controlCornerRadius, style: .continuous)
                    .strokeBorder(
                        isFocused ? Theme.toolbarOrange : contrast == .increased ? .white.opacity(0.5) : Theme.separator,
                        lineWidth: isFocused ? 2 : 1
                    )
                    .allowsHitTesting(false)
            }
    }
}
