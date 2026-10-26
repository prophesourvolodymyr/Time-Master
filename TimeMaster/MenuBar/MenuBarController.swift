#if os(macOS)
import AppKit
import Combine
import SwiftUI

@MainActor
final class MenuBarController: NSObject, NSPopoverDelegate {
    static let shared = MenuBarController()

    private let preferences = MenuBarPreferences.shared
    private let session = WorkoutLiveSession.shared
    private let tips = MenuBarGlanceTipController()
    private var startup: TmaxStartupModel?
    private var statusItem: NSStatusItem?
    private var popover: NSPopover?
    private var bag = Set<AnyCancellable>()
    private var storeBag = Set<AnyCancellable>()
    private var detector = MenuBarMomentDetector()
    private var currentState: WorkoutLiveState?
    private var currentFinish: WorkoutLiveFinish?
    private var showsLabel = true
    private var upcoming: MenuBarUpcoming?
    private var lastPresentation: MenuBarItemPresentation?
    private var lastWorkoutID: UUID?
    private var mutedWorkoutID: UUID?
    private var clock: Timer?
    private var previousApp: NSRunningApplication?
    private var activatedForKeyboard = false

    private override init() {
        super.init()
    }

    func install(startup: TmaxStartupModel) {
        guard self.startup == nil else { return }
        self.startup = startup
        tips.onOpen = { [weak self] in self?.showPopover() }
        tips.onMute = { [weak self] in self?.muteCurrentWorkout() }
        bind(startup)
        startClock()
    }

    private func bind(_ startup: TmaxStartupModel) {
        preferences.$isEnabled
            .removeDuplicates()
            .sink { [weak self] enabled in
                guard let self else { return }
                if enabled { self.installStatusItem() } else { self.removeStatusItem() }
            }
            .store(in: &bag)

        Publishers.CombineLatest3(session.$state, session.$lastFinish, preferences.$showsLabel)
            .sink { [weak self] state, finish, showsLabel in
                guard let self else { return }
                if let state,
                   self.currentState?.workoutID != state.workoutID || self.currentState?.startedAt != state.startedAt {
                    self.mutedWorkoutID = nil
                }
                self.currentState = state
                self.currentFinish = finish
                self.showsLabel = showsLabel
                if let state { self.lastWorkoutID = state.workoutID }
                self.refresh()
                self.detectMoments(state: state, finish: finish)
            }
            .store(in: &bag)

        startup.$workoutStore
            .compactMap { $0 }
            .first()
            .sink { [weak self] store in self?.observe(store) }
            .store(in: &bag)
    }

