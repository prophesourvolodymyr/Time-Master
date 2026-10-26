import SwiftUI

struct MenuBarWorkoutsPage: View {
    @ObservedObject var store: WorkoutStore
    @Environment(\.menuBarActions) private var actions
    @State private var query = ""
    @FocusState private var searchFocused: Bool

    private var results: [Workout] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return store.workouts }
        return store.workouts.filter {
            $0.name.localizedCaseInsensitiveContains(trimmed) || $0.type.name.localizedCaseInsensitiveContains(trimmed)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            searchField
                .padding(.horizontal, 14)
                .padding(.top, 12)
                .padding(.bottom, 8)
            ScrollView {
                VStack(spacing: 8) {
                    if store.workouts.isEmpty {
                        MenuBarCard {
                            MenuBarEmptyState(
                                symbol: "dumbbell.fill",
                                title: "No workouts yet",
                                message: "Create a workout in Tmax."
                            )
                        }
                    } else if results.isEmpty {
                        MenuBarCard {
                            MenuBarEmptyState(
                                symbol: "magnifyingglass",
                                title: "No match",
                                message: "Try another search."
                            )
                        }
                    } else {
                        ForEach(results) { workout in
                            MenuBarWorkoutRow(workout: workout)
                        }
                    }
                    MenuBarCompactButton(title: "New workout", symbol: "plus", fillsWidth: true) {
                        actions.newWorkout()
                    }
                    .padding(.top, 4)
                }
                .padding(.horizontal, 14)
                .padding(.bottom, 14)
            }
            .scrollIndicators(.hidden)
        }
    }

    private var searchField: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Theme.textSecondary)
                .accessibilityHidden(true)
            TextField("Search workouts", text: $query)
                .textFieldStyle(.plain)
                .font(TimeMasterFont.body(15))
                .foregroundStyle(Theme.textPrimary)
                .focused($searchFocused)
                .onChange(of: searchFocused) { focused in
                    if focused { actions.requestKeyboard() }
                }
            if !query.isEmpty {
                Button {
                    query = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(Theme.textSecondary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Clear search")
            }
        }
        .padding(.horizontal, 12)
        .frame(minHeight: 40)
        .modifier(TimeMasterCardSurface(cornerRadius: 14, flat: true))
    }
}

private struct MenuBarWorkoutRow: View {
    let workout: Workout
    @Environment(\.menuBarActions) private var actions

    private var canStart: Bool { !workout.sections.isEmpty }

    var body: some View {
        MenuBarCard(padding: 10) {
            HStack(spacing: 10) {
                MenuBarTypeTile(colorHex: workout.type.colorHex, symbol: workout.type.iconName, size: 40)
                Button {
                    actions.openWorkoutDetail(workout.id)
                } label: {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(workout.name)
                            .font(TimeMasterFont.rowTitle())
                            .foregroundStyle(Theme.textPrimary)
                            .lineLimit(1)
                        Text(meta)
                            .font(TimeMasterFont.caption())
                            .foregroundStyle(Theme.textSecondary)
                            .lineLimit(1)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(MenuBarRowButtonStyle())
                Button {
                    actions.startWorkout(workout.id)
                } label: {
                    Image(systemName: "play.fill")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(Theme.textPrimary)
                }
                .buttonStyle(TimeMasterActionButtonStyle(circular: true, minimumSize: 40, tint: Theme.surface2))
                .disabled(!canStart)
                .accessibilityLabel(canStart ? "Start \(workout.name)" : "\(workout.name) has no exercises yet")
            }
        }
    }

    private var meta: String {
        guard canStart else { return "No exercises yet" }
        let sections = workout.sections.count == 1 ? "1 section" : "\(workout.sections.count) sections"
        return "\(MenuBarFormat.minutes(workout.totalDuration)) · \(sections) · \(workout.type.name)"
    }
}
