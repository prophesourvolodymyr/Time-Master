#if os(iOS)
import SwiftUI

struct OutdoorRecorderView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var store: OutdoorActivityStore
    @StateObject private var recorder: OutdoorLocationRecorder
    @State private var timeTargetSeconds: Int?
    @State private var showingFinishChoices = false
    @State private var finishedActivity: OutdoorActivity?
    @State private var showError = false

    init(kind: OutdoorActivityKind, store: OutdoorActivityStore, plannedRoute: PlannedRoute? = nil) {
        _store = ObservedObject(wrappedValue: store)
        _recorder = StateObject(wrappedValue: OutdoorLocationRecorder(kind: kind, store: store, plannedRoute: plannedRoute))
    }

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                OutdoorMapLibreView(points: recorder.route, followsUser: followsUser, state: recorder.state, plannedPoints: recorder.plannedPoints)
                    .ignoresSafeArea()
                VStack(spacing: 12) {
                    statsPanel
                    controls
                }
                .padding()
            }
            .navigationTitle(recorder.activeActivity?.title ?? "Outdoor Activity")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") {
                        let isRecording = recorder.state == .recording
                            || recorder.state == .manualPaused
                            || recorder.state == .autoPaused
                        if isRecording { return }
                        dismiss()
                    }
                }
            }
            .sheet(item: $finishedActivity) { activity in
                OutdoorActivitySummaryView(activity: activity, store: store) { dismiss() }
            }
            .alert("Location Recording", isPresented: $showError) {
                Button("OK", role: .cancel) { recorder.clearError() }
            } message: {
                Text(recorder.errorMessage ?? "Unable to record this activity.")
            }
            .onChange(of: recorder.errorMessage) { value in showError = value != nil }
        }
    }
    private var statsPanel: some View {
        VStack(spacing: 10) {
            HStack {
                Label(recorder.gpsUnavailable ? "GPS unavailable" : stateLabel, systemImage: recorder.gpsUnavailable ? "location.slash" : "location.fill")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(recorder.gpsUnavailable ? .orange : .primary)
                Spacer()
                if recorder.state == .idle {
                    Menu {
                        Button("No target") { timeTargetSeconds = nil }
                        ForEach([900, 1800, 3600], id: \.self) { seconds in
                            Button("\(seconds / 60) minutes") { timeTargetSeconds = seconds }
                        }
                    } label: {
                        Label(timeTargetSeconds.map { "Target \($0 / 60)m" } ?? "Optional target", systemImage: "timer")
                    }
                }
            }
            HStack(spacing: 24) {
                metric(value: formattedTime, label: "Time")
                metric(value: formattedDistance, label: "Distance")
                metric(value: formattedSpeed, label: "Speed")
            }
            if !recorder.plannedPoints.isEmpty {
                HStack {
                    Image(systemName: recorder.snappedPosition == nil ? "location.slash" : "point.topleft.down.curvedto.point.bottomright.up")
                    Text(routeStatus)
                    Spacer()
                }
                .font(.caption.weight(.semibold))
                .foregroundStyle(recorder.snappedPosition == nil ? .orange : .green)
            }
        }
        .padding()
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 18))
    }

    private var controls: some View {
        Group {
            if recorder.state == .idle {
                Button {
                    recorder.start(timeTargetSeconds: timeTargetSeconds)
                } label: {
                    Label("Start", systemImage: "play.fill")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
            } else if recorder.state == .recording || recorder.state == .manualPaused || recorder.state == .autoPaused {
                HStack {
                    Button {
                        recorder.state == .recording ? recorder.pauseManually() : recorder.resumeManually()
                    } label: {
                        Label(recorder.state == .recording ? "Pause" : "Resume", systemImage: recorder.state == .recording ? "pause.fill" : "play.fill")
                    }
                    .buttonStyle(.bordered)
                    Button { recorder.lap() } label: { Label("Lap", systemImage: "flag.fill") }
                        .buttonStyle(.bordered)
                    Button(role: .destructive) { showingFinishChoices = true } label: { Label("Finish", systemImage: "stop.fill") }
                        .buttonStyle(.borderedProminent)
                }
                if showingFinishChoices {
                    HStack {
                        Button("Save") {
                            showingFinishChoices = false
                            finishedActivity = recorder.finish()
                        }
                        .buttonStyle(.borderedProminent)
                        Button("Discard", role: .destructive) {
                            showingFinishChoices = false
                            recorder.cancel()
                            dismiss()
                        }
                        .buttonStyle(.bordered)
                    }
                }
            }
        }
    }

    private var followsUser: Bool {
        recorder.state == .recording
    }

    private var routeStatus: String {
        guard let snap = recorder.snappedPosition else {
            return recorder.route.isEmpty ? "Route loaded" : "Off route"
        }
        return "On route \(Int((snap.progress * 100).rounded()))%"
    }

    private var stateLabel: String {
        switch recorder.state {
        case .idle: "Ready"
        case .requestingAuthorization: "Requesting location…"
        case .recording: "Recording"
        case .manualPaused: "Paused"
        case .autoPaused: "Auto-paused"
        case .finished: "Finished"
        case .failed: "Needs attention"
        }
    }

    private var formattedTime: String { format(seconds: store.active?.elapsedSeconds ?? 0) }
    private var formattedDistance: String {
        let meters = store.active?.distanceMeters ?? 0
        return meters >= 1000 ? String(format: "%.2f km", meters / 1000) : String(format: "%.0f m", meters)
    }
    private var formattedSpeed: String {
        guard let speed = store.active?.averageSpeedMetersPerSecond else { return "—" }
        return String(format: "%.1f km/h", speed * 3.6)
    }

    private func metric(value: String, label: String) -> some View {
        VStack(spacing: 2) { Text(value).font(.headline.monospacedDigit()); Text(label).font(.caption).foregroundStyle(.secondary) }
            .frame(maxWidth: .infinity)
    }

    private func format(seconds: Int) -> String {
        String(format: "%02d:%02d:%02d", seconds / 3600, (seconds % 3600) / 60, seconds % 60)
    }
}

#endif
