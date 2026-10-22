import SwiftUI
import Combine
import ImageIO
#if os(iOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif

@MainActor
struct PhysiqueCameraSetupView: View {
    @ObservedObject var store: PhysiqueStore
    let onOpen: (PhysiqueRoute) -> Void

    init(store: PhysiqueStore, onOpen: @escaping (PhysiqueRoute) -> Void) {
        self.store = store
        self.onOpen = onOpen
    }

    @ObservedObject private var camera = PhysiqueCamera.shared
    @ObservedObject private var cloudAccount = CloudAccountStore.shared
    @Environment(\.physiqueWindowID) private var windowID
    @Environment(\.physiquePresentationActive) private var presentationActive
    @Environment(\.scenePhase) private var scenePhase
    @State private var operation: Operation?
    @State private var operationTask: Task<Void, Never>?
    @State private var revision = UUID()
    @State private var diagnosticRequested = false
    @State private var diagnosticImage: CGImage?
    @State private var localError: String?
    @State private var settingsDetail: String?
    @State private var showsDetails = false
    @State private var selectedDeviceID: String?
    @State private var sourceAspect: CGFloat = {
        #if os(iOS)
        return 3.0 / 4.0
        #else
        return 4.0 / 3.0
        #endif
    }()
    @AccessibilityFocusState private var statusFocused: Bool

    private enum Operation: Equatable {
        case starting, checking, finding, refreshing
    }

    private var hasLocalReview: Bool {
        diagnosticRequested && diagnosticImage != nil && camera.candidate != nil && camera.ownerID == windowID
    }

    private var hasControl: Bool {
        store.canControl(from: windowID) && (camera.ownerID == nil || camera.ownerID == windowID)
    }

    private var privacyRequirement: String? {
        guard store.signedIn else { return "Sign in to your Tmax account before camera setup." }
        if store.localProcessingStopped || store.localOwnMediaHidden {
            return "Sharing is protected on this device. Review and explicitly renew the required consent before continuing."
        }
        guard let policy = store.policy else { return "The current Physique service policy has not loaded." }
        guard policy.ready else { return policy.unavailableReason ?? "Physique matching is unavailable until the service is ready." }
        guard let account = store.account else { return "Your current Physique account status has not been confirmed." }
        if store.isStale { return "Your service status is out of date. Refresh before continuing." }
        if let reason = account.restrictedReason, !reason.isEmpty { return reason }
        guard account.consent.accepted, account.consent.policyVersion == policy.version else {
            return "Review the current adult eligibility, rules, AI processing and opponent-sharing choices before continuing. Camera permission is separate."
        }
        return nil
    }

    private var participationRequirement: String? {
        if let privacyRequirement { return privacyRequirement }
        if !hasControl { return "Another Physique window controls this session. Camera access and search stay off here." }
        if activeRoute != nil { return "A Physique search or duel already exists. Open it instead of starting another search." }
        if store.cancellationPending { return "The previous cancellation is not confirmed. Refresh the current status before starting another search." }
        if let remaining = store.account?.allowance.remaining, remaining <= 0 { return "No Physique matches are available in your current allowance." }
        return nil
    }

    private var activeRoute: PhysiqueRoute? {
        switch store.stage {
        case .searching: return .search
        case .ready: return .ready
        case .countdown, .capture, .submitting: return .battle
        case .judging: return .judging
        default: return nil
        }
    }

    private var cameraEngaged: Bool {
        camera.ownerID == windowID && (camera.status == .requesting || camera.status == .starting || camera.status.isRunning || camera.isCapturing || camera.candidate != nil)
    }

    private var statusTitle: String {
        switch operation {
        case .checking: return "Checking locally"
        case .finding: return "Rechecking camera and service"
        case .refreshing: return "Refreshing service status"
        case .starting: return camera.status.message
        case nil: return hasLocalReview ? "Local check · not sent" : camera.status.message
        }
    }

    private var primaryTitle: String {
        if operation == .finding { return "Checking before search…" }
        if operation == .checking { return "Checking locally…" }
        if hasLocalReview { return "Find opponent" }
        if diagnosticRequested && camera.status == .idle { return "Adjust setup" }
        switch camera.status {
        case .running: return "Check setup"
        case .requesting: return "Waiting for camera permission…"
        case .starting: return "Starting camera…"
        case .interrupted: return "Resume camera"
        case .denied, .unavailable, .failed: return "Retry camera"
        default: return "Start camera"
        }
    }

