import SwiftUI

struct MenuBarWorkoutsPage: View {
    @ObservedObject var store: WorkoutStore
    @Environment(\.menuBarActions) private var actions
    @State private var query = ""
    @FocusState private var searchFocused: Bool

    private var trimmedQuery: String {
        query.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var results: [Workout] {
        let trimmed = trimmedQuery
        guard !trimmed.isEmpty else { return store.workouts.filter { !store.isArchived($0) } }
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
                    if results.isEmpty && trimmedQuery.isEmpty {
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
                            MenuBarWorkoutRow(workout: workout, isArchived: store.isArchived(workout))
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
                .keyNavPlainButtonStyle(shape: .circle)
                .accessibilityLabel("Clear search")
            }
        }
        .padding(.horizontal, 14)
        .frame(minHeight: MenuBarMetrics.buttonHeight)
        .background(WidgetTint.graphite.base, in: Capsule())
        .overlay {
            Capsule()
                .strokeBorder(Color.white.opacity(searchFocused ? 0.24 : 0.08), lineWidth: 1)
                .allowsHitTesting(false)
        }
    }
}

private struct MenuBarWorkoutRow: View {
    let workout: Workout
    let isArchived: Bool
    @Environment(\.menuBarActions) private var actions

    private var canStart: Bool { !workout.sections.isEmpty }

    var body: some View {
        MenuBarCard(padding: 10) {
            HStack(spacing: 10) {
                MenuBarArtTile(art: .forWorkout(workout), size: 40)
                Button {
                    actions.openWorkoutDetail(workout.id)
                } label: {
                    VStack(alignment: .leading, spacing: 1) {
                        Text(WorkoutTitle.short(workout.name))
                            .font(TimeMasterFont.black(15, relativeTo: .subheadline))
                            .foregroundStyle(Theme.textPrimary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                        Text(meta)
                            .font(WidgetFont.label())
                            .foregroundStyle(WidgetTint.graphite.secondaryInk)
                            .lineLimit(1)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(MenuBarRowButtonStyle())
                .accessibilityLabel("\(workout.name), \(meta)")
                HomeIconButton(
                    systemImage: "play.fill",
                    label: canStart ? "Start \(workout.name)" : "\(workout.name) has no exercises yet",
                    diameter: MenuBarMetrics.buttonHeight
                ) {
                    actions.startWorkout(workout.id)
                }
                .disabled(!canStart)
                .opacity(canStart ? 1 : 0.4)
            }
        }
    }

    private var meta: String {
        guard canStart else { return "No exercises yet" }
        let minutes = MenuBarFormat.minutes(workout.totalDuration)
        return isArchived ? "Archived · \(minutes)" : minutes
    }
}
