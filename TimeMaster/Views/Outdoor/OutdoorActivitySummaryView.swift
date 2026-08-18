#if os(iOS)
import SwiftUI

struct OutdoorActivitySummaryView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var store: OutdoorActivityStore
    let activity: OutdoorActivity
    var onDone: (() -> Void)?
    @State private var title: String
    @State private var shareURL: URL?
    @State private var errorMessage: String?
    @State private var showingDeleteConfirmation = false

    init(activity: OutdoorActivity, store: OutdoorActivityStore, onDone: (() -> Void)? = nil) {
        self.activity = activity
        self.store = store
        self.onDone = onDone
        _title = State(initialValue: activity.title)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    OutdoorMapLibreView(
                        points: store.trackPoints(for: activity),
                        followsUser: false,
                        state: .finished,
                        plannedPoints: activity.plannedRouteID.flatMap { store.plannedRoute(withID: $0)?.points }
                    )
                        .frame(height: 260)
                        .clipShape(RoundedRectangle(cornerRadius: 18))
                    TextField("Activity title", text: $title)
                        .textFieldStyle(.roundedBorder)
                        .onSubmit { saveTitle() }
                    metrics
                    if !activity.laps.isEmpty { laps }
                    HStack {
                        Button("Export GPX") { exportGPX() }.buttonStyle(.bordered)
                        Button("Export CSV") { exportCSV() }.buttonStyle(.bordered)
                    }
                    Button("Delete Activity", role: .destructive) { showingDeleteConfirmation = true }
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding()
            }
            .navigationTitle("Activity Summary")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { saveTitle(); onDone?(); dismiss() }
                }
            }
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
            .alert("Export failed", isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) {
                Button("OK", role: .cancel) { errorMessage = nil }
            } message: { Text(errorMessage ?? "") }
            .confirmationDialog("Delete this activity?", isPresented: $showingDeleteConfirmation, titleVisibility: .visible) {
                Button("Delete", role: .destructive) {
                    try? store.delete(activity)
                    dismiss()
                }
                Button("Cancel", role: .cancel) {}
            }
        }
    }

    private var metrics: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 14) {
            summaryMetric("Distance", value: String(format: "%.2f km", activity.distanceMeters / 1000))
            summaryMetric("Elapsed", value: format(activity.elapsedSeconds))
            summaryMetric("Moving", value: format(activity.movingSeconds))
            summaryMetric("Avg speed", value: activity.averageSpeedMetersPerSecond.map { String(format: "%.1f km/h", $0 * 3.6) } ?? "—")
            summaryMetric("Pauses", value: "\(activity.pauseIntervals.count)")
            summaryMetric("Target", value: activity.timeTargetSeconds.map(format) ?? "—")
        }
    }

    private var laps: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Laps").font(.headline)
            ForEach(activity.laps) { lap in
                HStack { Text("Lap \(lap.number)"); Spacer(); Text(String(format: "%.0f m", lap.distanceMeters)); Text(format(lap.elapsedSeconds)).foregroundStyle(.secondary) }
            }
        }
    }

    private func summaryMetric(_ label: String, value: String) -> some View {
        VStack(alignment: .leading) { Text(value).font(.headline.monospacedDigit()); Text(label).font(.caption).foregroundStyle(.secondary) }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
            .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12))
    }

    private func saveTitle() {
        try? store.updateTitle(title, for: activity)
    }

    private func exportGPX() {
        do { shareURL = try OutdoorExportService.gpxURL(for: activity, points: store.trackPoints(for: activity)) }
        catch { errorMessage = error.localizedDescription }
    }

    private func exportCSV() {
        do { shareURL = try OutdoorExportService.csvURL(for: activity, points: store.trackPoints(for: activity)) }
        catch { errorMessage = error.localizedDescription }
    }

    private func format(_ seconds: Int) -> String { String(format: "%02d:%02d:%02d", seconds / 3600, (seconds % 3600) / 60, seconds % 60) }
}
#endif
