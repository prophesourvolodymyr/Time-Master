import SwiftUI

private enum RankedFlowSheet: String, Identifiable {
    case rules, leaderboard, details
    var id: String { rawValue }
}

struct RankedMatchFlowView: View {
    @StateObject private var controller: RankedMatchController
    @ObservedObject private var account = RankedAccountStore.shared
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @State private var sheet: RankedFlowSheet?
    @State private var confirmsLeave = false

    init(variation: RankedVariation, mode: RankedMode) {
        _controller = StateObject(wrappedValue: RankedMatchController(variation: variation, mode: mode))
    }

    var body: some View {
        Group {
            if controller.stage == .live {
                RankedDuelPlayerView(variation: controller.variation, mode: controller.mode, frame: controller.frame,
                                     camera: controller.camera, onLeave: { confirmsLeave = true })
            } else {
                VStack(spacing: 0) {
                    header
                    ScrollView {
                        VStack(spacing: ProfileStyle.inset) {
                            content
                            if let error = controller.error {
                                RankedServiceNotice(message: error, retry: { Task { await controller.retry() } })
                            }
                        }
                        .padding(ProfileStyle.inset)
                        .frame(maxWidth: ProfileStyle.readableWidth).frame(maxWidth: .infinity)
                    }.scrollIndicators(.hidden)
                }
            }
        }
        .background(Theme.background.ignoresSafeArea()).foregroundStyle(.white)
        .tint(Theme.toolbarOrange).preferredColorScheme(.dark)
        .interactiveDismissDisabled(controller.stage != .camera && controller.stage != .result)
        .sheet(item: $sheet) { destination in
            switch destination {
            case .rules: RankedRulesView(variation: controller.variation)
            case .leaderboard: RankedLeaderboardView(initialVariation: controller.variation)
            case .details:
                if let match = controller.match {
                    NavigationStack {
                        RankedMatchDetailView(match: match)
                            .toolbar { AppToolbar.item(placement: .confirmationAction) { Button("Close") { sheet = nil } } }
                    }
                }
            }
        }
        .alert(controller.mode == .duel && controller.postGo ? "Forfeit this match?" : "Leave this activity?", isPresented: $confirmsLeave) {
            Button("Continue", role: .cancel) { }
            Button(controller.mode == .duel && controller.postGo ? "Forfeit and leave" : "Leave", role: .destructive) {
                Task { if await controller.leave() { dismiss() } }
            }
        } message: {
            Text(controller.mode == .practice ? "No competitive rating or match slot is affected." : controller.postGo ? "Leaving or backgrounding after Go is a forfeit. The started match remains charged." : "Cancel before Go without using a slot or changing Elo.")
        }
        .task { await controller.run() }
        .onDisappear { controller.stop() }
        .onChange(of: account.identity?.publicID) { _ in
            if controller.mode == .duel { controller.stop(); dismiss() }
        }
        .onChange(of: scenePhase) { phase in
            Task {
                if phase == .background { await controller.background() }
                else if phase == .active { await controller.foreground() }
            }
        }
    }

    private var header: some View {
        HStack(spacing: ProfileStyle.spacing) {
            Button(controller.stage == .result || controller.stage == .verifying ? "Close" : "Cancel") {
                if controller.stage == .countdown { confirmsLeave = true }
                else { Task { if await controller.leave() { dismiss() } } }
            }
            .buttonStyle(TimeMasterToolbarWideButtonStyle()).disabled(controller.busy)
            Spacer(minLength: 0)
            Text(controller.mode == .practice ? "PRACTICE" : "RANKED 1V1").font(TimeMasterFont.caption())
            Spacer(minLength: 0)
            Button { sheet = .rules } label: { Label("Movement rules", systemImage: "list.bullet.clipboard").labelStyle(.iconOnly) }
                .buttonStyle(TimeMasterToolbarIconButtonStyle())
        }.padding(ProfileStyle.inset)
    }

    @ViewBuilder private var content: some View {
        switch controller.stage {
        case .camera:
            RankedCameraSetupView(controller: controller, camera: controller.camera, onRules: { sheet = .rules })
        case .searching:
            RankedSearchView(variation: controller.variation, onCancel: { Task { if await controller.leave() { dismiss() } } })
        case .ready:
            if let match = controller.match {
                RankedReadyCameraContent(controller: controller, match: match, onRules: { sheet = .rules })
            }
        case .countdown:
            Text(controller.countdown == 0 ? "GO" : String(controller.countdown))
                .font(.custom("Inter-Black", size: 96, relativeTo: .largeTitle)).foregroundStyle(Theme.toolbarOrange)
                .frame(maxWidth: .infinity).padding(.vertical, ProfileStyle.inset * 2)
            RankedCameraPreview(camera: controller.camera).frame(height: 300)
            Text(controller.variation.fullTitle).font(TimeMasterFont.heading())
            Text("Get into position · No pause after Go").font(TimeMasterFont.caption()).foregroundStyle(ProfileStyle.secondary)
        case .live: EmptyView()
        case .verifying:
            ProgressView()
            Text("Verifying the round").font(TimeMasterFont.title())
            Text("The service is checking the movement timeline and finalizing both results. You can close this screen and return from Recent rounds; no winner is guessed while the service is unavailable.")
                .font(TimeMasterFont.secondary()).foregroundStyle(ProfileStyle.secondary)
            Button("Check result") { Task { await controller.retry() } }.buttonStyle(TimeMasterToolbarWideButtonStyle())
        case .result:
            RankedMatchResultView(variation: controller.variation, mode: controller.mode, match: controller.match,
                                  frame: controller.frame, onAnother: { Task { await controller.restart() } },
                                  onLobby: { dismiss() }, onLeaderboard: { sheet = .leaderboard }, onDetails: { sheet = .details })
        case .noOpponent:
            ProfileEmptyState(symbol: "person.2.slash", title: "No opponent available", detail: "Nobody within this movement's current skill window was matched. No slot was used. Try again or return to solo Practice.")
            Button("Try again") { Task { await controller.retry() } }.buttonStyle(TimeMasterToolbarWideButtonStyle())
        }
    }
}

private struct RankedReadyCameraContent: View {
    @ObservedObject var controller: RankedMatchController
    let match: RankedMatch
    let onRules: () -> Void
    @ObservedObject private var camera: RankedCamera
    init(controller: RankedMatchController, match: RankedMatch, onRules: @escaping () -> Void) {
        self.controller = controller
        self.match = match
        self.onRules = onRules
        camera = controller.camera
    }
    var body: some View {
        VStack(spacing: ProfileStyle.inset) {
            RankedCameraPreview(camera: camera).frame(height: 180)
            RankedOpponentReadyView(match: match, calibrated: camera.tracking.calibrated, busy: controller.busy,
                                    onReady: { Task { await controller.ready() } }, onRules: onRules)
        }
    }
}
