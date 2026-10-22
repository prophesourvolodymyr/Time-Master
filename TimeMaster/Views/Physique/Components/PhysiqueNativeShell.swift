import SwiftUI
#if os(macOS)
import AppKit
#elseif os(iOS)
import UIKit
#endif

private struct PhysiqueWindowIDKey: EnvironmentKey { static let defaultValue = UUID() }
private struct PhysiquePresentationKey: EnvironmentKey { static let defaultValue = true }
private struct PhysiqueLiveResizingKey: EnvironmentKey { static let defaultValue = false }
extension EnvironmentValues {
    var physiqueWindowID: UUID {
        get { self[PhysiqueWindowIDKey.self] }
        set { self[PhysiqueWindowIDKey.self] = newValue }
    }
    var physiquePresentationActive: Bool {
        get { self[PhysiquePresentationKey.self] }
        set { self[PhysiquePresentationKey.self] = newValue }
    }
    var physiqueLiveResizing: Bool {
        get { self[PhysiqueLiveResizingKey.self] }
        set { self[PhysiqueLiveResizingKey.self] = newValue }
    }
}

@MainActor
struct PhysiqueNativeShell<Content: View>: View {
    @ObservedObject var store: PhysiqueStore
    let onOpen: (PhysiqueRoute) -> Void
    private let content: Content
    @ObservedObject private var camera = PhysiqueCamera.shared
    @ObservedObject private var cloudAccount = CloudAccountStore.shared
    @Environment(\.physiqueWindowID) private var windowID
    @Environment(\.scenePhase) private var scenePhase
    @State private var windowActive = false
    @State private var liveResizing = false
    @State private var visible = false
    @State private var hasBeenActive = false
    @State private var privacyPaused = false
    @State private var restoring = false
    @State private var restorationError: String?
    @State private var protectionID = UUID()
    @State private var restorationTask: Task<Void, Never>?

    init(store: PhysiqueStore, onOpen: @escaping (PhysiqueRoute) -> Void, @ViewBuilder content: () -> Content) {
        self.store = store
        self.onOpen = onOpen
        self.content = content()
    }

    private var active: Bool { visible && scenePhase == .active && windowActive }
    private var covered: Bool { !active || privacyPaused || restoring }
    private var ownsCamera: Bool { camera.ownerID == windowID }
    private var otherWindowControlsMatch: Bool {
        store.controllingWindowID != nil && !store.canControl(from: windowID)
            && (store.stage == .searching || store.match?.stage.terminal == false)
    }

