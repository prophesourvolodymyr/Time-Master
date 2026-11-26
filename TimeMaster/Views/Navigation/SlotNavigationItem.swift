// SlotNavigationItem.swift
//
// Navigation models, theme, copy and the app's destination catalog with its saved order. The bar, its editor, the arc
// and the page wheel use them; the app owns the items, the selection and the persistence.

import SwiftUI

// MARK: - Presentation

enum SlotNavigationPresentation: Equatable, Hashable {
    case visible
    case hidden
}

enum SlotNavigationPlacement: String, CaseIterable {
    case bottom
    case top

    var edge: Edge {
        self == .bottom ? .bottom : .top
    }

    var alignment: Alignment {
        self == .bottom ? .bottom : .top
    }

    var outwardSign: CGFloat {
        self == .bottom ? 1 : -1
    }

    func contentBounds(in frame: CGRect, reservedHeight: CGFloat) -> CGRect {
        guard frame.origin.x.isFinite, frame.origin.y.isFinite,
              frame.size.width.isFinite, frame.size.height.isFinite else { return .zero }
        let width = max(0, frame.size.width)
        let height = max(0, frame.size.height)
        guard (frame.origin.x + width).isFinite,
              (frame.origin.y + height).isFinite else { return .zero }
        let reserved = reservedHeight.isNaN ? 0 : min(height, max(0, reservedHeight))
        return CGRect(
            x: frame.origin.x,
            y: frame.origin.y + (self == .top ? reserved : 0),
            width: width,
            height: height - reserved
        )
    }

    func acceptsDismiss(translation: CGSize, projected: CGSize) -> Bool {
        let distance = translation.height * outwardSign
        let projectedDistance = projected.height * outwardSign
        guard translation.width.isFinite, distance.isFinite,
              projected.width.isFinite, projectedDistance.isFinite,
              distance > abs(translation.width) * 1.3,
              projectedDistance > abs(projected.width) * 1.3,
              projectedDistance >= distance else { return false }
        return distance > 40 || projectedDistance > 80
    }

    func dismissOffset(for translation: CGSize) -> CGFloat {
        guard translation.width.isFinite, translation.height.isFinite,
              translation.height * outwardSign > abs(translation.width) * 1.3 else { return 0 }
        return translation.height
    }

    /// Whether a drag on the bar pulls it away from its edge into the page wheel: inward, mostly straight, and far
    /// enough that a tap or a sideways scrub that wobbles never starts it.
    func beginsWheelPull(translation: CGSize) -> Bool {
        let inward = -translation.height * outwardSign
        guard translation.width.isFinite, inward.isFinite else { return false }
        return inward > 16 && inward > abs(translation.width) * 1.4
    }
}

struct SlotNavigationPresentationPreferenceKey: PreferenceKey {
    static let defaultValue: SlotNavigationPresentation? = nil

    static func reduce(
        value: inout SlotNavigationPresentation?,
        nextValue: () -> SlotNavigationPresentation?
    ) {
        if let next = nextValue() {
            value = next
        }
    }
}

struct SlotNavigationInteractionDisabledPreferenceKey: PreferenceKey {
    static let defaultValue = false
    static func reduce(value: inout Bool, nextValue: () -> Bool) {
        value = value || nextValue()
    }
}

struct SlotNavigationStripPreferenceKey: PreferenceKey {
    static let defaultValue = false
    static func reduce(value: inout Bool, nextValue: () -> Bool) {
        value = value || nextValue()
    }
}

extension View {
    func slotNavigationPresentation(_ presentation: SlotNavigationPresentation) -> some View {
        preference(key: SlotNavigationPresentationPreferenceKey.self, value: presentation)
    }

    /// Hides the navigation while a destination is presenting something immersive — a detail
    /// drawer, a player, a modal — without changing the selection. The bar comes back when the
    /// flag clears.
    func slotNavigationInteractionDisabled(_ disabled: Bool = true) -> some View {
        preference(key: SlotNavigationInteractionDisabledPreferenceKey.self, value: disabled)
    }

    /// Asks the navigation to use its flat strip instead of the arch while this page is shown,
    /// for pages that place a primary control directly on top of the bar.
    func slotNavigationPrefersStrip(_ prefersStrip: Bool = true) -> some View {
        preference(key: SlotNavigationStripPreferenceKey.self, value: prefersStrip)
    }
}

// MARK: - Arc lens frame

private struct SlotNavigationArcFrameKey: EnvironmentKey {
    static let defaultValue = CGRect.zero
}

