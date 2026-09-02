#if os(iOS)
import SwiftUI
import UIKit
import UniformTypeIdentifiers

@MainActor
struct OutdoorRouteRecordingView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @ObservedObject private var store: OutdoorActivityStore
    @ObservedObject private var preferences: OutdoorRecordingPreferencesStore
    @StateObject private var recorder: OutdoorLocationRecorder
    @StateObject private var musicSession: OutdoorMusicSession
    @ObservedObject private var musicManager: MusicManager
    private let musicLibrary: MusicLibraryStore
    @Binding private var exposedFinishedActivity: OutdoorActivity?
    private let initialActivityID: UUID?
    private let initialLibraryEntry: MusicLibraryItem?

    @Namespace private var glassNamespace
    @State private var committedKind: OutdoorActivityKind
    @State private var previewKind: OutdoorActivityKind
    @State private var mainContent: OutdoorMainContent = .start
    @State private var mainDetent: OutdoorPineDetent = .compact
    @State private var mainHeight: CGFloat = 0
    @State private var feature: OutdoorRouteFeature?
    @State private var rememberedFeature: OutdoorRouteFeature = .music
    @State private var featureHeight: CGFloat = 0
    @State private var mainHeightBeforeFeature: CGFloat?
    @State private var rememberedFeatureHeights: [OutdoorRouteFeature: CGFloat] = [:]
    @State private var musicHeightManuallyAdjusted = false
    @State private var musicEditorResetToken = 0
    @State private var mainDrag = OutdoorPineDragState()
    @State private var featureDrag = OutdoorPineDragState()
    @State private var maxDrawerOffset: CGFloat = 0
    @State private var finishModalPresented = false
    @State private var shortSessionReason: String?
    @State private var mapMode: OutdoorMapMode = .explore
    @State private var activeMapMode: OutdoorMapMode = .explore
    @State private var mapCapabilities: [OutdoorMapMode: OutdoorMapCapability] = [:]
    @State private var weatherState: OutdoorWeatherState = .disabled
    @State private var mapFocusRequestID = 0
    @State private var mapCityFitRequestID = 0
    @State private var mapFollowsUser = false
    @State private var upperQuickFeature: OutdoorUpperQuickFeature?
    @State private var mapOfflineMessage: String?
    @State private var mapControlsHeight: CGFloat = 134
    @State private var pineFinishedActivity: OutdoorActivity?
    @State private var libraryActivityID: UUID?
    @State private var didConfigureInitialContent = false
    @State private var showingMusicFileImporter = false
    @State private var musicImportError: String?
    @AccessibilityFocusState private var focusedFeature: OutdoorRouteFeature?

    init(
        kind: OutdoorActivityKind,
        store: OutdoorActivityStore,
        plannedRoute: PlannedRoute? = nil,
        preferences: OutdoorRecordingPreferencesStore,
        musicLibrary: MusicLibraryStore,
        initialActivityID: UUID? = nil,
        initialLibraryEntry: MusicLibraryItem? = nil,
        finishedActivity: Binding<OutdoorActivity?> = .constant(nil)
    ) {
        let normalizedKind = kind
        self.initialActivityID = initialActivityID
        self.initialLibraryEntry = initialLibraryEntry
        self.musicLibrary = musicLibrary
        self._store = ObservedObject(wrappedValue: store)
        self._preferences = ObservedObject(wrappedValue: preferences)
        self._recorder = StateObject(
            wrappedValue: OutdoorLocationRecorder(
                kind: normalizedKind,
                store: store,
                preferences: preferences,
                plannedRoute: plannedRoute
            )
        )
        self._musicSession = StateObject(wrappedValue: OutdoorMusicSession())
        self._exposedFinishedActivity = finishedActivity
        self._musicManager = ObservedObject(wrappedValue: MusicManager.shared)
        self._committedKind = State(initialValue: normalizedKind)
        self._previewKind = State(initialValue: normalizedKind)
    }

    var body: some View {
        GeometryReader { proxy in
            let showsCompactPlayer = musicManager.currentTrack != nil && mainContent != .finish
            let layout = OutdoorPineGeometry(
                size: proxy.size,
                safeAreaTop: proxy.safeAreaInsets.top,
                safeAreaBottom: proxy.safeAreaInsets.bottom,
                playerReserve: showsCompactPlayer ? 94 : 0
            )
            let offlineCapabilities = OutdoorMapMode.allCases.map { OutdoorMapProviderConfiguration.main.capability(for: $0) }
            let quickGeometry = upperQuickGeometry(for: layout)
            ZStack(alignment: .topLeading) {
                OutdoorMapLibreView(
                    points: displayedMapPoints,
                    followsUser: mapFollowsUser,
                    state: recorder.state,
                    plannedPoints: recorder.plannedPoints,
                    mode: mapMode,
                    focusRequestID: mapFocusRequestID,
                    cityFitRequestID: mapCityFitRequestID,
                    weatherInfoEnabled: preferences.preferences.weatherInfo,
                    onCapabilityChange: { capability in
                        mapCapabilities[capability.mode] = capability
                        if capability.mode == mapMode, capability.isUsable {
                            activeMapMode = capability.mode
                        }
                    },
                    onWeatherStateChange: { state in
                        weatherState = state
                    },
                    onFollowStateChange: { followsUser in
                        mapFollowsUser = followsUser
                    },
                    onFocusFailure: { message in
                        mapFollowsUser = false
                        mapOfflineMessage = message
                    }
                )
                .ignoresSafeArea()
                if let mapOfflineMessage {
                    OutdoorRouteNotification(
                        message: mapOfflineMessage,
                        systemImage: "arrow.down.circle",
                        onDismiss: { self.mapOfflineMessage = nil }
                    )
                    .padding(.top, layout.safeAreaTop + 12)
                    .padding(.horizontal, 16)
                    .frame(maxWidth: .infinity, alignment: .top)
                    .zIndex(60)
                } else if let shortSessionReason {
                    OutdoorRouteNotification(
                        message: shortSessionReason,
                        systemImage: "exclamationmark.triangle",
                        onDismiss: { self.shortSessionReason = nil }
                    )
                    .padding(.top, layout.safeAreaTop + 12)
                    .padding(.horizontal, 16)
                    .frame(maxWidth: .infinity, alignment: .top)
                    .zIndex(60)
                }


                if upperQuickFeature == nil,
                   (mainContent == .start || mainContent == .live),
                   mainDetent != .max,
                   quickGeometry.opacity > 0 {
                    OutdoorMapQuickStack(
                        opacity: quickGeometry.opacity,
                        onSelect: openUpperQuick
                    )
                    .frame(width: 44, height: OutdoorPineGeometry.quickStackHeight)
                    .position(x: 33, y: quickGeometry.top + (OutdoorPineGeometry.quickStackHeight / 2))
                    .zIndex(4)
                }

                if upperQuickFeature == nil,
                   (mainContent == .start || mainContent == .live),
                   mainDetent != .max {
                    mapControls(layout)
                        .zIndex(5)
                }


                if canDismissRoute {
                    OutdoorRouteIdleCloseControl(onDismiss: { dismiss() })
                        .padding(.top, layout.safeAreaTop + 12)
                        .padding(.trailing, 10)
                        .frame(maxWidth: .infinity, alignment: .topTrailing)
                        .zIndex(6)
                }

                if let upperQuickFeature {
                    OutdoorUpperQuickPine(
                        feature: upperQuickFeature,
                        namespace: glassNamespace,
                        mapMode: mapMode,
                        activeMapMode: activeMapMode,
                        mapCapabilities: mapCapabilities,
                        preferences: preferences,
                        offlineCapabilities: offlineCapabilities,
                        onMapMode: selectMapMode,
                        onManageMusic: { focusMusicFromUpperQuick(layout: layout) },
                        onDismiss: closeUpperQuick,
                        height: layout.usableHeight * 0.30
                    )
                    .padding(.top, layout.safeAreaTop + 12)
                    .transition(
                        reduceMotion
                            ? .opacity
                            : .scale(scale: 0.08, anchor: upperQuickOrigin(for: upperQuickFeature, layout: layout))
                                .combined(with: .opacity)
                    )
                    .zIndex(40)
                }

                mainPine(layout)

                featurePine(layout)
                    .opacity(feature == nil ? 0 : 1)
                    .offset(y: feature == nil ? layout.size.height : 0)
                    .allowsHitTesting(feature != nil)
                    .accessibilityHidden(feature == nil)
                if showsCompactPlayer {
                    OutdoorCompactPlayerView(
                        musicManager: musicManager,
                        namespace: glassNamespace,
                        onEdit: {
                            if feature != .music { toggleFeature(.music, layout: layout) }
                        }
                    )
                    .padding(.horizontal, 10)
                    .padding(.bottom, layout.safeAreaBottom + 6)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                    .transition(reduceMotion ? .opacity : .move(edge: .bottom).combined(with: .opacity))
                    .zIndex(50)
                }

            }
            .animation(
                reduceMotion ? .none : .spring(response: 0.28, dampingFraction: 0.9),
                value: mapOfflineMessage != nil || shortSessionReason != nil
            )
            .background(Theme.background)
            .onAppear {
                configureInitialContent()
                configureInitialGeometry(layout)
            }
            .onChange(of: proxy.size) { _ in
                configureInitialGeometry(layout)
            }
            .onChange(of: recorder.activeActivity?.id) { activityID in
                guard let activityID, let activity = recorder.activeActivity else { return }
                committedKind = activity.kind
                previewKind = activity.kind
                musicSession.start(activityID: activityID, existingEvents: activity.playedTracks)
            }
            .onChange(of: recorder.state) { state in
                if state == .recording || state == .manualPaused || state == .autoPaused || state == .requestingAuthorization {
                    mainContent = .live
                }
            }
            .onChange(of: feature) { next in
                DispatchQueue.main.async {
                    focusedFeature = next
                }
            }
            .onChange(of: preferences.preferences) { _ in
                recorder.applyPreferences()
            }
            .onChange(of: scenePhase) { phase in
                guard phase == .inactive || phase == .background else { return }
                recorder.checkpoint(at: Date())
            }
            .onDisappear {
                musicLibrary.resetRouteSession()
                musicSession.stop()
            }
        }
        .fileImporter(
            isPresented: $showingMusicFileImporter,
            allowedContentTypes: [.audio, .movie, .mp3, .mpeg4Audio],
            allowsMultipleSelection: true,
            onCompletion: importLocalMusic
        )
        .alert(
            "Import Failed",
            isPresented: Binding(
                get: { musicImportError != nil },
                set: { if !$0 { musicImportError = nil } }
            )
        ) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(musicImportError ?? "")
        }
    }

    private func importLocalMusic(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let URLs):
            Task {
                do {
                    for URL in URLs {
                        let isVideo = ["mov", "mp4", "m4v", "avi", "mkv"].contains(URL.pathExtension.lowercased())
                        if isVideo {
                            try await musicManager.importTrackAsync(from: URL)
                        } else {
                            musicManager.importTrack(from: URL)
                        }
                    }
                    musicLibrary.adoptMusicManagerTracks()
                } catch {
                    musicImportError = error.localizedDescription
                }
            }
        case .failure(let error):
            musicImportError = error.localizedDescription
        }
    }

    private func configureInitialContent() {
        guard !didConfigureInitialContent else { return }
        didConfigureInitialContent = true

        let requestedActivity = initialActivityID.flatMap { activityID in
            store.activities.first(where: { $0.id == activityID })
        }
        let candidate = requestedActivity ?? recorder.activeActivity ?? store.recoverableActivities.first

        if let candidate {
            if candidate.establishedAt != nil {
                libraryActivityID = candidate.id
                mainContent = .library
                mainDetent = .medium
            } else if candidate.finished {
                pineFinishedActivity = candidate
                exposedFinishedActivity = candidate
                mainContent = .finish
            } else {
                committedKind = candidate.kind
                previewKind = candidate.kind
                if recorder.resumeAfterFinish(candidate) {
                    mainContent = .live
                } else {
                    shortSessionReason = recorder.errorMessage
                }
            }
        }
        if initialLibraryEntry != nil, mainContent == .start {
            feature = .music
        }
        if let active = recorder.activeActivity, !active.finished {
            musicSession.start(activityID: active.id, existingEvents: active.playedTracks)
        }
    }
    private func configureInitialGeometry(_ layout: OutdoorPineGeometry) {
        guard layout.usableHeight > 1 else { return }
        if mainHeight == 0 {
            if mainContent == .library {
                mainDetent = .medium
                mainHeight = layout.libraryHeight
            } else {
                mainHeight = layout.mainHeight(for: mainDetent)
            }
        }
        if feature != nil, featureHeight == 0 {
            featureHeight = preferredFeatureHeight(for: feature, layout: layout)
        }
    }
    private var canDismissRoute: Bool {
        (recorder.state == .idle || recorder.state == .failed)
            && recorder.activeActivity == nil
            && exposedFinishedActivity == nil
            && pineFinishedActivity == nil
            && mainContent != .library
            && mainContent != .finish
    }

    private func mapControls(_ layout: OutdoorPineGeometry) -> some View {
        let mainFrame = displayedMainHeight(layout)
        let mainTop = layout.mainTop(
            mainHeight: mainFrame,
            featureHeight: feature != nil && mainDetent != .max ? featureHeight : nil
        )
        let controlsHeight = max(134, mapControlsHeight)
        let hasRoom = mainTop - layout.safeAreaTop >= controlsHeight + 18
        let bottomClearance = max(18, layout.size.height - mainTop + 18)
        return VStack(spacing: 0) {
            Spacer(minLength: 0)
            OutdoorMapControls(
                weatherState: weatherState,
                weatherInfoEnabled: preferences.preferences.weatherInfo,
                followsUser: mapFollowsUser,
                mapAttribution: (
                    mapCapabilities[activeMapMode]
                        ?? OutdoorMapProviderConfiguration.main.capability(for: activeMapMode)
                ).attribution,
                onDownload: {
                    mapCityFitRequestID &+= 1
                    mapOfflineMessage = "Map view resized to city scale. Offline area selection is not available yet."
                },
                onFocusLocation: focusMapLocation
            )
            .background {
                GeometryReader { proxy in
                    Color.clear.preference(
                        key: OutdoorMapControlsHeightKey.self,
                        value: proxy.size.height
                    )
                }
            }
            .onPreferenceChange(OutdoorMapControlsHeightKey.self) { height in
                guard height > 0, abs(height - mapControlsHeight) > 0.5 else { return }
                withoutAnimation { mapControlsHeight = height }
            }
            .frame(maxWidth: .infinity, alignment: .trailing)
            .padding(.trailing, 8)
            .padding(.bottom, bottomClearance)
        }
        .frame(width: layout.size.width, height: layout.size.height)
        .opacity(hasRoom ? 1 : 0)
        .allowsHitTesting(hasRoom)
    }


    private func focusMapLocation() {
        mapOfflineMessage = nil
        mapFocusRequestID &+= 1
    }

    private func selectMapMode(_ mode: OutdoorMapMode) {
        selectionHaptic()
        animate {
            mapMode = mode
            mapOfflineMessage = nil
        }
    }

    private func openUpperQuick(_ feature: OutdoorUpperQuickFeature) {
        selectionHaptic()
        withAnimation(reduceMotion ? .easeOut(duration: 0.18) : .spring(response: 0.34, dampingFraction: 0.88)) {
            upperQuickFeature = feature
        }
    }

    private func closeUpperQuick() {
        withAnimation(reduceMotion ? .easeOut(duration: 0.18) : .spring(response: 0.34, dampingFraction: 0.88)) {
            upperQuickFeature = nil
        }
    }

    private func focusMusicFromUpperQuick(layout: OutdoorPineGeometry) {
        closeUpperQuick()
        toggleFeature(.music, layout: layout)
    }

    private func upperQuickOrigin(for feature: OutdoorUpperQuickFeature, layout: OutdoorPineGeometry) -> UnitPoint {
        let index: CGFloat
        switch feature {
        case .map: index = 0
        case .trophy: index = 1
        case .settings: index = 2
        }
        let center = upperQuickGeometry(for: layout).top + 3 + index * 45 + 22
        let top = layout.safeAreaTop + 12
        let y = min(1, max(0, (center - top) / 246))
        return UnitPoint(x: min(1, max(0, 28 / max(1, layout.size.width))), y: y)
    }


    private func upperQuickGeometry(for layout: OutdoorPineGeometry) -> OutdoorUpperQuickGeometry {
        let mainFrame = displayedMainHeight(layout)
        let mainTop = layout.mainTop(
            mainHeight: mainFrame,
            featureHeight: feature != nil && mainDetent != .max ? featureHeight : nil
        )
        return OutdoorUpperQuickGeometry(
            top: layout.quickStackTop(mainTop: mainTop),
            opacity: layout.quickStackOpacity(mainTop: mainTop)
        )
    }

    private func mainPine(_ layout: OutdoorPineGeometry) -> some View {
        let isMax = mainDetent == .max
        let height = displayedMainHeight(layout)
        let top = isMax ? layout.safeAreaTop : layout.mainTop(
            mainHeight: height,
            featureHeight: feature != nil && !isMax ? featureHeight : nil
        )
        let expansion = mainExpansion(height, layout: layout)
        let cornerRadius: CGFloat = isMax ? 0 : 26

        return OutdoorPineGlassSurface(
            identity: "route-main-pine",
            namespace: glassNamespace,
            cornerRadius: cornerRadius,
            flat: isMax,
            interactive: true
        ) {
            ZStack(alignment: .top) {
                mainContentView(expansion: expansion, layout: layout)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)


                mainHandle(layout)
                    .allowsHitTesting(!finishModalPresented)
                    .accessibilityHidden(finishModalPresented)

                if !finishModalPresented && ((mainDetent == .expanded && !mainDrag.isDragging) || isMax) {
                    Button {
                        toggleMax(layout)
                    } label: {
                        Image(systemName: isMax ? "arrow.down.right.and.arrow.up.left" : "arrow.up.left.and.arrow.down.right")
                            .font(.system(size: 17, weight: .semibold))
                    }
                    .buttonStyle(.plain)
                    .frame(width: 48, height: 48)
                    .padding(.top, 4)
                    .padding(.trailing, 6)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                    .accessibilityLabel(isMax ? "Exit maximum route view" : "Enter maximum route view")
                    .accessibilityValue(isMax ? "Maximum" : "Full")
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(maxWidth: .infinity)
        .frame(height: height)
        .padding(.horizontal, isMax ? 0 : 10)
        .offset(y: top)
        .zIndex(isMax ? 20 : 8)
    }

    private func featurePine(_ layout: OutdoorPineGeometry) -> some View {
        let selectedFeature = feature ?? rememberedFeature
        let isMaxDrawer = mainDetent == .max
        let height = isMaxDrawer ? min(featureHeight, layout.usableHeight * 0.31) : max(1, featureHeight)
        let top = layout.size.height - layout.lowerInset - height
        let cornerRadius: CGFloat = isMaxDrawer ? 28 : 25

        return OutdoorPineGlassSurface(
            identity: "route-feature-pine",
            namespace: glassNamespace,
            cornerRadius: cornerRadius,
            flat: false,
            interactive: true
        ) {
            ZStack(alignment: .bottom) {
                featureContent(selectedFeature, layout: layout)
                    .transition(reduceMotion ? .opacity : .opacity.combined(with: .scale(scale: 0.985, anchor: .bottom)))
                    .animation(reduceMotion ? .easeOut(duration: 0.16) : .spring(response: 0.34, dampingFraction: 0.88), value: feature)
                    .frame(height: layout.usableHeight)
                    .accessibilityFocused($focusedFeature, equals: selectedFeature)
            }
            .frame(maxWidth: .infinity)
            .frame(height: height, alignment: .bottom)
            .overlay(alignment: .top) {
                featureHandle(layout, isMaxDrawer: isMaxDrawer)
            }
            .clipped()
            .contentShape(Rectangle())
        }
        .frame(maxWidth: .infinity)
        .frame(height: height)
        .offset(y: top + (isMaxDrawer ? maxDrawerOffset : 0))
        .opacity(min(1, max(0, (height - 1) / 44)))
        .padding(.horizontal, isMaxDrawer ? 0 : 10)
        .zIndex(30)
    }

    @ViewBuilder
    private func mainContentView(expansion: CGFloat, layout: OutdoorPineGeometry) -> some View {
        switch mainContent {
        case .start:
            OutdoorStartContent(
                expansion: expansion,
                isDragging: mainDrag.isDragging,
                committedKind: committedKind,
                activeFeature: feature,
                onLibrary: { openLibrary(layout) },
                onStart: startRecording,
                onFeature: { next in
                    toggleFeature(next, layout: layout)
                }
            )
        case .live:
            OutdoorLiveContent(
                recorder: recorder,
                preferences: preferences,
                expansion: expansion,
                isDragging: mainDrag.isDragging,
                onMusic: { toggleFeature(.music, layout: layout) },
                onFinish: { finishRecording(layout) },
                onTogglePause: togglePause,
                onHeart: {},
                onRetry: startRecording,
                onOpenSettings: openLocationSettings
            )
        case .finish:
            OutdoorFinishContent(
                store: store,
                preferences: preferences,
                activity: pineFinishedActivity ?? exposedFinishedActivity ?? recorder.activeActivity,
                points: finalizedPoints(),
                expansion: expansion,
                onResume: resumeFinished,
                onEstablished: { _ in
                    shortSessionReason = nil
                    libraryActivityID = nil
                    exposedFinishedActivity = nil
                    recorder.clearFinishedSession()
                    musicSession.reset()
                    musicLibrary.resetRouteSession()
                    pineFinishedActivity = nil
                    mainContent = .start
                    mainDetent = .compact
                    animate { mainHeight = layout.mainCompactHeight }
                },
                onDeleted: {
                    shortSessionReason = nil
                    recorder.clearFinishedSession()
                    musicSession.reset()
                    musicLibrary.resetRouteSession()
                    pineFinishedActivity = nil
                    exposedFinishedActivity = nil
                    libraryActivityID = nil
                    mainContent = .start
                    mainDetent = .compact
                    animate { mainHeight = layout.mainCompactHeight }
                },
                onModalStateChange: { finishModalPresented = $0 }
            )
        case .library:
            OutdoorLibraryContent(
                store: store,
                preferences: preferences,
                initialActivityID: libraryActivityID ?? initialActivityID,
                onClose: closeLibrary,
                onSelectedActivityIDChange: { libraryActivityID = $0 }
            )
        }
    }

    private func featureContent(_ selectedFeature: OutdoorRouteFeature, layout: OutdoorPineGeometry) -> some View {
        ZStack {
            OutdoorTypePicker(
                previewKind: $previewKind,
                committedKind: committedKind,
                onCommit: commitType
            )
            .opacity(selectedFeature == .type ? 1 : 0)
            .allowsHitTesting(selectedFeature == .type)
            .accessibilityHidden(selectedFeature != .type)

            OutdoorMusicFeatureSlot(
                library: musicLibrary,
                musicManager: musicManager,
                entry: initialLibraryEntry,
                resetToken: musicEditorResetToken,
                onImportLocalMusic: { showingMusicFileImporter = true },
                onMeasuredHeight: { height in
                    guard feature == .music else { return }
                    applyMusicContentFit(height, layout: layout)
                }
            )
            .opacity(selectedFeature == .music ? 1 : 0)
            .allowsHitTesting(selectedFeature == .music)
            .accessibilityHidden(selectedFeature != .music)

            if selectedFeature == .rate || selectedFeature == .route {
                Color.clear
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .accessibilityHidden(true)
            }
        }
        .animation(reduceMotion ? .none : .easeOut(duration: 0.18), value: selectedFeature)
    }

    private func mainHandle(_ layout: OutdoorPineGeometry) -> some View {
        Capsule()
            .fill(Color.white.opacity(0.76))
            .frame(width: 56, height: 5)
            .frame(width: 132, height: 48)
            .contentShape(Rectangle())
            .gesture(mainDragGesture(layout))
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Route pane handle")
            .accessibilityValue(mainDetent.accessibilityName)
            .accessibilityAdjustableAction { direction in
                adjustMainDetent(direction, layout: layout)
            }
    }

    private func featureHandle(_ layout: OutdoorPineGeometry, isMaxDrawer: Bool) -> some View {
        Capsule()
            .fill(Color.white.opacity(0.72))
            .frame(width: 54, height: 5)
            .frame(width: 132, height: 48)
            .contentShape(Rectangle())
            .gesture(featureDragGesture(layout, isMaxDrawer: isMaxDrawer))
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("\(feature?.title ?? "Feature") pane handle")
            .accessibilityValue(featureDetentName(layout, isMaxDrawer: isMaxDrawer))
            .accessibilityAdjustableAction { direction in
                adjustFeatureDetent(direction, layout: layout)
            }
            .accessibilityAction(named: "Dismiss") {
                closeFeature()
            }
    }

    private func mainDragGesture(_ layout: OutdoorPineGeometry) -> some Gesture {
        DragGesture(minimumDistance: 0, coordinateSpace: .global)
            .onChanged { value in
                guard mainDetent != .max else { return }
                if !mainDrag.isDragging {
                    mainDrag.begin(at: displayedMainHeight(layout))
                }
                mainDrag.update(translation: value.translation.height)
                updateMainHeight(mainDrag.startValue - value.translation.height, layout: layout, animated: false)
            }
            .onEnded { value in
                guard mainDrag.isDragging else { return }
                let projected = displayedMainHeight(layout) - (value.predictedEndTranslation.height - value.translation.height)
                mainDrag.end()
                settleMain(to: projected, layout: layout)
            }
    }

    private func featureDragGesture(_ layout: OutdoorPineGeometry, isMaxDrawer: Bool) -> some Gesture {
        DragGesture(minimumDistance: 0, coordinateSpace: .global)
            .onChanged { value in
                if !featureDrag.isDragging {
                    featureDrag.begin(at: featureHeight)
                }
                if feature == .music, !isMaxDrawer {
                    musicHeightManuallyAdjusted = true
                }
                featureDrag.update(translation: value.translation.height)
                if isMaxDrawer {
                    maxDrawerOffset = max(0, value.translation.height)
                } else {
                    updateFeatureHeight(featureDrag.startValue - value.translation.height, layout: layout, animated: false)
                }
            }
            .onEnded { value in
                guard featureDrag.isDragging else { return }
                if isMaxDrawer {
                    let projected = maxDrawerOffset + (value.predictedEndTranslation.height - value.translation.height)
                    featureDrag.end()
                    if projected > 72 {
                        closeFeature()
                    } else {
                        animate { maxDrawerOffset = 0 }
                    }
                    return
                }
                let projected = featureHeight - (value.predictedEndTranslation.height - value.translation.height)
                featureDrag.end()
                if featureHeight <= layout.featureCloseThreshold {
                    closeFeature()
                } else {
                    settleFeature(to: projected, layout: layout)
                }
            }
    }

    private func updateMainHeight(_ proposed: CGFloat, layout: OutdoorPineGeometry, animated: Bool) {
        let minimum = feature != nil && mainDetent != .max ? layout.mainMinimumWithFeature : layout.mainCompactHeight
        var maximum: CGFloat
        if feature != nil, mainDetent != .max {
            let featureTop = layout.size.height - layout.lowerInset - featureHeight
            let siblingMaximum = max(minimum, featureTop - layout.safeAreaTop - 8)
            maximum = min(layout.mainFullHeight, siblingMaximum)
            if proposed > siblingMaximum {
                let newFeatureHeight = layout.size.height - layout.lowerInset - layout.safeAreaTop - 8 - proposed
                updateFeatureHeight(newFeatureHeight, layout: layout, animated: false)
                let adjustedFeatureTop = layout.size.height - layout.lowerInset - featureHeight
                maximum = min(
                    layout.mainFullHeight,
                    max(minimum, adjustedFeatureTop - layout.safeAreaTop - 8)
                )
            }
        } else {
            maximum = layout.mainFullHeight
        }
        let value = min(maximum, max(minimum, proposed))
        if animated {
            animate { mainHeight = value }
        } else {
            withoutAnimation { mainHeight = value }
        }
    }

    private func updateFeatureHeight(_ proposed: CGFloat, layout: OutdoorPineGeometry, animated: Bool) {
        guard let selectedFeature = feature else { return }
        let minimum: CGFloat = 1
        let lowerBottom = layout.size.height - layout.lowerInset
        let maximum = max(
            layout.featureExpandedHeight,
            lowerBottom - layout.safeAreaTop - 8 - layout.mainMinimumWithFeature
        )
        let value = min(maximum, max(minimum, proposed))
        let featureTop = lowerBottom - value
        let maximumMain = max(layout.mainMinimumWithFeature, featureTop - layout.safeAreaTop - 8)
        let updates = {
            featureHeight = value
            if mainDetent != .max, mainHeight > maximumMain {
                mainHeight = maximumMain
            }
        }
        if animated {
            animate(updates)
        } else {
            withoutAnimation(updates)
        }
        if value > layout.featureCloseThreshold {
            rememberedFeatureHeights[selectedFeature] = value
        }
    }

    private func settleMain(to projected: CGFloat, layout: OutdoorPineGeometry) {
        let minimum = feature != nil && mainDetent != .max ? layout.mainMinimumWithFeature : layout.mainCompactHeight
        let maximum = feature != nil && mainDetent != .max
            ? min(layout.mainFullHeight, layout.size.height - layout.lowerInset - featureHeight - layout.safeAreaTop - 8)
            : layout.mainFullHeight
        let points = [layout.mainCompactHeight, layout.mainMediumHeight, maximum]
            .filter { $0 >= minimum && $0 <= maximum }
        let target = nearest(to: min(maximum, max(minimum, projected)), among: points)
        let detent: OutdoorPineDetent = target >= layout.mainFullHeight - 16 ? .expanded : target >= layout.mainMediumHeight - 16 ? .medium : .compact
        animate {
            mainHeight = target
            mainDetent = detent
        }
    }

    private func settleFeature(to projected: CGFloat, layout: OutdoorPineGeometry) {
        guard let feature else { return }
        let points: [CGFloat] = feature == .music
            ? [layout.featureCompactHeight, layout.musicFitHeight, layout.usableHeight - layout.safeAreaTop - layout.lowerInset - 8 - layout.mainMinimumWithFeature]
            : [layout.featureCompactHeight, layout.featureMediumHeight, layout.featureExpandedHeight]
        let valid = points.filter { $0 > layout.featureCloseThreshold }
        if projected <= layout.featureCloseThreshold {
            closeFeature()
            return
        }
        let target = nearest(to: projected, among: valid)
        animate {
            featureHeight = target
        }
        rememberedFeatureHeights[feature] = target
    }

    private func displayedMainHeight(_ layout: OutdoorPineGeometry) -> CGFloat {
        if mainDetent == .max { return layout.usableHeight }
        let base = mainHeight > 0 ? mainHeight : layout.mainHeight(for: mainDetent)
        guard feature != nil else { return min(layout.mainFullHeight, base) }
        let top = layout.size.height - layout.lowerInset - featureHeight
        let maximum = max(layout.mainMinimumWithFeature, top - layout.safeAreaTop - 8)
        return min(maximum, base)
    }

    private func mainExpansion(_ height: CGFloat, layout: OutdoorPineGeometry) -> CGFloat {
        let span = max(1, layout.mainFullHeight - layout.mainCompactHeight)
        return min(1, max(0, (height - layout.mainCompactHeight) / span))
    }

    private func preferredFeatureHeight(for feature: OutdoorRouteFeature?, layout: OutdoorPineGeometry) -> CGFloat {
        guard let feature else { return layout.featureCompactHeight }
        if let remembered = rememberedFeatureHeights[feature] { return remembered }
        return feature == .music ? layout.musicFitHeight : layout.featureCompactHeight
    }

    private func toggleFeature(_ next: OutdoorRouteFeature, layout: OutdoorPineGeometry) {
        guard mainContent != .finish else { return }
        selectionHaptic()
        if feature == next {
            closeFeature()
            return
        }
        if let current = feature {
            rememberedFeatureHeights[current] = featureHeight
            if current == .music {
                musicEditorResetToken += 1
            }
        } else {
            mainHeightBeforeFeature = mainHeight
        }
        if feature == nil, next == .music {
            musicHeightManuallyAdjusted = false
        }
        rememberedFeature = next

        let targetHeight = preferredFeatureHeight(for: next, layout: layout)
        animate {
            feature = next
            maxDrawerOffset = 0
            if mainDetent != .max {
                mainDetent = .compact
                mainHeight = min(layout.mainCompactHeight, mainHeight)
            }
            featureHeight = targetHeight
        }
    }

    private func closeFeature() {
        guard let current = feature else { return }
        if current == .music {
            musicEditorResetToken += 1
        }
        if featureHeight > 2 { rememberedFeatureHeights[current] = featureHeight }
        let restoredMainHeight = mainHeightBeforeFeature
        animate {
            feature = nil
            maxDrawerOffset = 0
            featureHeight = 0
            if mainDetent != .max, let restoredMainHeight {
                mainHeight = restoredMainHeight
            }
        }
        mainHeightBeforeFeature = nil
    }
    private var displayedMapPoints: [OutdoorTrackPoint] {
        if mainContent == .finish {
            return finalizedPoints()
        }
        if mainContent == .library,
           let libraryActivityID,
           let activity = store.activities.first(where: { $0.id == libraryActivityID }) {
            return store.trackPoints(for: activity)
        }
        return recorder.route
    }

    private func finalizedPoints() -> [OutdoorTrackPoint] {
        if !recorder.route.isEmpty { return recorder.route }
        guard let activity = pineFinishedActivity ?? exposedFinishedActivity ?? recorder.activeActivity else { return [] }
        return store.trackPoints(for: activity)
    }

    private func openLibrary(_ layout: OutdoorPineGeometry) {
        shortSessionReason = nil
        closeFeature()
        animate {
            mainDetent = .medium
            mainHeight = layout.libraryHeight
            mainContent = .library
        }
    }

    private func closeLibrary() {
        dismiss()
    }

    private func startRecording() {
        shortSessionReason = nil
        mainContent = .live
        recorder.start()
    }

    private func togglePause() {
        switch recorder.state {
        case .recording: recorder.pauseManually()
        case .manualPaused, .autoPaused: recorder.resumeManually()
        default: break
        }
    }
    private func finishRecording(_ layout: OutdoorPineGeometry) {
        switch recorder.finishWithOutcome() {
        case .shortSessionDiscarded:
            mainContent = .start
            mainDetent = .compact
            animate { mainHeight = layout.mainCompactHeight }
            pineFinishedActivity = nil
            exposedFinishedActivity = nil
            shortSessionReason = recorder.errorMessage ?? "Workout not saved — less than 3 m recorded."
            musicSession.reset()
            musicLibrary.resetRouteSession()
        case .finished(let activity):
            let playedTracks = musicSession.finish()
            var finalizedActivity = activity
            do {
                try store.setPlayedTracks(playedTracks, for: activity)
                finalizedActivity.playedTracks = playedTracks
            } catch {
                shortSessionReason = "The route was saved, but its played-track history could not be saved: \(error.localizedDescription)"
            }
            if feature == .music {
                musicEditorResetToken += 1
            }
            feature = nil
            featureHeight = 0
            maxDrawerOffset = 0
            mainHeightBeforeFeature = nil
            pineFinishedActivity = finalizedActivity
            exposedFinishedActivity = finalizedActivity
            mainContent = .finish
        case .failed(let message):
            shortSessionReason = message
        }
    }

    private func resumeFinished() {
        guard let activity = pineFinishedActivity ?? exposedFinishedActivity ?? recorder.activeActivity else {
            return
        }
        guard recorder.resumeAfterFinish(activity) else {
            shortSessionReason = recorder.errorMessage
            return
        }
        musicSession.start(activityID: activity.id, existingEvents: activity.playedTracks)
        pineFinishedActivity = nil
        exposedFinishedActivity = nil
        mainContent = .live
        shortSessionReason = nil
    }

    private func commitType() {
        selectionHaptic()
        animate { committedKind = previewKind }
        recorder.updateKind(previewKind)
    }

    private func toggleMax(_ layout: OutdoorPineGeometry) {
        if mainDetent == .max {
            animate {
                mainDetent = .expanded
                mainHeight = layout.mainFullHeight
            }
        } else if mainDetent == .expanded && !mainDrag.isDragging {
            closeFeatureForMax()
            animate {
                mainDetent = .max
                mainHeight = layout.usableHeight
            }
        }
    }

    private func closeFeatureForMax() {
        guard let current = feature else { return }
        rememberedFeatureHeights[current] = featureHeight
        if current == .music {
            musicEditorResetToken += 1
        }
        feature = nil
        featureHeight = 0
        maxDrawerOffset = 0
    }

    private func adjustMainDetent(_ direction: AccessibilityAdjustmentDirection, layout: OutdoorPineGeometry) {
        let points: [OutdoorPineDetent] = [.compact, .medium, .expanded]
        guard let current = points.firstIndex(of: mainDetent) else { return }
        let next: Int
        switch direction {
        case .increment: next = min(points.count - 1, current + 1)
        case .decrement: next = max(0, current - 1)
        @unknown default: next = current
        }
        let detent = points[next]
        mainDetent = detent
        updateMainHeight(layout.mainHeight(for: detent), layout: layout, animated: true)
        let actualHeight = nearest(
            to: mainHeight,
            among: [layout.mainCompactHeight, layout.mainMediumHeight, layout.mainFullHeight]
        )
        mainDetent = actualHeight >= layout.mainFullHeight - 16
            ? .expanded
            : actualHeight >= layout.mainMediumHeight - 16 ? .medium : .compact
    }

    private func adjustFeatureDetent(_ direction: AccessibilityAdjustmentDirection, layout: OutdoorPineGeometry) {
        guard let selectedFeature = feature else { return }
        let points: [CGFloat] = [layout.featureCompactHeight, layout.featureMediumHeight, layout.featureExpandedHeight]
        let current = nearest(to: featureHeight, among: points)
        guard let index = points.firstIndex(of: current) else { return }
        if selectedFeature == .music {
            musicHeightManuallyAdjusted = true
        }
        let next: Int
        switch direction {
        case .increment: next = min(points.count - 1, index + 1)
        case .decrement: next = max(0, index - 1)
        @unknown default: next = index
        }
        updateFeatureHeight(points[next], layout: layout, animated: true)
    }


    private func featureDetentName(_ layout: OutdoorPineGeometry, isMaxDrawer: Bool) -> String {
        if isMaxDrawer { return "Drawer" }
        if featureHeight <= layout.featureCompactHeight + 8 { return "Compact" }
        if featureHeight <= layout.featureMediumHeight + 8 { return "Medium" }
        return "Expanded"
    }

    private func applyMusicContentFit(_ height: CGFloat, layout: OutdoorPineGeometry) {
        guard feature == .music, !musicHeightManuallyAdjusted, height > 0 else { return }
        let preferred = min(layout.featureExpandedHeight, max(layout.featureCompactHeight, height))
        if !featureDrag.isDragging, featureHeight == 0 || abs(featureHeight - preferred) > 12 {
            featureHeight = preferred
        }
    }

    private func nearest(to value: CGFloat, among points: [CGFloat]) -> CGFloat {
        points.min(by: { abs($0 - value) < abs($1 - value) }) ?? value
    }

    private func animate(_ updates: () -> Void) {
        withAnimation(reduceMotion ? .easeOut(duration: 0.18) : .spring(response: 0.36, dampingFraction: 0.86), updates)
    }

    private func withoutAnimation(_ updates: () -> Void) {
        var transaction = Transaction()
        transaction.animation = nil
        withTransaction(transaction, updates)
    }
    private func selectionHaptic() {
        guard preferences.preferences.haptics else { return }
        UISelectionFeedbackGenerator().selectionChanged()
    }

    private func openLocationSettings() {
        guard let settingsURL = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(settingsURL)
    }

}

enum OutdoorMainContent: Hashable {
    case start
    case live
    case finish
    case library
}

enum OutdoorUpperQuickFeature: Equatable {
    case map
    case trophy
    case settings
}

struct OutdoorUpperQuickGeometry: Equatable {
    var top: CGFloat
    var opacity: CGFloat
}

private struct OutdoorMapControlsHeightKey: PreferenceKey {
    static var defaultValue: CGFloat = 134

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

struct OutdoorMusicFeatureSlot: View {
    let library: MusicLibraryStore
    let musicManager: MusicManager
    let entry: MusicLibraryItem?
    let resetToken: Int
    let onImportLocalMusic: () -> Void
    let onMeasuredHeight: (CGFloat) -> Void

    var body: some View {
        OutdoorMusicEditorView(
            library: library,
            musicManager: musicManager,
            initialItem: entry,
            resetToken: resetToken,
            onMeasuredHeight: onMeasuredHeight,
            onImportLocalMusic: onImportLocalMusic
        )
        .accessibilityLabel("Music editor")
        .accessibilityValue(entry?.title ?? "Shared music library")
    }
}

struct OutdoorMusicContentSizeKey: PreferenceKey {
    static var defaultValue: CGFloat = 0

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {

        value = nextValue()
    }
}

#endif
