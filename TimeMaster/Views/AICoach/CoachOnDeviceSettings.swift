import SwiftUI
import TimeMasterCore

struct CoachOnDeviceSettingsContent: View {
    let showsSwitch: Bool

    @ObservedObject private var store = AIStore.shared
    @State private var availability = OnDeviceSupport.availability()

    private var status: String {
        switch availability {
        case .unavailable(let reason):
            return reason
        case .ready:
            if store.usesOwnKey { return "The on-device helper is ready, but the coach uses your own key." }
            if store.hasKey(for: store.activeProviderID) { return "You have a provider key, so the coach uses it. Remove the key to use the on-device helper." }
            return "The coach runs on Apple Intelligence, on this device. Nothing leaves it."
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(status)
                .font(TimeMasterFont.body(14, relativeTo: .subheadline))
                .foregroundStyle(Theme.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
            Text("It can look things up in your library and add notes to exercise pages. It cannot create, change or delete anything.")
                .font(TimeMasterFont.caption())
                .foregroundStyle(Theme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
            if showsSwitch {
                Toggle("Use my own provider key instead", isOn: $store.usesOwnKey)
                    .font(TimeMasterFont.body(14, relativeTo: .subheadline))
            }
            Button("Check again") {
                availability = OnDeviceSupport.availability()
                store.refreshEngineName()
            }
            .buttonStyle(TimeMasterActionButtonStyle())
        }
        .onAppear { availability = OnDeviceSupport.availability() }
    }
}
