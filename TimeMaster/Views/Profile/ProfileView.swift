import SwiftUI
#if os(iOS)
import UIKit
#endif

struct ProfileView: View {
    @EnvironmentObject private var outdoorStore: OutdoorActivityStore
    @EnvironmentObject private var musicLibraryStore: MusicLibraryStore
    @EnvironmentObject private var outdoorPreferencesStore: OutdoorRecordingPreferencesStore
    @State private var selectedActivity: OutdoorActivity?

    private var weekActivities: [OutdoorActivity] { activities(in: Calendar.current.dateInterval(of: .weekOfYear, for: Date())) }
    private var monthActivities: [OutdoorActivity] { activities(in: Calendar.current.dateInterval(of: .month, for: Date())) }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    totals
                    NavigationLink {
                        HistoryView()
                            .environmentObject(outdoorStore)
                    } label: {
                        Label("All Activity History", systemImage: "clock.arrow.circlepath")
                            .foregroundStyle(.white)
                    }
                    if outdoorStore.profileActivities.isEmpty {
                        emptyState
                    } else {
                        activityList
                    }
                }
                .padding(16)
            }
            .background(Theme.background.ignoresSafeArea())
            .navigationTitle("Profile")
#if os(iOS)
            .fullScreenCover(
                item: Binding(
                    get: { UIDevice.current.userInterfaceIdiom == .phone ? selectedActivity : nil },
                    set: { selectedActivity = $0 }
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
    }

    private var totals: some View {
        HStack(spacing: 10) {
            totalCard("Week", activities: weekActivities)
            totalCard("Month", activities: monthActivities)
            totalCard("All time", activities: outdoorStore.profileActivities)
        }
    }

    private func totalCard(_ title: String, activities: [OutdoorActivity]) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title).font(.caption).foregroundStyle(Theme.textSecondary)
            Text("\(activities.count)").font(.title2.bold()).foregroundStyle(.white)
            Text(String(format: "%.1f km", activities.reduce(0) { $0 + $1.distanceMeters } / 1000))
                .font(.caption2).foregroundStyle(Theme.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: 14))
    }

    private var activityList: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Outdoor activity").font(.headline).foregroundStyle(.white)
            ForEach(outdoorStore.profileActivities) { activity in
                Group {
#if os(iOS)
                    if UIDevice.current.userInterfaceIdiom == .phone {
                        Button {
                            selectedActivity = activity
                        } label: {
                            activityRow(activity)
                        }
                        .buttonStyle(.plain)
                    } else {
                        activityRow(activity)
                    }
#else
                    activityRow(activity)
#endif
                }
                .padding(12)
                .background(Theme.surface, in: RoundedRectangle(cornerRadius: 14))
            }
        }
    }

    private func activityRow(_ activity: OutdoorActivity) -> some View {
        HStack(spacing: 12) {
            Image(systemName: activity.kind.iconName)
                .frame(width: 38, height: 38)
                .background(.white.opacity(0.1), in: RoundedRectangle(cornerRadius: 10))
            VStack(alignment: .leading, spacing: 3) {
                Text(activity.title).font(.subheadline.weight(.semibold)).foregroundStyle(.white)
                Text(activity.startedAt, style: .date).font(.caption).foregroundStyle(Theme.textSecondary)
            }
            Spacer()
            Text(String(format: "%.2f km", activity.distanceMeters / 1000))
                .font(.caption.monospacedDigit())
                .foregroundStyle(Theme.textSecondary)
        }
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 10) {
            Image(systemName: "figure.run.circle").font(.system(size: 42)).foregroundStyle(.white)
            Text("No outdoor activities yet").font(.title3.bold()).foregroundStyle(.white)
            Text("Public Run, Walk, and Bike activities appear here after you establish them from the route Library.")
                .font(.subheadline).foregroundStyle(Theme.textSecondary)
        }
        .padding(18)
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: 18))
    }

    private func activities(in interval: DateInterval?) -> [OutdoorActivity] {
        guard let interval else { return [] }
        return outdoorStore.profileActivities.filter { interval.contains($0.startedAt) }
    }
}