    var body: some View {
        content
            .environment(\.physiquePresentationActive, !covered)
            .environment(\.physiqueLiveResizing, liveResizing)
            .opacity(covered ? 0 : 1)
            .allowsHitTesting(!covered)
            .accessibilityHidden(covered)
            .background(Theme.background.ignoresSafeArea())
            .safeAreaInset(edge: .top, spacing: 0) {
                #if os(macOS)
                if otherWindowControlsMatch, !covered {
                    HStack(alignment: .firstTextBaseline, spacing: ProfileStyle.spacing) {
                        Label("Match open in another window", systemImage: "macwindow.on.rectangle")
                            .font(TimeMasterFont.caption())
                            .fixedSize(horizontal: false, vertical: true)
                        Spacer(minLength: 0)
                        if let owner = store.controllingWindowID, PhysiqueWindowRegistry.contains(owner) {
                            Button("Show match window", action: showMatchWindow)
                        } else {
                            Button("Check status", action: checkStatus)
                                .disabled(store.loading)
                        }
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .padding(.horizontal, ProfileStyle.inset)
                    .padding(.vertical, 8)
                    .foregroundStyle(Theme.textPrimary)
                    .background(Theme.surface)
                }
                #endif
            }
            .overlay {
                if covered {
                    PhysiquePrivacyCover(
                        active: active,
                        restoring: restoring,
                        waiting: store.loading,
                        error: restorationError,
                        onContinue: continueSession
                    )
                    .transition(.identity)
                    .transaction { $0.disablesAnimations = true }
                }
            }
            .animation(nil, value: covered)
            .toolbar {
                ToolbarItemGroup(placement: .automatic) {
                    Group {
                        Button(action: openSafety) {
                            Label("Safety", systemImage: "shield")
                        }
                        .help("Stop the camera and open Physique safety")
                        Button(action: openPrivacy) {
                            Label("Privacy", systemImage: "hand.raised")
                        }
                        .help("Stop the camera and open privacy choices")
                        if ownsCamera {
                            Button(action: stopCamera) {
                                Label("Stop camera", systemImage: "video.slash")
                            }
                            .help(camera.status.message)
                        }
                    }
                    .buttonStyle(.automatic)
                    .disabled(!active)
                }
            }
            .onAppear {
                visible = true
                activateIfPermitted()
            }
            .onChange(of: active) { enabled in
                if enabled { activateIfPermitted() }
            }
            .onChange(of: scenePhase) { phase in
                if phase != .active { protect() }
            }
            .onChange(of: cloudAccount.accountID) { _ in
                protect(forcePause: true)
                store.releaseControl(for: windowID)
                activateIfPermitted()
            }
            .onChange(of: store.controllingWindowID) { owner in
                if owner == nil { activateIfPermitted() }
                else if owner != windowID { store.camera.stop(owner: windowID) }
            }
            .onDisappear {
                visible = false
                protect()
                store.releaseControl(for: windowID)
            }
            #if os(macOS)
            .focusedSceneValue(\.physiqueNativeActions, nativeActions)
            .background(PhysiqueWindowObserver(
                windowID: windowID,
                onChange: setWindowActive,
                onResize: { liveResizing = $0 },
                onPrivacyStop: stopCamera
            ))
            #elseif os(iOS)
            .background(PhysiquePhoneActivityObserver(
                onChange: setWindowActive,
                onPrivacyStop: stopCamera
            ))
            #endif
    }

    private func activateIfPermitted() {
        guard active else { return }
        hasBeenActive = true
        if store.controllingWindowID == nil { _ = store.claimControl(for: windowID) }
    }

    private func setWindowActive(_ enabled: Bool) {
        if !enabled { protect() }
        windowActive = enabled
    }

    private func protect(forcePause: Bool = false) {
        store.camera.stop(owner: windowID)
        if store.canControl(from: windowID) { store.cancelReveals() }
        restorationTask?.cancel()
        restorationTask = nil
        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            protectionID = UUID()
            privacyPaused = forcePause || hasBeenActive || privacyPaused
            restoring = false
            restorationError = nil
        }
    }

    private func continueSession() {
        guard active, !restoring, !store.loading else { return }
        let expectedAccount = cloudAccount.accountID
        let expectedProtection = protectionID
        let requestedAt = Date()
        restoring = true
        restorationError = nil
        restorationTask = Task { @MainActor in
            await store.refresh()
            guard !Task.isCancelled, protectionID == expectedProtection,
                  active, cloudAccount.accountID == expectedAccount else { return }
            restoring = false
            restorationTask = nil
            if expectedAccount != nil {
                guard !store.isStale, store.account != nil,
                      let refreshedAt = store.lastRefreshedAt, refreshedAt >= requestedAt,
                      store.error == nil else {
                    restorationError = store.error ?? "Current status is not confirmed. Try again, or open Safety or Privacy."
                    return
                }
            }
            privacyPaused = false
            activateIfPermitted()
        }
    }

    private func stopCamera() { store.camera.stop(owner: windowID) }

    private func openSafety() { openProtected(.safety) }
    private func openPrivacy() { openProtected(.privacy) }

    private func openProtected(_ route: PhysiqueRoute) {
        guard active else { return }
        store.suspendCapture()
        restorationTask?.cancel()
        restorationTask = nil
        protectionID = UUID()
        restoring = false
        restorationError = nil
        onOpen(route)
        privacyPaused = false
    }

    private func checkStatus() {
        guard active, !store.loading else { return }
        if privacyPaused { continueSession() }
        else { Task { await store.refresh() } }
    }

