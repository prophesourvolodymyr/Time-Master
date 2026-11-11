import SwiftUI

/// Links a workout: the user's workouts as a grid of their covers, searchable by name or type.
struct WorkoutLinkPickerSheet: View {
    let linkedIDs: Set<UUID>
    let onPick: (Workout) -> Void

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var workoutStore: WorkoutStore
    @State private var query = ""
    @ScaledMetric(relativeTo: .body) private var tileSide: CGFloat = 140

    private var shown: [Workout] {
        let text = query.trimmingCharacters(in: .whitespacesAndNewlines)
        let all = workoutStore.workouts.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
        guard !text.isEmpty else { return all }
        return all.filter { $0.name.localizedCaseInsensitiveContains(text) || $0.type.name.localizedCaseInsensitiveContains(text) }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                if shown.isEmpty {
                    VStack(spacing: 10) {
                        Image(systemName: "figure.strengthtraining.traditional")
                            .font(.system(size: 34))
                            .foregroundStyle(Theme.textSecondary)
                        Text(workoutStore.workouts.isEmpty ? "No workouts" : "No match")
                            .font(TimeMasterFont.secondary())
                            .foregroundStyle(Theme.textSecondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, 60)
                } else {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: tileSide + 20), spacing: 14, alignment: .top)], spacing: 18) {
                        ForEach(shown) { workout in
                            tile(workout)
                        }
                    }
                    .padding(20)
                }
            }
            .background(Theme.background.ignoresSafeArea())
            .searchable(text: $query)
            .timeMasterNavigationTitle("Link a workout")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                AppToolbar.item(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .buttonStyle(TimeMasterToolbarTextButtonStyle())
                }
            }
        }
        .keyNavHost()
        #if os(macOS)
        .frame(minWidth: 560, minHeight: 520)
        #endif
    }

    private func tile(_ workout: Workout) -> some View {
        let isLinked = linkedIDs.contains(workout.id)
        return Button {
            onPick(workout)
            dismiss()
        } label: {
            VStack(alignment: .leading, spacing: 8) {
                WorkoutCoverMosaic(workout: workout, size: tileSide)
                    .overlay(alignment: .topTrailing) {
                        if isLinked {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 20, weight: .bold))
                                .symbolRenderingMode(.palette)
                                .foregroundStyle(.black, Theme.toolbarOrange)
                                .padding(6)
                        }
                    }
                Text(workout.name)
                    .font(TimeMasterFont.rowTitle())
                    .foregroundStyle(Theme.textPrimary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                HStack(spacing: 4) {
                    Image(systemName: workout.type.iconName)
                        .font(.system(size: 10, weight: .bold))
                    Text("\(max(1, workout.totalDuration / 60)) min")
                        .font(TimeMasterFont.technical())
                }
                .foregroundStyle(Color(hex: workout.type.colorHex))
            }
            .frame(width: tileSide, alignment: .leading)
            .contentShape(Rectangle())
        }
        .keyNavPlainButtonStyle(shape: .roundedRectangle(cornerRadius: 14))
        .accessibilityLabel(workout.name)
        .accessibilityValue(isLinked ? "Linked" : "")
        .accessibilityAddTraits(isLinked ? .isSelected : [])
    }
}
