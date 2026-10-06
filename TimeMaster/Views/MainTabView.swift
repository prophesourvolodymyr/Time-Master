import SwiftUI
import Combine
import UniformTypeIdentifiers
import TimeMasterCore
#if os(iOS)
import UIKit
#endif

struct MainTabView: View {
    @EnvironmentObject var workoutStore: WorkoutStore
    @StateObject private var databaseStore = DatabaseStore.shared
    @StateObject private var databaseNavigationState = DatabaseNavigationState()
    @StateObject private var aiStore = AIStore.shared
    @StateObject private var outdoorStore = OutdoorActivityStore()
    @StateObject private var musicLibraryStore = MusicLibraryStore()
    @StateObject private var outdoorPreferencesStore = OutdoorRecordingPreferencesStore()
    @StateObject private var navigationLayout = SlotNavigationLayoutStore()
    @State private var selectedDestination: String? = SlotNavigationDestination.home.rawValue
    @State private var lastPageDestination = SlotNavigationDestination.home.rawValue
    @State private var scheduleWeek = WeeklyWorkoutSchedule.weekStart(Date())
    @State private var requestedWorkoutID: UUID?
    #if os(iOS)
    @State private var activeOutdoorKind: OutdoorActivityKind?
    @State private var activeOutdoorPlannedRoute: PlannedRoute?
    @State private var activeOutdoorActivityID: UUID?
    @StateObject private var outdoorRecorder: OutdoorLocationRecorder
    #endif
#if os(macOS)
    @FocusState private var keyboardFocused: Bool
#endif
#if os(iOS)
    init() {
        let outdoorStore = OutdoorActivityStore()
        let outdoorPreferences = OutdoorRecordingPreferencesStore()
        _outdoorStore = StateObject(wrappedValue: outdoorStore)
        _outdoorPreferencesStore = StateObject(wrappedValue: outdoorPreferences)
        _outdoorRecorder = StateObject(
            wrappedValue: OutdoorLocationRecorder(
                kind: .run,
                store: outdoorStore,
                preferences: outdoorPreferences
            )
        )
    }
#endif

    /// The bar is taller on macOS, where the arc has always carried more of the surface.
    private static var barHeight: CGFloat {
#if os(macOS)
        196
#else
        SlotCarouselNavigationBar.fullHeight
#endif
    }

    var body: some View {
        Group {
            SlotCarouselNavigation(
                selection: $selectedDestination,
                items: navigationLayout.items,
                availableItems: navigationLayout.catalog,
                onInsert: { id, index in navigationLayout.insert(id: id, at: index) },
                onMove: { id, index in navigationLayout.move(id: id, to: index) },
                onRemove: removeDestination,
                onEditingEnded: ensureSelection,
                barHeight: Self.barHeight,
                guideDefaultsKey: "tm.navigation.editorGuideSeen",
                theme: .timeMaster,
                strings: .timeMaster
            ) {
                detailView
            }
            #if os(iOS)
            .overlay(alignment: .topTrailing) {
                if selectedPage != .map, outdoorRecorder.isLiveSession {
                    OutdoorLiveWorkoutStatusWidget(
                        recorder: outdoorRecorder,
                        preferences: outdoorPreferencesStore,
                        onOpenMap: openActiveOutdoorMap
                    )
                    .padding(.top, 8)
                    .padding(.trailing, 12)
                    .zIndex(100)
                }
            }
            .fullScreenCover(
                item: Binding(
                    get: { UIDevice.current.userInterfaceIdiom == .phone ? activeOutdoorKind : nil },
                    set: { activeOutdoorKind = $0 }
                ),
                onDismiss: {
                    activeOutdoorPlannedRoute = nil
                    activeOutdoorActivityID = nil
                }
            ) { kind in
                OutdoorRouteRecordingView(
                    kind: kind,
                    store: outdoorStore,
                    plannedRoute: activeOutdoorPlannedRoute,
                    preferences: outdoorPreferencesStore,
                    musicLibrary: musicLibraryStore,
                    initialActivityID: activeOutdoorActivityID,
                    recordingSession: outdoorRecorder
                )
            }
            #endif
        }
        .environmentObject(musicLibraryStore)
        .environmentObject(outdoorPreferencesStore)
        .environmentObject(databaseNavigationState)
#if os(macOS)
        .buttonStyle(.plain)
        .focusable()
        .focusEffectDisabled()
        .focused($keyboardFocused)
        .onKeyPress(phases: [.down, .repeat], action: handleKeyPress)
#endif
        .onReceive(NotificationCenter.default.publisher(for: .openWorkoutDetail)) { notification in
            routeToWorkoutDetail(notification)
        }
        .onReceive(NotificationCenter.default.publisher(for: .openSettingsCommand)) { _ in
            if !navigationLayout.contains(id: SlotNavigationDestination.settings.rawValue) {
                navigationLayout.insert(id: SlotNavigationDestination.settings.rawValue, at: navigationLayout.order.count)
            }
            selectedDestination = SlotNavigationDestination.settings.rawValue
        }
        .onChange(of: selectedDestination) { destination in
            guard let destination, destination != SlotNavigationDestination.map.rawValue else { return }
            lastPageDestination = destination
        }
        .onAppear {
            musicLibraryStore.setCustomTypes(workoutStore.customWorkoutTypes)
            musicLibraryStore.setWorkouts(workoutStore.workouts)
            ensureSelection()
#if os(macOS)
            keyboardFocused = true
#endif
        }
        .onReceive(workoutStore.$workouts.dropFirst()) { musicLibraryStore.setWorkouts($0) }
        .onReceive(workoutStore.$customWorkoutTypes.dropFirst()) { musicLibraryStore.setCustomTypes($0) }
    }

