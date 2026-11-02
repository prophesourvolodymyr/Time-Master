import SwiftUI
import TimeMasterCore

extension View {
    @ViewBuilder
    func coachAgentChrome() -> some View {
        #if os(macOS)
        modifier(CoachAgentChrome())
        #else
        task { AIStore.shared.refreshEngineName() }
        #endif
    }
}

#if os(macOS)
private struct CoachRequestItem: Identifiable {
    let request: EverAgentUIRequest
    var id: String { request.requestId }
}

struct CoachAgentChrome: ViewModifier {
    @ObservedObject private var engine = EverAgentCoachEngine.shared

    private var requestItem: Binding<CoachRequestItem?> {
        Binding(
            get: { engine.request.map(CoachRequestItem.init) },
            set: { newValue in
                if newValue == nil, engine.request != nil {
                    Task { await engine.answer(.null, cancelled: true) }
                }
            }
        )
    }

    func body(content: Content) -> some View {
        content
            .safeAreaInset(edge: .top, spacing: 0) { CoachEngineBanner() }
            .sheet(item: requestItem) { item in
                CoachRequestSheet(request: item.request)
            }
            .task {
                if engine.availability == .unknown { await engine.refresh() }
            }
    }
}

struct CoachEngineBanner: View {
    @ObservedObject private var engine = EverAgentCoachEngine.shared
    @ObservedObject private var store = AIStore.shared

    private var hasOwnKey: Bool {
        !store.currentAPIKey.isEmpty
    }

    var body: some View {
        switch engine.availability {
        case .unavailable(let message) where !store.usesOwnKey:
            banner {
                VStack(alignment: .leading, spacing: 8) {
                    Label(message, systemImage: "bolt.horizontal.circle")
                        .font(TimeMasterFont.black(14, relativeTo: .subheadline))
                        .foregroundStyle(Theme.textPrimary)
                    Text(hasOwnKey
                         ? "Until it is back, the coach uses your own provider key."
                         : store.shouldUseOnDevice
                            ? "Until it is back, the coach uses the on-device helper."
                            : "Start EverAgent to use the models you connected there, or add your own key in AI Settings.")
                        .font(TimeMasterFont.caption())
                        .foregroundStyle(Theme.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                    HStack(spacing: 8) {
                        Button("Start EverAgent") { Task { await engine.startEverAgent() } }
                            .buttonStyle(TimeMasterActionButtonStyle(prominent: true))
                        Button("Check again") { Task { await engine.refresh() } }
                            .buttonStyle(TimeMasterActionButtonStyle())
                    }
                }
            }
        case .checking, .starting:
            banner {
                HStack(spacing: 10) {
                    ProgressView().controlSize(.small)
                    Text(engine.availability == .starting ? "Starting EverAgent…" : "Looking for EverAgent…")
                        .font(TimeMasterFont.body(14, relativeTo: .subheadline))
                        .foregroundStyle(Theme.textSecondary)
                }
            }
        case .unknown, .ready, .unavailable:
            EmptyView()
        }
    }

    private func banner<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        content()
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(12)
            .modifier(TimeMasterCardSurface(cornerRadius: 16, flat: true))
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .frame(maxWidth: 800)
            .frame(maxWidth: .infinity)
    }
}

struct CoachEngineSettingsContent: View {
    @ObservedObject private var engine = EverAgentCoachEngine.shared
    @ObservedObject private var store = AIStore.shared

    private var status: String {
        switch engine.availability {
        case .ready: return store.usesOwnKey ? "EverAgent is running, but the coach uses your own key." : "The coach runs on EverAgent with the models you connected there."
        case .checking: return "Looking for EverAgent…"
        case .starting: return "Starting EverAgent…"
        case .unknown: return "Not checked yet."
        case .unavailable(let message): return message
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(status)
                .font(TimeMasterFont.body(14, relativeTo: .subheadline))
                .foregroundStyle(Theme.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
            Toggle("Use my own provider key instead", isOn: $store.usesOwnKey)
                .font(TimeMasterFont.body(14, relativeTo: .subheadline))
            if engine.availability == .ready, !store.usesOwnKey, !engine.models.isEmpty {
                Picker("Model", selection: $engine.modelChoice) {
                    Text("EverAgent default").tag(String?.none)
                    ForEach(engine.models, id: \.ref) { model in
                        Text("\(model.name) · \(model.provider)").tag(Optional(EverAgentCoachEngine.modelKey(model)))
                    }
                }
                .font(TimeMasterFont.body(14, relativeTo: .subheadline))
            }
            HStack(spacing: 8) {
                Button("Check again") { Task { await engine.refresh() } }
                    .buttonStyle(TimeMasterActionButtonStyle())
                if engine.availability != .ready {
                    Button("Start EverAgent") { Task { await engine.startEverAgent() } }
                        .buttonStyle(TimeMasterActionButtonStyle())
                }
            }
        }
        .task(id: engine.availability) {
            if engine.availability == .ready { await engine.loadModels() }
        }
    }
}
#endif
