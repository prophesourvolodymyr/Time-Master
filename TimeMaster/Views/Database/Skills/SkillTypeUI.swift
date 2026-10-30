import SwiftUI
import TimeMasterCore
#if os(iOS)
import UIKit
#else
import AppKit
#endif

/// Colours, names and the base effect of a type (a user-made tag with a colour, an icon, an effect and a sort rule).
enum SkillTypeStyle {
    static let fallbackHex = "8B7CFF"

    static func hex(_ type: SkillType) -> String { SkillColors.normalizedHex(type.colorHex) ?? fallbackHex }
    static func color(_ type: SkillType) -> Color { Color(hex: hex(type)) }

    static func title(_ effect: SkillTypeEffect) -> String {
        switch effect {
        case .none: return "None"
        case .tint: return "Tint"
        case .glow: return "Glow"
        case .outline: return "Outline"
        case .gradient: return "Gradient"
        }
    }

    static func detail(_ effect: SkillTypeEffect) -> String {
        switch effect {
        case .none: return "Only the chip shows the type."
        case .tint: return "The card takes a soft wash of the colour."
        case .glow: return "A glow of the colour around the card."
        case .outline: return "A bold outline in the colour."
        case .gradient: return "The card fades from the colour into the dark."
        }
    }

    static func title(_ rule: SkillTypeSortRule) -> String {
        switch rule {
        case .none: return "Stay put"
        case .top: return "Top"
        case .bottom: return "Bottom"
        }
    }

    static func detail(_ rule: SkillTypeSortRule) -> String {
        switch rule {
        case .none: return "Pages with this type keep their place."
        case .top: return "Pages with this type move to the top of the list, row or column they are in."
        case .bottom: return "Pages with this type move to the bottom of the list, row or column they are in."
        }
    }

    /// The type's icon, or a tag when it has none.
    static func iconName(_ type: SkillType) -> String { type.iconName ?? "tag.fill" }

    /// A menu entry's title: an emoji icon goes in front, since a menu cannot draw it as an image.
    static func menuTitle(_ type: SkillType) -> String {
        if type.iconType == .emoji, let icon = type.iconName, !icon.isEmpty { return "\(icon) \(type.title)" }
        return type.title
    }

    /// What a preset without an icon shows: the Select circle.
    static let presetFallbackSymbol = "chevron.down.circle.fill"

    /// The SF Symbol of a preset for a menu entry: its own symbol, else the Select circle (an emoji goes in the title instead).
    static func symbolName(_ preset: SkillTypePreset) -> String {
        guard preset.iconType == .system, let name = preset.iconName, symbolExists(name) else { return presetFallbackSymbol }
        return name
    }

    /// A preset's title for a menu entry: an emoji icon goes in front.
    static func menuTitle(_ preset: SkillTypePreset) -> String {
        if preset.iconType == .emoji, let icon = preset.iconName, !icon.isEmpty { return "\(icon) \(preset.title)" }
        return preset.title
    }

    /// True when this system has an SF Symbol of that name (a name an agent or an older build wrote may not exist).
    private static func symbolExists(_ name: String) -> Bool {
        #if os(iOS)
        return UIImage(systemName: name) != nil
        #else
        return NSImage(systemSymbolName: name, accessibilityDescription: nil) != nil
        #endif
    }
}

/// A preset's icon: its symbol or emoji, or the Select circle when it has none.
struct SkillTypePresetIcon: View {
    let preset: SkillTypePreset
    var size: CGFloat = 16

    var body: some View {
        SkillIconView(
            iconName: preset.iconName ?? SkillTypeStyle.presetFallbackSymbol,
            iconType: preset.iconName == nil ? .system : preset.iconType,
            colorHex: nil,
            size: size
        )
    }
}

/// A type as a small chip: its icon and its name in its colour, on a wash of the same colour.
struct SkillTypeChip: View {
    let type: SkillType
    var showsChevron = false

