import SwiftUI

struct DeviceSyncPairingSheet: View {
    @ObservedObject private var sync = DeviceSyncCoordinator.shared
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.background.ignoresSafeArea()
                ScrollView {
                    VStack(alignment: .leading, spacing: EverSpacing.x5) {
                        content
                    }
                    .padding(EverSpacing.x5)
                    .frame(maxWidth: EverLayout.maximumReadableWidth, alignment: .leading)
                    .frame(maxWidth: .infinity)
                }
            }
            .timeMasterNavigationTitle("Add a device")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                AppToolbar.item(placement: .cancellationAction) {
                    Button(isDone ? "Done" : "Cancel") { dismiss() }
                        .foregroundColor(.white)
                }
            }
        }
        .onAppear { sync.beginPairing() }
    }

    private var isDone: Bool {
        if case .paired = sync.pairing { return true }
        return false
    }

    @ViewBuilder
    private var content: some View {
        switch sync.pairing {
        case .idle, .waiting:
            waiting
        case .connecting(let name):
            progress("Connecting to \(name)…")
        case .comparing(let name, let platform, let code):
            comparing(name: name, platform: platform, code: code)
        case .waitingForOther(let name):
            progress("Waiting for \(name) to confirm…")
        case .paired(let name):
            paired(name)
        case .failed(let message):
            failed(message)
        }
    }

    private var devicesToPair: [DeviceSyncNearby] { sync.nearby.filter(\.isPairing) }

    private var waiting: some View {
        VStack(alignment: .leading, spacing: EverSpacing.x5) {
            Text("Add a device")
                .font(TimeMasterFont.title())
                .foregroundStyle(EverColor.textPrimary)
            Text("On your other device, open Tmax → Settings → Device Sync and tap Add a device. It shows up here when it is ready.")
                .font(TimeMasterFont.secondary())
                .foregroundStyle(EverColor.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
            if devicesToPair.isEmpty {
                HStack(spacing: EverSpacing.x3) {
                    TmaxLoadingIndicator()
                    Text("Looking on this Wi-Fi…")
                        .font(TimeMasterFont.rowTitle())
                        .foregroundStyle(EverColor.textPrimary)
                }
                .padding(.vertical, EverSpacing.x3)
            } else {
                VStack(alignment: .leading, spacing: EverSpacing.x3) {
                    ForEach(devicesToPair) { device in
                        EverSurfaceCard {
                            SettingsActionRow(title: device.name, detail: device.platform.label, symbol: device.platform.symbol) {
                                Button("Pair") { sync.pair(with: device) }
                                    .buttonStyle(EverActionButtonStyle(isPrimary: true))
                                    .accessibilityLabel("Pair with \(device.name)")
                                    .accessibilityIdentifier("device-sync-pair-\(device.id)")
                            }
                        }
                    }
                }
            }
            if let problem = sync.problem {
                Text(problem)
                    .font(TimeMasterFont.secondary())
                    .foregroundStyle(EverColor.warning)
            }
        }
    }

    private func progress(_ text: String) -> some View {
        HStack(spacing: EverSpacing.x3) {
            TmaxLoadingIndicator()
            Text(text)
                .font(TimeMasterFont.rowTitle())
                .foregroundStyle(EverColor.textPrimary)
        }
        .padding(.vertical, EverSpacing.x4)
    }

    private func comparing(name: String, platform: DeviceSyncPlatform, code: String) -> some View {
        VStack(alignment: .leading, spacing: EverSpacing.x5) {
            Label(name, systemImage: platform.symbol)
                .font(TimeMasterFont.rowTitle())
                .foregroundStyle(EverColor.textPrimary)
            Text("Does \(name) show the same six digits?")
                .font(TimeMasterFont.title())
                .foregroundStyle(EverColor.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
            Text(code)
                .font(TimeMasterFont.black(44, relativeTo: .largeTitle))
                .monospacedDigit()
                .foregroundStyle(EverColor.accent)
                .tracking(2)
                .frame(maxWidth: .infinity)
                .padding(.vertical, EverSpacing.x5)
                .background { EverSurfaceMaterial() }
                .accessibilityLabel("Code \(code.replacingOccurrences(of: " ", with: ", "))")
                .accessibilityIdentifier("device-sync-code")
            Text("If they match, you are talking to your own device and nobody else.")
                .font(TimeMasterFont.secondary())
                .foregroundStyle(EverColor.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
            VStack(spacing: EverSpacing.x3) {
                Button {
                    sync.confirmPairing(matches: true)
                } label: {
                    Text("Yes, they match")
                }
                .buttonStyle(EverPrimaryButtonStyle())
                .accessibilityIdentifier("device-sync-match")
                Button {
                    sync.confirmPairing(matches: false)
                } label: {
                    Text("No, they are different")
                }
                .buttonStyle(EverSecondaryButtonStyle())
                .accessibilityIdentifier("device-sync-mismatch")
            }
        }
    }

    private func paired(_ name: String) -> some View {
        VStack(alignment: .leading, spacing: EverSpacing.x4) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 44))
                .foregroundStyle(EverColor.accent)
                .accessibilityHidden(true)
            Text("Paired with \(name)")
                .font(TimeMasterFont.title())
                .foregroundStyle(EverColor.textPrimary)
            Text("Syncing starts now. From here on, a change on either device shows up on the other while both are on this Wi-Fi.")
                .font(TimeMasterFont.secondary())
                .foregroundStyle(EverColor.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
            Button {
                dismiss()
            } label: {
                Text("Done")
            }
            .buttonStyle(EverPrimaryButtonStyle())
        }
    }

    private func failed(_ message: String) -> some View {
        VStack(alignment: .leading, spacing: EverSpacing.x4) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 36))
                .foregroundStyle(EverColor.warning)
                .accessibilityHidden(true)
            Text("That did not pair")
                .font(TimeMasterFont.title())
                .foregroundStyle(EverColor.textPrimary)
            Text(message)
                .font(TimeMasterFont.secondary())
                .foregroundStyle(EverColor.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
            Button {
                sync.retryPairing()
            } label: {
                Text("Try again")
            }
            .buttonStyle(EverPrimaryButtonStyle())
        }
    }
}
