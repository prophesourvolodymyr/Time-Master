#if os(iOS)
import SwiftUI
import CoreLocation

struct OutdoorMapOfflineSettingsView: View {
    @StateObject private var location = OfflineMapLocationProvider()
    @State private var isDownloading = false
    @State private var message: String?

    var body: some View {
        List {
            SwiftUI.Section {
                Text("Download the current map area before a workout so the map can keep rendering when the network is unavailable.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Button {
                    downloadCurrentArea()
                } label: {
                    HStack {
                        Label("Download Current Area", systemImage: "arrow.down.circle")
                        Spacer()
                        if isDownloading {
                            ProgressView()
                        }
                    }
                }
                .disabled(isDownloading || location.coordinate == nil)

                if let message {
                    Text(message)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            SwiftUI.Section {
                Label(
                    location.coordinate == nil ? "Location is needed to choose an area" : "Location ready",
                    systemImage: location.coordinate == nil ? "location.slash" : "location.fill"
                )
                .foregroundStyle(location.coordinate == nil ? Color.secondary : Color.green)
            }
        }
        .navigationTitle("Offline Maps")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            location.requestLocation()
        }
        .onChange(of: location.errorMessage) { errorMessage in
            if let errorMessage {
                message = errorMessage
            }
        }
    }

    private func downloadCurrentArea() {
        guard let coordinate = location.coordinate else { return }
        isDownloading = true
        message = "Download started. Keep this screen open until it finishes."
        OutdoorMapOfflineManager.shared.downloadCurrentArea(center: coordinate) { error in
            DispatchQueue.main.async {
                isDownloading = false
                message = error.map { "Download failed: \($0.localizedDescription)" } ?? "Map area is ready for offline use."
            }
        }
    }
}

private final class OfflineMapLocationProvider: NSObject, ObservableObject, CLLocationManagerDelegate {
    @Published var coordinate: CLLocationCoordinate2D?
    @Published var errorMessage: String?

    private let manager = CLLocationManager()

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
    }

    func requestLocation() {
        guard CLLocationManager.locationServicesEnabled() else {
            errorMessage = "Location Services are disabled."
            return
        }
        switch manager.authorizationStatus {
        case .authorizedAlways, .authorizedWhenInUse:
            manager.requestLocation()
        case .notDetermined:
            manager.requestWhenInUseAuthorization()
        case .denied, .restricted:
            errorMessage = "Allow location access in Settings to download the current area."
        @unknown default:
            errorMessage = "TimeMaster could not determine location access."
        }
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        if manager.authorizationStatus == .authorizedWhenInUse || manager.authorizationStatus == .authorizedAlways {
            manager.requestLocation()
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        coordinate = locations.last?.coordinate
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        errorMessage = error.localizedDescription
    }
}
#endif