    var body: some View {
        let color = SkillTypeStyle.color(type)
        HStack(spacing: 5) {
            SkillIconView(iconName: SkillTypeStyle.iconName(type), iconType: type.iconType, colorHex: SkillTypeStyle.hex(type), size: 11)
            Text(type.title)
                .font(TimeMasterFont.caption())
                .fontWeight(.semibold)
                .lineLimit(1)
            if showsChevron {
                Image(systemName: "chevron.down")
                    .font(.system(size: 8, weight: .bold))
                    .opacity(0.7)
            }
        }
        .foregroundStyle(color)
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
        .background(Capsule(style: .continuous).fill(color.opacity(0.18)))
        .overlay(Capsule(style: .continuous).strokeBorder(color.opacity(0.42), lineWidth: 1))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Type: \(type.title)")
    }
}

/// The "no type yet" chip: a dashed tag that says a type can go here.
struct SkillAddTypeChip: View {
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "tag")
                .font(.system(size: 10, weight: .semibold))
            Text("Type")
                .font(TimeMasterFont.caption())
        }
        .foregroundStyle(Theme.textSecondary)
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
        .overlay(Capsule(style: .continuous).strokeBorder(Theme.separator, style: StrokeStyle(lineWidth: 1, dash: [3, 3])))
        .accessibilityLabel("Add a type")
    }
}

/// What a type does to the card it is on: a wash, a glow, an outline or a gradient in its colour.
struct SkillTypeBase: ViewModifier {
    let type: SkillType?
    var cornerRadius: CGFloat = 14

    func body(content: Content) -> some View {
        if let type, type.effect != .none {
            let color = SkillTypeStyle.color(type)
            let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            content
                .overlay { fill(for: type.effect, color: color, shape: shape) }
                .overlay { stroke(for: type.effect, color: color, shape: shape) }
                .shadow(color: type.effect == .glow ? color.opacity(0.5) : .clear, radius: type.effect == .glow ? 12 : 0)
        } else {
            content
        }
    }

    @ViewBuilder
    private func fill(for effect: SkillTypeEffect, color: Color, shape: RoundedRectangle) -> some View {
        switch effect {
        case .tint:
            shape.fill(color.opacity(0.14)).allowsHitTesting(false)
        case .gradient:
            shape.fill(LinearGradient(colors: [color.opacity(0.34), color.opacity(0.04)], startPoint: .topLeading, endPoint: .bottomTrailing))
                .allowsHitTesting(false)
        case .glow, .outline, .none:
            EmptyView()
        }
    }

    @ViewBuilder
    private func stroke(for effect: SkillTypeEffect, color: Color, shape: RoundedRectangle) -> some View {
        switch effect {
        case .tint: shape.strokeBorder(color.opacity(0.38), lineWidth: 1).allowsHitTesting(false)
        case .gradient: shape.strokeBorder(color.opacity(0.3), lineWidth: 1).allowsHitTesting(false)
        case .glow: shape.strokeBorder(color.opacity(0.6), lineWidth: 1.5).allowsHitTesting(false)
        case .outline: shape.strokeBorder(color.opacity(0.95), lineWidth: 2).allowsHitTesting(false)
        case .none: EmptyView()
        }
    }
}

extension View {
    /// The base effect of `type` on a card or row (nothing when it has none).
    func skillTypeBase(_ type: SkillType?, cornerRadius: CGFloat = 14) -> some View {
        modifier(SkillTypeBase(type: type, cornerRadius: cornerRadius))
    }
}

/// The entries of the type menu. A page wears one type of one preset, so the menu first asks which preset: every preset is a
/// submenu holding its types, with "Add an option…" and "Edit preset…" at its end. A skill without presets is told so and
/// offered a new preset on the spot. Also: "No type", "New preset…", "Edit…" the page's type and "Manage presets…". The sheets
/// those open are hosted by whoever owns the two bindings: a menu (a context menu especially) cannot present a sheet itself.
struct SkillTypeMenuItems: View {
    /// A page's manifest id.
    let pageID: String
    @Binding var editor: SkillTypeEditorRoute?
    @Binding var showingManager: Bool

    @EnvironmentObject private var store: DatabaseStore

