import SwiftUI

struct DeviceSyncSettingsView: View {
    @ObservedObject private var sync = DeviceSyncCoordinator.shared
    @State private var showsPairing = false
    @State private var removing: DeviceSyncCoordinator.Device?

    private var footer: String {
        #if os(iOS)
        return "Syncs whenever Tmax is open on the same Wi-Fi as your other device. Everything stays between your devices, encrypted, and never goes through the internet or the cloud."
        #else
        return "Keep Tmax open on your Mac and your iPhone catches up whenever it is open on the same Wi-Fi. Everything stays between your devices, encrypted, and never goes through the internet or the cloud."
        #endif
    }

    var body: some View {
        EverSettingsPage(title: "Device Sync") {
            EverSettingsSection(title: "This device", detail: footer) {
                SettingsActionRow(title: sync.deviceName, detail: sync.platform.label, symbol: sync.platform.symbol)
                Toggle("Keep my devices in sync", isOn: $sync.isEnabled)
                    .font(TimeMasterFont.rowTitle())
                    .accessibilityIdentifier("device-sync-enabled")
                Text("Pages, media, workouts, history, schedule and routes follow you from one device to the other within a second or two.")
                    .font(TimeMasterFont.caption())
                    .foregroundStyle(EverColor.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if sync.isEnabled {
                EverSettingsSection(
                    title: "Paired devices",
                    detail: sync.devices.isEmpty ? "Pair your iPhone and Mac once and they keep each other up to date." : nil
                ) {
                    if sync.devices.isEmpty {
                        Text("No devices paired yet.")
                            .font(TimeMasterFont.secondary())
                            .foregroundStyle(EverColor.textSecondary)
                    }
                    ForEach(sync.devices) { device in
                        deviceRow(device)
                    }
                    Button {
                        showsPairing = true
                    } label: {
                        Label("Add a device", systemImage: "plus.circle")
                    }
                    .buttonStyle(EverPrimaryButtonStyle())
                    .accessibilityIdentifier("device-sync-add")
                }

                if let notice = sync.notice {
                    Label(notice, systemImage: "arrow.triangle.merge")
                        .font(TimeMasterFont.caption())
                        .foregroundStyle(EverColor.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityIdentifier("device-sync-notice")
                }
                if let problem = sync.problem {
                    Label(problem, systemImage: "exclamationmark.triangle")
                        .font(TimeMasterFont.caption())
                        .foregroundStyle(EverColor.warning)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            EverSettingsSection(
                title: "Cloud sync",
                detail: "Device Sync is separate from cloud sync of the exercise database. They can both be on: a change one brings in counts as an ordinary edit for the other."
            ) {
                NavigationLink { DatabaseSyncSettingsView() } label: {
                    SettingsActionRow(title: "Database Sync", symbol: "arrow.triangle.2.circlepath.icloud") {
                        Image(systemName: "chevron.right").foregroundStyle(EverColor.textTertiary)
                    }
                }
                .buttonStyle(.plain)
            }
        }
        .tint(Theme.toolbarOrange)
        .accessibilityIdentifier("device-sync-settings")
        #if DEBUG && os(macOS)
        .onReceive(NotificationCenter.default.publisher(for: .qaOpenDeviceSyncPairing)) { _ in showsPairing = true }
        #endif
        .sheet(isPresented: $showsPairing, onDismiss: { sync.endPairing() }) {
            DeviceSyncPairingSheet()
                #if os(macOS)
                .frame(
                    minWidth: EverLayout.popupMaximumWidth,
                    idealWidth: EverLayout.popupMaximumWidth,
                    minHeight: EverLayout.standardRowMinimum * 8,
                    idealHeight: EverLayout.standardRowMinimum * 9
                )
                #endif
                .everSheetBackground()
                .keyNavHost()
        }
        .confirmationDialog(
            "Stop syncing with \(removing?.name ?? "this device")?",
            isPresented: Binding(get: { removing != nil }, set: { if !$0 { removing = nil } }),
            titleVisibility: .visible,
            presenting: removing
        ) { device in
            Button("Remove", role: .destructive) { sync.remove(device.id) }
            Button("Keep it", role: .cancel) {}
        } message: { device in
            Text("Nothing is deleted on either device. To sync again, pair \(device.name) once more.")
        }
    }

    private func deviceRow(_ device: DeviceSyncCoordinator.Device) -> some View {
        VStack(alignment: .leading, spacing: EverSpacing.x3) {
            SettingsActionRow(title: device.name, detail: detail(of: device), symbol: device.platform.symbol)
            HStack(spacing: EverSpacing.x3) {
                Button {
                    sync.syncNow(device.id)
                } label: {
                    Label("Sync now", systemImage: "arrow.triangle.2.circlepath")
                }
                .buttonStyle(EverActionButtonStyle(isPrimary: true))
                .disabled(!canSyncNow(device))
                .accessibilityIdentifier("device-sync-now-\(device.id)")
                Button(role: .destructive) {
                    removing = device
                } label: {
                    Label("Remove", systemImage: "trash")
                }
                .buttonStyle(EverActionButtonStyle())
                .accessibilityIdentifier("device-sync-remove-\(device.id)")
                Spacer(minLength: 0)
            }
        }
        .padding(.vertical, EverSpacing.x1)
    }

    private func canSyncNow(_ device: DeviceSyncCoordinator.Device) -> Bool {
        switch device.status {
        case .syncing: return false
        default: return true
        }
    }

    private func detail(of device: DeviceSyncCoordinator.Device) -> String {
        switch device.status {
        case .notNearby:
            guard let last = device.lastSynced else { return "Not on this network" }
            return "Not on this network · synced \(last.formatted(.relative(presentation: .named)))"
        case .connecting:
            return "Connecting…"
        case .connected:
            return "Connected"
        case .syncing(let text):
            return text
        case .upToDate:
            return "Up to date"
        case .problem(let text):
            return text
        }
    }
}
