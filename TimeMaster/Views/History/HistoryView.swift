import SwiftUI

struct HistoryView: View {
    @EnvironmentObject var store: WorkoutStore
    @State private var showingClearAlert = false

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.background.ignoresSafeArea()

                if store.historyEntries.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "clock")
                            .font(.system(size: 60))
                            .foregroundColor(Theme.textSecondary)
                        Text("No History Yet")
                            .font(.title2).fontWeight(.semibold)
                            .foregroundColor(Theme.textPrimary)
                        Text("Complete a workout to see it here")
                            .font(.subheadline)
                            .foregroundColor(Theme.textSecondary)
                    }
                } else {
                    List {
                        ForEach(store.historyEntries) { entry in
                            HistoryRow(entry: entry)
                                .listRowBackground(Theme.surface)
                                .listRowSeparatorTint(Theme.separator)
                        }
                        .onDelete(perform: deleteEntries)
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                }
            }
            .navigationTitle("History")
            .toolbar {
                if !store.historyEntries.isEmpty {
                    ToolbarItem(placement: .primaryAction) {
                        Button { showingClearAlert = true } label: {
                            Image(systemName: "trash")
                                .foregroundColor(.white)
                        }
                    }
                }
            }
            .alert("Clear History?", isPresented: $showingClearAlert) {
                Button("Cancel", role: .cancel) {}
                Button("Clear", role: .destructive) { store.clearHistory() }
            } message: {
                Text("This will delete all workout history")
            }
        }
    }

    private func deleteEntries(at offsets: IndexSet) {
        // Rebuild history without the removed entries
        var entries = store.historyEntries
        entries.remove(atOffsets: offsets)
        store.clearHistory()
        for entry in entries.reversed() { store.addHistoryEntry(entry) }
    }
}

struct HistoryRow: View {
    let entry: WorkoutHistoryEntry

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "checkmark.circle.fill")
                .font(.title2)
                .foregroundColor(.green)
                .frame(width: 40)

            VStack(alignment: .leading, spacing: 4) {
                Text(entry.workoutName)
                    .font(.headline)
                    .foregroundColor(Theme.textPrimary)
                    .lineLimit(1)

                HStack(spacing: 6) {
                    Text(formatDate(entry.completedAt))
                        .font(.caption)
                        .foregroundColor(Theme.textSecondary)
                    Text("·")
                        .foregroundColor(Theme.textSecondary)
                    Text(formatDuration(entry.durationCompleted))
                        .font(.caption)
                        .foregroundColor(Theme.textSecondary)
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
        .preferredColorScheme(.dark)
}
