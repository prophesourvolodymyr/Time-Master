import Foundation
import Network

/// Listens on UDP port 8889 for the companion server's broadcast beacon.
/// When the beacon `TIMEMASTER:<ip>:<port>` is received, it automatically
/// updates ServerSettings.shared — no manual IP entry required.
final class ServerDiscovery: ObservableObject {

    static let shared = ServerDiscovery()

    @Published var isSearching = false
    @Published var lastDetectedHost: String? = nil

    private let discoveryPort: NWEndpoint.Port = 8889
    private var listener: NWListener?
    private let queue = DispatchQueue(label: "com.timemaster.discovery", qos: .utility)

    private init() {}

    // MARK: - Public

    func start() {
        guard listener == nil else { return }
        isSearching = true

        let params = NWParameters.udp
        params.allowLocalEndpointReuse = true

        guard let listener = try? NWListener(using: params, on: discoveryPort) else {
            isSearching = false
            return
        }
        self.listener = listener

        listener.newConnectionHandler = { [weak self] connection in
            self?.receive(on: connection)
        }

        listener.stateUpdateHandler = { [weak self] state in
            if case .failed = state {
                self?.stop()
            }
        }

        listener.start(queue: queue)
    }

    func stop() {
        listener?.cancel()
        listener = nil
        DispatchQueue.main.async { self.isSearching = false }
    }

    // MARK: - Private

    private func receive(on connection: NWConnection) {
        connection.start(queue: queue)
        connection.receiveMessage { [weak self] data, _, _, _ in
            guard let data, let message = String(data: data, encoding: .utf8) else { return }
            self?.handle(message: message)
            // Keep receiving on next connection (UDP: each datagram = new connection)
        }
    }

    private func handle(message: String) {
        // Expected format: TIMEMASTER:<ip>:<port>
        let parts = message.trimmingCharacters(in: .whitespacesAndNewlines).split(separator: ":")
        guard parts.count == 3,
              parts[0] == "TIMEMASTER",
              let port = Int(parts[2]) else { return }

        let host = String(parts[1])

        DispatchQueue.main.async {
            self.lastDetectedHost = host
            let settings = ServerSettings.shared
            settings.host = host
            settings.port = port
            self.stop() // found — no need to keep listening
        }
    }
}