    #if os(macOS)
    private var nativeActions: PhysiqueNativeActions {
        let cameraAction: (() -> Void)? = ownsCamera ? { stopCamera() } : nil
        let showsMatchWindow = store.controllingWindowID.map { PhysiqueWindowRegistry.contains($0) } ?? false
        let windowAction: (() -> Void)? = showsMatchWindow ? { showMatchWindow() } : nil
        return PhysiqueNativeActions(
            available: active,
            refreshing: restoring || store.loading,
            safety: openSafety,
            privacy: openPrivacy,
            checkStatus: checkStatus,
            stopCamera: cameraAction,
            showMatchWindow: windowAction
        )
    }

    private func showMatchWindow() {
        guard let owner = store.controllingWindowID else { return }
        PhysiqueWindowRegistry.show(owner)
    }
    #endif
}

private struct PhysiquePrivacyCover: View {
    let active: Bool
    let restoring: Bool
    let waiting: Bool
    let error: String?
    let onContinue: () -> Void
    @Environment(\.colorSchemeContrast) private var contrast
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()
            GeometryReader { geometry in
                let compact = geometry.size.width < 560 || dynamicTypeSize.isAccessibilitySize
                let inset: CGFloat = geometry.size.width < 700 ? 24 : 40

                ZStack {
                    PhysiquePrivacyCourtShape()
                        .stroke(
                            Theme.textPrimary.opacity(contrast == .increased ? 0.16 : 0.055),
                            lineWidth: 1
                        )
                        .rotationEffect(.degrees(-12))
                        .scaleEffect(1.15)
                        .offset(x: geometry.size.width * 0.3, y: geometry.size.height * 0.22)
                        .allowsHitTesting(false)
                        .accessibilityHidden(true)

                    ViewThatFits(in: .vertical) {
                        presentation(compact: compact)
                            .padding(inset)
                            .frame(maxWidth: 960)
                            .fixedSize(horizontal: false, vertical: true)

                        ScrollView {
                            presentation(compact: compact)
                                .padding(inset)
                                .frame(maxWidth: 960)
                                .frame(maxWidth: .infinity)
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                .clipped()
            }
        }
        .foregroundStyle(Theme.textPrimary)
        .accessibilityIdentifier("physique-privacy-cover")
    }

    private func presentation(compact: Bool) -> some View {
        VStack(alignment: .leading, spacing: compact ? 24 : 32) {
            HStack(spacing: ProfileStyle.spacing) {
                Rectangle()
                    .fill(Theme.toolbarOrange)
                    .frame(width: 4, height: 22)
                    .accessibilityHidden(true)
                Text("PHYSIQUE DUELS")
                    .font(TimeMasterFont.black(12, relativeTo: .caption))
                    .tracking(2)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: ProfileStyle.spacing)
                if compact {
                    PhysiquePrivacyCrest()
                        .frame(width: 56, height: 64)
                }
            }

            HStack(alignment: .center, spacing: 32) {
                if !compact {
                    PhysiquePrivacyCrest()
                        .frame(width: 168, height: 200)
                }
                VStack(alignment: .leading, spacing: ProfileStyle.spacing) {
                    Text("SESSION PRIVATE")
                        .font(TimeMasterFont.black(11, relativeTo: .caption2))
                        .tracking(2.4)
                        .foregroundStyle(ProfileStyle.secondary)
                    VStack(alignment: .leading, spacing: -8) {
                        Text("CAMERA")
                        Text("OFF")
                            .foregroundStyle(Theme.toolbarOrange)
                    }
                    .font(TimeMasterFont.black(compact ? 48 : 68, relativeTo: .largeTitle))
                    .tracking(-2)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("Camera off")
                    .accessibilityAddTraits(.isHeader)
                    Label("Media hidden", systemImage: "eye.slash")
                        .font(TimeMasterFont.secondary())
                        .foregroundStyle(ProfileStyle.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            Rectangle()
                .fill(contrast == .increased ? Theme.textPrimary.opacity(0.4) : Theme.separator)
                .frame(height: 1)
                .accessibilityHidden(true)

            if active, let error, !error.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Label("Status not confirmed", systemImage: "exclamationmark.circle")
                        .font(TimeMasterFont.rowTitle())
                    Text(error)
                        .font(TimeMasterFont.secondary())
                        .foregroundStyle(ProfileStyle.secondary)
                        .textSelection(.enabled)
                }
                .fixedSize(horizontal: false, vertical: true)
                .padding(.leading, ProfileStyle.inset)
                .overlay(alignment: .leading) {
                    Rectangle()
                        .fill(Theme.toolbarOrange)
                        .frame(width: 2)
                        .accessibilityHidden(true)
                }
            }

            let recoveryLayout = compact
                ? AnyLayout(VStackLayout(alignment: .leading, spacing: 20))
                : AnyLayout(HStackLayout(alignment: .center, spacing: 32))
            recoveryLayout {
                Text("Continue checks the session without starting the camera or reopening media.")
                    .font(TimeMasterFont.secondary())
                    .foregroundStyle(ProfileStyle.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
                recovery
                    .frame(
                        minWidth: compact ? 0 : 200,
                        maxWidth: compact ? .infinity : 240,
                        alignment: .leading
                    )
            }
        }
        .multilineTextAlignment(.leading)
    }

    @ViewBuilder
    private var recovery: some View {
        if active {
            if restoring || waiting {
                ProgressView("Checking current status")
                    .font(TimeMasterFont.secondary())
                    .tint(Theme.toolbarOrange)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(minHeight: ProfileStyle.touchTarget, alignment: .leading)
            } else {
                Button(action: onContinue) {
                    HStack(spacing: ProfileStyle.spacing) {
                        Text("Continue")
                        Spacer(minLength: ProfileStyle.spacing)
                        Image(systemName: "arrow.right")
                    }
                    .font(TimeMasterFont.label())
                    .foregroundStyle(Theme.background)
                    #if os(iOS)
                    .frame(minHeight: ProfileStyle.touchTarget)
                    #else
                    .padding(.vertical, 8)
                    #endif
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .tint(Theme.toolbarOrange)
                .accessibilityHint("Check the session without starting the camera or reopening media.")
            }
        } else {
            Text("Return to this window to continue.")
                .font(TimeMasterFont.label())
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

private struct PhysiquePrivacyCrest: View {
    @Environment(\.colorSchemeContrast) private var contrast

    var body: some View {
        ZStack {
            PhysiquePrivacyCrestShape()
                .fill(Theme.toolbarOrange)
            PhysiquePrivacyCrestShape()
                .fill(Theme.surface)
                .padding(2)
            PhysiquePrivacyCrestShape()
                .stroke(Theme.toolbarOrange.opacity(contrast == .increased ? 0.8 : 0.35), lineWidth: 1)
                .scaleEffect(0.82)
            PhysiquePrivacyPauseShape()
                .fill(Theme.toolbarOrange)
        }
        .accessibilityHidden(true)
    }
}

private struct PhysiquePrivacyCrestShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX + rect.width * 0.23, y: rect.minY + rect.height * 0.04))
        path.addLine(to: CGPoint(x: rect.minX + rect.width * 0.8, y: rect.minY + rect.height * 0.04))
        path.addLine(to: CGPoint(x: rect.minX + rect.width * 0.97, y: rect.minY + rect.height * 0.22))
        path.addLine(to: CGPoint(x: rect.minX + rect.width * 0.86, y: rect.minY + rect.height * 0.71))
        path.addLine(to: CGPoint(x: rect.minX + rect.width * 0.46, y: rect.minY + rect.height * 0.98))
        path.addLine(to: CGPoint(x: rect.minX + rect.width * 0.1, y: rect.minY + rect.height * 0.71))
        path.addLine(to: CGPoint(x: rect.minX + rect.width * 0.03, y: rect.minY + rect.height * 0.25))
        path.closeSubpath()
        return path
    }
}

private struct PhysiquePrivacyPauseShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX + rect.width * 0.32, y: rect.minY + rect.height * 0.28))
        path.addLine(to: CGPoint(x: rect.minX + rect.width * 0.46, y: rect.minY + rect.height * 0.28))
        path.addLine(to: CGPoint(x: rect.minX + rect.width * 0.39, y: rect.minY + rect.height * 0.68))
        path.addLine(to: CGPoint(x: rect.minX + rect.width * 0.25, y: rect.minY + rect.height * 0.68))
        path.closeSubpath()
        path.move(to: CGPoint(x: rect.minX + rect.width * 0.57, y: rect.minY + rect.height * 0.28))
        path.addLine(to: CGPoint(x: rect.minX + rect.width * 0.71, y: rect.minY + rect.height * 0.28))
        path.addLine(to: CGPoint(x: rect.minX + rect.width * 0.64, y: rect.minY + rect.height * 0.68))
        path.addLine(to: CGPoint(x: rect.minX + rect.width * 0.5, y: rect.minY + rect.height * 0.68))
        path.closeSubpath()
        return path
    }
}

private struct PhysiquePrivacyCourtShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX + rect.width * 0.28, y: rect.minY + rect.height * 0.08))
        path.addLine(to: CGPoint(x: rect.minX + rect.width * 0.72, y: rect.minY + rect.height * 0.08))
        path.addLine(to: CGPoint(x: rect.minX + rect.width * 0.96, y: rect.minY + rect.height * 0.92))
        path.addLine(to: CGPoint(x: rect.minX + rect.width * 0.04, y: rect.minY + rect.height * 0.92))
        path.closeSubpath()
        path.move(to: CGPoint(x: rect.minX + rect.width * 0.16, y: rect.midY))
        path.addLine(to: CGPoint(x: rect.minX + rect.width * 0.84, y: rect.midY))
        path.move(to: CGPoint(x: rect.minX + rect.width * 0.39, y: rect.minY + rect.height * 0.08))
        path.addLine(to: CGPoint(x: rect.minX + rect.width * 0.27, y: rect.minY + rect.height * 0.92))
        path.move(to: CGPoint(x: rect.minX + rect.width * 0.61, y: rect.minY + rect.height * 0.08))
        path.addLine(to: CGPoint(x: rect.minX + rect.width * 0.73, y: rect.minY + rect.height * 0.92))
        path.addEllipse(in: CGRect(
            x: rect.minX + rect.width * 0.37,
            y: rect.minY + rect.height * 0.39,
            width: rect.width * 0.26,
            height: rect.height * 0.22
        ))
        return path
    }
}

