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

    static let standard = SlotNavigationTypography(
        editorTitle: TimeMasterFont.pageTitle(31, relativeTo: .title2),
        sectionTitle: TimeMasterFont.sectionTitle(),
        buttonLabel: TimeMasterFont.label(),
        body: TimeMasterFont.body(),
        secondary: TimeMasterFont.secondary()
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
        editorTitle: "Edit menu bar",
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

enum SlotNavigationIcon: Hashable {
    case system(String)
    case asset(String)
}

struct SlotNavigationItem: Identifiable, Hashable {
    let id: String
    let icon: SlotNavigationIcon
    let title: String
    let accessibilityHint: String
    let presentation: SlotNavigationPresentation
    let isPending: Bool
    let isConfigurable: Bool
    let badgeCount: Int

    init(
        id: String,
        icon: SlotNavigationIcon,
        title: String,
        accessibilityHint: String = "",
        presentation: SlotNavigationPresentation = .visible,
        isPending: Bool = false,
        isConfigurable: Bool = false,
        badgeCount: Int = 0
    ) {
        self.id = id
        self.icon = icon
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
            icon: icon,
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

    static func resolve(
        isExpanded: Bool,
        isInteracting: Bool,
        isEditing: Bool,
        isOverlayVisible: Bool,
        contentRequiresInline: Bool = false
    ) -> Self {
        isExpanded || isInteracting || isEditing || isOverlayVisible || !contentRequiresInline ? .full : .inline
    }
}

struct SlotNavigationClearanceContext: Equatable {
    let page: String?
    let viewport: CGRect
    let placement: SlotNavigationPlacement
    let dynamicTypeSize: DynamicTypeSize
    var safeAreaInsets = EdgeInsets()
    var archedHeight: CGFloat = 0
}

struct SlotNavigationContentClearance: Equatable {
    var context: SlotNavigationClearanceContext?
    var measuredArchedLayout = false
    var controlCount = 0
    var controlSize = CGSize.zero
    var hasObstruction = false

    static func assess(
        control: CGRect, contentBounds: CGRect, viewport: CGRect,
        placement: SlotNavigationPlacement, primaryAction: Bool, scrollBounds: CGRect?
    ) -> (isRelevant: Bool, hasObstruction: Bool) {
        guard isUsable(control), isUsable(contentBounds), isUsable(viewport),
              control.intersects(viewport) else { return (false, false) }
        if let scrollBounds {
            guard primaryAction, isUsable(scrollBounds),
                  control.intersects(scrollBounds) else { return (false, false) }
        }
        guard control.maxX > contentBounds.minX, control.minX < contentBounds.maxX else { return (false, false) }
        let boundary = placement == .bottom ? contentBounds.maxY : contentBounds.minY
        let clippedByMenu = placement == .bottom ? control.maxY > boundary + 1 : control.minY < boundary - 1
        guard clippedByMenu else { return (true, false) }
        if let scrollBounds {
            return (true, placement == .bottom
                ? scrollBounds.maxY >= boundary - 1
                : scrollBounds.minY <= boundary + 1)
        }
        return (true, true)
    }

    private static func isUsable(_ rect: CGRect) -> Bool {
        !rect.isInfinite && rect.origin.x.isFinite && rect.origin.y.isFinite
            && rect.minX.isFinite && rect.minY.isFinite && rect.maxX.isFinite && rect.maxY.isFinite
            && rect.size.width > 0 && rect.size.height > 0
    }
}

struct SlotNavigationClearanceState {
    private(set) var context: SlotNavigationClearanceContext?
    private(set) var controlCount = 0
    private var controlSize = CGSize.zero
    private(set) var requiresInline = false
    private var lastMeasuredArchedLayout: Bool?

    func requiresInline(in context: SlotNavigationClearanceContext) -> Bool {
        self.context == context && requiresInline
    }

    mutating func observe(_ measurement: SlotNavigationContentClearance) {
        guard let context = measurement.context else { return }
        let contextChanged = self.context != context
        let controlsChanged = lastMeasuredArchedLayout == measurement.measuredArchedLayout
            && (controlCount != measurement.controlCount || controlSize != measurement.controlSize)
        if contextChanged || controlsChanged || measurement.controlCount == 0 {
            requiresInline = false
        }
        self.context = context
        controlCount = measurement.controlCount
        controlSize = measurement.controlSize
        lastMeasuredArchedLayout = measurement.measuredArchedLayout
        if measurement.measuredArchedLayout && measurement.hasObstruction {
            requiresInline = true
        }
    }
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
    case ranked
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
        case .ranked: "Ranked"
        case .map: "Map"
        case .schedule: "Schedule"
        case .settings: "Settings"
        }
    }

    var icon: SlotNavigationIcon {
        switch self {
        case .home: .system("house.fill")
        case .workouts: .system("dumbbell.fill")
        case .database: .system("books.vertical.fill")
        case .analytics: .system("chart.bar.fill")
        case .coach: .system("brain.head.profile")
        case .profile: .system("person.crop.circle")
        case .ranked: .asset("RankedMenuIcon")
        case .map: .system("map.fill")
        case .schedule: .system("calendar")
        case .settings: .system("gearshape.fill")
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
        case .ranked: "Shows your Ranked arena and movement loadout."
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
    static let defaultOrder: [SlotNavigationDestination] = [.coach, .profile, .home, .map, .ranked, .workouts, .schedule, .database, .analytics, .settings]
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
        if !defaults.bool(forKey: "tm.navigation.rankedAdded") {
            if !order.contains(.ranked) {
                let index = (order.firstIndex(of: .map) ?? order.firstIndex(of: .home)).map { $0 + 1 } ?? order.count
                order.insert(.ranked, at: index)
            }
            save()
            defaults.set(true, forKey: "tm.navigation.rankedAdded")
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