    private var primaryDisabled: Bool {
        operation != nil || store.busy || store.loading || !presentationActive || scenePhase != .active || participationRequirement != nil || camera.status == .requesting || camera.status == .starting || camera.status == .restricted || (!hasLocalReview && camera.status.isRunning && !camera.canCapture)
    }

    var body: some View {
        PhysiqueScreen(title: "Camera setup", subtitle: "Fit arms and legs in view. Your local check is not uploaded.") {
            cameraStage
            VStack(alignment: .leading, spacing: ProfileStyle.spacing) {
                Label(statusTitle, systemImage: hasLocalReview ? "lock.shield" : "camera")
                    .font(TimeMasterFont.heading())
                    .accessibilityAddTraits(.isHeader)
                    .accessibilityFocused($statusFocused)
                Text(hasLocalReview ? "Review the exact face-obscured sample. This is not a rated pose or service approval." : camera.framingMessage)
                    .font(TimeMasterFont.secondary())
                    .foregroundStyle(ProfileStyle.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                cameraDeviceControls
            }
            localChecks
            if let account = store.account {
                Label("\(account.allowance.remaining) of \(account.allowance.limit) Physique matches available\(store.isStale ? " · Last confirmed" : "")", systemImage: "ticket")
                    .font(TimeMasterFont.secondary())
                    .foregroundStyle(ProfileStyle.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if let requirement = participationRequirement {
                PhysiqueStatusView(title: "Before you continue", detail: requirement, systemImage: "hand.raised")
                requirementActions
            }
            if let message = localError ?? camera.error ?? store.error {
                PhysiqueStatusView(title: "Not confirmed", detail: message)
            }
            if let settingsDetail {
                Text(settingsDetail)
                    .font(TimeMasterFont.secondary())
                    .foregroundStyle(ProfileStyle.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if camera.status == .denied {
                PhysiqueAction(title: settingsTitle, systemImage: "gearshape", role: .cancel, action: openCameraSettings)
            }
            if camera.status == .restricted {
                Text("Camera access is controlled by device or administrator restrictions. Change those controls outside Tmax before trying again.")
                    .font(TimeMasterFont.secondary())
                    .foregroundStyle(ProfileStyle.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            DisclosureGroup("Setup details", isExpanded: $showsDetails) {
                VStack(alignment: .leading, spacing: ProfileStyle.spacing) {
                    Text("The local camera view is not mirrored. The protected sample uses the camera’s actual aspect ratio without cropping your body.")
                    Text("This check stays on your device. It does not use a pose slot, retake or match allowance. Leaving, stopping or adjusting setup discards it.")
                    Text("Face obscuring is not anonymity or identity verification. Check the background and mirrors. Only you may be in view.")
                    Text("Framing and ordinary, even light still need your review. Local checks do not approve attire or guarantee that later evidence will be accepted.")
                    Text("Each rated image needs its own protected review and current sharing consent. No camera video or local diagnostic accompanies the search request.")
                }
                .font(TimeMasterFont.secondary())
                .foregroundStyle(ProfileStyle.secondary)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, ProfileStyle.spacing)
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            actionLane
                .padding(ProfileStyle.inset)
                .frame(maxWidth: .infinity)
                .background(Theme.background)
        }
        .toolbar {
            ToolbarItemGroup(placement: .automatic) {
                #if os(macOS)
                if !camera.devices.isEmpty { cameraPicker }
                #endif
                Button(action: openGuide) { Label("Pose guide", systemImage: "figure.stand") }
                if cameraEngaged || operation != nil {
                    Button(action: stopSetup) { Label("Stop camera", systemImage: "stop.fill") }
                }
            }
        }
        .task { await refreshOnEntry() }
        .onReceive(camera.$previewImage) { image in
            guard let image else { return }
            let aspect = CGFloat(image.width) / CGFloat(image.height)
            if sourceAspect != aspect { sourceAspect = aspect }
        }
        .onReceive(camera.$selectedDeviceID) { selectedDeviceID = $0 }
        .onChange(of: selectedDeviceID) { selectCamera($0) }
        .onChange(of: camera.candidate != nil) { available in
            if !available {
                diagnosticRequested = false
                diagnosticImage = nil
            }
        }
        .onChange(of: camera.status) { status in
            switch status {
            case .denied, .restricted, .unavailable, .interrupted, .failed:
                diagnosticImage = nil
                diagnosticRequested = false
                statusFocused = true
            default: break
            }
        }
        .onChange(of: cloudAccount.accountID) { _ in stopSetup() }
        .onChange(of: privacyRequirement) { requirement in
            if requirement != nil { stopSetup() }
        }
        .onChange(of: store.privacyRevision) { _ in stopSetup() }
        .onChange(of: store.controllingWindowID) { _ in
            if !store.canControl(from: windowID) { stopSetup() }
        }
        .onChange(of: camera.ownerID) { owner in
            if owner != nil && owner != windowID { stopSetup() }
        }
        .onChange(of: presentationActive) { active in
            if !active { stopSetup() }
        }
        .onChange(of: scenePhase) { phase in
            if phase != .active { stopSetup() }
        }
        .onDisappear(perform: stopSetup)
    }

    private var cameraDeviceControls: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Camera").font(TimeMasterFont.caption()).foregroundStyle(ProfileStyle.secondary)
            #if os(iOS)
            if !camera.devices.isEmpty {
                cameraPicker.labelsHidden()
            } else {
                Text(camera.deviceName ?? "No camera selected").font(TimeMasterFont.rowTitle())
                    .fixedSize(horizontal: false, vertical: true)
            }
            #else
            Text(camera.deviceName ?? "No camera selected").font(TimeMasterFont.rowTitle())
                .fixedSize(horizontal: false, vertical: true)
            #endif
        }
    }

    private var cameraPicker: some View {
        Picker("Camera", selection: $selectedDeviceID) {
            if selectedDeviceID == nil {
                Text("Select a camera").tag(nil as String?)
            }
            if let selectedDeviceID, !camera.devices.contains(where: { $0.id == selectedDeviceID }) {
                Text("\(camera.deviceName ?? "Selected camera") · Disconnected").tag(Optional(selectedDeviceID))
            }
            ForEach(camera.devices) { device in
                Text(device.name).tag(Optional(device.id))
            }
        }
        .pickerStyle(.menu)
        .disabled(operation != nil || store.busy || participationRequirement != nil || camera.status == .restricted || !presentationActive || scenePhase != .active)
        .accessibilityLabel("Camera")
        .accessibilityHint("Changing camera discards the local check and starts a fresh private view.")
    }

    private var cameraStage: some View {
        ZStack {
            Theme.background
            if presentationActive && scenePhase == .active && hasControl && privacyRequirement == nil {
                if hasLocalReview, let diagnosticImage {
                    Image(decorative: diagnosticImage, scale: 1)
                        .resizable()
                        .scaledToFit()
                } else if operation == .checking || operation == .finding {
                    VStack(spacing: ProfileStyle.spacing) {
                        ProgressView()
                        Text(statusTitle).font(TimeMasterFont.secondary())
                    }
                } else {
                    PhysiqueCameraPreview(camera: camera)
                }
            } else {
                Image(systemName: "camera.fill")
                    .font(.largeTitle)
                    .foregroundStyle(ProfileStyle.secondary)
            }
        }
        .aspectRatio(sourceAspect, contentMode: .fit)
        .clipShape(RoundedRectangle(cornerRadius: ProfileStyle.corner, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: ProfileStyle.corner, style: .continuous)
                .strokeBorder(Theme.separator, lineWidth: 1)
                .allowsHitTesting(false)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(hasLocalReview ? "Local face-obscured check, not sent" : "Local camera preview")
        .accessibilityValue(statusTitle)
    }

    private var localChecks: some View {
        PhysiqueCard {
            checkRow("Framing", detail: hasLocalReview || camera.canCapture ? "Required body regions detected locally; review the full view" : "Include both arms and lower legs", symbol: "viewfinder")
            checkRow("Light", detail: "Use ordinary, even light; review the sample", symbol: "sun.max")
            checkRow("Privacy", detail: hasLocalReview ? "Exact locally obscured sample" : camera.canCapture ? "Face obscuring available locally" : "Waiting for a protected view", symbol: "lock.shield")
            checkRow("Alone", detail: hasLocalReview || camera.canCapture ? "One person detected locally; check mirrors and background" : "Single-person view not established", symbol: "person")
        }
    }

    private func checkRow(_ title: String, detail: String, symbol: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Label(title, systemImage: symbol).font(TimeMasterFont.rowTitle())
            Text(detail).font(TimeMasterFont.secondary()).foregroundStyle(ProfileStyle.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private var requirementActions: some View {
        if !store.signedIn {
            PhysiqueAction(title: "Sign in", systemImage: "person.crop.circle") { open(.account) }
        } else if !hasControl {
            PhysiqueAction(title: "Use this window", systemImage: "macwindow", action: takeControl)
        } else if let route = activeRoute {
            PhysiqueAction(title: "Open active match", systemImage: "arrow.right") { open(route) }
        } else if let policy = store.policy, policy.ready, let account = store.account,
                  store.localProcessingStopped || store.localOwnMediaHidden || !account.consent.accepted || account.consent.policyVersion != policy.version {
            PhysiqueAction(title: "Review eligibility and consent", systemImage: "checkmark.shield") { open(.consent) }
        } else {
            PhysiqueAction(title: "Refresh service status", systemImage: "arrow.clockwise", role: .cancel, disabled: operation != nil || store.loading || store.busy, action: refreshStatus)
            if let next = store.account?.allowance.nextAvailableAt {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Next Physique match available").font(TimeMasterFont.caption())
                    Text(Date(timeIntervalSince1970: next), format: .dateTime.month().day().hour().minute())
                        .font(TimeMasterFont.secondary())
                }
                .foregroundStyle(ProfileStyle.secondary)
                .accessibilityElement(children: .combine)
            }
        }
    }

    private var actionLane: some View {
        #if os(macOS)
        HStack(spacing: ProfileStyle.spacing) {
            if camera.status != .restricted {
                Button(primaryTitle, action: performPrimaryAction)
                    .buttonStyle(.borderedProminent)
                    .tint(Theme.toolbarOrange)
                    .disabled(primaryDisabled)
            }
            if hasLocalReview {
                Button("Adjust setup", action: startCamera).disabled(operation != nil)
            } else if cameraEngaged || operation != nil {
                Button("Stop camera", action: stopSetup)
            }
            Spacer(minLength: 0)
            Button("Close", action: closeSetup).keyboardShortcut(.cancelAction)
        }
        .frame(maxWidth: ProfileStyle.readableWidth)
        #else
        VStack(spacing: ProfileStyle.spacing) {
            if camera.status != .restricted {
                PhysiqueAction(title: primaryTitle, systemImage: hasLocalReview ? "person.2" : camera.status.isRunning ? "viewfinder" : "camera", disabled: primaryDisabled, action: performPrimaryAction)
            }
            HStack(spacing: ProfileStyle.spacing) {
                if hasLocalReview {
                    PhysiqueAction(title: "Adjust setup", systemImage: "arrow.counterclockwise", role: .cancel, disabled: operation != nil, action: startCamera)
                } else if cameraEngaged || operation != nil {
                    PhysiqueAction(title: "Stop camera", systemImage: "stop.fill", role: .cancel, action: stopSetup)
                }
                PhysiqueAction(title: "Close", role: .cancel, action: closeSetup)
            }
        }
        .frame(maxWidth: ProfileStyle.readableWidth)
        #endif
    }

    private func performPrimaryAction() {
        if hasLocalReview { findOpponent() }
        else if camera.status.isRunning { checkSetup() }
        else { startCamera() }
    }

    private func begin(_ next: Operation) -> UUID {
        operationTask?.cancel()
        revision = UUID()
        operation = next
        localError = nil
        settingsDetail = nil
        return revision
    }

    private func isCurrent(_ token: UUID) -> Bool {
        token == revision && !Task.isCancelled && presentationActive && scenePhase == .active && hasControl
    }

    private func finish(_ token: UUID) {
        guard token == revision else { return }
        operation = nil
        operationTask = nil
    }

    private func startCamera() {
        guard operation == nil, participationRequirement == nil, presentationActive, scenePhase == .active,
              store.claimControl(for: windowID) else { return }
        diagnosticRequested = false
        diagnosticImage = nil
        let token = begin(.starting)
        operationTask = Task {
            await camera.start(owner: windowID)
            finish(token)
        }
    }

    private func selectCamera(_ id: String?) {
        guard let id, id != camera.selectedDeviceID, operation == nil, participationRequirement == nil,
              camera.status != .restricted, presentationActive, scenePhase == .active,
              store.claimControl(for: windowID) else { return }
        stopSetup()
        let token = begin(.starting)
        operationTask = Task {
            await camera.selectDevice(id, owner: windowID)
            if isCurrent(token) { selectedDeviceID = camera.selectedDeviceID }
            finish(token)
        }
    }

    private func checkSetup() {
        guard operation == nil, participationRequirement == nil, camera.canCapture, camera.ownerID == windowID else { return }
        let token = begin(.checking)
        diagnosticRequested = true
        diagnosticImage = nil
        operationTask = Task {
            await camera.capture(pose: .front)
            guard isCurrent(token) else { finish(token); return }
            updateDiagnostic(camera.candidate)
            if !hasLocalReview {
                localError = camera.error ?? "The local check could not be prepared. Adjust setup and try again. Nothing was sent."
            }
            finish(token)
            statusFocused = true
        }
    }

    private func updateDiagnostic(_ data: Data?) {
        guard diagnosticRequested, camera.ownerID == windowID, camera.candidatePose == .front,
              let data, let source = CGImageSourceCreateWithData(data as CFData, nil),
              let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
            diagnosticImage = nil
            return
        }
        diagnosticImage = image
        sourceAspect = CGFloat(image.width) / CGFloat(image.height)
    }

    private func findOpponent() {
        guard operation == nil, hasLocalReview, participationRequirement == nil, let accountID = cloudAccount.accountID,
              store.claimControl(for: windowID) else { return }
        let token = begin(.finding)
        diagnosticRequested = false
        diagnosticImage = nil
        operationTask = Task {
            defer { finish(token) }
            await camera.start(owner: windowID)
            guard isCurrent(token) else { return }
            guard camera.ownerID == windowID, camera.canCapture else {
                localError = camera.error ?? camera.framingMessage
                statusFocused = true
                return
            }
            let refreshStarted = Date()
            await store.refresh()
            guard isCurrent(token), cloudAccount.accountID == accountID else { return }
            guard !store.loading, !store.isStale, store.error == nil,
                  let refreshed = store.lastRefreshedAt, refreshed >= refreshStarted else {
                localError = store.error ?? "Current service status is not confirmed. Refresh, then make a new local check."
                camera.stop(owner: windowID)
                statusFocused = true
                return
            }
            guard participationRequirement == nil, camera.canCapture, camera.ownerID == windowID else {
                localError = participationRequirement ?? "The camera no longer has a fresh protected view. Make a new local check."
                camera.stop(owner: windowID)
                statusFocused = true
                return
            }
            let admitted = await store.perform("enqueue")
            guard isCurrent(token), cloudAccount.accountID == accountID else { return }
            if admitted {
                open(activeRoute ?? .search)
            } else {
                localError = store.error ?? "Search was not confirmed. Refresh the current status before trying again."
                camera.stop(owner: windowID)
                statusFocused = true
            }
        }
    }


    private func refreshOnEntry() async {
        statusFocused = true
        if store.signedIn { await store.refresh() }
        else { await store.loadPolicy() }
    }

    private func refreshStatus() {
        guard operation == nil, !store.loading, !store.busy else { return }
        let token = begin(.refreshing)
        operationTask = Task {
            await refreshOnEntry()
            finish(token)
        }
    }

    private func stopSetup() {
        revision = UUID()
        operationTask?.cancel()
        operationTask = nil
        operation = nil
        diagnosticRequested = false
        diagnosticImage = nil
        camera.stop(owner: windowID)
    }

    private func takeControl() {
        stopSetup()
        store.transferControl(to: windowID)
    }

    private func open(_ route: PhysiqueRoute) {
        stopSetup()
        onOpen(route)
    }

    private func openGuide() { open(.guide) }
    private func closeSetup() { open(.lobby) }

    private var settingsTitle: String {
        #if os(iOS)
        return "Open Settings"
        #else
        return "Open System Settings"
        #endif
    }

    private func openCameraSettings() {
        stopSetup()
        #if os(iOS)
        let instructions = "In Settings, allow Tmax to use Camera. Return here and start the camera again; opening Settings does not grant access."
        settingsDetail = instructions
        guard let url = URL(string: UIApplication.openSettingsURLString) else {
            localError = "Settings could not be opened. \(instructions)"
            return
        }
        UIApplication.shared.open(url, options: [:]) { opened in
            if !opened {
                Task { @MainActor in localError = "Settings could not be opened. \(instructions)" }
            }
        }
        #else
        let instructions = "Open System Settings → Privacy & Security → Camera and review Tmax access. Return here and start the camera again."
        settingsDetail = instructions
        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.apple.systempreferences"),
              NSWorkspace.shared.open(url) else {
            localError = "System Settings could not be opened. \(instructions)"
            return
        }
        #endif
    }
}