extension EnvironmentValues {
    /// Rectangle covering the arc surface, in the global coordinate space, whenever the bar
    /// is in its full layout and the editor is closed. Content that stretches or refracts
    /// around the arc reads it; it stays `.zero` at every other time.
    var slotNavigationArcFrame: CGRect {
        get { self[SlotNavigationArcFrameKey.self] }
        set { self[SlotNavigationArcFrameKey.self] = newValue }
    }
}

// MARK: - Theme

struct SlotNavigationTypography {
    /// Title of the editing overlay, for example "EDIT MENU BAR".
    var editorTitle: Font
    /// Body copy in the editing guide.
    var body: Font

    static let standard = SlotNavigationTypography(
        editorTitle: TimeMasterFont.pageTitle(31, relativeTo: .title2),
        body: TimeMasterFont.body()
    )
}

/// Colors used by the navigation surface, the wheel and the editor chrome.
struct SlotNavigationTheme {
    /// Fill of the arc surface.
    var surface: Color
    /// Hairline drawn along the arc and around the wheel.
    var rim: Color
    /// Item labels and the editor title.
    var textPrimary: Color
    /// Guide copy.
    var textSecondary: Color
    /// The red remove buttons and the notification badges.
    var destructive: Color
    /// Scrim shown over the content while the editor is open.
    var scrim: Color
    /// Opacity of `scrim` when Reduce Transparency is off.
    var scrimOpacity: Double
    /// Page background behind the arc.
    var background: Color
    /// Brand accent of the editor: the "+" slots, the catalog's add badges and the guide's step markers.
    var accent: Color
    var typography: SlotNavigationTypography

    /// TimeMaster's palette: the app's near-black background with a single hairline rim.
    static let timeMaster = SlotNavigationTheme(
        surface: Theme.background,
        rim: Color.white.opacity(0.12),
        textPrimary: Theme.textPrimary,
        textSecondary: Theme.textSecondary,
        destructive: Color(hex: "FF3B30"),
        scrim: .black,
        scrimOpacity: 0.35,
        background: Theme.background,
        accent: Theme.toolbarOrange,
        typography: .standard
    )
}

// MARK: - Copy

struct SlotNavigationGuideStep {
    /// SF Symbol drawn in the step's marker.
    var symbol: String
    var text: String
}

/// Every string the navigation shows or announces.
struct SlotNavigationStrings {
    var editorTitle: String
    var guideSteps: [SlotNavigationGuideStep]
    var guideDismissTitle: String
    var guideAccessibilityLabel: String
    var editNavigation: String
    var doneEditing: String
    var showNavigation: String
    var openWheel: String
    var addItemTitle: String
    var addItemAtStart: String
    var addItemAtEnd: String
    var addToNavigation: (String) -> String
    var removeFromNavigation: String
    var removeItem: (String) -> String
    var selectedValue: String
    var notSelectedValue: String
    var alreadyAddedValue: String
    var editingValue: String
    var expandedValue: String
    var compactValue: String

    static let timeMaster = SlotNavigationStrings(
        editorTitle: "Edit menu bar",
        guideSteps: [
            SlotNavigationGuideStep(symbol: "plus", text: "Tap + to add one of the app's pages."),
            SlotNavigationGuideStep(symbol: "minus", text: "Tap the red minus on a page to take it off the menu."),
            SlotNavigationGuideStep(symbol: "hand.point.up.left", text: "Hold an icon, then drag it to change its position."),
            SlotNavigationGuideStep(symbol: "circle.dashed", text: "Swipe up on the menu to turn it into the page wheel."),
            SlotNavigationGuideStep(symbol: "checkmark", text: "Tap the dimmed background to finish.")
        ],
        guideDismissTitle: "Got it",
        guideAccessibilityLabel: "Menu editing guide",
        editNavigation: "Edit navigation",
        doneEditing: "Done",
        showNavigation: "Show navigation",
        openWheel: "Open page wheel",
        addItemTitle: "Add",
        addItemAtStart: "Add page at beginning",
        addItemAtEnd: "Add page at end",
        addToNavigation: { "Add \($0)" },
        removeFromNavigation: "Remove from navigation",
        removeItem: { "Remove \($0)" },
        selectedValue: "Selected",
        notSelectedValue: "Not selected",
        alreadyAddedValue: "Already on the menu",
        editingValue: "Editing navigation",
        expandedValue: "Expanded",
        compactValue: "Compact"
    )
}

// MARK: - Item

enum SlotNavigationIcon: Hashable {
    case system(String)
    case art(lit: String, unlit: String)
}

/// A page's icon, lit by `lit` from 0 to 1 (the art icons cross-fade to their glowing version).
struct SlotNavigationIconImage: View {
    let icon: SlotNavigationIcon
    let size: CGFloat
    var lit: CGFloat = 0

    static let artScale: CGFloat = 1.15

