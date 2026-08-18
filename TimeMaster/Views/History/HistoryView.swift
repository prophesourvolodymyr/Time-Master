import SwiftUI

private enum HistoryItem: Identifiable {
    case workout(WorkoutHistoryEntry)
    case outdoor(OutdoorActivity)

    var id: String {
        switch self {
        case .workout(let entry): "workout-\(entry.id.uuidString)"
        case .outdoor(let activity): "outdoor-\(activity.id.uuidString)"
        }
    }

    var date: Date {
        switch self {
        case .workout(let entry): entry.completedAt
        case .outdoor(let activity): activity.startedAt
        }
    }
}

struct HistoryView: View {
    @EnvironmentObject var store: WorkoutStore
    @EnvironmentObject var outdoorStore: OutdoorActivityStore
    @State private var showingClearAlert = false
    @State private var showingOutdoorClearAlert = false
    @State private var selectedOutdoorActivity: OutdoorActivity?

    private var items: [HistoryItem] {
        (store.historyEntries.map(HistoryItem.workout) + outdoorStore.activities.filter(\.finished).map(HistoryItem.outdoor))
            .sorted { $0.date > $1.date }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.background.ignoresSafeArea()
                if items.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "clock").font(.system(size: 60)).foregroundColor(Theme.textSecondary)
                        Text("No History Yet").font(.title2).fontWeight(.semibold).foregroundColor(Theme.textPrimary)
                        Text("Complete a workout or outdoor activity to see it here").font(.subheadline).foregroundColor(Theme.textSecondary)
                    }
                } else {
                    List {
                        ForEach(items) { item in
                            switch item {
                            case .workout(let entry):
                                HistoryRow(entry: entry)
                                    .listRowBackground(Theme.surface)
                                    .swipeActions {
                                        Button(role: .destructive) {
                                            if let index = store.historyEntries.firstIndex(where: { $0.id == entry.id }) {
                                                store.deleteHistoryEntries(at: IndexSet(integer: index))
                                            }
                                        } label: { Label("Delete", systemImage: "trash") }
                                    }
                            case .outdoor(let activity):
                                Button { selectedOutdoorActivity = activity } label: {
                                    OutdoorHistoryRow(activity: activity)
                                }
                                .buttonStyle(.plain)
                                .listRowBackground(Theme.surface)
                                .swipeActions {
                                    Button(role: .destructive) { try? outdoorStore.delete(activity) } label: { Label("Delete", systemImage: "trash") }
                                }
                            }
                        }
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                }
            }
            .navigationTitle("History")
            .toolbar {
                if !store.historyEntries.isEmpty {
                    AppToolbar.item(placement: .primaryAction) {
                        Button { showingClearAlert = true } label: {
                            Image(systemName: "trash").foregroundColor(.white)
                        }
                    }
                }
                if !outdoorStore.activities.filter(\.finished).isEmpty {
                    AppToolbar.item(placement: .primaryAction) {
                        Button { showingOutdoorClearAlert = true } label: {
                            Image(systemName: "figure.run.circle").foregroundColor(.cyan)
                        }
                    }
                }
            }
            .alert("Clear Workout History?", isPresented: $showingClearAlert) {
                Button("Cancel", role: .cancel) {}
                Button("Clear", role: .destructive) { store.clearHistory() }
            } message: { Text("Outdoor activities will remain.") }
            .alert("Clear Outdoor Activities?", isPresented: $showingOutdoorClearAlert) {
                Button("Cancel", role: .cancel) {}
                Button("Clear", role: .destructive) { try? outdoorStore.clearFinished() }
            } message: { Text("This deletes saved routes and cannot be undone.") }
            .sheet(item: $selectedOutdoorActivity) { activity in
                OutdoorActivityDetailView(store: outdoorStore, activity: activity)
            }
        }
    }
}

private struct OutdoorHistoryRow: View {
    let activity: OutdoorActivity

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: activity.kind.iconName).font(.title2).foregroundColor(.cyan).frame(width: 40)
            VStack(alignment: .leading, spacing: 4) {
                Text(activity.title).font(.headline).foregroundColor(Theme.textPrimary)
                HStack(spacing: 6) {
                    Text(activity.startedAt, style: .date)
                    Text("·")
                    Text(String(format: "%.2f km", activity.distanceMeters / 1000))
                    Text("·")
                    Text(formatDuration(activity.elapsedSeconds))
                }
                .font(.caption).foregroundColor(Theme.textSecondary)
            }
            Spacer()
        }
        .padding(.vertical, 8)
    }

    private func formatDuration(_ seconds: Int) -> String {
        String(format: "%02d:%02d:%02d", seconds / 3600, (seconds % 3600) / 60, seconds % 60)
    }
}

struct HistoryRow: View {
    let entry: WorkoutHistoryEntry

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: entry.isPartial ? "clock.badge.exclamationmark" : "checkmark.circle.fill")
                .font(.title2)
                .foregroundColor(entry.isPartial ? Color.orange : .white)
                .frame(width: 40)

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(entry.workoutName)
                        .font(.headline)
                        .foregroundColor(Theme.textPrimary)
                        .lineLimit(1)
                    if entry.isPartial {
                        Text("[Partial]")
                            .font(.caption2.weight(.bold))
                            .foregroundColor(.orange)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(Color.orange.opacity(0.15))
                            .cornerRadius(4)
                    }
                }

                HStack(spacing: 6) {
                    Text(formatDate(entry.completedAt))
                        .font(.caption)
                        .foregroundColor(Theme.textSecondary)
                    Text("·")
                        .foregroundColor(Theme.textSecondary)
                    if entry.isPartial {
                        Text(formatDuration(entry.elapsedSeconds))
                            .font(.caption)
                            .foregroundColor(Theme.textSecondary)
                        Text("of \(formatDuration(entry.durationCompleted))")
                            .font(.caption)
                            .foregroundColor(Theme.textSecondary.opacity(0.5))
                    } else {
                        Text(formatDuration(entry.durationCompleted))
                            .font(.caption)
                            .foregroundColor(Theme.textSecondary)
                    }
                }
            }

            Spacer()
        }
        .padding(.vertical, 8)
    }

    private func formatDate(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .short
        return f.string(from: date)
    }

    private func formatDuration(_ seconds: Int) -> String {
        let m = seconds / 60, s = seconds % 60
        return m > 0 ? "\(m)m \(s)s" : "\(s)s"
    }
}

#Preview {
    HistoryView()
        .environmentObject(WorkoutStore())
        .environmentObject(OutdoorActivityStore())
        .preferredColorScheme(.dark)
}