#if os(macOS)
private struct PhysiqueNativeActions {
    let available: Bool
    let refreshing: Bool
    let safety: () -> Void
    let privacy: () -> Void
    let checkStatus: () -> Void
    let stopCamera: (() -> Void)?
    let showMatchWindow: (() -> Void)?
}

private struct PhysiqueNativeActionsKey: FocusedValueKey {
    typealias Value = PhysiqueNativeActions
}

private extension FocusedValues {
    var physiqueNativeActions: PhysiqueNativeActions? {
        get { self[PhysiqueNativeActionsKey.self] }
        set { self[PhysiqueNativeActionsKey.self] = newValue }
    }
}

@MainActor
struct PhysiqueNativeCommands: Commands {
    @FocusedValue(\.physiqueNativeActions) private var actions

    var body: some Commands {
        CommandMenu("Physique") {
            Button("Show match window") { actions?.showMatchWindow?() }
                .disabled(actions?.showMatchWindow == nil)
            Divider()
            Button("Safety") { actions?.safety() }
                .disabled(actions?.available != true)
            Button("Privacy") { actions?.privacy() }
                .disabled(actions?.available != true)
            Button("Check status") { actions?.checkStatus() }
                .disabled(actions?.available != true || actions?.refreshing != false)
            Divider()
            Button("Stop camera") { actions?.stopCamera?() }
                .disabled(actions?.stopCamera == nil)
        }
    }
}

@MainActor
private enum PhysiqueWindowRegistry {
    private final class Reference {
        weak var window: NSWindow?
        init(_ window: NSWindow) { self.window = window }
    }
    private static var windows: [UUID: Reference] = [:]

    static func register(_ window: NSWindow, for id: UUID) { windows[id] = Reference(window) }
    static func remove(_ id: UUID, window: NSWindow?) {
        if windows[id]?.window === window { windows.removeValue(forKey: id) }
    }
    static func contains(_ id: UUID) -> Bool { windows[id]?.window != nil }
    static func show(_ id: UUID) {
        guard let window = windows[id]?.window else { return }
        if window.isMiniaturized { window.deminiaturize(nil) }
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
    }
}