    var body: some View {
        switch icon {
        case let .system(name):
            Image(systemName: name)
                .font(.system(size: size, weight: .semibold))
        case let .art(litName, unlitName):
            ZStack {
                Image(unlitName)
                    .resizable()
                    .interpolation(.high)
                    .scaledToFit()
                    .opacity(1 - lit)
                Image(litName)
                    .resizable()
                    .interpolation(.high)
                    .scaledToFit()
                    .opacity(lit)
                    .blendMode(.plusLighter)
            }
            .compositingGroup()
            .frame(width: size * Self.artScale, height: size * Self.artScale)
        }
    }
}

struct SlotNavigationItem: Identifiable, Hashable {
    let id: String
    let icon: SlotNavigationIcon
    let title: String
    let accessibilityHint: String
    let presentation: SlotNavigationPresentation
    let isPending: Bool

    init(
        id: String,
        icon: SlotNavigationIcon,
        title: String,
        accessibilityHint: String = "",
        presentation: SlotNavigationPresentation = .visible,
        isPending: Bool = false
    ) {
        self.id = id
        self.icon = icon
        self.title = title
        self.accessibilityHint = accessibilityHint
        self.presentation = presentation
        self.isPending = isPending
    }
}

enum SlotNavigationBarLayout: Equatable {
    case full
    case inline

    static func resolve(isExpanded: Bool, isEditing: Bool, isOverlayVisible: Bool, prefersInline: Bool) -> Self {
        isExpanded || isEditing || isOverlayVisible || !prefersInline ? .full : .inline
    }
}

// MARK: - Destinations

/// Every page the app can put on the bar. Raw values are the ids the component stores, so
/// they must stay stable once a layout has been saved on a device.
enum SlotNavigationDestination: String, CaseIterable, Identifiable {
    case home
    case workouts
    case database
    case skills
    case analytics
    case coach
    case profile
    case ranked
    case physique
    case map
    case schedule
    case settings

    var id: String { rawValue }

    var title: String {
        switch self {
        case .home: "Home"
        case .workouts: "Workouts"
        case .database: "Database"
        case .skills: "Skills"
        case .analytics: "Analytics"
        case .coach: "AI Coach"
        case .profile: "Profile"
        case .ranked: "Ranked"
        case .physique: "Physique"
        case .map: "Map"
        case .schedule: "Schedule"
        case .settings: "Settings"
        }
    }

    var icon: SlotNavigationIcon {
        .art(lit: "tab_\(rawValue)_lit", unlit: "tab_\(rawValue)_unlit")
    }

    var accessibilityHint: String {
        switch self {
        case .home: "Shows your daily dashboard."
        case .workouts: "Shows your workouts."
        case .database: "Shows your exercise database."
        case .skills: "Shows the skills you are learning."
        case .analytics: "Shows your workout analytics."
        case .coach: "Opens your AI coach."
        case .profile: "Shows your profile and history."
        case .ranked: "Shows your Ranked arena and movement loadout."
        case .physique: "Shows Physique Duels, guided poses and its independent competitive rating."
        case .map: "Opens the live outdoor map and workout start page."
        case .schedule: "Shows your weekly workout Plans and streak."
        case .settings: "Shows app settings."
        }
    }

    var presentation: SlotNavigationPresentation {
        switch self {
        case .map: .hidden
        default: .visible
        }
    }

    var isAvailable: Bool {
        #if os(iOS)
        true
        #else
        self != .map
        #endif
    }

    /// The arrangement the app ships with, before anyone edits the bar.
    static let defaultOrder: [SlotNavigationDestination] = [.coach, .profile, .workouts, .home, .database, .schedule, .skills, .map, .ranked, .physique, .analytics, .settings]
}

extension SlotNavigationItem {
    init(destination: SlotNavigationDestination, isPending: Bool = false) {
        self.init(
            id: destination.rawValue,
            icon: destination.icon,
            title: destination.title,
            accessibilityHint: destination.accessibilityHint,
            presentation: destination.presentation,
            isPending: isPending
        )
    }
}

// MARK: - Saved layout

/// The order of pages on the bar, kept per device. The component holds no copy of the layout:
/// every edit is applied here and saved immediately.
@MainActor
final class SlotNavigationLayoutStore: ObservableObject {
    @Published private(set) var order: [SlotNavigationDestination]

    private let defaults: UserDefaults
    private let orderKey = "tm.navigation.order.v1"
    private static let workoutsLeftOfHomeKey = "tm.navigation.workoutsLeftOfHome.v1"
    private static let skillsAddedKey = "tm.navigation.skillsAdded"

