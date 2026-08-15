import SwiftUI

struct WorkoutPickerSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var workoutStore: WorkoutStore

    let page: ExercisePage

    @State private var duration: Int
    @State private var sets: Int
    @State private var reps: Int
    @State private var restAfter: Int
    @State private var restBetweenSets: Int
    @State private var prepareTime: Int
    @State private var showToast = false
    @State private var toastWorkoutName = ""

    init(page: ExercisePage) {
        self.page = page
        _duration = State(initialValue: page.manifest.duration ?? 30)
        _sets = State(initialValue: page.manifest.sets ?? 1)
        _reps = State(initialValue: page.manifest.sets != nil ? 12 : 0)
        _restAfter = State(initialValue: page.manifest.restAfter ?? 10)
        _restBetweenSets = State(initialValue: page.manifest.restBetweenSets ?? 10)
        _prepareTime = State(initialValue: page.manifest.prepareTime ?? 4)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.background.ignoresSafeArea()

                if workoutStore.workouts.isEmpty {
                    emptyWorkoutsView
                } else {
                    VStack(spacing: 0) {
                        configSummary
                        Divider().background(Theme.separator)
                        workoutList
                    }
                }
            }
            .navigationTitle("Add to Workout")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                AppToolbar.item(placement: .cancellationAction) { Button("Cancel") { dismiss() }.foregroundColor(.white)
                                 }
            }
            .overlay(alignment: .bottom) {
                if showToast {
                    toastBanner
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
        }
    }

    private var configSummary: some View {
        VStack(spacing: 10) {
            HStack {
                Text("Section Config")
                    .font(.headline)
                    .foregroundColor(Theme.textPrimary)
                Spacer()
                Text(page.title)
                    .font(.subheadline.weight(.medium))
                    .foregroundColor(Theme.textSecondary)
                    .lineLimit(1)
            }

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 72), spacing: 8)], spacing: 8) {
                compactStepper(label: "Dur.", value: $duration, range: 5...600, step: 5, unit: "s")
                compactStepper(label: "Sets", value: $sets, range: 1...20, step: 1, unit: "")
                compactStepper(label: "Reps", value: $reps, range: 0...100, step: 1, unit: "")
                compactStepper(label: "Rest", value: $restAfter, range: 0...120, step: 5, unit: "s")
                compactStepper(label: "Btwn", value: $restBetweenSets, range: 0...120, step: 5, unit: "s")
                compactStepper(label: "Prep", value: $prepareTime, range: 0...30, step: 1, unit: "s")
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    private func compactStepper(label: String, value: Binding<Int>, range: ClosedRange<Int>, step: Int, unit: String) -> some View {
        VStack(spacing: 2) {
            Text(label)
                .font(.system(size: 9))
                .foregroundColor(Theme.textSecondary)
            Text("\(value.wrappedValue)\(unit)")
                .font(.caption.weight(.semibold))
                .foregroundColor(.white)
            HStack(spacing: 4) {
                Button {
                    let new = value.wrappedValue - step
                    if new >= range.lowerBound { value.wrappedValue = new }
                } label: {
                    Image(systemName: "minus").font(.system(size: 8, weight: .bold))
                        .foregroundColor(.white).frame(width: 18, height: 18)
                        .background(Theme.surface).cornerRadius(4)
                }
                Button {
                    let new = value.wrappedValue + step
                    if new <= range.upperBound { value.wrappedValue = new }
                } label: {
                    Image(systemName: "plus").font(.system(size: 8, weight: .bold))
                        .foregroundColor(.white).frame(width: 18, height: 18)
                        .background(Theme.surface).cornerRadius(4)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 6)
        .background(Theme.surface)
        .cornerRadius(8)
    }

    private var workoutList: some View {
        ScrollView {
            LazyVStack(spacing: 8) {
                ForEach(workoutStore.workouts) { workout in
                    workoutRow(workout)
                }
            }
            .padding(16)
        }
    }

    private func workoutRow(_ workout: Workout) -> some View {
        Button {
            addSection(to: workout)
        } label: {
            HStack(spacing: 12) {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(hex: workout.colorHex))
                    .frame(width: 40, height: 40)
                    .overlay(
                        Image(systemName: workout.type.iconName)
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(workout.colorHex == "FFFFFF" ? .black : .white)
                    )
                VStack(alignment: .leading, spacing: 2) {
                    Text(workout.name)
                        .font(.subheadline.weight(.medium))
                        .foregroundColor(Theme.textPrimary)
                    Text("\(workout.sectionCount) sections · \(workout.type.name)")
                        .font(.caption)
                        .foregroundColor(Theme.textSecondary)
                }
                Spacer()
                Image(systemName: "plus.circle")
                    .font(.title3)
                    .foregroundColor(Color.white.opacity(0.6))
            }
            .padding(12)
            .background(Theme.surface)
            .cornerRadius(10)
        }
        .buttonStyle(.plain)
    }

    private func addSection(to workout: Workout) {
        let configuration = WorkoutSectionImportConfiguration(
            duration: duration,
            sets: sets,
            repCount: reps > 0 ? reps : nil,
            restAfter: restAfter,
            restBetweenSets: restBetweenSets,
            prepareTime: prepareTime
        )
        guard let newSection = WorkoutSectionBuilder.makeSection(
            page: page,
            configuration: configuration
        ) else { return }

        workoutStore.addSection(to: workout, section: newSection)
        dismiss()
    }

    private var toastBanner: some View {
        HStack(spacing: 8) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(.green)
            Text("Added to \(toastWorkoutName)")
                .font(.subheadline.weight(.medium))
                .foregroundColor(.white)
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color.black.opacity(0.85))
        .cornerRadius(12)
        .padding(.horizontal, 16)
        .padding(.bottom, 16)
    }

    private var emptyWorkoutsView: some View {
        VStack(spacing: 12) {
            Image(systemName: "figure.strengthtraining.traditional")
                .font(.system(size: 40))
                .foregroundColor(Theme.textSecondary.opacity(0.5))
            Text("No Workouts")
                .font(.headline)
                .foregroundColor(Theme.textPrimary)
            Text("Create a workout first to add pages to it.")
                .font(.subheadline)
                .foregroundColor(Theme.textSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