@MainActor
private struct PhysiqueWindowObserver: NSViewRepresentable {
    let windowID: UUID
    let onChange: (Bool) -> Void
    let onResize: (Bool) -> Void
    let onPrivacyStop: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(windowID: windowID, onChange: onChange, onResize: onResize, onPrivacyStop: onPrivacyStop)
    }
    func makeNSView(context: Context) -> WindowProbe {
        let view = WindowProbe()
        view.didAttach = { [weak coordinator = context.coordinator] in coordinator?.attach($0) }
        return view
    }
    func updateNSView(_ nsView: WindowProbe, context: Context) {
        context.coordinator.onChange = onChange
        context.coordinator.onResize = onResize
        context.coordinator.onPrivacyStop = onPrivacyStop
    }
    static func dismantleNSView(_ nsView: WindowProbe, coordinator: Coordinator) { coordinator.detach() }

    final class WindowProbe: NSView {
        var didAttach: ((NSWindow?) -> Void)?
        override func viewDidMoveToWindow() { super.viewDidMoveToWindow(); didAttach?(window) }
    }

    @MainActor
    final class Coordinator {
        let windowID: UUID
        var onChange: (Bool) -> Void
        var onResize: (Bool) -> Void
        var onPrivacyStop: () -> Void
        private weak var window: NSWindow?
        private var observers: [(NotificationCenter, NSObjectProtocol)] = []
        private var shields: [ObjectIdentifier: NSView] = [:]
        private var lastActive: Bool?
        private var lastResizing = false
        private var appInactive = false
        private var systemAwake = true
        private var screensAwake = true
        private var sessionActive = true
        private var menuContextActive = false
        private var sheetBeginning = false

        init(windowID: UUID, onChange: @escaping (Bool) -> Void, onResize: @escaping (Bool) -> Void, onPrivacyStop: @escaping () -> Void) {
            self.windowID = windowID
            self.onChange = onChange
            self.onResize = onResize
            self.onPrivacyStop = onPrivacyStop
        }

        func attach(_ nextWindow: NSWindow?) {
            guard nextWindow !== window else { return }
            detach()
            window = nextWindow
            guard let window else { return }
            PhysiqueWindowRegistry.register(window, for: windowID)
            appInactive = !NSApp.isActive || NSApp.isHidden
            for name in [NSWindow.didBecomeKeyNotification, NSWindow.didResignKeyNotification,
                         NSWindow.didChangeOcclusionStateNotification, NSWindow.didDeminiaturizeNotification] {
                observe(name) { [weak self] _ in self?.update() }
            }
            for name in [NSWindow.willMiniaturizeNotification, NSWindow.willCloseNotification] {
                observe(name, object: window) { [weak self] _ in self?.publish(false) }
            }
            observe(NSWindow.willBeginSheetNotification, object: window) { [weak self] _ in
                guard let self else { return }
                self.sheetBeginning = true
                self.onPrivacyStop()
                self.update()
            }
            observe(NSWindow.didEndSheetNotification, object: window) { [weak self] _ in
                DispatchQueue.main.async { [weak self] in
                    self?.sheetBeginning = false
                    self?.update()
                }
            }
            observe(NSWindow.willStartLiveResizeNotification, object: window) { [weak self] _ in self?.setResizing(true) }
            observe(NSWindow.didEndLiveResizeNotification, object: window) { [weak self] _ in self?.setResizing(false) }
            for name in [NSApplication.willResignActiveNotification, NSApplication.willHideNotification,
                         NSApplication.willTerminateNotification] {
                observe(name) { [weak self] _ in self?.appInactive = true; self?.publish(false) }
            }
            for name in [NSApplication.didBecomeActiveNotification, NSApplication.didUnhideNotification] {
                observe(name) { [weak self] _ in
                    self?.appInactive = !NSApp.isActive || NSApp.isHidden
                    self?.update()
                }
            }
            observe(NSMenu.didBeginTrackingNotification) { [weak self] _ in
                self?.menuContextActive = self?.lastActive == true
            }
            observe(NSMenu.didEndTrackingNotification) { [weak self] _ in
                self?.menuContextActive = false
                self?.update()
            }
            let workspace = NSWorkspace.shared.notificationCenter
            observe(NSWorkspace.willSleepNotification, center: workspace) { [weak self] _ in
                self?.systemAwake = false
                self?.publish(false)
            }
            observe(NSWorkspace.screensDidSleepNotification, center: workspace) { [weak self] _ in
                self?.screensAwake = false
                self?.publish(false)
            }
            observe(NSWorkspace.sessionDidResignActiveNotification, center: workspace) { [weak self] _ in
                self?.sessionActive = false
                self?.publish(false)
            }
            observe(NSWorkspace.didWakeNotification, center: workspace) { [weak self] _ in
                self?.systemAwake = true
                self?.update()
            }
            observe(NSWorkspace.screensDidWakeNotification, center: workspace) { [weak self] _ in
                self?.screensAwake = true
                self?.update()
            }
            observe(NSWorkspace.sessionDidBecomeActiveNotification, center: workspace) { [weak self] _ in
                self?.sessionActive = true
                self?.update()
            }
            applyShields(active: false)
            DispatchQueue.main.async { [weak self] in self?.update() }
        }

        func detach() {
            if window != nil { onPrivacyStop() }
            PhysiqueWindowRegistry.remove(windowID, window: window)
            observers.forEach { $0.0.removeObserver($0.1) }
            observers.removeAll()
            shields.values.forEach { $0.removeFromSuperview() }
            shields.removeAll()
            window = nil
            lastActive = nil
            menuContextActive = false
            sheetBeginning = false
        }

        private func observe(_ name: Notification.Name, object: AnyObject? = nil, center: NotificationCenter = .default, action: @escaping @MainActor (Notification) -> Void) {
            let token = center.addObserver(forName: name, object: object, queue: .main) { notification in
                MainActor.assumeIsolated { action(notification) }
            }
            observers.append((center, token))
        }

        private func update() {
            guard let window else { return }
            var keyWindow = NSApp.keyWindow
            while let parent = keyWindow?.sheetParent ?? keyWindow?.parent { keyWindow = parent }
            let keyContext = keyWindow === window
                || (NSApp.keyWindow == nil && window.isMainWindow && (menuContextActive || sheetBeginning))
            let contextVisible = window.occlusionState.contains(.visible)
                || (keyContext && NSApp.keyWindow?.occlusionState.contains(.visible) == true)
            let active = !appInactive && systemAwake && screensAwake && sessionActive
                && NSApp.isActive && !NSApp.isHidden && window.isVisible
                && !window.isMiniaturized && contextVisible && keyContext
            publish(active)
            setResizing(window.inLiveResize)
        }

        private func publish(_ active: Bool) {
            applyShields(active: active)
            guard lastActive != active else { return }
            if !active { onPrivacyStop() }
            lastActive = active
            onChange(active)
        }

        private func setResizing(_ resizing: Bool) {
            guard resizing != lastResizing else { return }
            lastResizing = resizing
            onResize(resizing)
        }

        private func applyShields(active: Bool) {
            guard let window else { return }
            var protectedViews: [NSView] = []
            if (!active || window.attachedSheet != nil || sheetBeginning), let content = window.contentView {
                protectedViews.append(content)
            }
            if !active {
                var sheet = window.attachedSheet
                while let current = sheet {
                    if let content = current.contentView { protectedViews.append(content) }
                    sheet = current.attachedSheet
                }
            }
            let required = Set(protectedViews.map(ObjectIdentifier.init))
            for id in Array(shields.keys) where !required.contains(id) {
                shields.removeValue(forKey: id)?.removeFromSuperview()
            }
            for content in protectedViews {
                let id = ObjectIdentifier(content)
                guard shields[id] == nil else { continue }
                let shield = NSView(frame: content.bounds)
                shield.autoresizingMask = [.width, .height]
                shield.wantsLayer = true
                shield.layer?.backgroundColor = NSColor(Theme.background).cgColor
                shield.setAccessibilityElement(true)
                shield.setAccessibilityLabel("Private Physique content hidden")
                content.addSubview(shield, positioned: .above, relativeTo: nil)
                shields[id] = shield
                shield.displayIfNeeded()
            }
        }

        deinit {
            observers.forEach { $0.0.removeObserver($0.1) }
        }
    }
}
#elseif os(iOS)
@MainActor
private struct PhysiquePhoneActivityObserver: UIViewRepresentable {
    let onChange: (Bool) -> Void
    let onPrivacyStop: () -> Void

