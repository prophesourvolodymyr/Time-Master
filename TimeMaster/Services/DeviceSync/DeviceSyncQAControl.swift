#if DEBUG && os(macOS)
import AppKit
import SwiftUI

@MainActor
final class DeviceSyncQAControl {
    static let shared = DeviceSyncQAControl()

    private var timer: Timer?
    private var directory: URL?
    private var lastStatus = Date.distantPast

    func startIfRequested() {
        guard timer == nil, let path = ProcessInfo.processInfo.environment["TIMEMASTER_QA_DIR"], !path.isEmpty else { return }
        let directory = URL(fileURLWithPath: path, isDirectory: true)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        self.directory = directory
        timer = Timer.scheduledTimer(withTimeInterval: 0.2, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.tick() }
        }
    }

    private func tick() {
        guard let directory else { return }
        let sync = DeviceSyncCoordinator.shared
        if let names = try? FileManager.default.contentsOfDirectory(atPath: directory.path),
           let next = names.filter({ $0.hasPrefix("command-") && $0.hasSuffix(".json") }).sorted().first {
            let url = directory.appendingPathComponent(next)
            let data = try? Data(contentsOf: url)
            try? FileManager.default.removeItem(at: url)
            if let data, let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                let result = run(object, sync: sync)
                let id = next.dropFirst("command-".count).dropLast(".json".count)
                if let out = try? JSONSerialization.data(withJSONObject: result, options: [.sortedKeys]) {
                    try? out.write(to: directory.appendingPathComponent("result-\(id).json"))
                }
            }
        }
        if Date().timeIntervalSince(lastStatus) > 0.25 {
            lastStatus = Date()
            writeStatus(sync, to: directory.appendingPathComponent("status.json"))
        }
    }

    private func run(_ command: [String: Any], sync: DeviceSyncCoordinator) -> [String: Any] {
        let name = command["cmd"] as? String ?? ""
        let argument = command["arg"] as? String ?? ""
        switch name {
        case "begin-pairing":
            sync.beginPairing()
        case "end-pairing":
            sync.endPairing()
        case "pair":
            guard let device = sync.nearby.first(where: { $0.isPairing && $0.name.localizedCaseInsensitiveContains(argument) }) else {
                return ["ok": false, "error": "no device named \(argument) is open for pairing"]
            }
            sync.pair(with: device)
        case "confirm":
            sync.confirmPairing(matches: argument != "no")
        case "sync-now":
            for device in sync.devices { sync.syncNow(device.id) }
        case "remove":
            for device in sync.devices { sync.remove(device.id) }
        case "enable":
            sync.isEnabled = argument != "off"
        case "open-settings":
            NotificationCenter.default.post(name: .openSettingsCommand, object: nil)
        case "open-pairing-sheet":
            NotificationCenter.default.post(name: .qaOpenDeviceSyncPairing, object: nil)
        case "snapshot":
            return snapshot(to: argument)
        default:
            return ["ok": false, "error": "unknown command \(name)"]
        }
        return ["ok": true]
    }

    private func snapshot(to path: String) -> [String: Any] {
        let candidates = NSApp.windows.filter { $0.isVisible && $0.contentView != nil && $0.frame.width > 300 }
        guard let window = candidates.first(where: { $0.isSheet }) ?? candidates.first,
              let view = window.contentView,
              let representation = view.bitmapImageRepForCachingDisplay(in: view.bounds) else {
            return ["ok": false, "error": "no window to capture"]
        }
        view.cacheDisplay(in: view.bounds, to: representation)
        guard let data = representation.representation(using: .png, properties: [:]) else { return ["ok": false, "error": "could not encode"] }
        do {
            try data.write(to: URL(fileURLWithPath: path))
            return ["ok": true, "bytes": data.count]
        } catch {
            return ["ok": false, "error": error.localizedDescription]
        }
    }

    private func writeStatus(_ sync: DeviceSyncCoordinator, to url: URL) {
        var pairing: [String: Any]
        switch sync.pairing {
        case .idle: pairing = ["state": "idle"]
        case .waiting: pairing = ["state": "waiting"]
        case .connecting(let name): pairing = ["state": "connecting", "name": name]
        case .comparing(let name, _, let code): pairing = ["state": "comparing", "name": name, "code": code]
        case .waitingForOther(let name): pairing = ["state": "waitingForOther", "name": name]
        case .paired(let name): pairing = ["state": "paired", "name": name]
        case .failed(let message): pairing = ["state": "failed", "message": message]
        }
        let devices: [[String: Any]] = sync.devices.map { device in
            let status: String
            switch device.status {
            case .notNearby: status = "notNearby"
            case .connecting: status = "connecting"
            case .connected: status = "connected"
            case .syncing(let text): status = "syncing: \(text)"
            case .upToDate: status = "upToDate"
            case .problem(let text): status = "problem: \(text)"
            }
            return ["id": device.id, "name": device.name, "status": status]
        }
        let object: [String: Any] = [
            "deviceName": sync.deviceName,
            "enabled": sync.isEnabled,
            "pairing": pairing,
            "devices": devices,
            "nearby": sync.nearby.map { ["id": $0.id, "name": $0.name, "pairing": $0.isPairing] },
            "notice": sync.notice ?? "",
            "problem": sync.problem ?? "",
            "pid": ProcessInfo.processInfo.processIdentifier,
        ]
        if let data = try? JSONSerialization.data(withJSONObject: object, options: [.sortedKeys]) { try? data.write(to: url) }
    }
}

extension Notification.Name {
    static let qaOpenDeviceSyncPairing = Notification.Name("TimeMaster.qaOpenDeviceSyncPairing")
}
#endif
