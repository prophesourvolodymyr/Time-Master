#if os(iOS)
import SwiftUI
import TimeMasterCore

struct CoachPhoneEngineSettingsContent: View {
    @ObservedObject private var engine = EverAgentCoachEngine.shared
    @ObservedObject private var store = AIStore.shared
    @State private var showingPairing = false
    @State private var confirmingForget = false

    private var status: String {
        guard engine.pairedProfile != nil else {
            return "Not paired. Pair this iPhone with EverAhent to use the models you signed in to there. Your Mac runs the coach; nothing is copied to Tmax."
        }
        let place = engine.gatewayName.map { " “\($0)”" } ?? ""
        switch engine.availability {
        case .ready:
            return store.usesOwnKey ? "Paired with EverAhent\(place), but the coach uses your own key." : "Connected to EverAhent\(place). The coach uses the models you signed in to there."
        case .checking, .starting: return "Looking for your Mac…"
        case .unknown: return "Paired with EverAhent\(place)."
        case .unavailable(let message): return message
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(status)
                .font(TimeMasterFont.body(14, relativeTo: .subheadline))
                .foregroundStyle(Theme.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
            if engine.availability == .ready, engine.pairedProfile != nil, !store.usesOwnKey, !engine.models.isEmpty {
                Picker("Model", selection: $engine.modelChoice) {
                    Text("EverAhent default").tag(String?.none)
                    ForEach(engine.models, id: \.ref) { model in
                        Text("\(model.name) · \(model.provider)").tag(Optional(EverAgentCoachEngine.modelKey(model)))
                    }
                }
                .font(TimeMasterFont.body(14, relativeTo: .subheadline))
            }
            HStack(spacing: 8) {
                if engine.pairedProfile == nil {
                    Button("Pair with EverAhent") { showingPairing = true }
                        .buttonStyle(TimeMasterActionButtonStyle(prominent: true))
                } else {
                    Button("Check again") { Task { await engine.refresh() } }
                        .buttonStyle(TimeMasterActionButtonStyle())
                    Button("Pair again") { showingPairing = true }
                        .buttonStyle(TimeMasterActionButtonStyle())
                    Button("Forget") { confirmingForget = true }
                        .buttonStyle(TimeMasterActionButtonStyle())
                }
            }
        }
        .sheet(isPresented: $showingPairing) { CoachPairingSheet() }
        .confirmationDialog("Forget this pairing?", isPresented: $confirmingForget, titleVisibility: .visible) {
            Button("Forget", role: .destructive) { Task { await engine.forgetPairing() } }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("The coach stops using your Mac. This iPhone stays on the container's device list until you remove it: in EverAhent on your Mac, open the container and choose Revoke access under “Paired devices”.")
        }
        .task(id: engine.availability) {
            if engine.availability == .ready { await engine.loadModels() }
        }
        .task {
            if engine.pairedProfile != nil, engine.availability == .unknown { await engine.refresh() }
        }
    }
}
#endif
