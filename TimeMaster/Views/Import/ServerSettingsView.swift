import SwiftUI

struct ServerSettingsView: View {
    @ObservedObject var settings: ServerSettings
    @ObservedObject private var discovery = ServerDiscovery.shared
    @Environment(\.dismiss) private var dismiss

    @State private var portString: String = ""
    @State private var connectionStatus: ConnectionStatus = .idle

    enum ConnectionStatus: Equatable {
        case idle, checking, ok, failed
        var label: String {
            switch self {
            case .idle:     return ""
            case .checking: return "Checking…"
            case .ok:       return "Connected"
            case .failed:   return "Not reachable"
            }
        }
        var color: Color {
            switch self {
            case .ok:     return .green
            case .failed: return .red
            default:      return Theme.textSecondary
            }
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.background.ignoresSafeArea()
                ScrollView {
                    VStack(spacing: 16) {
                        autoDetectCard
                        connectionCard
                        instructionsCard
                    }
                    .padding(16)
                }
            }
            .timeMasterNavigationTitle("Server Settings")
            #if os(iOS)
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            #endif
            .toolbar {
                AppToolbar.item(placement: .confirmationAction) { Button("Done") { applyPort(); dismiss() }
                    .foregroundColor(.white)
                                 }
            }
            .onAppear {
                portString = "\(settings.port)"
                ServerDiscovery.shared.start()
            }
            .onDisappear {
                ServerDiscovery.shared.stop()
            }
            .onChange(of: discovery.lastDetectedHost) { host in
                guard host != nil else { return }
                portString = "\(settings.port)"
                testConnection()
            }
        }
    }

    // MARK: - Auto-detect card

    private var autoDetectCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: "antenna.radiowaves.left.and.right")
                    .foregroundColor(.white)
                Text("Auto-Detect Server")
                    .font(TimeMasterFont.sectionTitle()).foregroundColor(Theme.textPrimary)
                Spacer()
            }

            if discovery.isSearching {
                HStack(spacing: 10) {
                    TmaxLoadingIndicator(size: 18)
                    Text("Scanning local network…")
                        .font(TimeMasterFont.body(15, relativeTo: .subheadline)).foregroundColor(Theme.textSecondary)
                }
            } else if let host = discovery.lastDetectedHost {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill").foregroundColor(.green)
                    Text("Found at \(host)")
                        .font(TimeMasterFont.body(15, relativeTo: .subheadline)).foregroundColor(.green)
                    Spacer()
                    Button("Scan again") {
                        discovery.lastDetectedHost = nil
                        ServerDiscovery.shared.start()
                    }
                    .font(TimeMasterFont.caption()).foregroundColor(Theme.textSecondary)
                }
            } else {
                HStack(spacing: 8) {
                    Image(systemName: "xmark.circle").foregroundColor(Theme.textSecondary)
                    Text("No server found — make sure server.py is running")
                        .font(TimeMasterFont.body(15, relativeTo: .subheadline)).foregroundColor(Theme.textSecondary)
                    Spacer()
                    Button("Retry") { ServerDiscovery.shared.start() }
                        .font(TimeMasterFont.caption()).foregroundColor(.white)
                }
            }
        }
        .padding(16)
        .background(Theme.surface)
        .cornerRadius(14)
    }

    // MARK: - Manual connection card

    private var connectionCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Manual Override")
                .font(TimeMasterFont.sectionTitle()).foregroundColor(Theme.textPrimary)

            VStack(spacing: 8) {
                HStack {
                    Text("Host").foregroundColor(Theme.textPrimary)
                    Spacer()
                    TextField("192.168.x.x", text: $settings.host)
                        .multilineTextAlignment(.trailing)
                        .foregroundColor(Theme.textPrimary)
                        .frame(maxWidth: 180)
                        #if os(iOS)
                        .autocapitalization(.none)
                        #endif
                        .autocorrectionDisabled()
                }
                .padding(14).background(Theme.surface2).cornerRadius(10)

                HStack {
                    Text("Port").foregroundColor(Theme.textPrimary)
                    Spacer()
                    TextField("8888", text: $portString)
                        .multilineTextAlignment(.trailing)
                        .foregroundColor(Theme.textPrimary)
                        .frame(maxWidth: 80)
                        #if os(iOS)
                        .keyboardType(.numberPad)
                        #endif
                }
                .padding(14).background(Theme.surface2).cornerRadius(10)
            }

            HStack(spacing: 12) {
                Button { testConnection() } label: {
                    Text("Test Connection")
                        .font(TimeMasterFont.rowTitle())
                        .foregroundColor(Theme.textPrimary)
                        .padding(.horizontal, 16).padding(.vertical, 10)
                        .background(Theme.surface2).cornerRadius(8)
                }

                if connectionStatus != .idle {
                    HStack(spacing: 6) {
                        if connectionStatus == .checking {
                            TmaxLoadingIndicator(size: 16)
                        }
                        Text(connectionStatus.label)
                            .font(TimeMasterFont.body(15, relativeTo: .subheadline))
                            .foregroundColor(connectionStatus.color)
                    }
                }
                Spacer()
            }
        }
        .padding(16)
        .background(Theme.surface)
        .cornerRadius(14)
    }

    // MARK: - Instructions card

    private var instructionsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Setup Instructions")
                .font(TimeMasterFont.sectionTitle()).foregroundColor(Theme.textPrimary)

            VStack(alignment: .leading, spacing: 10) {
                instructionRow("1", "Install yt-dlp:  pip3 install yt-dlp")
                instructionRow("2", "From the project root:  python3 server.py")
                instructionRow("3", "Open this screen — server is detected automatically")
                instructionRow("4", "Both Mac and iPhone must be on the same Wi-Fi")
            }
        }
        .padding(16)
        .background(Theme.surface)
        .cornerRadius(14)
    }

    private func instructionRow(_ step: String, _ text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Text(step)
                .font(TimeMasterFont.black(12, relativeTo: .caption))
                .foregroundColor(Theme.textSecondary)
                .frame(width: 16)
            Text(text)
                .font(TimeMasterFont.caption())
                .foregroundColor(Theme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
            Spacer()
        }
    }

    // MARK: - Actions

    private func testConnection() {
        applyPort()
        connectionStatus = .checking
        Task {
            let ok = await VideoDownloadService.healthCheck(settings: settings)
            connectionStatus = ok ? .ok : .failed
        }
    }

    private func applyPort() {
        if let p = Int(portString), p > 0 { settings.port = p }
    }
}
