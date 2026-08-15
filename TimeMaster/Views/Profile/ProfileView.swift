import SwiftUI

struct ProfileView: View {
    @EnvironmentObject private var outdoorStore: OutdoorActivityStore
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
                    if outdoorStore.activities.filter(\.finished).isEmpty {
                        emptyState
                    } else {
                        activityList
                    }
                }
                .padding(16)
            }
            .background(Theme.background.ignoresSafeArea())
            .navigationTitle("Profile")
            .sheet(item: $selectedActivity) { activity in
                OutdoorActivityDetailView(store: outdoorStore, activity: activity)
            }
        }
    }

    private var totals: some View {
        HStack(spacing: 10) {
            totalCard("Week", activities: weekActivities)
            totalCard("Month", activities: monthActivities)
            totalCard("All time", activities: outdoorStore.activities.filter(\.finished))
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
            ForEach(outdoorStore.activities.filter(\.finished)) { activity in
                Button { selectedActivity = activity } label: {
                    HStack(spacing: 12) {
                        Image(systemName: activity.kind.iconName)
                            .frame(width: 38, height: 38)
                            .background(.white.opacity(0.1), in: RoundedRectangle(cornerRadius: 10))
                        VStack(alignment: .leading, spacing: 3) {
                            Text(activity.title).font(.subheadline.weight(.semibold)).foregroundStyle(.white)
                            Text(activity.startedAt, style: .date).font(.caption).foregroundStyle(Theme.textSecondary)
                        }
                        Spacer()
                        Text(String(format: "%.2f km", activity.distanceMeters / 1000)).font(.caption.monospacedDigit()).foregroundStyle(Theme.textSecondary)
                    }
                }
                .buttonStyle(.plain)
                .padding(12)
                .background(Theme.surface, in: RoundedRectangle(cornerRadius: 14))
            }
        }
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 10) {
            Image(systemName: "figure.run.circle").font(.system(size: 42)).foregroundStyle(.white)
            Text("No outdoor activities yet").font(.title3.bold()).foregroundStyle(.white)
            Text("Record Run & Walk or Bike activities on iPhone. Saved activities appear here when available on this device.")
                .font(.subheadline).foregroundStyle(Theme.textSecondary)
        }
        .padding(18)
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: 18))
    }

    private func activities(in interval: DateInterval?) -> [OutdoorActivity] {
        guard let interval else { return [] }
        return outdoorStore.activities.filter { $0.finished && interval.contains($0.startedAt) }
    }
}

struct OutdoorActivityDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var store: OutdoorActivityStore
    let activity: OutdoorActivity
    @State private var shareURL: URL?
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    #if os(iOS)
                    OutdoorMapLibreView(points: store.trackPoints(for: activity), followsUser: false, state: .finished, plannedPoints: nil)
                        .frame(height: 260)
                        .clipShape(RoundedRectangle(cornerRadius: 18))
                    #endif
                    Text(activity.title).font(.title2.bold())
                    Text(activity.kind.displayName).foregroundStyle(.secondary)
                    detailGrid
                    #if os(iOS)
                    HStack {
                        Button("GPX") { exportGPX() }.buttonStyle(.bordered)
                        Button("CSV") { exportCSV() }.buttonStyle(.bordered)
                    }
                    #endif
                }
                .padding()
            }
            .navigationTitle("Activity")
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
            #if os(iOS)
            .sheet(
                isPresented: Binding(
                    get: { shareURL != nil },
                    set: { if !$0 { shareURL = nil } }
                )
            ) {
                if let shareURL {
                    ShareSheet(activityItems: [shareURL])
                }
            }
            #endif
            .alert("Export failed", isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) {
                Button("OK", role: .cancel) { errorMessage = nil }
            } message: { Text(errorMessage ?? "") }
        }
    }

    private var detailGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 14) {
            detailMetric("Distance", String(format: "%.2f km", activity.distanceMeters / 1000))
            detailMetric("Moving", format(activity.movingSeconds))
            detailMetric("Elapsed", format(activity.elapsedSeconds))
            detailMetric("Avg speed", activity.averageSpeedMetersPerSecond.map { String(format: "%.1f km/h", $0 * 3.6) } ?? "—")
        }
    }

    private func detailMetric(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading) { Text(value).font(.headline.monospacedDigit()); Text(label).font(.caption).foregroundStyle(.secondary) }
            .frame(maxWidth: .infinity, alignment: .leading).padding().background(Theme.surface, in: RoundedRectangle(cornerRadius: 12))
    }

    #if os(iOS)
    private func exportGPX() { do { shareURL = try OutdoorExportService.gpxURL(for: activity, points: store.trackPoints(for: activity)) } catch { errorMessage = error.localizedDescription } }
    private func exportCSV() { do { shareURL = try OutdoorExportService.csvURL(for: activity, points: store.trackPoints(for: activity)) } catch { errorMessage = error.localizedDescription } }
    #endif

    private func format(_ seconds: Int) -> String { String(format: "%02d:%02d:%02d", seconds / 3600, (seconds % 3600) / 60, seconds % 60) }
}
