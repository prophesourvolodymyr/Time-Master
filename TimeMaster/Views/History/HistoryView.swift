import SwiftUI
#if os(iOS)
import UIKit
#endif

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
    @EnvironmentObject var musicLibraryStore: MusicLibraryStore
    @EnvironmentObject var outdoorPreferencesStore: OutdoorRecordingPreferencesStore
    @State private var showingClearAlert = false
    @State private var selectedOutdoorActivity: OutdoorActivity?

    private var items: [HistoryItem] {
        (store.historyEntries.map(HistoryItem.workout) + outdoorStore.establishedActivities.map(HistoryItem.outdoor))
            .sorted { $0.date > $1.date }
    }

    var body: some View {
            ZStack {
                Theme.background.ignoresSafeArea()
                if items.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "clock").font(.system(size: 60)).foregroundColor(Theme.textSecondary)
                        Text("No History Yet").font(TimeMasterFont.black(22, relativeTo: .title2)).foregroundColor(Theme.textPrimary)
                        Text("Complete a workout or outdoor activity to see it here").font(TimeMasterFont.secondary()).foregroundColor(Theme.textSecondary)
                    }
                } else {
                    List {
                        ForEach(items) { item in
                            switch item {
                            case .workout(let entry):
                                HistoryRow(entry: entry)
                                    .keyNavTarget(id: item.id, role: .primary, shape: .roundedRectangle(cornerRadius: 0))
                                    .listRowBackground(Theme.surface)
                                    .swipeActions {
                                        Button(role: .destructive) {
                                            if let index = store.historyEntries.firstIndex(where: { $0.id == entry.id }) {
                                                store.deleteHistoryEntries(at: IndexSet(integer: index))
                                            }
                                        } label: { Label("Delete", systemImage: "trash") }
                                    }
                            case .outdoor(let activity):
                                Group {
#if os(iOS)
                                    if UIDevice.current.userInterfaceIdiom == .phone {
                                        Button {
                                            selectedOutdoorActivity = activity
                                        } label: {
                                            OutdoorHistoryRow(activity: activity)
                                        }
                                        .buttonStyle(.plain)
                                    } else {
                                        OutdoorHistoryRow(activity: activity)
                                    }
#else
                                    OutdoorHistoryRow(activity: activity)
                                        .keyNavTarget(id: item.id, role: .primary, shape: .roundedRectangle(cornerRadius: 0))
#endif
                                }
                                .listRowBackground(Theme.surface)
                            }
                        }
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                }
            }
            .font(TimeMasterFont.body())
            .timeMasterNavigationTitle("History")
            .navigationBarBackButtonHidden(true)
            .toolbar {
                AppToolbar.item(placement: .cancellationAction) { TimeMasterBackButton()
                    .oneHandedActionSource()
                                 }
                if !store.historyEntries.isEmpty {
                    AppToolbar.iconItem(placement: .primaryAction) {
                        clearHistoryButton.oneHandedActionSource()
                    }
                }
            }
            .oneHandedActions(id: "history", actions: historyActions)
            .alert("Clear Workout History?", isPresented: $showingClearAlert) {
                Button("Cancel", role: .cancel) {}
                Button("Clear", role: .destructive) { store.clearHistory() }
            } message: { Text("Outdoor activities will remain.") }
#if os(iOS)
            .fullScreenCover(
                item: Binding(
                    get: { UIDevice.current.userInterfaceIdiom == .phone ? selectedOutdoorActivity : nil },
                    set: { selectedOutdoorActivity = $0 }
                )
            ) { activity in
                OutdoorRouteRecordingView(
                    kind: activity.kind,
                    store: outdoorStore,
                    preferences: outdoorPreferencesStore,
                    musicLibrary: musicLibraryStore,
                    initialActivityID: activity.id
                )
            }
            #endif
    }

    private var historyActions: [ReachabilityAction] {
        var actions = [
            ReachabilityAction("back", title: "Back") {
                TimeMasterBackButton()
            }
        ]
        if !store.historyEntries.isEmpty {
            actions.append(ReachabilityAction("clear-history", title: "Clear History") {
                clearHistoryButton.buttonStyle(TimeMasterToolbarIconButtonStyle())
            })
        }
        return actions
    }

    private var clearHistoryButton: some View {
        Button { showingClearAlert = true } label: {
            Image(systemName: "trash").foregroundColor(.white)
        }
        .accessibilityLabel("Clear Workout History")
    }
}

private struct OutdoorHistoryRow: View {
    let activity: OutdoorActivity

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: activity.kind.iconName).font(.title2).foregroundColor(.cyan).frame(width: 40)
            VStack(alignment: .leading, spacing: 4) {
                Text(activity.title).font(TimeMasterFont.sectionTitle()).foregroundColor(Theme.textPrimary)
                HStack(spacing: 6) {
                    Text(activity.startedAt, style: .date)
                    Text("·")
                    Text(String(format: "%.2f km", activity.distanceMeters / 1000))
                        .font(TimeMasterFont.black(12, relativeTo: .caption))
                    Text("·")
                    Text(formatDuration(activity.elapsedSeconds))
                        .font(TimeMasterFont.black(12, relativeTo: .caption))
                }
                .font(TimeMasterFont.caption()).monospacedDigit().foregroundColor(Theme.textSecondary)
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
                        .font(TimeMasterFont.sectionTitle())
                        .foregroundColor(Theme.textPrimary)
                        .lineLimit(1)
                    if entry.isPartial {
                        Text("[Partial]")
                            .font(TimeMasterFont.black(11, relativeTo: .caption2))
                            .foregroundColor(.orange)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(Color.orange.opacity(0.15))
                            .cornerRadius(4)
                    }
                }

                HStack(spacing: 6) {
                    Text(formatDate(entry.completedAt))
                        .font(TimeMasterFont.caption())
                        .monospacedDigit()
                        .foregroundColor(Theme.textSecondary)
                    Text("·")
                        .foregroundColor(Theme.textSecondary)
                    if entry.isPartial {
                        Text(formatDuration(entry.elapsedSeconds))
                            .font(TimeMasterFont.black(12, relativeTo: .caption))
                            .monospacedDigit()
                            .foregroundColor(Theme.textSecondary)
                        Text("of \(formatDuration(entry.durationCompleted))")
                            .font(TimeMasterFont.black(12, relativeTo: .caption))
                            .monospacedDigit()
                            .foregroundColor(Theme.textSecondary.opacity(0.5))
                    } else {
                        Text(formatDuration(entry.durationCompleted))
                            .font(TimeMasterFont.black(12, relativeTo: .caption))
                            .monospacedDigit()
                            .foregroundColor(Theme.textSecondary)
                    }
                }
                .font(TimeMasterFont.caption())
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
        .environmentObject(MusicLibraryStore())
        .environmentObject(OutdoorRecordingPreferencesStore())
        .preferredColorScheme(.dark)
}
