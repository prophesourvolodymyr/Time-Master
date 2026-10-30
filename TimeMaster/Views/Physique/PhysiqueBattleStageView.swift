import SwiftUI
#if os(iOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif

struct PhysiqueBattleStageView: View {
    @ObservedObject var store: PhysiqueStore
    let onOpen: (PhysiqueRoute) -> Void

    @ObservedObject private var camera = PhysiqueCamera.shared
    @ObservedObject private var cloudAccount = CloudAccountStore.shared
    @Environment(\.physiqueWindowID) private var windowID
    @Environment(\.physiquePresentationActive) private var presentationActive
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.physiqueLiveResizing) private var liveResizing
    @AccessibilityFocusState private var accessibilityFocus: FocusTarget?
    @State private var selectedPose: PhysiquePose = .front
    @State private var captureDelay = 3
    @State private var captureTask: Task<Void, Never>?
    @State private var captureToken: UUID?
    @State private var captureEndpoint: Double?
    @State private var resumeTask: Task<Void, Never>?
    @State private var resumeToken: UUID?
    @State private var resuming = false
    @State private var submissionPending = false
    @State private var message: String?
    @State private var cameraPanelVisible = true
    @State private var captureDeadlineReached = false
    @State private var preparingRetake = false
    @State private var reviewHandoff = false
    @State private var visible = false
    @State private var routedState: String?
    @State private var exitRequest: ExitRequest?
    @State private var confirmsExit = false
    @State private var confirmsControl = false

    private enum FocusTarget: Hashable {
        case phase, pose, message
    }

    private struct ExitRequest {
        let matchID: String
        let postGo: Bool
    }

    private struct DeadlineKey: Hashable {
        let matchID: String?
        let stage: PhysiqueStage
        let deadline: Double?
    }

    private enum StageAction {
        case signIn, refresh, ready, review, returnToCamera, resume, capture
        case cancelCapture, nextPose(PhysiquePose), submit, judging, transfer
        case waiting, result, lobby, consent
    }

    private let cameraAnchor = "physique-battle-camera"
    private let scrollSpace = "physique-battle-scroll"
    private let arenaWidth: CGFloat = 880

    var body: some View {
        ScrollViewReader { proxy in
            VStack(spacing: 0) {
                topBand(proxy: proxy)
                stage
            }
            #if os(iOS)
            .safeAreaInset(edge: .bottom, spacing: 0) {
                actionBand(proxy: proxy)
                    .padding(.horizontal, ProfileStyle.inset)
                    .padding(.vertical, ProfileStyle.spacing)
                    .background(Theme.background)
                    .overlay(alignment: .top) { Divider() }
            }
            #endif
        }
        .font(TimeMasterFont.body())
        .foregroundStyle(Theme.textPrimary)
        .background(Theme.background.ignoresSafeArea())
        .tint(Theme.toolbarOrange)
        .navigationTitle("Physique duel")
        .navigationBarBackButtonHidden(store.match?.stage.terminal != true)
        .interactiveDismissDisabled(store.match != nil && store.match?.stage.terminal != true)
        .confirmationDialog(exitTitle, isPresented: $confirmsExit, titleVisibility: .visible) {
            if let request = exitRequest {
                Button(request.postGo ? "Forfeit and leave" : "Cancel match", role: .destructive) {
                    Task { await confirmExit(request) }
                }
                if safeVisualDismissal {
                    Button("Return to lobby") { open(.lobby) }
                }
            }
            Button("Continue", role: .cancel) { accessibilityFocus = .pose }
        } message: {
            Text(exitDetail)
        }
        .alert("Use this window?", isPresented: $confirmsControl) {
            Button("Keep current window", role: .cancel) { }
            Button("Use this window") {
                stopLocalCapture()
                store.transferControl(to: windowID)
                message = "Control moved here. Check the match, then resume the camera deliberately."
                Task { await store.refresh(); reconcileStage() }
            }
        } message: {
            Text("The other window's camera will stop immediately. Your match, deadline and retake history do not restart. No still is taken automatically.")
        }
        .onAppear {
            visible = true
            reviewHandoff = false
            routedState = nil
            if !applyRequestedPose() {
                selectedPose = nextUnacceptedPose ?? selectedPose
                preparingRetake = false
            }
            reconcileStage()
        }
        .task {
            await store.refresh()
            guard !Task.isCancelled else { return }
            reconcileStage()
        }
        .task(id: deadlineKey) { await watchCaptureDeadline() }
        .onChange(of: store.snapshot?.serverTime) { _ in reconcileStage() }
        .onChange(of: store.stage) { _ in
            if visible { accessibilityFocus = .phase }
            reconcileStage()
        }
        .onChange(of: cloudAccount.accountID) { _ in
            stopLocalCapture()
            selectedPose = .front
            preparingRetake = false
            message = nil
        }
        .onChange(of: store.requestedPose) { _ in
            if visible { _ = applyRequestedPose() }
        }
        .onChange(of: store.privacyRevision) { _ in
            if visible { stopLocalCapture() }
        }
        .onChange(of: store.controllingWindowID) { _ in
            if !controlsMatch { stopLocalCapture() }
        }
        .onChange(of: store.isStale) { stale in
            if stale {
                stopLocalCapture()
                message = "Connection not confirmed. Check the same match before resuming."
            }
        }
        .onChange(of: presentationActive) { active in
            if !active { stopLocalCapture() }
        }
        .onChange(of: scenePhase) { phase in
            if phase != .active { stopLocalCapture() }
        }
        .onChange(of: camera.status) { status in
            if !status.isRunning, captureEndpoint != nil {
                cancelCapture(message: "Capture cancelled. The camera is no longer running.")
            }
        }
        .onChange(of: camera.ownerID) { owner in
            if owner != windowID, captureToken != nil || resuming {
                stopLocalCapture()
                message = "Camera ownership changed. No delayed capture will occur."
            }
        }
        .onDisappear {
            visible = false
            cancelResume()
            cancelCapture()
            if !reviewHandoff { camera.stop(owner: windowID) }
        }
        #if os(macOS)
        .onExitCommand {
            if captureToken != nil { cancelCapture(message: "Capture cancelled.") }
            else { requestExit() }
        }
        #endif
    }

    private func topBand(proxy: ScrollViewProxy) -> some View {
        VStack(spacing: ProfileStyle.spacing) {
            PhysiqueBattleBrandHeader()
            #if os(macOS)
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .center, spacing: 28) {
                    phaseTimer
                        .frame(minWidth: 220, maxWidth: 360)
                    VStack(alignment: .leading, spacing: ProfileStyle.spacing) {
                        safeActionBand
                        actionBand(proxy: proxy)
                            .controlSize(.regular)
                    }
                    .frame(minWidth: 300, maxWidth: 480)
                }
                VStack(spacing: ProfileStyle.spacing) {
                    phaseTimer
                    safeActionBand
                    actionBand(proxy: proxy)
                        .controlSize(.regular)
                }
            }
            #else
            VStack(spacing: 0) {
                phaseTimer
                safeActionBand
            }
            #endif
        }
        .padding(.horizontal, ProfileStyle.inset)
        .padding(.vertical, 8)
        .frame(maxWidth: arenaWidth)
        .frame(maxWidth: .infinity)
        .background(Theme.background)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(Theme.separator)
                .frame(height: 1)
                .accessibilityHidden(true)
        }
    }

    private var phaseTimer: some View {
        PhysiqueTimerView(clock: phaseClock)
            .accessibilityFocused($accessibilityFocus, equals: .phase)
    }

    private var safeActionBand: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: ProfileStyle.spacing) { safeActions }
                .fixedSize(horizontal: true, vertical: false)
            HStack(alignment: .top, spacing: 8) { safeActions }
            VStack(alignment: .leading, spacing: 0) { safeActions }
        }
        .font(TimeMasterFont.secondary())
        .labelStyle(.titleAndIcon)
        #if os(macOS)
        .buttonStyle(.bordered)
        .controlSize(.small)
        #else
        .buttonStyle(.plain)
        #endif
        .frame(maxWidth: .infinity)
    }

    @ViewBuilder private var safeActions: some View {
        Button { open(.safety, protectAllWindows: true) } label: {
            Label("Safety", systemImage: "shield")
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 4)
                .frame(minHeight: safeActionHeight)
                .contentShape(Rectangle())
        }
        .keyNavTarget(shape: .roundedRectangle(cornerRadius: 6))
        .accessibilityInputLabels(["Safety"])
        Button { open(.privacy, protectAllWindows: true) } label: {
            Label("Privacy", systemImage: "hand.raised")
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 4)
                .frame(minHeight: safeActionHeight)
                .contentShape(Rectangle())
        }
        .keyNavTarget(shape: .roundedRectangle(cornerRadius: 6))
        .accessibilityInputLabels(["Privacy"])
        Button(action: requestExit) {
            Label(exitActionTitle, systemImage: "rectangle.portrait.and.arrow.right")
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 4)
                .frame(minHeight: safeActionHeight)
                .contentShape(Rectangle())
        }
        .keyNavTarget(shape: .roundedRectangle(cornerRadius: 6))
        .accessibilityInputLabels(["Exit", exitActionTitle])
    }

    private var safeActionHeight: CGFloat {
        #if os(macOS)
        24
        #else
        ProfileStyle.touchTarget
        #endif
    }

    private var stage: some View {
        GeometryReader { viewport in
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    if let match = store.match {
                        VStack(alignment: .leading, spacing: ProfileStyle.inset) {
                            PhysiqueIdentityRail(identity: match.you.identity, ownerLabel: "You") { _ in
                                open(.badges)
                            }
                            if store.locallyBlockedIDs.contains(match.opponent.identity.id) {
                                PhysiqueStatusView(title: "Opponent hidden", detail: "Local protection is active. No opponent images are shown.", systemImage: "person.crop.circle.badge.xmark")
                            } else {
                                PhysiqueIdentityRail(identity: match.opponent.identity, ownerLabel: "Opponent") { _ in
                                    open(.badges)
                                }
                            }
                        }
                        serviceStatus
                        ownPlayer(match: match)
                            .id(cameraAnchor)
                        matchupDivider
                        opponentPlayer(match: match)
                    } else {
                        serviceStatus
                        PhysiqueStatusView(
                            title: store.loading ? "Restoring match" : "No confirmed match",
                            detail: "Camera capture is unavailable until the service confirms your paired match.",
                            systemImage: "person.2"
                        )
                    }
                }
                .padding(.vertical, 24)
                .frame(maxWidth: arenaWidth)
                .padding(.horizontal, viewport.size.width >= 700 ? 28 : ProfileStyle.inset)
                .frame(maxWidth: .infinity)
            }
            .coordinateSpace(name: scrollSpace)
            .onPreferenceChange(PhysiqueBattleCameraBounds.self) { frame in
                guard !frame.isNull, viewport.size.height > 0 else { return }
                let inView = frame.maxY > 0 && frame.minY < viewport.size.height
                guard inView != cameraPanelVisible else { return }
                cameraPanelVisible = inView
                if !inView, camera.ownerID == windowID,
                   camera.status.isRunning || captureToken != nil || resuming {
                    stopLocalCapture()
                    message = "Camera paused while its panel is offscreen. Return to the camera, then resume when ready."
                }
            }
        }
        .background {
            PhysiqueBattleBackground(
                stage: store.stage,
                cameraActive: camera.status.isRunning && camera.ownerID == windowID,
                motionAllowed: backdropMotionAllowed
            )
        }
    }

    @ViewBuilder private var serviceStatus: some View {
        if let policy = store.policy, !policy.ready {
            PhysiqueStatusView(title: "Rated capture unavailable", detail: policy.unavailableReason ?? "The service has not confirmed that rated Physique matches are available.", systemImage: "hand.raised")
        }
        if !controlsMatch {
            PhysiqueStatusView(title: "Open in another window", detail: "This window shows the same confirmed match. Move control here explicitly to use its camera or submit poses.", systemImage: "macwindow.on.rectangle")
        }
        if store.isStale {
            PhysiqueStatusView(title: "Last confirmed match", detail: "Connection is not confirmed. Progress may have changed; capture is paused and the original deadline continues.", systemImage: "wifi.slash")
        }
        if let reason = store.account?.restrictedReason {
            PhysiqueStatusView(title: "Participation restricted", detail: reason, systemImage: "hand.raised")
        }
        if let error = store.error {
            PhysiqueStatusView(title: submissionPending ? "Submission awaiting confirmation" : "Service action not confirmed", detail: error, systemImage: "exclamationmark.circle")
        }
        if let message {
            Label(message, systemImage: "info.circle")
                .font(TimeMasterFont.secondary())
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityFocused($accessibilityFocus, equals: .message)
        }
        if let notice = store.notice {
            Text(notice)
                .font(TimeMasterFont.secondary())
                .foregroundStyle(ProfileStyle.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func ownPlayer(match: PhysiqueMatch) -> some View {
        VStack(alignment: .leading, spacing: ProfileStyle.inset) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: ProfileStyle.spacing) {
                    Text("POSE \(poseNumber(selectedPose)) / \(PhysiquePose.allCases.count.formatted(.number.precision(.integerLength(2))))")
                        .font(TimeMasterFont.black(12, relativeTo: .caption))
                        .tracking(1.8)
                        .foregroundStyle(Theme.toolbarOrange)
                    Rectangle()
                        .fill(Theme.separator)
                        .frame(height: 1)
                        .accessibilityHidden(true)
                }
                Text(selectedPose.title)
                    .font(TimeMasterFont.black(28, relativeTo: .title2))
                    .fixedSize(horizontal: false, vertical: true)
                    .contentTransition(.opacity)
                    .animation(stageMotionAllowed ? .easeOut(duration: 0.16) : nil, value: selectedPose)
                    .accessibilityAddTraits(.isHeader)
                    .accessibilityFocused($accessibilityFocus, equals: .pose)
                Text(selectedPose.instruction)
                    .font(TimeMasterFont.secondary())
                    .foregroundStyle(ProfileStyle.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                if let captureEndpoint {
                    PhysiqueTimerView(clock: PhysiqueClock(mode: .countdown, label: "Local shutter · Capture in", endpoint: captureEndpoint, serverOffset: 0))
                }
            }
            PhysiquePlayerPanel(title: "You", status: ownStatus(match: match)) {
                if camera.isCapturing, camera.ownerID == windowID {
                    ProgressView("Preparing protected preview")
                        .font(TimeMasterFont.secondary())
                } else if camera.status.isRunning, camera.ownerID == windowID,
                          presentationActive, scenePhase == .active, controlsMatch {
                    PhysiqueCameraPreview(camera: camera)
                } else {
                    PhysiqueAthleteIllustration(pose: selectedPose)
                }
            }
            .background {
                GeometryReader { geometry in
                    Color.clear.preference(key: PhysiqueBattleCameraBounds.self, value: geometry.frame(in: .named(scrollSpace)))
                }
            }
            poseControls
            if match.stage == .capture, !match.you.submitted {
                Picker("Capture delay", selection: $captureDelay) {
                    Text("3-second timer").tag(3)
                    Text("Immediate").tag(0)
                }
                .pickerStyle(.menu)
                .keyNavTarget(shape: .roundedRectangle(cornerRadius: 6))
                .disabled(captureToken != nil || camera.isCapturing)
                .accessibilityHint("This local shutter delay does not change the match deadline.")
                captureDetail
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: ProfileStyle.spacing) { poseSecondaryActions }
                        .fixedSize(horizontal: true, vertical: false)
                    VStack(alignment: .leading, spacing: ProfileStyle.spacing) { poseSecondaryActions }
                }
                .font(TimeMasterFont.secondary())
                #if os(macOS)
                .buttonStyle(.bordered)
                #else
                .buttonStyle(TimeMasterActionButtonStyle(prominent: false))
                #endif
            }
        }
    }

    private func poseNumber(_ pose: PhysiquePose) -> String {
        let index = PhysiquePose.allCases.firstIndex(of: pose) ?? 0
        return (index + 1).formatted(.number.precision(.integerLength(2)))
    }

    private var poseControls: some View {
        LazyVGrid(
            columns: [GridItem(.adaptive(minimum: dynamicTypeSize.isAccessibilitySize ? 220 : 100), spacing: 8, alignment: .leading)],
            alignment: .leading,
            spacing: 8
        ) {
            ForEach(PhysiquePose.allCases) { pose in
                Button {
                    select(pose)
                } label: {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text(poseNumber(pose))
                                .font(TimeMasterFont.technical())
                            Spacer(minLength: 0)
                            if selectedPose == pose {
                                Image(systemName: "arrowtriangle.down.fill")
                                    .font(.caption2)
                                    .foregroundStyle(Theme.toolbarOrange)
                                    .accessibilityHidden(true)
                            }
                        }
                        .foregroundStyle(ProfileStyle.secondary)
                        PhysiquePoseIcon(
                            pose: pose,
                            accepted: poseStatus(pose) == "Accepted",
                            selected: selectedPose == pose
                        )
                        .frame(maxWidth: .infinity)
                        if poseStatus(pose) != "Accepted" {
                            Label(poseStatus(pose), systemImage: poseStatusSymbol(pose))
                                .font(TimeMasterFont.caption())
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    .padding(ProfileStyle.spacing)
                    .frame(maxWidth: .infinity, alignment: .topLeading)
                    .background(selectedPose == pose ? Theme.surface2 : Theme.background)
                    .overlay(alignment: .bottom) {
                        Rectangle()
                            .fill(selectedPose == pose ? Theme.toolbarOrange : Theme.separator)
                            .frame(height: selectedPose == pose ? 3 : 1)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(TimeMasterCardButtonStyle())
                .keyNavShape(.roundedRectangle(cornerRadius: 0))
                .accessibilityLabel(pose.title)
                .accessibilityValue(poseStatus(pose))
                .accessibilityAddTraits(selectedPose == pose ? .isSelected : [])
                .accessibilityInputLabels([pose.shortTitle, pose.title])
            }
        }
    }

    @ViewBuilder private var captureDetail: some View {
        if let item = evidence(for: selectedPose) {
            VStack(alignment: .leading, spacing: 4) {
                Label(poseStatus(selectedPose), systemImage: poseStatusSymbol(selectedPose))
                Text(item.retakes >= 2 ? "Retakes used" : "\(max(0, 2 - item.retakes)) retakes remaining")
                    .foregroundStyle(ProfileStyle.secondary)
            }
            .font(TimeMasterFont.secondary())
            .fixedSize(horizontal: false, vertical: true)
            if let reason = item.reason, item.status == "rejected" {
                Label(reason, systemImage: "exclamationmark.circle")
                    .font(TimeMasterFont.secondary())
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        if camera.ownerID == windowID {
            Text(camera.status.isRunning ? camera.framingMessage : camera.status.message)
                .font(TimeMasterFont.secondary())
                .foregroundStyle(ProfileStyle.secondary)
                .fixedSize(horizontal: false, vertical: true)
            if let error = camera.error {
                Label(error, systemImage: "exclamationmark.circle")
                    .font(TimeMasterFont.secondary())
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        if let reason = captureEligibilityReason {
            Text(reason)
                .font(TimeMasterFont.secondary())
                .fixedSize(horizontal: false, vertical: true)
        } else if captureDelay == 3, !hasTimeForDelay {
            Text("Not enough time for a 3-second timer. Select Immediate only if capture remains open.")
                .font(TimeMasterFont.secondary())
                .fixedSize(horizontal: false, vertical: true)
        }
        if !allPosesAccepted {
            Text(submissionRequirement)
                .font(TimeMasterFont.caption())
                .foregroundStyle(ProfileStyle.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    @ViewBuilder private var poseSecondaryActions: some View {
        Button { open(.guide) } label: {
            Label("Pose guide", systemImage: "figure.stand")
        }
        .keyNavTarget(shape: .roundedRectangle(cornerRadius: 6))
        if camera.candidate != nil, camera.candidatePose == selectedPose, camera.ownerID == windowID {
            Button { openReview() } label: { Label("Review pose · Not sent", systemImage: "eye") }
                .keyNavTarget(shape: .roundedRectangle(cornerRadius: 6))
        } else if selectedPreviewAvailable {
            Button { openReview() } label: { Label("Review selected pose", systemImage: "eye") }
                .keyNavTarget(shape: .roundedRectangle(cornerRadius: 6))
        }
        if evidence(for: selectedPose) != nil, !preparingRetake, canRetake {
            Button {
                preparingRetake = true
                resumeCamera()
            } label: { Label("Retake \(selectedPose.shortTitle.lowercased())", systemImage: "arrow.counterclockwise") }
            .keyNavTarget(shape: .roundedRectangle(cornerRadius: 6))
            .disabled(captureEligibilityReason != nil || store.loading)
            .accessibilityLabel("Retake \(selectedPose.title)")
        }
        if camera.status == .denied, camera.ownerID == windowID {
            Button(action: openCameraSettings) { Label("Open camera settings", systemImage: "gearshape") }
                .keyNavTarget(shape: .roundedRectangle(cornerRadius: 6))
        }
    }

    private func opponentPlayer(match: PhysiqueMatch) -> some View {
        PhysiquePlayerPanel(title: "Opponent", status: opponentStatus(match: match)) {
            PhysiqueAthleteIllustration(isOpponent: true)
        }
        .accessibilityHint("Neutral illustration. Opponent pose images are not available during capture.")
    }

    private var matchupDivider: some View {
        PhysiqueVersusDivider()
            .opacity(visible ? 1 : 0)
            .scaleEffect(visible ? 1 : 0.96)
            .animation(stageMotionAllowed ? .easeOut(duration: 0.28) : nil, value: visible)
            .accessibilityHidden(true)
    }

    private func actionBand(proxy: ScrollViewProxy) -> some View {
        let action = primaryAction
        return VStack(alignment: .leading, spacing: 8) {
            ViewThatFits(in: .horizontal) {
                HStack(spacing: ProfileStyle.spacing) {
                    primaryButton(action, proxy: proxy)
                    stopButton
                }
                VStack(alignment: .leading, spacing: 8) {
                    primaryButton(action, proxy: proxy)
                    stopButton
                }
            }
            if submissionPending {
                Text("Submitting selected set · Awaiting service confirmation")
                    .font(TimeMasterFont.caption())
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity)
    }

    @ViewBuilder
    private func primaryButton(_ action: StageAction, proxy: ScrollViewProxy) -> some View {
        #if os(macOS)
        Button { activate(action, proxy: proxy) } label: {
            Label(actionTitle(action), systemImage: actionSymbol(action))
                .font(TimeMasterFont.rowTitle())
                .fixedSize(horizontal: false, vertical: true)
        }
        .buttonStyle(.borderedProminent)
        .keyNavTarget(shape: .roundedRectangle(cornerRadius: 8))
        .disabled(actionDisabled(action))
        .accessibilityLabel(actionAccessibilityTitle(action))
        .accessibilityInputLabels([actionAccessibilityTitle(action)])
        #else
        PhysiqueAction(title: actionTitle(action), systemImage: actionSymbol(action), disabled: actionDisabled(action)) {
            activate(action, proxy: proxy)
        }
        .accessibilityLabel(actionAccessibilityTitle(action))
        .accessibilityInputLabels([actionAccessibilityTitle(action)])
        #endif
    }

    @ViewBuilder private var stopButton: some View {
        if camera.ownerID == windowID,
           camera.status.isRunning || camera.isCapturing || camera.status == .requesting || camera.status == .starting || resuming {
            Button {
                stopLocalCapture()
                message = "Camera stopped. This does not forfeit the match. The original deadline continues."
                accessibilityFocus = .message
            } label: { Label("Stop camera", systemImage: "video.slash") }
            #if os(macOS)
            .buttonStyle(.bordered)
            #else
            .buttonStyle(TimeMasterActionButtonStyle(prominent: false))
            #endif
            .keyNavTarget(shape: .roundedRectangle(cornerRadius: 6))
            .accessibilityInputLabels(["Stop camera"])
        }
    }

    private var controlsMatch: Bool { store.canControl(from: windowID) }
    private var serverNow: Double { Date().timeIntervalSince1970 + store.serverOffset }
    private var activeSurface: Bool { visible && presentationActive && scenePhase == .active }
    private var backdropMotionAllowed: Bool {
        guard activeSurface, store.signedIn, store.account != nil,
              let match = store.match, !store.loading, !store.isStale,
              store.lastRefreshedAt != nil, store.policy?.ready == true,
              store.account?.restrictedReason == nil,
              !store.localProcessingStopped, consentCurrent,
              !confirmsExit, !confirmsControl, !reviewHandoff else { return false }
        if match.stage == .judging {
            guard let deadline = match.judgingDeadline,
                  deadline.isFinite, deadline > serverNow else { return false }
        } else if match.stage == .submitting {
            guard let deadline = match.deadline,
                  deadline.isFinite, deadline > serverNow else { return false }
        }
        return true
    }
    private var stageMotionAllowed: Bool {
        let process = ProcessInfo.processInfo
        return backdropMotionAllowed && !reduceMotion && !liveResizing
            && !process.isLowPowerModeEnabled && process.thermalState == .nominal
            && store.stage != .capture && store.stage != .countdown
            && !camera.status.isRunning && !camera.isCapturing && captureToken == nil
    }
    private var deadlineKey: DeadlineKey {
        DeadlineKey(matchID: store.match?.id, stage: store.stage, deadline: store.match?.deadline)
    }
    private var postGo: Bool {
        guard let stage = store.match?.stage else { return false }
        return stage == .capture || stage == .submitting || stage == .judging
    }
    private var safeVisualDismissal: Bool {
        store.match?.you.submitted == true || store.stage == .judging
    }
    private var exitActionTitle: String {
        guard let match = store.match, !match.stage.terminal else { return "Return to lobby" }
        return postGo ? "Exit" : "Cancel match"
    }
    private var exitTitle: String { exitRequest?.postGo == true ? "Leave this started match?" : "Cancel this match?" }
    private var exitDetail: String {
        if exitRequest?.postGo == true {
            return "Only an otherwise eligible, service-confirmed forfeit can change Physique Elo and keep the started allowance slot charged. Invalid evidence, safety abort or unavailable judging takes no-contest precedence. Stopping the camera or opening Safety is not a forfeit."
        }
        return "A cancellation confirmed before Go changes no Physique Elo and uses no started-match slot. If the service has already started the match, this cancellation will not be converted into a forfeit."
    }
    private var consentCurrent: Bool {
        guard let account = store.account, let policy = store.policy else { return false }
        let consent = account.consent
        let processing = consent.adult && consent.rulesAccepted && consent.aiProcessing
            && !consent.policyVersion.isEmpty && consent.policyVersion == policy.version
        return processing && (postGo || consent.opponentSharing)
    }
    private var captureEligibilityReason: String? {
        guard controlsMatch else { return "Capture is controlled by the other window." }
        guard activeSurface else { return "Resume only from the active, visible match window." }
        guard store.signedIn, store.account != nil else { return "Sign in to restore the same match." }
        guard !store.isStale, store.lastRefreshedAt != nil else { return "Confirm the current match before capturing." }
        guard let policy = store.policy, policy.ready else { return store.policy?.unavailableReason ?? "Rated capture has not been enabled by the service." }
        guard !store.localProcessingStopped else { return "Processing is stopped on this device. Review Privacy before capturing again." }
        guard consentCurrent else { return "Current Physique processing consent is required before capture." }
        guard store.account?.restrictedReason == nil else { return "Participation is restricted. Open Safety for available help." }
        guard let match = store.match, match.stage == .capture, !match.you.submitted else { return "The service has not confirmed an open capture phase." }
        guard let deadline = match.deadline, deadline.isFinite else { return "The capture deadline is unavailable. Check the current match." }
        guard !captureDeadlineReached, deadline > serverNow else { return "Capture deadline reached. Awaiting confirmed outcome." }
        return nil
    }
    private var hasTimeForDelay: Bool {
        guard let deadline = store.match?.deadline else { return false }
        return deadline - serverNow > Double(captureDelay)
    }
    private var canRetake: Bool {
        guard let item = evidence(for: selectedPose) else { return true }
        return item.retakes >= 0 && item.retakes < 2
    }
    private var selectedPreviewAvailable: Bool {
        guard !store.localOwnMediaHidden, !store.localProcessingStopped, controlsMatch,
              camera.ownerID == nil || camera.ownerID == windowID,
              let item = evidence(for: selectedPose) else { return false }
        return !store.isMediaHidden(item.id) && camera.selected[selectedPose] != nil
            && camera.selectedEvidenceIDs[selectedPose] == item.id
    }
    private var allPosesAccepted: Bool {
        PhysiquePose.allCases.allSatisfy { evidence(for: $0)?.status == "accepted" }
    }
    private var nextUnacceptedPose: PhysiquePose? {
        PhysiquePose.allCases.first { evidence(for: $0)?.status != "accepted" }
    }
    private var nextWorkingPose: PhysiquePose? {
        let other = PhysiquePose.allCases.filter { $0 != selectedPose }
        return other.first { evidence(for: $0) == nil }
            ?? other.first { evidence(for: $0)?.status == "rejected" }
            ?? other.first { evidence(for: $0)?.status != "accepted" && evidence(for: $0)?.status != "checking" }
    }
    private var submissionRequirement: String {
        let waiting = PhysiquePose.allCases.filter { evidence(for: $0)?.status != "accepted" }
        return "Service acceptance needed: \(waiting.map(\.shortTitle).joined(separator: ", "))."
    }

    private var phaseClock: PhysiqueClock {
        guard let match = store.match else {
            return PhysiqueClock(mode: .unavailable, label: "Restoring match", endpoint: nil, serverOffset: store.serverOffset)
        }
        if match.stage.terminal {
            return PhysiqueClock(mode: .ended, label: match.stage.title, endpoint: nil, serverOffset: store.serverOffset)
        }
        switch match.stage {
        case .countdown:
            return PhysiqueClock(mode: .countdown, label: "Service start", endpoint: match.startAt, serverOffset: store.serverOffset)
        case .capture:
            guard let deadline = match.deadline, deadline > serverNow, !captureDeadlineReached else {
                return PhysiqueClock(mode: .unavailable, label: "Awaiting confirmed outcome", endpoint: nil, serverOffset: store.serverOffset)
            }
            return PhysiqueClock(mode: .remaining, label: match.you.submitted ? "Waiting for opponent" : "Capture time left", endpoint: deadline, serverOffset: store.serverOffset)
        case .judging:
            let deadlinePassed = match.judgingDeadline.map { $0 <= serverNow } ?? false
            return PhysiqueClock(mode: deadlinePassed ? .unavailable : .elapsed, label: deadlinePassed ? "Awaiting confirmed result" : "Judging · Elapsed", endpoint: match.judgingStartedAt, serverOffset: store.serverOffset)
        case .submitting:
            return PhysiqueClock(mode: .unavailable, label: "Confirming submission", endpoint: nil, serverOffset: store.serverOffset)
        default:
            return PhysiqueClock(mode: .unavailable, label: "Awaiting confirmed start", endpoint: nil, serverOffset: store.serverOffset)
        }
    }

    private var primaryAction: StageAction {
        if !store.signedIn { return .signIn }
        guard let match = store.match else { return .refresh }
        if match.stage.terminal { return match.stage == .cancelled || match.stage == .noOpponent ? .lobby : .result }
        if !controlsMatch { return .transfer }
        if captureToken != nil { return .cancelCapture }
        if submissionPending { return .waiting }
        if store.isStale { return .refresh }
        if match.you.submitted || match.stage == .submitting || match.stage == .judging { return .judging }
        if match.stage == .ready { return .ready }
        if match.stage == .countdown { return .waiting }
        guard match.stage == .capture else { return .refresh }
        if !consentCurrent || store.localProcessingStopped { return .consent }
        if captureEligibilityReason != nil { return .refresh }
        if camera.candidate != nil, camera.candidatePose == selectedPose, camera.ownerID == windowID { return .review }
        if allPosesAccepted, !preparingRetake { return .submit }
        if !preparingRetake, let item = evidence(for: selectedPose), item.status == "accepted" || item.status == "checking" {
            if let next = nextWorkingPose { return .nextPose(next) }
            return .refresh
        }
        if !cameraPanelVisible { return .returnToCamera }
        if !camera.status.isRunning || camera.ownerID != windowID { return .resume }
        return .capture
    }

    private func actionTitle(_ action: StageAction) -> String {
        switch action {
        case .signIn: return "Sign in"
        case .refresh: return store.loading ? "Checking match" : "Check status"
        case .ready: return "Return to ready room"
        case .review: return "Review pose · Not sent"
        case .returnToCamera: return "Return to camera"
        case .resume: return resuming ? "Restoring camera" : "Resume camera"
        case .capture: return captureDelay == 0 ? "Capture · Immediate" : "Capture · 3s"
        case .cancelCapture: return "Cancel capture"
        case .nextPose(let pose): return "Next pose · \(pose.shortTitle)"
        case .submit: return "Submit poses"
        case .judging: return "View submission"
        case .transfer: return "Use this window"
        case .waiting: return submissionPending ? "Submitting poses" : "Awaiting service start"
        case .result: return "View result"
        case .lobby: return "Return to lobby"
        case .consent: return "Review consent"
        }
    }

    private func actionAccessibilityTitle(_ action: StageAction) -> String {
        if case .capture = action { return "Capture" }
        if case .nextPose = action { return "Next pose" }
        return actionTitle(action)
    }

    private func actionSymbol(_ action: StageAction) -> String {
        switch action {
        case .capture: return "camera"
        case .cancelCapture: return "xmark.circle"
        case .resume: return "video"
        case .returnToCamera: return "arrow.up.to.line"
        case .submit: return "paperplane"
        case .review: return "eye"
        case .nextPose: return "arrow.right"
        case .transfer: return "macwindow.on.rectangle"
        case .consent: return "hand.raised"
        case .signIn: return "person.crop.circle"
        case .waiting, .judging: return "hourglass"
        case .result: return "flag.checkered"
        case .lobby, .ready: return "arrow.uturn.backward"
        case .refresh: return "arrow.clockwise"
        }
    }

    private func actionDisabled(_ action: StageAction) -> Bool {
        switch action {
        case .cancelCapture, .returnToCamera, .review, .transfer, .judging, .result, .lobby, .signIn, .consent, .ready:
            return false
        case .waiting:
            return true
        case .refresh:
            return store.loading || store.busy
        case .resume:
            return resuming || store.loading || camera.status == .restricted || camera.status == .requesting || camera.status == .starting
        case .capture:
            return !camera.canCapture || !canRetake || !hasTimeForDelay || store.loading
        case .nextPose:
            return resuming
        case .submit:
            return !allPosesAccepted || store.busy || store.loading || captureEligibilityReason != nil
        }
    }

    private func activate(_ action: StageAction, proxy: ScrollViewProxy) {
        switch action {
        case .signIn: open(.account)
        case .refresh: Task { await store.refresh(); reconcileStage() }
        case .ready: open(.ready)
        case .review: openReview()
        case .returnToCamera: returnToCamera(proxy)
        case .resume: returnToCamera(proxy); resumeCamera()
        case .capture: armCapture()
        case .cancelCapture: cancelCapture(message: "Capture cancelled.")
        case .nextPose(let pose): select(pose); returnToCamera(proxy)
        case .submit: submitPoses()
        case .judging: open(.judging)
        case .transfer: stopLocalCapture(); confirmsControl = true
        case .result:
            if let match = store.match { open(.result(match.id)) }
        case .lobby: open(.lobby)
        case .consent: open(.consent)
        case .waiting: break
        }
    }

    private func evidence(for pose: PhysiquePose) -> PhysiqueEvidence? {
        store.match?.evidence.first { $0.pose == pose }
    }

    private func poseStatus(_ pose: PhysiquePose) -> String {
        if camera.ownerID == windowID, camera.candidatePose == pose, camera.candidate != nil { return "Not sent" }
        guard let item = evidence(for: pose) else { return "Not captured" }
        switch item.status {
        case "checking": return "Checking"
        case "accepted": return "Accepted"
        case "rejected": return "Needs retake"
        case "removed": return "Removed"
        case "expired": return "Expired"
        default: return "Status unavailable"
        }
    }

    private func poseStatusSymbol(_ pose: PhysiquePose) -> String {
        switch poseStatus(pose) {
        case "Accepted": return "checkmark.circle.fill"
        case "Checking": return "hourglass"
        case "Needs retake": return "arrow.counterclockwise.circle"
        case "Not sent": return "eye"
        case "Removed", "Expired": return "minus.circle"
        case "Not captured": return "circle.dashed"
        default: return "questionmark.circle"
        }
    }

    private func ownStatus(match: PhysiqueMatch) -> String {
        if match.you.submitted { return "Poses submitted · \(match.you.acceptedCount) of 3 accepted. You can relax." }
        if camera.isCapturing, camera.ownerID == windowID { return "Preparing protected preview · Not sent" }
        if camera.candidate != nil, camera.candidatePose == selectedPose, camera.ownerID == windowID { return "Review \(selectedPose.shortTitle.lowercased()) · Not sent" }
        if camera.status.isRunning, camera.ownerID == windowID { return "Camera active · Local preview · \(match.you.acceptedCount) of 3 accepted" }
        return "Camera paused · \(match.you.acceptedCount) of 3 accepted"
    }

    private func opponentStatus(match: PhysiqueMatch) -> String {
        if store.locallyBlockedIDs.contains(match.opponent.identity.id) { return "Opponent hidden. Match outcome remains service-owned." }
        let status: String
        if match.opponent.submitted { status = "Submitted · \(match.opponent.acceptedCount) of 3 accepted" }
        else if match.stage == .ready || match.stage == .countdown { status = match.opponent.ready ? "Ready" : "Awaiting readiness" }
        else { status = "\(match.opponent.acceptedCount) of 3 poses accepted" }
        return store.isStale ? "Last confirmed: \(status)" : status
    }

    @discardableResult
    private func applyRequestedPose() -> Bool {
        guard let pose = store.consumeRequestedPose() else { return false }
        cancelCapture()
        selectedPose = pose
        preparingRetake = evidence(for: pose) != nil
        accessibilityFocus = .pose
        return true
    }

    private func select(_ pose: PhysiquePose) {
        guard camera.candidate == nil || camera.candidatePose == pose else {
            message = "Review or discard the current protected candidate before changing pose."
            accessibilityFocus = .message
            return
        }
        cancelCapture()
        selectedPose = pose
        preparingRetake = false
        message = nil
        accessibilityFocus = .pose
    }

    private func returnToCamera(_ proxy: ScrollViewProxy) {
        withAnimation(reduceMotion || liveResizing ? nil : .easeInOut(duration: 0.18)) {
            proxy.scrollTo(cameraAnchor, anchor: .top)
        }
        accessibilityFocus = .pose
    }

    private func resumeCamera() {
        guard !resuming, controlsMatch, activeSurface, store.match?.stage == .capture else { return }
        let expectedMatch = store.match?.id
        let expectedAccount = cloudAccount.accountID
        let token = UUID()
        resumeToken = token
        resuming = true
        message = nil
        resumeTask = Task { @MainActor in
            defer {
                if resumeToken == token {
                    resumeToken = nil
                    resumeTask = nil
                    resuming = false
                }
            }
            await store.refresh()
            guard !Task.isCancelled, resumeToken == token, activeSurface, cameraPanelVisible,
                  !store.loading, store.match?.id == expectedMatch, cloudAccount.accountID == expectedAccount else { return }
            guard captureEligibilityReason == nil, canRetake else {
                message = captureEligibilityReason ?? "This pose has no retakes remaining."
                reconcileStage()
                return
            }
            guard store.claimControl(for: windowID) else { return }
            await camera.start(owner: windowID)
            guard !Task.isCancelled, resumeToken == token, activeSurface, cameraPanelVisible,
                  controlsMatch, captureEligibilityReason == nil else {
                camera.stop(owner: windowID)
                return
            }
        }
    }

    private func armCapture() {
        guard captureToken == nil, captureEligibilityReason == nil, camera.canCapture,
              camera.ownerID == windowID, cameraPanelVisible, canRetake, hasTimeForDelay,
              !store.loading, let matchID = store.match?.id else { return }
        let pose = selectedPose
        let accountID = cloudAccount.accountID
        let delay = captureDelay
        let token = UUID()
        captureToken = token
        captureEndpoint = delay == 0 ? nil : Date().timeIntervalSince1970 + Double(delay)
        message = nil
        captureTask = Task { @MainActor in
            if delay > 0 {
                do { try await Task.sleep(nanoseconds: UInt64(delay) * 1_000_000_000) }
                catch { return }
            }
            guard !Task.isCancelled, captureToken == token else { return }
            captureEndpoint = nil
            guard activeSurface, cameraPanelVisible, controlsMatch,
                  store.match?.id == matchID, cloudAccount.accountID == accountID,
                  selectedPose == pose, captureEligibilityReason == nil,
                  camera.canCapture, camera.ownerID == windowID, canRetake else {
                cancelCapture(message: "Capture cancelled because the current match or private camera conditions changed.")
                return
            }
            await camera.capture(pose: pose)
            guard !Task.isCancelled, captureToken == token else { return }
            captureToken = nil
            captureTask = nil
            guard activeSurface, controlsMatch, store.match?.id == matchID,
                  cloudAccount.accountID == accountID, captureEligibilityReason == nil else {
                camera.stop(owner: windowID)
                message = "Capture is no longer available. Nothing was sent. Check the current match."
                reconcileStage()
                return
            }
            guard camera.candidate != nil, camera.candidatePose == pose, camera.ownerID == windowID else {
                message = camera.error ?? "A protected preview could not be prepared. Nothing was sent."
                accessibilityFocus = .message
                return
            }
            openReview()
        }
    }

    private func cancelCapture(message newMessage: String? = nil) {
        captureTask?.cancel()
        captureTask = nil
        captureToken = nil
        captureEndpoint = nil
        if camera.isCapturing { camera.stop(owner: windowID) }
        if let newMessage { message = newMessage }
    }

    private func cancelResume() {
        resumeTask?.cancel()
        resumeTask = nil
        resumeToken = nil
        resuming = false
    }

    private func stopLocalCapture() {
        cancelResume()
        cancelCapture()
        reviewHandoff = false
        camera.stop(owner: windowID)
    }

    private func openReview() {
        let candidateAvailable = camera.ownerID == windowID && camera.candidatePose == selectedPose && camera.candidate != nil
        guard captureEligibilityReason == nil,
              candidateAvailable || selectedPreviewAvailable else {
            message = "The exact local protected preview is unavailable. No image was sent by this action."
            return
        }
        cancelResume()
        cancelCapture()
        camera.pause(owner: windowID)
        reviewHandoff = true
        onOpen(.poseReview(selectedPose))
    }

    private func submitPoses() {
        guard !submissionPending, allPosesAccepted, captureEligibilityReason == nil,
              !store.busy, let matchID = store.match?.id else { return }
        let accountID = cloudAccount.accountID
        cancelResume()
        cancelCapture()
        camera.pause(owner: windowID)
        submissionPending = true
        message = nil
        Task { @MainActor in
            let accepted = await store.perform("submit", matchID: matchID)
            submissionPending = false
            guard activeSurface, cloudAccount.accountID == accountID, store.match?.id == matchID else { return }
            if accepted {
                camera.stop(owner: windowID)
                reconcileStage()
                if store.match?.you.submitted != true, store.stage != .judging, store.match?.stage.terminal != true {
                    message = "Check the current match to confirm whether the selected set is locked."
                }
            } else {
                message = "Submission not confirmed. Check the same match before retrying; no new set is created here."
                accessibilityFocus = .message
            }
        }
    }

    private func requestExit() {
        stopLocalCapture()
        guard controlsMatch, let match = store.match, !match.stage.terminal else {
            onOpen(.lobby)
            return
        }
        exitRequest = ExitRequest(matchID: match.id, postGo: postGo)
        confirmsExit = true
    }

    private func confirmExit(_ request: ExitRequest) async {
        stopLocalCapture()
        guard store.canControl(from: windowID) else {
            message = "The other window controls this match. You can still open Safety or Privacy here."
            return
        }
        guard store.match?.id == request.matchID, store.match?.stage.terminal != true else {
            reconcileStage()
            return
        }
        let accepted = await store.perform("leave", matchID: request.matchID, reason: request.postGo ? "forfeit" : "cancel")
        guard visible else { return }
        if accepted {
            if store.match?.stage == .cancelled || (!request.postGo && store.match == nil) { open(.lobby) }
            else { reconcileStage() }
        } else {
            await store.refresh()
            if !request.postGo, postGo {
                message = "The service has started the match. Your cancellation was not changed into a forfeit. Choose Resume, Safety or a new explicit exit."
            } else {
                message = "Leaving is not confirmed. The camera is off; check the current match before trying again."
            }
            reconcileStage()
        }
    }

    private func open(_ route: PhysiqueRoute, protectAllWindows: Bool = false) {
        stopLocalCapture()
        if protectAllWindows { store.suspendCapture() }
        onOpen(route)
    }

    private func reconcileStage() {
        guard activeSurface, !reviewHandoff, let match = store.match else { return }
        if match.stage.terminal { confirmsExit = false }
        else if confirmsExit { return }
        if match.stage != .capture || match.you.submitted || !consentCurrent || store.localProcessingStopped || store.policy?.ready != true || store.isStale || !controlsMatch {
            if camera.ownerID == windowID, camera.status.isRunning || captureToken != nil || resuming { stopLocalCapture() }
        }
        let route: PhysiqueRoute?
        switch match.stage {
        case .completed, .forfeited, .noContest: route = .result(match.id)
        case .cancelled, .noOpponent: route = .lobby
        case .judging, .submitting: route = .judging
        case .capture: route = match.you.submitted ? .judging : nil
        case .ready: route = .ready
        default: route = nil
        }
        guard let route else { return }
        let state = "\(match.id):\(match.stage.rawValue):\(match.you.submitted)"
        guard routedState != state else { return }
        routedState = state
        open(route)
    }

    private func watchCaptureDeadline() async {
        captureDeadlineReached = false
        let key = deadlineKey
        guard key.stage == .capture, let deadline = key.deadline, deadline.isFinite else { return }
        while !Task.isCancelled {
            let remaining = deadline - serverNow
            if remaining <= 0 { break }
            do { try await Task.sleep(for: .seconds(remaining)) }
            catch { return }
        }
        guard !Task.isCancelled, deadlineKey == key else { return }
        captureDeadlineReached = true
        if visible {
            stopLocalCapture()
            message = "Capture deadline reached. Awaiting confirmed outcome; no result or rating is decided locally."
            accessibilityFocus = .message
        }
        reconcileStage()
    }

    private func openCameraSettings() {
        stopLocalCapture()
        #if os(iOS)
        if let url = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(url) }
        #elseif os(macOS)
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Camera") { NSWorkspace.shared.open(url) }
        #endif
    }
}

private struct PhysiqueBattleCameraBounds: PreferenceKey {
    static var defaultValue: CGRect { .null }
    static func reduce(value: inout CGRect, nextValue: () -> CGRect) { value = nextValue() }
}
