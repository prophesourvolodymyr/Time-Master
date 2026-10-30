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
                        workoutList
                    }
                }
            }
            .timeMasterNavigationTitle("Add to Workout")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                AppToolbar.item(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .buttonStyle(TimeMasterToolbarTextButtonStyle())
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
                    .font(TimeMasterFont.sectionTitle())
                    .foregroundColor(Theme.textPrimary)
                Spacer()
                Text(page.title)
                    .font(TimeMasterFont.rowTitle())
                    .foregroundColor(Theme.textSecondary)
                    .lineLimit(1)
            }

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 72), spacing: 8)], spacing: 8) {
                compactStepper(label: "Dur.", value: $duration, range: 5...600, step: 5, unit: "s")
                compactStepper(label: "Sets", value: $sets, range: 1...20, step: 1, unit: "")
                compactStepper(label: "Reps", value: $reps, range: 0...100, step: 1, unit: "")
                compactStepper(label: "Prep", value: $prepareTime, range: 0...30, step: 1, unit: "s")
                if sets > 1 {
                    compactStepper(label: "Between Sets", value: $restBetweenSets, range: 0...120, step: 5, unit: "s")
                }
                compactStepper(label: sets > 1 ? "Big Rest" : "Rest", value: $restAfter, range: 0...120, step: 5, unit: "s")
            }
            .animation(.easeOut(duration: 0.2), value: sets > 1)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    private func compactStepper(label: String, value: Binding<Int>, range: ClosedRange<Int>, step: Int, unit: String) -> some View {
        VStack(spacing: 4) {
            Text(label)
                .font(TimeMasterFont.body(10, relativeTo: .caption2))
                .foregroundColor(Theme.textSecondary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            Text("\(value.wrappedValue)\(unit)")
                .font(TimeMasterFont.black(14, relativeTo: .caption).monospacedDigit())
                .foregroundColor(Theme.toolbarOrange)
            HStack(spacing: 6) {
                compactStepButton("minus", label: "Decrease \(label)") {
                    let new = value.wrappedValue - step
                    if new >= range.lowerBound { value.wrappedValue = new }
                }
                compactStepButton("plus", label: "Increase \(label)") {
                    let new = value.wrappedValue + step
                    if new <= range.upperBound { value.wrappedValue = new }
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).strokeBorder(Color.white.opacity(0.08), lineWidth: 1))
    }

    private func compactStepButton(_ symbol: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 10, weight: .black))
                .foregroundColor(.white)
                .frame(width: 26, height: 26)
                .background(Theme.toolbarOrange.opacity(0.7), in: Circle())
                .overlay(Circle().strokeBorder(Color.white.opacity(0.2), lineWidth: 1))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
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
                        .font(TimeMasterFont.rowTitle())
                        .foregroundColor(Theme.textPrimary)
                    Text("\(workout.sectionCount) sections · \(workout.type.name)")
                        .font(TimeMasterFont.caption())
                        .foregroundColor(Theme.textSecondary)
                }
                Spacer()
                Image(systemName: "plus")
                    .font(.system(size: 15, weight: .black))
                    .foregroundStyle(Theme.textPrimary)
                    .frame(width: 40, height: 40)
                    .background(Theme.toolbarOrange.opacity(0.75), in: Circle())
                    .overlay(Circle().strokeBorder(Color.white.opacity(0.2), lineWidth: 1))
                    .accessibilityHidden(true)
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
                .font(TimeMasterFont.rowTitle())
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
                .font(TimeMasterFont.sectionTitle())
                .foregroundColor(Theme.textPrimary)
            Text("Create a workout first to add pages to it.")
                .font(TimeMasterFont.body(15, relativeTo: .subheadline))
                .foregroundColor(Theme.textSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