    /// Every arrangement an earlier build shipped, including the Mac one after its library-near-home
    /// migration. A saved order that still equals one of these was never edited by the person.
    static let previousDefaultOrders: [[SlotNavigationDestination]] = [
        [.coach, .profile, .home, .map, .ranked, .physique, .workouts, .schedule, .database, .analytics, .settings],
        [.coach, .profile, .home, .database, .analytics, .map, .ranked, .physique, .workouts, .schedule, .settings]
    ]

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        let stored = defaults.stringArray(forKey: orderKey)?
            .compactMap(SlotNavigationDestination.init(rawValue:))
        guard let stored, !stored.isEmpty else {
            order = SlotNavigationDestination.defaultOrder.filter(\.isAvailable)
            save()
            for key in [
                "tm.navigation.scheduleSettingsAdded", "tm.navigation.rankedAdded",
                "tm.navigation.macLibraryNearHome.v1", Self.workoutsLeftOfHomeKey, Self.skillsAddedKey
            ] {
                defaults.set(true, forKey: key)
            }
            return
        }
        order = stored.filter(\.isAvailable)
        if !defaults.bool(forKey: "tm.navigation.scheduleSettingsAdded") {
            if !order.contains(.schedule) {
                let index = order.firstIndex(of: .workouts).map { $0 + 1 } ?? order.count
                order.insert(.schedule, at: index)
            }
            if !order.contains(.settings) { order.append(.settings) }
            defaults.set(order.map(\.rawValue), forKey: orderKey)
            defaults.set(true, forKey: "tm.navigation.scheduleSettingsAdded")
        }
        if !defaults.bool(forKey: "tm.navigation.rankedAdded") {
            if !order.contains(.ranked) {
                let index = (order.firstIndex(of: .map) ?? order.firstIndex(of: .home)).map { $0 + 1 } ?? order.count
                order.insert(.ranked, at: index)
            }
            save()
            defaults.set(true, forKey: "tm.navigation.rankedAdded")
        }
        #if os(macOS)
        if !defaults.bool(forKey: "tm.navigation.macLibraryNearHome.v1") {
            if order.contains(.home) {
                let shortcuts = order.filter { $0 == .database || $0 == .analytics }
                order.removeAll { $0 == .database || $0 == .analytics }
                if let home = order.firstIndex(of: .home) {
                    order.insert(contentsOf: shortcuts, at: home + 1)
                    save()
                }
            }
            defaults.set(true, forKey: "tm.navigation.macLibraryNearHome.v1")
        }
        #endif
        if !defaults.bool(forKey: Self.workoutsLeftOfHomeKey) {
            let current = Self.withoutLateAdditions(order)
            if Self.previousDefaultOrders.contains(where: { Self.withoutLateAdditions($0.filter(\.isAvailable)) == current }) {
                let present = Set(order)
                order = SlotNavigationDestination.defaultOrder.filter(\.isAvailable).filter { present.contains($0) }
                save()
            }
            defaults.set(true, forKey: Self.workoutsLeftOfHomeKey)
        }
        if !defaults.bool(forKey: Self.skillsAddedKey) {
            if !order.contains(.skills) {
                let index = order.firstIndex(of: .database).map { $0 + 1 } ?? order.count
                order.insert(.skills, at: index)
                save()
            }
            defaults.set(true, forKey: Self.skillsAddedKey)
        }
    }

    private static func withoutLateAdditions(_ order: [SlotNavigationDestination]) -> [SlotNavigationDestination] {
        order.filter { $0 != .physique }
    }

    var items: [SlotNavigationItem] {
        order.map { SlotNavigationItem(destination: $0) }
    }

    /// Every page the app can show. A page that is already on the bar is listed as pending, so
    /// the catalog always shows the whole app; the editor draws those dimmed and ignores taps.
    var catalog: [SlotNavigationItem] {
        SlotNavigationDestination.allCases
            .filter(\.isAvailable)
            .map { destination in
                SlotNavigationItem(destination: destination, isPending: order.contains(destination))
            }
    }

    var firstID: String? { order.first?.rawValue }

    func contains(id: String?) -> Bool {
        guard let id else { return false }
        return order.contains { $0.rawValue == id }
    }

    func insert(id: String, at index: Int) {
        guard let destination = SlotNavigationDestination(rawValue: id),
              destination.isAvailable,
              order.contains(destination) == false else { return }
        order.insert(destination, at: min(max(index, 0), order.count))
        save()
    }

    func move(id: String, to index: Int) {
        guard let from = order.firstIndex(where: { $0.rawValue == id }) else { return }
        let destination = order.remove(at: from)
        order.insert(destination, at: min(max(index, 0), order.count))
        save()
    }

    func remove(id: String) {
        guard order.count > 1 else { return }
        order.removeAll { $0.rawValue == id }
        save()
    }

    private func save() {
        defaults.set(order.map(\.rawValue), forKey: orderKey)
    }
}