    var body: some View {
        let presets = store.skillTypePresets(for: pageID)
        let page = store.page(manifestID: pageID)
        let current = page?.manifest.typeID
        if presets.isEmpty {
            Text("No type presets yet")
            Button {
                editor = .newPreset
            } label: {
                Label("Make a preset…", systemImage: "plus")
            }
        } else {
            ForEach(presets) { preset in
                Menu {
                    ForEach(preset.orderedTypes) { type in
                        Button {
                            set(type.id)
                        } label: {
                            Label(SkillTypeStyle.menuTitle(type), systemImage: current == type.id ? "checkmark" : "tag")
                        }
                    }
                    if preset.types.isEmpty {
                        Text("No types in it yet")
                    }
                    Divider()
                    Button {
                        editor = .newType(presetID: preset.id)
                    } label: {
                        Label("Add an option…", systemImage: "plus")
                    }
                    Button {
                        editor = .editPreset(preset)
                    } label: {
                        Label("Edit preset…", systemImage: "pencil")
                    }
                } label: {
                    Label(SkillTypeStyle.menuTitle(preset), systemImage: SkillTypeStyle.symbolName(preset))
                }
            }
            if current != nil {
                Divider()
                Button {
                    set(nil)
                } label: {
                    Label("No type", systemImage: "xmark.circle")
                }
            }
            Divider()
            Button {
                editor = .newPreset
            } label: {
                Label("New preset…", systemImage: "plus.square.on.square")
            }
            if let page, let type = store.skillType(of: page) {
                Button {
                    editor = .editType(type)
                } label: {
                    Label("Edit “\(type.title)”…", systemImage: "pencil")
                }
            }
            Button {
                showingManager = true
            } label: {
                Label("Manage presets…", systemImage: "slider.horizontal.3")
            }
        }
    }

    private func set(_ typeID: String?) {
        SkillErrorCenter.shared.attempt("Set the type") { try store.setSkillType(typeID, for: pageID) }
    }
}

extension View {
    /// Hosts the sheets the type menu opens (a type, a preset, or the list of presets) for `pageID`.
    func skillTypeSheets(for pageID: String, editor: Binding<SkillTypeEditorRoute?>, showingManager: Binding<Bool>) -> some View {
        modifier(SkillTypeSheets(pageID: pageID, editor: editor, showingManager: showingManager))
    }
}

private struct SkillTypeSheets: ViewModifier {
    @EnvironmentObject private var store: DatabaseStore
    let pageID: String
    @Binding var editor: SkillTypeEditorRoute?
    @Binding var showingManager: Bool

    func body(content: Content) -> some View {
        let rootID = store.skillTypeOwner(of: pageID)?.manifest.id ?? pageID
        content
            .sheet(item: $editor) { route in
                Group {
                    switch route {
                    case .newType, .editType:
                        SkillTypeEditorSheet(rootID: rootID, assigningTo: pageID, route: route)
                    case .newPreset, .editPreset:
                        SkillTypePresetSheet(rootID: rootID, assigningTo: pageID, route: route)
                    }
                }
                .environmentObject(store)
            }
            .sheet(isPresented: $showingManager) {
                SkillTypesManagerSheet(rootID: rootID)
                    .environmentObject(store)
            }
    }
}

/// A button that opens the type menu for a page, with its own sheets. The label is whatever the caller draws (a chip,
/// a tag). Where several of these sit in one view, own the sheets once and use `SkillTypeMenuItems` instead.
struct SkillTypePicker<Label: View>: View {
    let pageID: String
    @ViewBuilder let label: () -> Label

    @State private var editor: SkillTypeEditorRoute?
    @State private var showingManager = false

    var body: some View {
        Menu {
            SkillTypeMenuItems(pageID: pageID, editor: $editor, showingManager: $showingManager)
        } label: {
            label()
        }
        .menuStyle(.button).keyNavPlainButtonStyle()
        .menuIndicator(.hidden)
        #if os(macOS)
        .fixedSize()
        #endif
        .skillTypeSheets(for: pageID, editor: $editor, showingManager: $showingManager)
        .help("Type")
        .accessibilityLabel("Type")
    }
}

/// What the type sheets are for: a type of a preset (new in a preset, or an existing one), or a preset itself.
enum SkillTypeEditorRoute: Identifiable {
    case newType(presetID: String)
    case editType(SkillType)
    case newPreset
    case editPreset(SkillTypePreset)

    var id: String {
        switch self {
        case .newType(let presetID): return "new-type-\(presetID)"
        case .editType(let type): return "edit-type-\(type.id)"
        case .newPreset: return "new-preset"
        case .editPreset(let preset): return "edit-preset-\(preset.id)"
        }
    }
}
