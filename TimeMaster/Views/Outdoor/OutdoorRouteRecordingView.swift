#if os(iOS)
import SwiftUI
import UIKit
import CoreLocation
import UniformTypeIdentifiers

@MainActor
struct OutdoorRouteRecordingView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.slotNavigationContentBounds) private var navigationBounds

    @ObservedObject private var store: OutdoorActivityStore
    @ObservedObject private var preferences: OutdoorRecordingPreferencesStore
    @StateObject private var recorder: OutdoorLocationRecorder
    @StateObject private var tripEditor: OutdoorTripEditor
    @StateObject private var tripAreas = OutdoorOfflineAreas()
    @StateObject private var nearbyRoutes = OutdoorNearbyRoutes()
    @StateObject private var musicSession: OutdoorMusicSession
    @ObservedObject private var musicManager: MusicManager
    private let musicLibrary: MusicLibraryStore
    @Binding private var exposedFinishedActivity: OutdoorActivity?
    private let initialActivityID: UUID?
    private let initialLibraryEntry: MusicLibraryItem?
    private let onExit: (() -> Void)?

    @Namespace private var glassNamespace
    @State private var committedKind: OutdoorActivityKind
    @State private var previewKind: OutdoorActivityKind
    @State private var mainContent: OutdoorMainContent = .start
    @State private var mainDetent: OutdoorPineDetent = .compact
    @State private var mainHeight: CGFloat = 0
    @State private var feature: OutdoorRouteFeature?
    @State private var presentedFeature: OutdoorRouteFeature?
    @State private var featureIsVisible = false
    @State private var featurePresentationGeneration = 0
    @State private var presentedModePrompt: OutdoorModeReminder.Prompt?
    @State private var presentedFeatureUsesDrawer = false
    @State private var featureHeight: CGFloat = 0
    @State private var mainHeightBeforeFeature: CGFloat?
    @State private var mainDetentBeforeFeature: OutdoorPineDetent?
    @State private var rememberedFeatureHeights: [OutdoorRouteFeature: CGFloat] = [:]
    @State private var musicHeightManuallyAdjusted = false
    @State private var musicEditorResetToken = 0
    @State private var mainDrag = OutdoorPineDragState()
    @State private var featureDrag = OutdoorPineDragState()
    @State private var fullscreenDrag = OutdoorPineDragState()
    @State private var fullscreenDragProgress: CGFloat = 0
    @GestureState private var mainGestureActive = false
    @GestureState private var featureGestureActive = false
    @GestureState private var fullscreenGestureActive = false
    @StateObject private var mainPresentation = OutdoorPanePresentation()
    @StateObject private var featurePresentation = OutdoorPanePresentation()
    @State private var featureOffset: CGFloat = 0
    @State private var paneModalPresented = false
    @State private var shortSessionReason: String?
    @State private var mapMode: OutdoorMapMode = .explore
    @State private var mapOverlayModes: Set<OutdoorMapMode> = []
    @State private var activeMapMode: OutdoorMapMode = .explore
    @State private var mapCapabilities: [OutdoorMapMode: OutdoorMapCapability] = [:]
    @State private var weatherState: OutdoorWeatherState = .disabled
    @State private var mapFocusRequestID = 0
    @State private var mapNorthRequestID = 0
    @State private var mapCityFitRequestID = 0
    @State private var mapRouteFitRequestID = 0
    @State private var mapFollowsUser = false
    @State private var mapHeading: CLLocationDirection = 0
    @State private var upperQuickFeature: OutdoorUpperQuickFeature?
    @State private var mapOfflineMessage: String?
    @State private var mapControlsHeight: CGFloat = 134
    @State private var pineFinishedActivity: OutdoorActivity?
    @State private var libraryActivityID: UUID?
    @State private var libraryEditorPresented = false
    @State private var libraryMapReturnHeight: CGFloat?
    @State private var libraryMapReturnDetent: OutdoorPineDetent = .medium
    @State private var didConfigureInitialContent = false
    @State private var showingMusicFileImporter = false
    @State private var musicImportError: String?
    private let modeReminder = OutdoorModeReminder.shared
    @State private var modePrompt: OutdoorModeReminder.Prompt?
    @AccessibilityFocusState private var focusedFeature: OutdoorRouteFeature?
    @State private var tripEntry: TripPlannerEntry?
    @State private var tripPanelHeight: CGFloat = 0
    @State private var tripBottomHeight: CGFloat = 0
    @State private var tripMenuRevision = 0
    @State private var tripFitPoints: [OutdoorTrackPoint]?
    @State private var tripPreviewFitPending = false
    @State private var offlineAreasPresented = false
    @State private var mapModeBeforeTrip: OutdoorMapMode?

    init(
        kind: OutdoorActivityKind,
        store: OutdoorActivityStore,
        plannedRoute: PlannedRoute? = nil,
        preferences: OutdoorRecordingPreferencesStore,
        musicLibrary: MusicLibraryStore,
        initialActivityID: UUID? = nil,
        initialLibraryEntry: MusicLibraryItem? = nil,
        recordingSession: OutdoorLocationRecorder? = nil,
        onExit: (() -> Void)? = nil,
        finishedActivity: Binding<OutdoorActivity?> = .constant(nil)
    ) {
        let normalizedKind = kind
        let resolvedRecorder = recordingSession ?? OutdoorLocationRecorder(
            kind: normalizedKind,
            store: store,
            preferences: preferences,
            plannedRoute: plannedRoute
        )
        self.initialActivityID = initialActivityID
        self.initialLibraryEntry = initialLibraryEntry
        self.musicLibrary = musicLibrary
        self.onExit = onExit
        self._store = ObservedObject(wrappedValue: store)
        self._preferences = ObservedObject(wrappedValue: preferences)
        self._recorder = StateObject(wrappedValue: resolvedRecorder)
        self._tripEditor = StateObject(wrappedValue: OutdoorTripEditor(route: nil, kind: kind, store: store))
        self._musicSession = StateObject(wrappedValue: OutdoorMusicSession())
        self._exposedFinishedActivity = finishedActivity
        self._musicManager = ObservedObject(wrappedValue: MusicManager.shared)
        self._committedKind = State(initialValue: normalizedKind)
        self._previewKind = State(initialValue: normalizedKind)
    }

    var body: some View {
        GeometryReader { proxy in
            let showsCompactPlayer = musicManager.currentTrack != nil && mainContent != .finish && tripEntry == nil
            let visibleHeight = navigationBounds.map {
                min(proxy.size.height, max(1, $0.maxY - proxy.frame(in: .global).minY))
            } ?? proxy.size.height
            let obscuredHeight = max(0, proxy.size.height - visibleHeight)
            let layout = OutdoorPineGeometry(
                size: CGSize(width: proxy.size.width, height: visibleHeight),
                safeAreaTop: proxy.safeAreaInsets.top,
                safeAreaBottom: max(0, min(proxy.safeAreaInsets.bottom, containerBottomInset) - obscuredHeight),
                playerReserve: showsCompactPlayer ? 94 : 0,
                fullscreenBounds: CGRect(
                    x: 0,
                    y: -proxy.safeAreaInsets.top,
                    width: proxy.size.width,
                    height: proxy.size.height + proxy.safeAreaInsets.top + proxy.safeAreaInsets.bottom
                )
            )
            let offlineCapabilities = (OutdoorMapMode.baseModes + OutdoorMapMode.overlayModes).map {
                OutdoorMapProviderConfiguration.main.capability(for: $0)
            }
            let quickGeometry = upperQuickGeometry(for: layout)
            ZStack(alignment: .topLeading) {
                OutdoorMapLibreView(
                    points: tripEntry == nil ? displayedMapPoints : [],
                    followsUser: mapFollowsUser,
                    state: recorder.state,
                    plannedPoints: tripEntry != nil ? tripEditor.mapPoints : mainContent == .library || feature == .route ? nil : recorder.plannedPoints,
                    mode: mapMode,
                    overlayModes: mapOverlayModes,
                    focusRequestID: mapFocusRequestID,
                    northRequestID: mapNorthRequestID,
                    cityFitRequestID: mapCityFitRequestID,
                    routeFitRequestID: mapRouteFitRequestID,
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
                    onHeadingChange: { heading in
                        mapHeading = heading
                    },
                    onFocusFailure: { message in
                        mapFollowsUser = false
                        mapOfflineMessage = message
                    },
                    tripEditing: tripMapEditing,
                    offlineStyleURL: tripEntry != nil || feature == .route ? tripAreas.styleURL : nil,
                    offlineBounds: tripEntry != nil || feature == .route ? tripAreas.displayedRegion?.manifest.bounds : nil,
                    plannedTrip: tripEntry != nil ? tripEditor.route.trip : mainContent == .library || feature == .route ? nil : recorder.selectedPlan?.trip,
                    routeFitPoints: tripFitPoints,
                    onLocationChange: nearbyRoutes.updateLocation
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


                if upperQuickFeature == nil, tripEntry == nil, (mainDetent != .max || libraryMapReturnHeight != nil), quickGeometry.opacity > 0 {
                    OutdoorMapQuickStack(
                        opacity: quickGeometry.opacity,
                        onSelect: openUpperQuick
                    )
                    .frame(width: 44, height: OutdoorPineGeometry.quickStackHeight)
                    .position(x: 33, y: quickGeometry.top + (OutdoorPineGeometry.quickStackHeight / 2))
                    .zIndex(70)
                }

                if upperQuickFeature == nil, tripEntry != nil || mainDetent != .max || libraryMapReturnHeight != nil {
                    mapControls(layout)
                        .disabled(tripEditor.isRouting || tripEditor.isGenerating)
                        .zIndex(70)
                }


                if tripEntry == nil, libraryMapReturnHeight == nil, mainDetent != .expanded && mainDetent != .max {
                    if canDismissRoute {
                        OutdoorRouteIdleCloseControl(onDismiss: leaveRoute)
                            .padding(.top, max(0, layout.safeAreaTop - 24))
                            .padding(.trailing, 8)
                            .frame(maxWidth: .infinity, alignment: .topTrailing)
                            .zIndex(100)
                    } else if recorder.isLiveSession {
                        OutdoorRouteExitControl(onExit: exitToApp)
                            .padding(.top, max(0, layout.safeAreaTop - 24))
                            .padding(.trailing, 8)
                            .frame(maxWidth: .infinity, alignment: .topTrailing)
                            .zIndex(100)
                    }
                }

                if let upperQuickFeature {
                    OutdoorUpperQuickPine(
                        feature: upperQuickFeature,
                        namespace: glassNamespace,
                        mapMode: mapMode,
                        enabledOverlays: mapOverlayModes,
                        mapCapabilities: mapCapabilities,
                        preferences: preferences,
                        offlineCapabilities: offlineCapabilities,
                        onMapMode: selectMapMode,
                        onToggleOverlay: toggleMapOverlay,
                        onManageMusic: { focusMusicFromUpperQuick(layout: layout) },
                        onDismiss: closeUpperQuick,
                        height: layout.usableHeight * 0.40
                    )
                    .padding(.top, layout.safeAreaTop + 12)
                    .transition(
                        reduceMotion
                            ? .opacity
                            : .scale(scale: 0.08, anchor: upperQuickOrigin(for: upperQuickFeature, layout: layout))
                            .combined(with: .opacity)
                    )
                    .zIndex(80)
                }

                mainPine(layout)
                    .offset(y: libraryMapReturnHeight == nil && tripEntry == nil ? 0 : layout.size.height + layout.safeAreaBottom)
                    .allowsHitTesting(libraryMapReturnHeight == nil && tripEntry == nil)
                    .accessibilityHidden(libraryMapReturnHeight != nil || tripEntry != nil)

                if libraryMapReturnHeight != nil {
                    Button(action: closeLibraryMap) {
                        Label("Back to workout", systemImage: "chevron.up")
                            .font(.headline)
                    }
                    .buttonStyle(OutdoorPineButtonStyle(prominent: true))
                    .padding(.bottom, layout.lowerInset)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                    .zIndex(40)
                }

                if let presentedFeature, tripEntry == nil {
                    featurePine(presentedFeature, layout: layout)
                        .allowsHitTesting(feature != nil && featureIsVisible)
                        .accessibilityHidden(feature == nil)
                        .onAppear {
                            guard feature != nil else { return }
                            animate { featureIsVisible = true }
                        }
                        .zIndex(30)
                }
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
                if let tripEntry {
                    OutdoorTripPlannerView(
                        editor: tripEditor, entry: tripEntry, units: preferences.preferences.unitSystem,
                        namespace: glassNamespace,
                        onPanelHeight: { tripPanelHeight = $0 },
                        onBottomHeight: { height in
                            tripBottomHeight = height
                            if tripPreviewFitPending, height > 0 {
                                tripPreviewFitPending = false
                                mapRouteFitRequestID += 1
                            }
                        },
                        onFit: { tripFitPoints = nil; mapRouteFitRequestID += 1 },
                        onFitLeg: { leg in
                            tripFitPoints = leg.coordinates.map { $0.trackPoint() }
                            mapRouteFitRequestID += 1
                        },
                        onManageAreas: { offlineAreasPresented = true },
                        onSaved: { route in
                            if !route.isDraft, recorder.state == .idle {
                                selectTrip(route)
                            }
                        },
                        onClose: closeTrip,
                        onStart: { route in
                            guard recorder.state == .idle else { return }
                            selectTrip(route)
                            closeTrip()
                            closeFeature()
                            mainDetent = .compact
                            animate { mainHeight = layout.mainCompactHeight }
                            startRecording(layout)
                        },
                        canStart: recorder.state == .idle
                    )
                    .opacity(upperQuickFeature == nil ? 1 : 0)
                    .allowsHitTesting(upperQuickFeature == nil)
                    .accessibilityHidden(upperQuickFeature != nil)
                    .transition(reduceMotion ? .opacity : .move(edge: .bottom).combined(with: .opacity))
                    .zIndex(40)
                }

            }
            .frame(width: layout.size.width, height: layout.size.height, alignment: .topLeading)
            .animation(feature == nil ? paneDismissalAnimation : paneAnimation, value: feature)
            .animation(paneAnimation, value: tripEntry)
            .animation(paneAnimation, value: tripPanelHeight)
            .animation(
                reduceMotion ? .none : .spring(response: 0.28, dampingFraction: 0.9),
                value: mapOfflineMessage != nil || shortSessionReason != nil
            )
            .background(Theme.background)
            .onAppear {
                configureInitialContent()
                configureInitialGeometry(layout)
            }
            .onChange(of: layout) { _ in
                configureInitialGeometry(layout)
            }
            .onChange(of: libraryActivityID) { _ in
                guard libraryActivityID != nil else { libraryEditorPresented = false; return }
                mapFollowsUser = false
                mapRouteFitRequestID &+= 1
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
            .onChange(of: mainGestureActive) { active in
                guard !active else { return }
                if mainDrag.isDragging {
                    mainDrag.end()
                    settleMain(to: displayedMainHeight(layout), layout: layout)
                }
                if fullscreenDrag.isDragging, !fullscreenGestureActive {
                    animate { fullscreenDrag.end() }
                }
            }
            .onChange(of: featureGestureActive) { active in
                guard !active, featureDrag.isDragging else { return }
                featureDrag.end()
                if mainDetent == .max {
                    animate { featureOffset = 0 }
                } else {
                    settleFeature(to: stackedFeatureHeight, layout: layout)
                }
            }
            .onChange(of: fullscreenGestureActive) { active in
                if !active, fullscreenDrag.isDragging, !mainGestureActive {
                    animate { fullscreenDrag.end() }
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
                if tripEntry != nil, tripEntry != .preview || tripEditor.hasChanges { tripEditor.preserve() }
                musicLibrary.resetRouteSession()
                musicSession.stop()
            }
        }
        .task { await tripAreas.reload() }
        .sheet(isPresented: $offlineAreasPresented, onDismiss: {
            nearbyRoutes.refresh(kind: committedKind)
            tripMenuRevision += 1
        }) { OutdoorOfflineAreasView(model: tripAreas) }
        .onChange(of: tripEditor.revision) { _ in
            if tripEntry != nil { tripAreas.displayCovering(tripEditor.trip.stops.map(\.coordinate)) }
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
        } else if mainDetent == .max {
            mainHeight = layout.mainMaximumHeight
        } else if mainDetent == .expanded {
            mainHeight = layout.mainFullHeight
        } else {
            mainHeight = min(mainHeight, layout.mainFullHeight)
        }
        if let feature {
            if mainHeightBeforeFeature == nil {
                mainHeightBeforeFeature = mainHeight
                mainDetentBeforeFeature = mainDetent
            }
            let preferred = preferredFeatureHeight(for: feature, layout: layout)
            let desired = rememberedFeatureHeights[feature] ?? max(featureHeight, preferred)
            featureHeight = min(layout.maximumFeatureHeight(music: feature == .music), max(1, desired))
            if presentedFeature == nil {
                presentedFeature = feature
                presentedFeatureUsesDrawer = mainDetent == .max
            }
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

    private var canExitToApp: Bool {
        recorder.isLiveSession
    }

    private func exitToApp() {
        guard canExitToApp else { return }
        recorder.checkpoint()
        leaveRoute()
    }
    private func leaveRoute() {
        if let onExit {
            onExit()
        } else {
            dismiss()
        }
    }

    private var containerBottomInset: CGFloat {
        for scene in UIApplication.shared.connectedScenes {
            guard let windowScene = scene as? UIWindowScene,
                  let window = windowScene.windows.first(where: \.isKeyWindow) else { continue }
            return window.safeAreaInsets.bottom
        }
        return 0
    }

    private var tripMapEditing: TripMapEditing? {
        guard tripEntry != nil else { return nil }
        return TripMapEditing(
            trip: tripEditor.trip, revision: tripEditor.revision, picking: tripEditor.picking && !tripEditor.isGenerating,
            topInset: tripPanelHeight, bottomInset: tripBottomHeight,
            onPick: tripEditor.pick, onBeginDrag: tripEditor.beginDrag,
            onDrag: tripEditor.updateDrag, onCancelDrag: tripEditor.cancelDrag,
            onLocation: tripEditor.setCurrentLocation
        )
    }

    private func openTrip(_ entry: TripPlannerEntry, route: PlannedRoute?) {
        tripEditor.open(route, kind: committedKind)
        if let location = nearbyRoutes.location { tripEditor.setCurrentLocation(location) }
        tripPanelHeight = 0
        tripBottomHeight = 0
        tripPreviewFitPending = entry == .preview
        tripFitPoints = nil
        mapFollowsUser = false
        mapModeBeforeTrip = mapMode
        mapMode = .explore
        animate {
            upperQuickFeature = nil
            tripEntry = entry
        }
        tripAreas.displayCovering(tripEditor.trip.stops.map(\.coordinate))
    }

    private func closeTrip() {
        tripEditor.suspend()
        tripFitPoints = nil
        tripPanelHeight = 0
        tripBottomHeight = 0
        tripPreviewFitPending = false
        if let mapModeBeforeTrip { mapMode = mapModeBeforeTrip }
        mapModeBeforeTrip = nil
        animate { tripEntry = nil }
        tripMenuRevision += 1
    }

    private func selectTrip(_ route: PlannedRoute) {
        recorder.selectPlannedRoute(route)
        if let kind = route.trip?.kind {
            committedKind = kind
            previewKind = kind
        }
        mapRouteFitRequestID += 1
    }

    private func mapControls(_ layout: OutdoorPineGeometry) -> some View {
        let mainFrame = displayedMainHeight(layout)
        let mainTop = libraryMapReturnHeight != nil ? layout.size.height - layout.lowerInset - 56 : layout.mainTop(
            mainHeight: mainFrame,
            featureHeight: feature != nil && mainDetent != .max ? stackedFeatureHeight : nil
        )
        let controlsHeight = max(134, mapControlsHeight)
        let plannerControlsTop = tripPanelHeight + 18
        let hasRoom = tripEntry == nil
            ? mainTop - layout.safeAreaTop >= controlsHeight + 18
            : layout.size.height - layout.safeAreaBottom - tripBottomHeight - plannerControlsTop >= controlsHeight
        let bottomClearance = tripEntry == nil
            ? max(18, layout.size.height - mainTop + 18)
            : max(0, layout.size.height - plannerControlsTop - controlsHeight)
        let attributionMode: OutdoorMapMode = tripEntry != nil ? .explore : mapOverlayModes.contains(.threeD) ? .threeD : activeMapMode
        let mapAttribution = (
            mapCapabilities[attributionMode]
                ?? OutdoorMapProviderConfiguration.main.capability(for: attributionMode)
        ).attribution
        return VStack(spacing: 0) {
            Spacer(minLength: 0)
            OutdoorMapControls(
                weatherState: weatherState,
                weatherInfoEnabled: preferences.preferences.weatherInfo && tripEntry == nil,
                followsUser: mapFollowsUser,
                mapAttribution: mapAttribution,
                onDownload: { offlineAreasPresented = true },
                onFocusLocation: focusMapLocation,
                onFitRoute: tripEntry == nil ? nil : { tripFitPoints = nil; mapRouteFitRequestID += 1 },
                onNorth: tripEntry == nil ? nil : { mapNorthRequestID += 1 }
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
        .accessibilityHidden(!hasRoom)
    }


    private func focusMapLocation() {
        mapOfflineMessage = nil
        mapFocusRequestID &+= 1
    }

    private func resetMapNorth() {
        mapNorthRequestID &+= 1
    }

    private func selectMapMode(_ mode: OutdoorMapMode) {
        guard mode.isBaseMapView else { return }
        selectionHaptic()
        animate {
            mapMode = mode
            mapOfflineMessage = nil
        }
    }

    private func toggleMapOverlay(_ overlay: OutdoorMapMode) {
        guard overlay.isMapOverlay else { return }
        let capability = mapCapabilities[overlay]
            ?? OutdoorMapProviderConfiguration.main.capability(for: overlay)
        guard capability.isUsable else {
            mapOfflineMessage = capability.reason ?? "\(overlay.displayName) is unavailable."
            return
        }
        selectionHaptic()
        animate {
            if mapOverlayModes.contains(overlay) {
                mapOverlayModes.remove(overlay)
            } else {
                mapOverlayModes.insert(overlay)
            }
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
        let mainTop = libraryMapReturnHeight != nil ? layout.size.height - layout.lowerInset : layout.mainTop(
            mainHeight: mainFrame,
            featureHeight: feature != nil && mainDetent != .max ? stackedFeatureHeight : nil
        )
        return OutdoorUpperQuickGeometry(
            top: layout.quickStackTop(mainTop: mainTop),
            opacity: layout.quickStackOpacity(mainTop: mainTop)
        )
    }

    private func mainPine(_ layout: OutdoorPineGeometry) -> some View {
        let isMax = mainDetent == .max
        let fullscreenAmount = fullscreenDrag.isDragging ? fullscreenDragProgress : isMax ? 1.0 : 0.0
        let normalHeight = isMax ? layout.mainFullHeight : displayedMainHeight(layout)
        let frame = layout.mainFrame(
            mainHeight: normalHeight,
            featureHeight: feature != nil && !isMax ? stackedFeatureHeight : nil,
            fullscreenProgress: fullscreenAmount
        )
        let expansion = mainExpansion(frame.height, layout: layout)
        let cornerRadius = 26 * (1 - fullscreenAmount)

        return OutdoorPineGlassSurface(
            identity: "route-main-pine",
            namespace: glassNamespace,
            cornerRadius: cornerRadius,
            flat: false,
            interactive: true
        ) {
            VStack(spacing: 0) {
                if mainContent != .library || libraryActivityID != nil {
                    OutdoorPaneHeader {
                        if mainContent == .library, libraryActivityID != nil {
                            HStack(spacing: 0) {
                                Button { libraryActivityID = nil } label: {
                                    Image(systemName: "chevron.left").frame(width: 44, height: 44)
                                }
                                .accessibilityLabel("Back to workout library")
                                Button { libraryEditorPresented = true } label: {
                                    Image(systemName: "pencil").frame(width: 44, height: 44)
                                }
                                .accessibilityLabel("Edit workout")
                            }
                            .buttonStyle(.plain)
                        } else if mainContent == .routes {
                            Button { closeLibrary(layout) } label: {
                                Image(systemName: "chevron.left").frame(width: 44, height: 44)
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("Back to Start")
                        }
                    } handle: {
                        mainHandle(layout)
                    } accessory: {
                        EmptyView()
                    }
                    .allowsHitTesting(!paneModalPresented)
                    .accessibilityHidden(paneModalPresented)
                }

                mainContentView(expansion: expansion, layout: layout)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .clipped()
                    .transaction {
                        if mainDrag.isDragging || featureDrag.isDragging || fullscreenDrag.isDragging {
                            $0.animation = nil
                            $0.disablesAnimations = true
                        }
                    }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(.top, layout.safeAreaTop * fullscreenAmount)
            .padding(.bottom, layout.mainMaximumBottomPadding * fullscreenAmount)
        }
        .frame(width: frame.width, height: frame.height)
        .background(OutdoorPanePresentationProbe(presentation: mainPresentation))
        .overlay(alignment: .topTrailing) {
            if isMax || fullscreenDrag.isDragging || (feature == nil && expansion >= 0.999) {
                OutdoorCornerResizeHandle(drag: fullscreenDrag)
                    .gesture(fullscreenDragGesture(layout))
                    .onTapGesture { toggleMax(layout) }
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("Fullscreen resize handle")
                    .accessibilityValue(isMax ? "Fullscreen" : "Expanded")
                    .accessibilityHint(isMax ? "Drag down to restore the floating pane" : "Drag up to fill the screen")
                    .accessibilityAddTraits(.isButton)
                    .accessibilityAction { toggleMax(layout) }
                    .padding(.top, layout.safeAreaTop * fullscreenAmount + 4)
                    .padding(.trailing, 4)
                    .transition(reduceMotion ? .opacity : .opacity.combined(with: .scale(scale: 0.7, anchor: .topTrailing)))
                    .allowsHitTesting(!paneModalPresented)
                    .accessibilityHidden(paneModalPresented)
            }
        }
        .offset(x: frame.minX, y: frame.minY)
        .zIndex(isMax || fullscreenDrag.isDragging ? 20 : 8)
    }

    private func featurePine(_ selectedFeature: OutdoorRouteFeature, layout: OutdoorPineGeometry) -> some View {
        let isMaxDrawer = presentedFeatureUsesDrawer
        let maxFeatureHeight = selectedFeature == .music
            ? layout.musicMaximumHeight
            : selectedFeature == .type ? layout.featureMediumHeight : layout.usableHeight * 0.31
        let height = isMaxDrawer ? min(featureHeight, maxFeatureHeight) : max(1, featureHeight)
        let top = reduceMotion || featureIsVisible
            ? layout.size.height - layout.lowerInset - height + featureOffset
            : layout.size.height
        let cornerRadius: CGFloat = isMaxDrawer ? 28 : 25

        return OutdoorPineGlassSurface(
            identity: "route-feature-pine",
            namespace: glassNamespace,
            cornerRadius: cornerRadius,
            flat: false,
            interactive: true
        ) {
            VStack(spacing: 0) {
                OutdoorPaneHeader {
                    if selectedFeature == .type {
                        Button { closeFeature() } label: {
                            Image(systemName: "xmark").frame(width: 44, height: 44)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Cancel activity selection")
                    }
                } handle: {
                    featureHandle(layout, isMaxDrawer: isMaxDrawer)
                } accessory: {
                    EmptyView()
                }
                featureContent(selectedFeature, layout: layout)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .clipped()
                    .transition(reduceMotion ? .opacity : .opacity.combined(with: .scale(scale: 0.985, anchor: .bottom)))
                    .animation(paneAnimation, value: selectedFeature)
                    .accessibilityFocused($focusedFeature, equals: selectedFeature)
            }
            .frame(maxWidth: .infinity)
            .frame(height: height)
            .clipped()
            .contentShape(Rectangle())
        }
        .frame(maxWidth: .infinity)
        .frame(height: height)
        .background(OutdoorPanePresentationProbe(presentation: featurePresentation))
        .offset(y: top)
        .opacity(reduceMotion && !featureIsVisible ? 0 : 1)
        .padding(.horizontal, isMaxDrawer ? 0 : 10)
    }

    @ViewBuilder
    private func mainContentView(expansion: CGFloat, layout: OutdoorPineGeometry) -> some View {
        switch mainContent {
        case .start:
            OutdoorStartContent(
                store: store,
                isDragging: mainDrag.isDragging,
                committedKind: committedKind,
                activeFeature: feature,
                onLibrary: { openLibrary(layout) },
                onStart: { startRecording(layout) },
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
                onRetry: { startRecording(layout) },
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
                onModalStateChange: { paneModalPresented = $0 }
            )
        case .library:
            OutdoorLibraryContent(
                store: store,
                preferences: preferences,
                selectedActivityID: $libraryActivityID,
                isEditing: $libraryEditorPresented,
                onClose: { closeLibrary(layout) },
                onShowMap: { showLibraryMap(layout) },
                onModalStateChange: { paneModalPresented = $0 }
            ) {
                mainHandle(layout, compact: true, expansion: expansion)
            }
        case .routes:
            featureContent(.route, layout: layout)
        }
    }

    @ViewBuilder
    private func featureContent(_ selectedFeature: OutdoorRouteFeature, layout: OutdoorPineGeometry) -> some View {
        switch selectedFeature {
        case .type:
            OutdoorTypePicker(
                previewKind: $previewKind,
                committedKind: committedKind,
                prompt: presentedModePrompt,
                onCommit: commitType
            )
        case .music:
            OutdoorMusicFeatureSlot(
                library: musicLibrary,
                musicManager: musicManager,
                entry: initialLibraryEntry,
                resetToken: musicEditorResetToken,
                onImportLocalMusic: { showingMusicFileImporter = true },
                onMeasuredHeight: { height, requiresSpace in
                    guard feature == .music else { return }
                    applyMusicContentFit(height, requiresSpace: requiresSpace, layout: layout)
                }
            )
        case .route:
            OutdoorTripsMenu(
                store: store, nearby: nearbyRoutes, kind: committedKind, units: preferences.preferences.unitSystem,
                canSelect: recorder.state == .idle, onOpen: openTrip,
                onManageAreas: { offlineAreasPresented = true }
            )
            .id(tripMenuRevision)
        case .rate:
            Color.clear
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .accessibilityHidden(true)
        }
    }

    private func mainHandle(_ layout: OutdoorPineGeometry, compact: Bool = false, expansion: CGFloat = 0) -> some View {
        Group {
            if mainContent == .library, libraryActivityID != nil {
                Image(systemName: "chevron.down").font(.body.weight(.semibold))
            } else {
                OutdoorElasticHandle(drag: fullscreenDrag.isDragging ? fullscreenDrag : mainDrag)
            }
        }
        .frame(width: 132, height: compact ? 20 : 48)
        .padding(.bottom, compact ? 28 * expansion : 0)
        .contentShape(Rectangle())
        .gesture(mainDragGesture(layout))
        .onTapGesture {
            if mainContent == .library, libraryActivityID != nil { showLibraryMap(layout) }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Route pane handle")
        .accessibilityValue("\(Int(displayedMainHeight(layout) / max(1, layout.mainMaximumHeight) * 100)) percent")
        .accessibilityAdjustableAction { direction in
            adjustMainDetent(direction, layout: layout)
        }
    }

    private func featureHandle(_ layout: OutdoorPineGeometry, isMaxDrawer: Bool) -> some View {
        OutdoorElasticHandle(drag: featureDrag)
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
            .updating($mainGestureActive) { _, active, _ in active = true }
            .onChanged { value in
                if mainDetent == .max, !(mainContent == .library && libraryActivityID != nil) {
                    updateFullscreenDrag(value, layout: layout)
                    return
                }
                if !mainDrag.isDragging {
                    mainDrag.begin(at: mainPresentation.height ?? displayedMainHeight(layout))
                }
                mainDrag.update(translation: value.translation.height, horizontal: value.translation.width)
                guard mainDetent != .max else { return }
                let proposed = mainDrag.startValue - value.translation.height
                updateMainHeight(proposed, layout: layout, animated: false)
                withoutAnimation {
                    if feature == nil, proposed > layout.mainFullHeight {
                        if !fullscreenDrag.isDragging { fullscreenDrag.begin(at: 0) }
                        fullscreenDrag.update(translation: value.translation.height, horizontal: value.translation.width)
                        fullscreenDragProgress = layout.fullscreenProgress(forProposedHeight: proposed)
                    } else {
                        fullscreenDrag.end()
                    }
                }
            }
            .onEnded { value in
                if fullscreenDrag.isDragging, !mainDrag.isDragging {
                    settleFullscreenDrag(value, layout: layout)
                    return
                }
                guard mainDrag.isDragging else { return }
                if mainContent == .library, libraryActivityID != nil,
                   value.translation.height > 44 || value.predictedEndTranslation.height > 90 {
                    let previousHeight = mainDrag.startValue
                    mainDrag.end()
                    showLibraryMap(layout, returnHeight: previousHeight)
                    return
                }
                if mainDetent == .max { mainDrag.end(); return }
                let projected = mainDrag.startValue - value.predictedEndTranslation.height
                mainDrag.end()
                if feature != nil, stackedFeatureHeight <= layout.featureCloseThreshold {
                    closeFeature(restoreMainHeight: false)
                }
                settleMain(to: projected, layout: layout)
            }
    }

    private func featureDragGesture(_ layout: OutdoorPineGeometry, isMaxDrawer: Bool) -> some Gesture {
        DragGesture(minimumDistance: 0, coordinateSpace: .global)
            .updating($featureGestureActive) { _, active, _ in active = true }
            .onChanged { value in
                if !featureDrag.isDragging {
                    featureDrag.begin(at: featurePresentation.height ?? featureHeight)
                }
                if feature == .music, !isMaxDrawer {
                    musicHeightManuallyAdjusted = true
                }
                featureDrag.update(translation: value.translation.height, horizontal: value.translation.width)
                if isMaxDrawer {
                    withoutAnimation { featureOffset = max(0, value.translation.height) }
                } else {
                    updateFeatureHeight(featureDrag.startValue - value.translation.height, layout: layout, animated: false)
                }
            }
            .onEnded { value in
                guard featureDrag.isDragging else { return }
                if isMaxDrawer {
                    let projected = featureOffset + (value.predictedEndTranslation.height - value.translation.height)
                    featureDrag.end()
                    if projected > 72 {
                        closeFeature()
                    } else {
                        animate { featureOffset = 0 }
                    }
                    return
                }
                let projected = featureDrag.startValue - value.predictedEndTranslation.height
                featureDrag.end()
                settleFeature(to: projected, layout: layout)
            }
    }

    private func updateMainHeight(_ proposed: CGFloat, layout: OutdoorPineGeometry, animated: Bool) {
        let minimum = feature != nil && mainDetent != .max ? layout.mainMinimumWithFeature : layout.mainCompactHeight
        var maximum: CGFloat
        if feature != nil, mainDetent != .max {
            let featureTop = layout.size.height - layout.lowerInset - stackedFeatureHeight
            let siblingMaximum = max(minimum, featureTop - layout.safeAreaTop - 8)
            maximum = min(layout.mainFullHeight, siblingMaximum)
            if proposed > siblingMaximum {
                let newFeatureHeight = layout.size.height - layout.lowerInset - layout.safeAreaTop - 8 - proposed
                updateFeatureHeight(newFeatureHeight, layout: layout, animated: false)
                if stackedFeatureHeight <= layout.featureCloseThreshold {
                    closeFeature(restoreMainHeight: false)
                    maximum = layout.mainFullHeight
                } else {
                    let adjustedFeatureTop = layout.size.height - layout.lowerInset - stackedFeatureHeight
                    maximum = min(
                        layout.mainFullHeight,
                        max(minimum, adjustedFeatureTop - layout.safeAreaTop - 8)
                    )
                }
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
        let dragLayout = layout.featureDragLayout(
            proposedHeight: proposed,
            music: selectedFeature == .music,
            allowsDismissal: !animated
        )
        let value = dragLayout.height
        let offset = dragLayout.offset
        let visibleHeight = max(0, value - offset)
        let featureTop = layout.size.height - layout.lowerInset - visibleHeight
        let maximumMain = max(layout.mainMinimumWithFeature, featureTop - layout.safeAreaTop - 8)
        let updates = {
            featureHeight = value
            featureOffset = offset
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
        if feature == nil, projected >= layout.mainFullHeight + layout.fullscreenDragTravel * 0.5 {
            selectionHaptic()
            animate {
                mainHeight = layout.mainMaximumHeight
                mainDetent = .max
                fullscreenDrag.end()
            }
            return
        }
        let minimum = feature != nil && mainDetent != .max ? layout.mainMinimumWithFeature : layout.mainCompactHeight
        let maximum = feature != nil && mainDetent != .max
            ? min(layout.mainFullHeight, layout.size.height - layout.lowerInset - stackedFeatureHeight - layout.safeAreaTop - 8)
            : layout.mainFullHeight
        let points = [layout.mainCompactHeight, layout.mainMediumHeight, maximum]
            .filter { $0 >= minimum && $0 <= maximum }
        let target = nearest(to: min(maximum, max(minimum, projected)), among: points)
        let detent: OutdoorPineDetent = target >= layout.mainFullHeight - 16 ? .expanded : target >= layout.mainMediumHeight - 16 ? .medium : .compact
        animate {
            mainHeight = target
            mainDetent = detent
            fullscreenDrag.end()
        }
    }

    private func settleFeature(to projected: CGFloat, layout: OutdoorPineGeometry) {
        guard let feature else { return }
        let points: [CGFloat]
        if feature == .music {
            points = [
                layout.musicCompactHeight,
                layout.musicMediumHeight,
                layout.musicMaximumHeight
            ]
        } else {
            points = [
                layout.featureCompactHeight,
                layout.featureMediumHeight,
                layout.featureExpandedHeight
            ]
        }
        let valid = points.filter { $0 > layout.featureCloseThreshold }
        let minimum = feature == .music ? layout.musicCompactHeight : layout.featureCompactHeight
        if projected < minimum * 0.7 {
            closeFeature()
            return
        }
        let target = nearest(to: projected, among: valid)
        updateFeatureHeight(target, layout: layout, animated: true)
    }

    private var stackedFeatureHeight: CGFloat {
        max(0, featureHeight - featureOffset)
    }

    private func displayedMainHeight(_ layout: OutdoorPineGeometry) -> CGFloat {
        if mainDetent == .max { return layout.mainMaximumHeight }
        let base = mainHeight > 0 ? mainHeight : layout.mainHeight(for: mainDetent)
        guard feature != nil else { return min(layout.mainFullHeight, base) }
        let top = layout.size.height - layout.lowerInset - stackedFeatureHeight
        let maximum = max(layout.mainMinimumWithFeature, top - layout.safeAreaTop - 8)
        return min(maximum, base)
    }

    private func mainExpansion(_ height: CGFloat, layout: OutdoorPineGeometry) -> CGFloat {
        let span = max(1, layout.mainFullHeight - layout.mainCompactHeight)
        return min(1, max(0, (height - layout.mainCompactHeight) / span))
    }

    private func preferredFeatureHeight(for feature: OutdoorRouteFeature?, layout: OutdoorPineGeometry) -> CGFloat {
        guard let feature else { return layout.featureCompactHeight }
        if let remembered = rememberedFeatureHeights[feature] {
            let minimum = feature == .music ? layout.musicCompactHeight : layout.featureCompactHeight
            return min(layout.maximumFeatureHeight(music: feature == .music), max(minimum, remembered))
        }
        let preferred = feature == .music ? layout.musicFitHeight : feature == .type ? layout.featureMediumHeight : layout.featureCompactHeight
        return min(layout.maximumFeatureHeight(music: feature == .music), preferred)
    }

    private func toggleFeature(_ next: OutdoorRouteFeature, layout: OutdoorPineGeometry) {
        guard mainContent != .finish else { return }
        if next == .route {
            closeFeature()
            animate {
                mainContent = .routes
                mainDetent = .medium
                mainHeight = layout.libraryHeight
            }
            return
        }
        selectionHaptic()
        if feature == next {
            closeFeature()
            return
        }
        if next == .type {
            previewKind = OutdoorActivityKind.newRecordingChoices.contains(committedKind) ? committedKind : .run
        } else {
            modePrompt = nil
        }
        if let current = feature {
            rememberedFeatureHeights[current] = featureHeight
            if current == .music {
                musicEditorResetToken += 1
            }
        } else {
            mainHeightBeforeFeature = mainHeight
            mainDetentBeforeFeature = mainDetent
        }
        if feature == nil, next == .music {
            musicHeightManuallyAdjusted = false
        }

        let targetHeight = preferredFeatureHeight(for: next, layout: layout)
        rememberedFeatureHeights[next] = targetHeight
        featurePresentationGeneration &+= 1
        presentedModePrompt = next == .type ? modePrompt : nil
        presentedFeatureUsesDrawer = mainDetent == .max
        let wasMounted = presentedFeature != nil
        if !wasMounted {
            withoutAnimation {
                featureHeight = targetHeight
                featureOffset = 0
                featureIsVisible = false
                presentedFeature = next
            }
        }
        animate {
            feature = next
            presentedFeature = next
            if wasMounted { featureIsVisible = true }
            featureOffset = 0
            if mainDetent != .max {
                mainDetent = .compact
                mainHeight = min(layout.mainCompactHeight, mainHeight)
            }
            featureHeight = targetHeight
        }
    }

    private func closeFeature(restoreMainHeight: Bool = true) {
        guard let current = feature else { return }
        featurePresentationGeneration &+= 1
        let generation = featurePresentationGeneration
        if current == .type { modePrompt = nil }
        if current == .music {
            UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        }
        let restoredMainHeight = mainHeightBeforeFeature
        let restoredDetent = mainDetentBeforeFeature
        let updates = {
            feature = nil
            featureIsVisible = false
            featureOffset = 0
            featureDrag.end()
            if restoreMainHeight, mainDetent != .max, let restoredMainHeight {
                mainHeight = restoredMainHeight
                if let restoredDetent { mainDetent = restoredDetent }
            }
        }
        let completed: @MainActor @Sendable () -> Void = {
            guard feature == nil, featurePresentationGeneration == generation else { return }
            withoutAnimation {
                presentedFeature = nil
                presentedModePrompt = nil
                if current == .music { musicEditorResetToken += 1 }
            }
        }
        if #available(iOS 17.0, *) {
            withAnimation(paneDismissalAnimation, completionCriteria: .removed, updates, completion: completed)
        } else {
            withAnimation(paneDismissalAnimation, updates)
            DispatchQueue.main.asyncAfter(deadline: .now() + (reduceMotion ? 0.18 : 0.3), execute: completed)
        }
        mainHeightBeforeFeature = nil
        mainDetentBeforeFeature = nil
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

    private func closeLibrary(_ layout: OutdoorPineGeometry) {
        closeFeature()
        libraryActivityID = nil
        libraryMapReturnHeight = nil
        libraryEditorPresented = false
        animate {
            mainContent = .start
            mainDetent = .compact
            mainHeight = layout.mainCompactHeight
        }
    }

    private func showLibraryMap(_ layout: OutdoorPineGeometry, returnHeight: CGFloat? = nil) {
        guard libraryActivityID != nil, libraryMapReturnHeight == nil else { return }
        libraryMapReturnDetent = mainDetent
        mapFollowsUser = false
        mapRouteFitRequestID &+= 1
        animate { libraryMapReturnHeight = returnHeight ?? displayedMainHeight(layout) }
    }

    private func closeLibraryMap() {
        guard let height = libraryMapReturnHeight else { return }
        animate {
            mainHeight = height
            mainDetent = libraryMapReturnDetent
            libraryMapReturnHeight = nil
        }
    }

    private func startRecording(_ layout: OutdoorPineGeometry) {
        guard modePrompt == nil else { return }
        if recorder.activeActivity == nil, let prompt = modeReminder.requestPrompt() {
            modePrompt = prompt
            presentedModePrompt = prompt
            if feature != .type {
                toggleFeature(.type, layout: layout)
            }
            updateFeatureHeight(layout.featureMediumHeight, layout: layout, animated: true)
            return
        }
        beginConfirmedRecording()
    }

    private func beginConfirmedRecording() {
        shortSessionReason = nil
        mainContent = .live
        recorder.updateKind(committedKind)
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
            closeFeature(restoreMainHeight: false)
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
        let latest = store.activities.first { $0.id == activity.id } ?? activity
        guard recorder.resumeAfterFinish(latest) else {
            shortSessionReason = recorder.errorMessage
            return
        }
        committedKind = latest.kind
        previewKind = latest.kind
        musicSession.start(activityID: latest.id, existingEvents: latest.playedTracks)
        pineFinishedActivity = nil
        exposedFinishedActivity = nil
        mainContent = .live
        shortSessionReason = nil
    }

    private func commitType() {
        let startsRecording = modePrompt != nil
        selectionHaptic()
        animate { committedKind = previewKind }
        recorder.updateKind(previewKind)
        if startsRecording { modeReminder.confirm() }
        closeFeature()
        if startsRecording { beginConfirmedRecording() }
    }

    private func toggleMax(_ layout: OutdoorPineGeometry) {
        let enteringFullscreen = mainDetent != .max
        closeFeature(restoreMainHeight: false)
        selectionHaptic()
        animate {
            mainDetent = enteringFullscreen ? .max : .expanded
            mainHeight = enteringFullscreen ? layout.mainMaximumHeight : layout.mainFullHeight
        }
    }

    private func fullscreenDragGesture(_ layout: OutdoorPineGeometry) -> some Gesture {
        DragGesture(minimumDistance: 3, coordinateSpace: .global)
            .updating($fullscreenGestureActive) { _, active, _ in active = true }
            .onChanged { updateFullscreenDrag($0, layout: layout) }
            .onEnded { settleFullscreenDrag($0, layout: layout) }
    }

    private func updateFullscreenDrag(_ value: DragGesture.Value, layout: OutdoorPineGeometry) {
        if !fullscreenDrag.isDragging {
            let height = mainPresentation.height ?? displayedMainHeight(layout)
            let span = max(1, layout.mainMaximumHeight - layout.mainFullHeight)
            let progress = min(1, max(0, (height - layout.mainFullHeight) / span))
            fullscreenDrag.begin(at: progress)
            closeFeature(restoreMainHeight: false)
        }
        withoutAnimation {
            fullscreenDrag.update(translation: value.translation.height, horizontal: value.translation.width)
            fullscreenDragProgress = min(1, max(0, fullscreenDrag.startValue - value.translation.height / layout.fullscreenDragTravel))
        }
    }

    private func settleFullscreenDrag(_ value: DragGesture.Value, layout: OutdoorPineGeometry) {
        guard fullscreenDrag.isDragging else { return }
        let projected = fullscreenDrag.startValue - value.predictedEndTranslation.height / layout.fullscreenDragTravel
        let enteringFullscreen = projected >= 0.5
        if enteringFullscreen != (mainDetent == .max) { selectionHaptic() }
        animate {
            mainDetent = enteringFullscreen ? .max : .expanded
            mainHeight = enteringFullscreen ? layout.mainMaximumHeight : layout.mainFullHeight
            fullscreenDrag.end()
        }
    }

    private func adjustMainDetent(_ direction: AccessibilityAdjustmentDirection, layout: OutdoorPineGeometry) {
        let points: [OutdoorPineDetent] = [.compact, .medium, .expanded, .max]
        guard let current = points.firstIndex(of: mainDetent) else { return }
        let next: Int
        switch direction {
        case .increment: next = min(points.count - 1, current + 1)
        case .decrement: next = max(0, current - 1)
        @unknown default: next = current
        }
        guard next != current else { return }
        let detent = points[next]
        if detent == .max || mainDetent == .max {
            toggleMax(layout)
            return
        }
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
        let points: [CGFloat]
        if selectedFeature == .music {
            points = [
                layout.musicCompactHeight,
                layout.musicMediumHeight,
                layout.musicFitHeight
            ]
        } else {
            points = [
                layout.featureCompactHeight,
                layout.featureMediumHeight,
                layout.featureExpandedHeight
            ]
        }
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
        if feature == .music, featureHeight <= layout.musicCompactHeight + 8 { return "Compact" }
        if feature == .music, featureHeight <= layout.musicMediumHeight + 8 { return "Medium" }
        if feature == .music { return "Expanded" }
        if featureHeight <= layout.featureCompactHeight + 8 { return "Compact" }
        if featureHeight <= layout.featureMediumHeight + 8 { return "Medium" }
        return "Expanded"
    }

    private func applyMusicContentFit(_ height: CGFloat, requiresSpace: Bool, layout: OutdoorPineGeometry) {
        guard feature == .music, height > 0, !featureDrag.isDragging else { return }
        let preferred = min(layout.musicMaximumHeight, max(layout.musicCompactHeight, height))
        if requiresSpace {
            if featureHeight < preferred {
                updateFeatureHeight(preferred, layout: layout, animated: true)
            }
        } else if !musicHeightManuallyAdjusted, featureHeight == 0 || abs(featureHeight - preferred) > 12 {
            updateFeatureHeight(preferred, layout: layout, animated: true)
        }
    }

    private func nearest(to value: CGFloat, among points: [CGFloat]) -> CGFloat {
        points.min(by: { abs($0 - value) < abs($1 - value) }) ?? value
    }

    private var paneAnimation: Animation {
        reduceMotion ? .easeOut(duration: 0.18) : .spring(response: 0.42, dampingFraction: 1, blendDuration: 0.12)
    }

    private var paneDismissalAnimation: Animation {
        reduceMotion ? .easeOut(duration: 0.18) : .timingCurve(0.22, 0.78, 0.26, 1, duration: 0.26)
    }

    private func animate(_ updates: () -> Void) {
        withAnimation(paneAnimation, updates)
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
    case routes
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
    let onMeasuredHeight: (CGFloat, Bool) -> Void
    var body: some View {
        OutdoorMusicEditorView(
            library: library,
            musicManager: musicManager,
            initialItem: entry,
            resetToken: resetToken,
            onMeasuredHeight: onMeasuredHeight,
            onImportLocalMusic: onImportLocalMusic
        )
        .accessibilityElement(children: .contain)
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
