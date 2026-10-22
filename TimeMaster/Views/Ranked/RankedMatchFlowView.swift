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
        .interactiveDismissDisabled((controller.stage != .camera && controller.stage != .result)
                                    || (controller.practiceResult != nil && !controller.practiceSaved))
        .sheet(item: $sheet) { destination in
            switch destination {
            case .rules: RankedRulesView(variation: controller.variation)
            case .leaderboard: RankedLeaderboardView(initialVariation: controller.variation)
            case .details:
                if let match = controller.match {
                    NavigationStack {
                        RankedMatchDetailView(match: match)
                            .toolbar { AppToolbar.iconItem(placement: .confirmationAction) { RankedCloseButton() } }
                    }
                } else if let result = controller.practiceResult {
                    NavigationStack {
                        RankedPracticeDetailView(result: result)
                            .toolbar { AppToolbar.iconItem(placement: .confirmationAction) { RankedCloseButton() } }
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
            Text(controller.mode == .practice ? "A started solo round is saved with its current score as Ended early. No competitive rating or match slot is affected." : controller.postGo ? "Leaving or backgrounding after Go is a forfeit. The started match remains charged." : "Cancel before Go without using a slot or changing Elo.")
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
            RankedIconAction(symbol: "xmark", label: controller.stage == .result || controller.stage == .verifying ? "Close" : "Cancel", id: "ranked-flow-close") {
                if controller.stage == .countdown { confirmsLeave = true }
                else { Task { if await controller.leave() { dismiss() } } }
            }
            .disabled(controller.busy)
            Spacer(minLength: 0)
            Label {
                TimeMasterPageTitle(controller.mode.title, size: 16, relativeTo: .caption)
            } icon: {
                Image(systemName: controller.mode.symbol)
                    .font(.caption.weight(.semibold))
            }
                .foregroundStyle(Theme.toolbarOrange)
            Spacer(minLength: 0)
            RankedIconAction(symbol: "list.bullet.clipboard", label: "Movement rules", id: "ranked-flow-rules") { sheet = .rules }
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
            if controller.countdown == 0 {
                Label("Go", systemImage: "flag.checkered").font(TimeMasterFont.heading())
            } else {
                Text(String(controller.countdown))
                    .font(TimeMasterFont.black(96, relativeTo: .largeTitle))
                    .accessibilityLabel("Countdown \(controller.countdown)")
            }
            RankedCameraPreview(camera: controller.camera).aspectRatio(4 / 3, contentMode: .fit)
            RankedMetric(value: "60", unit: "s")
        case .live: EmptyView()
        case .verifying:
            if controller.mode == .practice {
                TmaxLoadingIndicator().accessibilityLabel("Saving your Practice result")
                Text("Saving Practice")
                    .font(TimeMasterFont.rowTitle())
            } else {
                TmaxLoadingIndicator().accessibilityLabel("Verifying the round")
                RankedInfoButton(label: "Verification pending", message: "The service is checking the movement timeline and finalizing both results. You can close and return from Recent rounds. No winner is guessed while the service is unavailable.", symbol: "checkmark.shield")
                RankedIconAction(symbol: "arrow.clockwise", label: "Check result", id: "ranked-verification-retry") { Task { await controller.retry() } }
            }
        case .result:
            RankedMatchResultView(variation: controller.variation, mode: controller.mode, match: controller.match,
                                  frame: controller.frame, practiceResult: controller.practiceResult, practiceSaved: controller.practiceSaved,
                                  onAnother: { Task { await controller.restart() } },
                                  onLobby: { Task { if await controller.leave() { dismiss() } } },
                                  onLeaderboard: { sheet = .leaderboard }, onDetails: { sheet = .details })
        case .noOpponent:
            RankedInfoButton(label: "No opponent available", message: "Nobody within this movement's current skill window was matched. No slot was used. Try again or return to solo Practice.", symbol: "person.2.slash")
            RankedIconAction(symbol: "arrow.clockwise", label: "Try again", id: "ranked-search-retry") { Task { await controller.retry() } }
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
            RankedCameraPreview(camera: camera).aspectRatio(16 / 9, contentMode: .fit)
            RankedOpponentReadyView(match: match, calibrated: camera.tracking.calibrated, busy: controller.busy,
                                    onReady: { Task { await controller.ready() } }, onRules: onRules)
        }
    }
}