    private var selectedPage: SlotNavigationDestination {
        selectedDestination.flatMap(SlotNavigationDestination.init(rawValue:)) ?? .home
    }

    @ViewBuilder
    private var detailView: some View {
        switch selectedPage {
        case .home:
            homeDestination
        case .workouts:
            WorkoutListView(requestedWorkoutID: $requestedWorkoutID)
                .environmentObject(outdoorStore)
                .environmentObject(workoutStore)
        case .database:
            DatabaseView()
                .environmentObject(databaseStore)
                .environmentObject(workoutStore)
                .environmentObject(outdoorStore)
        case .analytics:
            AnalyticsView()
                .environmentObject(workoutStore)
                .environmentObject(outdoorStore)
        case .schedule:
            ScheduleView(week: $scheduleWeek)
                .environmentObject(workoutStore)
        case .settings:
            SettingsView()
                .environmentObject(workoutStore)
                .environmentObject(outdoorStore)
        case .coach:
            AICoachView()
                .environmentObject(aiStore)
        case .profile:
            ProfileView()
                .environmentObject(outdoorStore)
        case .map:
            #if os(iOS)
            mapDestination
            #else
            homeDestination
            #endif
        }
    }

    @ViewBuilder
    private var homeDestination: some View {
        HomeDashboardView(
            onBrowseWorkouts: { selectedDestination = SlotNavigationDestination.workouts.rawValue },
            onBrowseDatabase: { selectedDestination = SlotNavigationDestination.database.rawValue },
            onCreateWorkout: openWorkoutCreator,
            onStartOutdoor: startOutdoor
        )
        .environmentObject(outdoorStore)
        .environmentObject(workoutStore)
        .environmentObject(databaseStore)
    }

#if os(iOS)
    @ViewBuilder
    private var mapDestination: some View {
        OutdoorRouteRecordingView(
            kind: outdoorRecorder.activeActivity?.kind ?? .run,
            store: outdoorStore,
            preferences: outdoorPreferencesStore,
            musicLibrary: musicLibraryStore,
            initialActivityID: outdoorRecorder.activeActivity?.id,
            recordingSession: outdoorRecorder,
            onExit: { selectedDestination = lastPageDestination }
        )
    }
#endif

#if os(iOS)
    private func openActiveOutdoorMap() {
        guard UIDevice.current.userInterfaceIdiom == .phone,
              let activity = outdoorRecorder.activeActivity
        else { return }
        activeOutdoorKind = activity.kind
        activeOutdoorActivityID = activity.id
    }
#endif

    private func startOutdoor(_ kind: OutdoorActivityKind, _ route: PlannedRoute?, _ activityID: UUID?) {
#if os(iOS)
        guard UIDevice.current.userInterfaceIdiom == .phone else { return }
        activeOutdoorPlannedRoute = route
        activeOutdoorActivityID = activityID
        activeOutdoorKind = kind
#endif
    }

    private func openWorkoutCreator() {
        selectedDestination = SlotNavigationDestination.workouts.rawValue
        DispatchQueue.main.async {
            NotificationCenter.default.post(name: .newWorkoutCommand, object: nil)
        }
    }

    private func routeToWorkoutDetail(_ notification: Notification) {
        guard let workoutID = notification.userInfo?["workoutID"] as? UUID else { return }
        selectedDestination = SlotNavigationDestination.workouts.rawValue
        requestedWorkoutID = workoutID
    }

    /// A page can be removed while it is the visible one. Land on the first remaining page
    /// instead of leaving the bar pointing at nothing.
    private func ensureSelection() {
        guard !navigationLayout.contains(id: selectedDestination) else { return }
        selectedDestination = navigationLayout.firstID ?? SlotNavigationDestination.home.rawValue
        lastPageDestination = selectedDestination ?? lastPageDestination
    }

    private func removeDestination(_ id: String) {
        navigationLayout.remove(id: id)
        ensureSelection()
    }

#if os(macOS)
    private func handleKeyPress(_ keyPress: KeyPress) -> KeyPress.Result {
        switch keyPress.key {
        case .leftArrow:
            moveSelection(by: -1)
            return .handled
        case .rightArrow:
            moveSelection(by: 1)
            return .handled
        default:
            break
        }

        guard let character = keyPress.characters.first,
              let number = Int(String(character)),
              number > 0,
              navigationLayout.order.indices.contains(number - 1) else {
            return .ignored
        }
        selectedDestination = navigationLayout.order[number - 1].rawValue
        return .handled
    }

    private func moveSelection(by delta: Int) {
        guard let current = selectedDestination,
              let index = navigationLayout.order.firstIndex(where: { $0.rawValue == current }) else { return }
        let next = min(max(index + delta, 0), navigationLayout.order.count - 1)
        guard next != index else { return }
        selectedDestination = navigationLayout.order[next].rawValue
    }
#endif
}

#Preview {
    MainTabView()
        .environmentObject(WorkoutStore())
        .preferredColorScheme(.dark)
}
