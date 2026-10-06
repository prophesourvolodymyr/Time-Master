// SlotNavigationItem.swift
//
// Navigation models, theme, copy and the app's destination catalog with its saved order.
// The bar, its editor and the arc are the CarouselNavigation component from the
// SwiftComponentLibrary (`Sources/CarouselNavigation`), adapted here with TimeMaster's
// palette, copy and destinations. The component keeps the layout, motion and gestures; the
// app owns the items, the selection and the persistence.

import SwiftUI

// MARK: - Presentation

enum SlotNavigationPresentation: Equatable, Hashable {
    case full
    case inline
    case hidden
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
}

// MARK: - Bar geometry published to the host

struct SlotNavigationBarFramePreferenceKey: PreferenceKey {
    static let defaultValue: CGRect = .zero

    static func reduce(value: inout CGRect, nextValue: () -> CGRect) {
        let next = nextValue()
        if next != .zero {
            value = next
        }
    }
}

/// Publishes the bar frame into `SlotNavigationBarFramePreferenceKey`.
struct SlotNavigationBarFrameReader: View {
    var body: some View {
        GeometryReader { proxy in
            Color.clear
                .preference(key: SlotNavigationBarFramePreferenceKey.self, value: proxy.frame(in: .global))
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

// MARK: - Arc lens frame

private struct SlotNavigationArcLensFrameKey: EnvironmentKey {
    static let defaultValue = CGRect.zero
}

extension EnvironmentValues {
    /// Rectangle covering the arc surface, in the global coordinate space, whenever the bar
    /// is in its full layout and the editor is closed. Content that stretches or refracts
    /// around the arc reads it; it stays `.zero` at every other time.
    var slotNavigationArcLensFrame: CGRect {
        get { self[SlotNavigationArcLensFrameKey.self] }
        set { self[SlotNavigationArcLensFrameKey.self] = newValue }
    }
}

// MARK: - Theme

struct SlotNavigationTypography {
    /// Title of the editing overlay, for example "EDIT MENU BAR".
    var editorTitle: Font
    /// Section titles inside the source picker.
    var sectionTitle: Font
    /// Button labels in the source picker and the guide.
    var buttonLabel: Font
    /// Body copy in the editing guide.
    var body: Font
    /// Secondary copy under the source picker title.
    var secondary: Font

    init(
        editorTitle: Font,
        sectionTitle: Font,
        buttonLabel: Font,
        body: Font,
        secondary: Font
    ) {
        self.editorTitle = editorTitle
        self.sectionTitle = sectionTitle
        self.buttonLabel = buttonLabel
        self.body = body
        self.secondary = secondary
    }

    /// System fonts at the sizes and weights the EverStore app used with Inter.
    static let standard = SlotNavigationTypography(
        editorTitle: .system(size: 24, weight: .black),
        sectionTitle: .system(size: 17, weight: .black),
        buttonLabel: .system(size: 16, weight: .black),
        body: .system(size: 16, weight: .regular),
        secondary: .system(size: 14, weight: .regular)
    )
}

/// Colors used by the navigation surface and its editor chrome.
struct SlotNavigationTheme {
    /// Fill of the arc surface and of the source-picker panel.
    var surface: Color
    /// Hairline drawn along the arc.
    var rim: Color
    /// Item labels, editor title and picker title.
    var textPrimary: Color
    /// Guide copy, picker message and the source-change glyph.
    var textSecondary: Color
    /// "Add" glyphs, the catalog glyph and the catalog chip border.
    var success: Color
    /// Removal glyph and notification badge fill.
    var destructive: Color
    /// Scrim shown over the content while the editor is open.
    var scrim: Color
    /// Opacity of `scrim` when Reduce Transparency is off.
    var scrimOpacity: Double
    /// Page background behind the arc.
    var background: Color
    /// Label color inside a notification badge.
    var badgeText: Color
    /// Fill behind quiet buttons in the editor chrome.
    var controlSurface: Color
    /// Fill of the prominent confirmation button in the guide.
    var accent: Color
    /// Label color on top of `accent`.
    var onAccent: Color
    var typography: SlotNavigationTypography

    init(
        surface: Color,
        rim: Color,
        textPrimary: Color,
        textSecondary: Color,
        success: Color,
        destructive: Color,
        scrim: Color,
        scrimOpacity: Double,
        badgeText: Color,
        background: Color,
        controlSurface: Color,
        accent: Color,
        onAccent: Color,
        typography: SlotNavigationTypography = .standard
    ) {
        self.surface = surface
        self.rim = rim
        self.textPrimary = textPrimary
        self.textSecondary = textSecondary
        self.success = success
        self.destructive = destructive
        self.scrim = scrim
        self.scrimOpacity = scrimOpacity
        self.badgeText = badgeText
        self.background = background
        self.controlSurface = controlSurface
        self.accent = accent
        self.onAccent = onAccent
        self.typography = typography
    }

    /// TimeMaster's palette: the app's near-black background with a single hairline rim.
    static let timeMaster = SlotNavigationTheme(
        surface: Theme.background,
        rim: Color.white.opacity(0.12),
        textPrimary: Theme.textPrimary,
        textSecondary: Theme.textSecondary,
        success: Color(hex: "32D74B"),
        destructive: Color(hex: "FF453A"),
        scrim: .black,
        scrimOpacity: 0.35,
        badgeText: .white,
        background: Theme.background,
        controlSurface: Theme.surface2,
        accent: .white,
        onAccent: .black
    )
}

// MARK: - Copy

struct SlotNavigationGuideStep {
    var symbol: String
    var text: String

    init(symbol: String, text: String) {
        self.symbol = symbol
        self.text = text
    }
}

/// Every string the component shows or announces. Replace them for another language or
/// another product vocabulary.
struct SlotNavigationStrings {
    /// Title of the editing overlay.
    var editorTitle: String
    /// Lines shown the first time the editor opens.
    var guideSteps: [SlotNavigationGuideStep]
    /// Confirmation button that closes the guide.
    var guideDismissTitle: String
    /// Accessibility label of the button that reopens the guide.
    var guideAccessibilityLabel: String
    /// Accessibility action that opens the editor.
    var editNavigation: String
    /// Accessibility action that closes the editor.
    var doneEditing: String
    /// Accessibility action that reveals navigation when a destination hides it.
    var showNavigation: String
    /// Title used for the two "+" slots.
    var addItemTitle: String
    /// Accessibility label of the "+" slot at the start of the arc.
    var addItemAtStart: String
    /// Accessibility label of the "+" slot at the end of the arc.
    var addItemAtEnd: String
    /// Accessibility label of a catalog entry.
    var addToNavigation: (String) -> String
    /// Accessibility action that removes an item.
    var removeFromNavigation: String
    /// Accessibility action that opens the source picker for an item.
    var changeSource: String
    /// Accessibility value for the selected item.
    var selectedValue: String
    /// Accessibility value for an unselected item.
    var notSelectedValue: String
    /// Accessibility value for a catalog page that is already on the bar.
    var alreadyAddedValue: String
    /// Accessibility value while the bar is expanded and editable.
    var editingValue: String
    /// Accessibility value while the bar is expanded and not editable.
    var expandedValue: String
    /// Accessibility value while the bar is compact.
    var compactValue: String
    /// Accessibility hint for an item that can change its source.
    var configurableHint: String

    init(
        editorTitle: String,
        guideSteps: [SlotNavigationGuideStep],
        guideDismissTitle: String,
        guideAccessibilityLabel: String,
        editNavigation: String,
        doneEditing: String,
        showNavigation: String,
        addItemTitle: String,
        addItemAtStart: String,
        addItemAtEnd: String,
        addToNavigation: @escaping (String) -> String,
        removeFromNavigation: String,
        changeSource: String,
        selectedValue: String,
        notSelectedValue: String,
        alreadyAddedValue: String,
        editingValue: String,
        expandedValue: String,
        compactValue: String,
        configurableHint: String
    ) {
        self.editorTitle = editorTitle
        self.guideSteps = guideSteps
        self.guideDismissTitle = guideDismissTitle
        self.guideAccessibilityLabel = guideAccessibilityLabel
        self.editNavigation = editNavigation
        self.doneEditing = doneEditing
        self.showNavigation = showNavigation
        self.addItemTitle = addItemTitle
        self.addItemAtStart = addItemAtStart
        self.addItemAtEnd = addItemAtEnd
        self.addToNavigation = addToNavigation
        self.removeFromNavigation = removeFromNavigation
        self.changeSource = changeSource
        self.selectedValue = selectedValue
        self.notSelectedValue = notSelectedValue
        self.alreadyAddedValue = alreadyAddedValue
        self.editingValue = editingValue
        self.expandedValue = expandedValue
        self.compactValue = compactValue
        self.configurableHint = configurableHint
    }

    static let timeMaster = SlotNavigationStrings(
        editorTitle: "EDIT MENU BAR",
        guideSteps: [
            SlotNavigationGuideStep(symbol: "\u{2795}", text: "Tap + to add one of the app's pages."),
            SlotNavigationGuideStep(symbol: "\u{1F446}", text: "Hold an icon, then drag it to change its position."),
            SlotNavigationGuideStep(symbol: "\u{2B06}\u{FE0F}", text: "Drag an icon upward to remove it from the menu."),
            SlotNavigationGuideStep(symbol: "\u{2705}", text: "Tap the dimmed background to finish.")
        ],
        guideDismissTitle: "Got it",
        guideAccessibilityLabel: "Menu editing guide",
        editNavigation: "Edit navigation",
        doneEditing: "Done",
        showNavigation: "Show navigation",
        addItemTitle: "Add",
        addItemAtStart: "Add page at beginning",
        addItemAtEnd: "Add page at end",
        addToNavigation: { "Add \($0)" },
        removeFromNavigation: "Remove from navigation",
        changeSource: "Change page",
        selectedValue: "Selected",
        notSelectedValue: "Not selected",
        alreadyAddedValue: "Already on the menu",
        editingValue: "Editing navigation",
        expandedValue: "Expanded",
        compactValue: "Compact",
        configurableHint: "Tap to change page. Hold to move."
    )
}

// MARK: - Item

struct SlotNavigationItem: Identifiable, Hashable {
    let id: String
    let symbolName: String
    let title: String
    let accessibilityHint: String
    let presentation: SlotNavigationPresentation
    let isPending: Bool
    let isConfigurable: Bool
    let badgeCount: Int

    init(
        id: String,
        symbolName: String,
        title: String,
        accessibilityHint: String = "",
        presentation: SlotNavigationPresentation = .full,
        isPending: Bool = false,
        isConfigurable: Bool = false,
        badgeCount: Int = 0
    ) {
        self.id = id
        self.symbolName = symbolName
        self.title = title
        self.accessibilityHint = accessibilityHint
        self.presentation = presentation
        self.isPending = isPending
        self.isConfigurable = isConfigurable
        self.badgeCount = max(0, badgeCount)
    }

    func withBadgeCount(_ badgeCount: Int) -> SlotNavigationItem {
        SlotNavigationItem(
            id: id,
            symbolName: symbolName,
            title: title,
            accessibilityHint: accessibilityHint,
            presentation: presentation,
            isPending: isPending,
            isConfigurable: isConfigurable,
            badgeCount: badgeCount
        )
    }
}

// MARK: - Source picker

struct SlotNavigationConfiguration {
    let title: String
    let message: String
    let choices: [SlotNavigationItem]
    let onSelect: (String) -> Void
    let onCancel: () -> Void

    init(
        title: String,
        message: String,
        choices: [SlotNavigationItem],
        onSelect: @escaping (String) -> Void,
        onCancel: @escaping () -> Void
    ) {
        self.title = title
        self.message = message
        self.choices = choices
        self.onSelect = onSelect
        self.onCancel = onCancel
    }
}

enum SlotNavigationBarLayout: Equatable {
    case full
    case inline
}
// MARK: - Destinations

/// Every page the app can put on the bar. Raw values are the ids the component stores, so
/// they must stay stable once a layout has been saved on a device.
enum SlotNavigationDestination: String, CaseIterable, Identifiable {
    case home
    case workouts
    case database
    case analytics
    case coach
    case profile
    case map
    case schedule
    case settings

    var id: String { rawValue }

    var title: String {
        switch self {
        case .home: "Home"
        case .workouts: "Workouts"
        case .database: "Database"
        case .analytics: "Analytics"
        case .coach: "AI Coach"
        case .profile: "Profile"
        case .map: "Map"
        case .schedule: "Schedule"
        case .settings: "Settings"
        }
    }

    var symbolName: String {
        switch self {
        case .home: "house.fill"
        case .workouts: "dumbbell.fill"
        case .database: "books.vertical.fill"
        case .analytics: "chart.bar.fill"
        case .coach: "brain.head.profile"
        case .profile: "person.crop.circle"
        case .map: "map.fill"
        case .schedule: "calendar"
        case .settings: "gearshape.fill"
        }
    }

    var accessibilityHint: String {
        switch self {
        case .home: "Shows your daily dashboard."
        case .workouts: "Shows your workouts."
        case .database: "Shows your exercise database."
        case .analytics: "Shows your workout analytics."
        case .coach: "Opens your AI coach."
        case .profile: "Shows your profile and history."
        case .map: "Opens the live outdoor map and workout start page."
        case .schedule: "Shows your weekly workout Plans and streak."
        case .settings: "Shows app settings."
        }
    }

    var presentation: SlotNavigationPresentation {
        switch self {
        case .coach: .inline
        case .map: .hidden
        default: .full
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
    static let defaultOrder: [SlotNavigationDestination] = [.coach, .profile, .home, .map, .workouts, .schedule, .database, .analytics, .settings]
}

extension SlotNavigationItem {
    init(destination: SlotNavigationDestination, isPending: Bool = false) {
        self.init(
            id: destination.rawValue,
            symbolName: destination.symbolName,
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

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        let stored = defaults.stringArray(forKey: orderKey)?
            .compactMap(SlotNavigationDestination.init(rawValue:))
        let resolved = stored?.isEmpty == false ? stored! : SlotNavigationDestination.defaultOrder
        order = resolved.filter(\.isAvailable)
        if !defaults.bool(forKey: "tm.navigation.scheduleSettingsAdded") {
            if !order.contains(.schedule) {
                let index = order.firstIndex(of: .workouts).map { $0 + 1 } ?? order.count
                order.insert(.schedule, at: index)
            }
            if !order.contains(.settings) { order.append(.settings) }
            defaults.set(order.map(\.rawValue), forKey: orderKey)
            defaults.set(true, forKey: "tm.navigation.scheduleSettingsAdded")
        }
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
        order.removeAll { $0.rawValue == id }
        save()
    }

    private func save() {
        defaults.set(order.map(\.rawValue), forKey: orderKey)
    }
}