    func makeCoordinator() -> Coordinator { Coordinator(onChange: onChange, onPrivacyStop: onPrivacyStop) }
    func makeUIView(context: Context) -> WindowProbe {
        let view = WindowProbe()
        view.isUserInteractionEnabled = false
        view.didAttach = { [weak coordinator = context.coordinator] in coordinator?.attach($0) }
        return view
    }
    func updateUIView(_ uiView: WindowProbe, context: Context) {
        context.coordinator.onChange = onChange
        context.coordinator.onPrivacyStop = onPrivacyStop
    }
    static func dismantleUIView(_ uiView: WindowProbe, coordinator: Coordinator) { coordinator.detach() }

    final class WindowProbe: UIView {
        var didAttach: ((UIWindow?) -> Void)?
        override func didMoveToWindow() { super.didMoveToWindow(); didAttach?(window) }
    }

    @MainActor
    final class Coordinator {
        var onChange: (Bool) -> Void
        var onPrivacyStop: () -> Void
        private weak var window: UIWindow?
        private var observers: [NSObjectProtocol] = []
        private var shield: UIView?
        private var lastActive: Bool?
        private var interrupted = false

        init(onChange: @escaping (Bool) -> Void, onPrivacyStop: @escaping () -> Void) {
            self.onChange = onChange
            self.onPrivacyStop = onPrivacyStop
        }
        func attach(_ nextWindow: UIWindow?) {
            guard nextWindow !== window else { return }
            detach()
            window = nextWindow
            guard let window else { return }
            for name in [UIApplication.willResignActiveNotification, UIApplication.didEnterBackgroundNotification] {
                observe(name) { [weak self] _ in self?.interrupted = true; self?.publish(false) }
            }
            observe(UIApplication.didBecomeActiveNotification) { [weak self] _ in self?.interrupted = false; self?.update() }
            if let scene = window.windowScene {
                for name in [UIScene.willDeactivateNotification, UIScene.didEnterBackgroundNotification] {
                    observe(name, object: scene) { [weak self] _ in self?.interrupted = true; self?.publish(false) }
                }
                observe(UIScene.didActivateNotification, object: scene) { [weak self] _ in self?.interrupted = false; self?.update() }
            }
            observe(UIWindow.didBecomeKeyNotification, object: window) { [weak self] _ in self?.update() }
            observe(UIWindow.didResignKeyNotification, object: window) { [weak self] _ in self?.publish(false) }
            applyShield(active: false)
            DispatchQueue.main.async { [weak self] in self?.update() }
        }
        func detach() {
            if window != nil { onPrivacyStop() }
            observers.forEach(NotificationCenter.default.removeObserver)
            observers.removeAll()
            shield?.removeFromSuperview()
            shield = nil
            window = nil
            lastActive = nil
        }
        private func observe(_ name: Notification.Name, object: AnyObject? = nil, action: @escaping @MainActor (Notification) -> Void) {
            observers.append(NotificationCenter.default.addObserver(forName: name, object: object, queue: .main) { notification in
                MainActor.assumeIsolated { action(notification) }
            })
        }
        private func update() {
            guard let window else { return }
            publish(!interrupted && UIApplication.shared.applicationState == .active
                    && window.windowScene?.activationState == .foregroundActive
                    && window.isKeyWindow && !window.isHidden)
        }
        private func publish(_ active: Bool) {
            applyShield(active: active)
            guard lastActive != active else { return }
            if !active { onPrivacyStop() }
            lastActive = active
            onChange(active)
        }
        private func applyShield(active: Bool) {
            if active {
                shield?.removeFromSuperview()
                shield = nil
            } else if shield == nil, let window {
                let shield = UIView(frame: window.bounds)
                shield.autoresizingMask = [.flexibleWidth, .flexibleHeight]
                shield.backgroundColor = UIColor(Theme.background)
                shield.isAccessibilityElement = true
                shield.accessibilityLabel = "Private Physique content hidden"
                window.addSubview(shield)
                self.shield = shield
                shield.layer.displayIfNeeded()
            }
        }
        deinit { observers.forEach(NotificationCenter.default.removeObserver) }
    }
}
#endif