    private func observe(_ store: WorkoutStore) {
        storeBag.removeAll()
        let changes: [AnyPublisher<Void, Never>] = [
            store.$weeklySchedule.map { _ in () }.eraseToAnyPublisher(),
            store.$typeSchedules.map { _ in () }.eraseToAnyPublisher(),
            store.$workouts.map { _ in () }.eraseToAnyPublisher(),
            store.$historyEntries.map { _ in () }.eraseToAnyPublisher()
        ]
        Publishers.MergeMany(changes)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] in self?.recomputeUpcoming() }
            .store(in: &storeBag)
        recomputeUpcoming()
    }

    private func startClock() {
        let timer = Timer(timeInterval: 5, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.recomputeUpcoming()
                self?.refresh()
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        clock = timer
    }

    private func recomputeUpcoming() {
        guard let store = startup?.workoutStore else {
            upcoming = nil
            return
        }
        let now = Date()
        let next = store.scheduledWorkouts(for: now, now: now)
            .filter { $0.status == .pending && $0.hasScheduledTime && $0.scheduledStart > now && !$0.workout.sections.isEmpty }
            .min { $0.scheduledStart < $1.scheduledStart }
        let value = next.map { MenuBarUpcoming(name: $0.workout.name, startsAt: $0.scheduledStart) }
        if value != upcoming {
            upcoming = value
            refresh()
        }
    }

    private func installStatusItem() {
        guard statusItem == nil else { return }
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        item.button?.target = self
        item.button?.action = #selector(statusItemClicked(_:))
        item.button?.sendAction(on: [.leftMouseUp, .rightMouseUp])
        statusItem = item
        lastPresentation = nil
        refresh()
    }

    private func removeStatusItem() {
        closePopover()
        tips.hide(animated: false)
        if let statusItem {
            NSStatusBar.system.removeStatusItem(statusItem)
        }
        statusItem = nil
        lastPresentation = nil
    }

    private func refresh() {
        guard let button = statusItem?.button else { return }
        let presentation = MenuBarItemPresentation.make(
            state: currentState,
            finish: currentFinish,
            upcoming: upcoming,
            now: Date(),
            showsLabel: showsLabel
        )
        guard presentation != lastPresentation else { return }
        lastPresentation = presentation
        button.image = MenuBarIconRenderer.image(for: presentation.glyph, progress: presentation.progress)
        if let label = presentation.label {
            let weight: NSFont.Weight = switch presentation.glyph {
            case .countdown, .exercise, .paused, .finished: .bold
            default: .medium
            }
            button.imagePosition = .imageLeading
            button.attributedTitle = NSAttributedString(
                string: " " + label,
                attributes: [.font: NSFont.monospacedDigitSystemFont(ofSize: 12, weight: weight)]
            )
        } else {
            button.imagePosition = .imageOnly
            button.title = ""
        }
        button.toolTip = presentation.tooltip
        button.setAccessibilityLabel(presentation.accessibilityLabel)
    }

    @objc private func statusItemClicked(_ sender: NSStatusBarButton) {
        guard let event = NSApp.currentEvent else {
            togglePopover()
            return
        }
        if event.type == .rightMouseUp || event.modifierFlags.contains(.control) {
            showContextMenu()
        } else {
            togglePopover()
        }
    }

    private func showContextMenu() {
        guard let statusItem else { return }
        closePopover()
        tips.hide(animated: false)
        let menu = NSMenu()
        menu.addItem(item("Open Tmax", #selector(openTmax)))
        if let state = session.state {
            menu.addItem(item(state.isPaused ? "Resume Workout" : "Pause Workout", #selector(togglePause)))
            menu.addItem(item("Skip", #selector(skipPhase)))
        } else {
            menu.addItem(item("Start Workout", #selector(startWorkout)))
        }
        menu.addItem(.separator())
        menu.addItem(item("Hide Menu Bar Icon", #selector(hideIcon)))
        menu.addItem(item("Quit Tmax", #selector(quitTmax)))
        statusItem.menu = menu
        statusItem.button?.performClick(nil)
        statusItem.menu = nil
    }

    private func item(_ title: String, _ action: Selector) -> NSMenuItem {
        let menuItem = NSMenuItem(title: title, action: action, keyEquivalent: "")
        menuItem.target = self
        return menuItem
    }

    @objc private func openTmax() { AppCommandBus.showMainWindow() }
    @objc private func togglePause() { session.send(.togglePause) }
    @objc private func skipPhase() { session.send(.skipPhase) }
    @objc private func startWorkout() { AppCommandBus.startWorkout(nil) }
    @objc private func hideIcon() { preferences.isEnabled = false }
    @objc private func quitTmax() { NSApp.terminate(nil) }

    private func togglePopover() {
        if popover?.isShown == true {
            closePopover()
        } else {
            showPopover()
        }
    }

    private func showPopover() {
        guard popover?.isShown != true, let button = statusItem?.button, let startup else { return }
        tips.hide(animated: false)
        let popover = NSPopover()
        popover.behavior = .transient
        popover.animates = !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
        popover.appearance = NSAppearance(named: .darkAqua)
        popover.contentSize = NSSize(width: MenuBarPopupMetrics.width, height: MenuBarPopupMetrics.height)
        popover.delegate = self
        popover.contentViewController = NSHostingController(
            rootView: MenuBarPopupRoot(startup: startup).environment(\.menuBarActions, actions)
        )
        self.popover = popover
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
    }

    private func closePopover() {
        popover?.performClose(nil)
    }

    nonisolated func popoverDidClose(_ notification: Notification) {
        guard let closed = notification.object as? NSPopover else { return }
        Task { @MainActor in
            guard popover === closed else { return }
            popover = nil
            restorePreviousApp()
        }
    }

    private func activateForKeyboard() {
        guard !NSApp.isActive else { return }
        let frontmost = NSWorkspace.shared.frontmostApplication
        if frontmost?.processIdentifier != ProcessInfo.processInfo.processIdentifier {
            previousApp = frontmost
        }
        activatedForKeyboard = true
        NSRunningApplication.current.activate(options: [])
        popover?.contentViewController?.view.window?.makeKey()
    }

    private func restorePreviousApp() {
        guard activatedForKeyboard else { return }
        activatedForKeyboard = false
        let mainWindowShowing = MacMainWindow.window?.isVisible == true
        if !mainWindowShowing {
            previousApp?.activate(options: [])
        }
        previousApp = nil
    }

    private var actions: MenuBarPopupActions {
        MenuBarPopupActions(
            startWorkout: { [weak self] id in
                self?.closePopover()
                AppCommandBus.startWorkout(id)
            },
            openPage: { [weak self] destination, prompt in
                self?.closePopover()
                AppCommandBus.openPage(destination, coachPrompt: prompt)
            },
            openWorkoutDetail: { [weak self] id in
                self?.closePopover()
                AppCommandBus.openWorkoutDetail(id)
            },
            newWorkout: { [weak self] in
                self?.closePopover()
                AppCommandBus.newWorkout()
            },
            showMainWindow: { [weak self] in
                self?.closePopover()
                AppCommandBus.showMainWindow()
            },
            quit: { NSApp.terminate(nil) },
            requestKeyboard: { [weak self] in self?.activateForKeyboard() }
        )
    }

    private func muteCurrentWorkout() {
        mutedWorkoutID = session.state?.workoutID ?? lastWorkoutID
    }

    private var tmaxIsFront: Bool {
        guard NSApp.isActive, let window = MacMainWindow.window else { return false }
        return window.isVisible && window.isKeyWindow
    }

    private func detectMoments(state: WorkoutLiveState?, finish: WorkoutLiveFinish?) {
        let moments = detector.ingest(state: state, finish: finish)
        guard let moment = moments.last(where: { preferences.isMomentEnabled($0.kind) }) else { return }
        guard preferences.level != .quiet,
              popover?.isShown != true,
              statusItem != nil else { return }
        let workoutID = state?.workoutID ?? lastWorkoutID
        guard workoutID == nil || workoutID != mutedWorkoutID else { return }
        if preferences.calmWhenTmaxIsFront && tmaxIsFront { return }
        guard let anchor = statusItem?.button?.window?.frame else { return }

        var quote: String?
        if moment.kind == .restStarted, preferences.showsQuotes {
            let picked = MenuBarQuotes.quote(seed: state?.elapsedSeconds ?? 0)
            quote = "“\(picked.text)” · \(picked.author)"
        }
        let tip = MenuBarTip(
            title: moment.title,
            message: moment.message,
            quote: quote,
            symbol: symbol(for: moment.kind),
            isRest: moment.kind == .restStarted
        )
        tips.show(tip, below: anchor)
        if preferences.level == .alert {
            NSSound(named: NSSound.Name("Pop"))?.play()
        }
    }

    private func symbol(for kind: MenuBarMomentKind) -> String {
        switch kind {
        case .countdown: "timer"
        case .restStarted: "moon.zzz.fill"
        case .sectionChanged: "list.number"
        case .halfway: "flag.fill"
        case .lastMinute: "hourglass"
        case .finished: "checkmark.seal.fill"
        }
    }
}
#endif
