import SwiftUI

struct Theme {
    static let accent = Color(hex: "4ECDC4")
    static let toolbarOrange = Color(hex: "FF6A00")
    // App-wide monochrome palette
    static let background    = Color(hex: "0A0A0A")
    static let surface       = Color(hex: "141414")
    static let surface2      = Color(hex: "1C1C1C")
    static let textPrimary   = Color.white
    static let textSecondary = Color.white.opacity(0.45)
    static let separator     = Color.white.opacity(0.08)
    static let controlCornerRadius: CGFloat = 18

    // Icon color palette (8 choices) — used in WorkoutListView and DatabaseView
    static let iconColors: [(hex: String, label: String)] = [
        ("FFFFFF", "White"),
        ("FF3B30", "Red"),
        ("FF9500", "Orange"),
        ("FFCC00", "Yellow"),
        ("34C759", "Green"),
        ("007AFF", "Blue"),
        ("AF52DE", "Purple"),
        ("FF2D55", "Pink"),
    ]
}

struct TimeMasterCardSurface: ViewModifier {
    @Environment(\.colorSchemeContrast) private var contrast
    var cornerRadius: CGFloat = 20
    var accent: Color = Theme.toolbarOrange
    var emphasized = false
    var flat = false

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        content
            .background {
                if flat {
                    shape.fill(Theme.surface)
                } else {
                    shape.fill(
                        LinearGradient(colors: [Theme.surface2, Theme.surface],
                                       startPoint: .topLeading, endPoint: .bottomTrailing)
                    )
                    shape.fill(
                        LinearGradient(colors: [accent.opacity(emphasized ? 0.12 : 0), .clear],
                                       startPoint: .topLeading, endPoint: .bottomTrailing)
                    )
                }
            }
            .overlay {
                if flat {
                    shape.strokeBorder(
                        contrast == .increased ? .white.opacity(0.5)
                            : emphasized ? accent.opacity(0.3) : Theme.separator,
                        lineWidth: 1
                    )
                    .allowsHitTesting(false)
                } else {
                    shape.strokeBorder(
                        LinearGradient(
                            colors: [emphasized ? accent.opacity(0.65) : .white.opacity(contrast == .increased ? 0.5 : 0.2),
                                     .white.opacity(contrast == .increased ? 0.3 : 0.06)],
                            startPoint: .topLeading, endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
                    .allowsHitTesting(false)
                }
            }
    }
}

struct TimeMasterCardButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(SlotNavigationContentClearanceReader())
            .modifier(TimeMasterActionFeedback(isPressed: configuration.isPressed))
            .keyNavButtonSurface(.roundedRectangle(cornerRadius: 20))
    }
}

struct TimeMasterSelectionButtonStyle: ButtonStyle {
    var isSelected = false
    @Environment(\.isFocused) private var isFocused
    @Environment(\.colorSchemeContrast) private var contrast

    func makeBody(configuration: Configuration) -> some View {
        let shape = RoundedRectangle(cornerRadius: Theme.controlCornerRadius, style: .continuous)
        configuration.label
            .font(TimeMasterFont.label())
            .foregroundStyle(Theme.textPrimary)
            .padding(.horizontal, 14)
            .frame(minWidth: 44, minHeight: 44)
            .background(shape.fill(isSelected ? Theme.toolbarOrange : .clear))
            .overlay {
                shape.strokeBorder(
                    .white.opacity(isFocused ? 0.75 : (contrast == .increased ? 0.45 : 0.14)),
                    lineWidth: isFocused ? 2 : 1
                )
                .allowsHitTesting(false)
            }
            .contentShape(shape)
            .background(SlotNavigationContentClearanceReader())
            .modifier(TimeMasterActionFeedback(isPressed: configuration.isPressed))
            .keyNavButtonSurface(.roundedRectangle(cornerRadius: Theme.controlCornerRadius))
    }
}

struct TimeMasterInsetControlStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        TimeMasterActionButtonStyle()
            .makeBody(configuration: configuration)
            .font(TimeMasterFont.black(15, relativeTo: .subheadline))
    }
}

struct TimeMasterDisclosureIndicator: View {
    var systemImage = "chevron.right"

    var body: some View {
        Image(systemName: systemImage)
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(Theme.textPrimary.opacity(0.8))
            .frame(width: 44, height: 44)
            .modifier(TimeMasterCardSurface(cornerRadius: 12, flat: true))
            .accessibilityHidden(true)
    }
}
 
enum AppToolbar {
#if os(macOS)
    static func item<Content: View>(
        placement: AppToolbarPlacement,
        fileID: String = #fileID,
        line: Int = #line,
        column: Int = #column,
        @ViewBuilder content: () -> Content
    ) -> AppToolbarEntry {
        AppToolbarEntry(
            id: "\(fileID):\(line):\(column)",
            placement: placement,
            content: AnyView(content().buttonStyle(TimeMasterToolbarWideButtonStyle()))
        )
    }
#else
    @ToolbarContentBuilder
    static func item<Content: View>(
        placement: ToolbarItemPlacement,
        @ViewBuilder content: @escaping () -> Content
    ) -> some ToolbarContent {
        if #available(iOS 26.0, macOS 26.0, *) {
            ToolbarItem(placement: placement) {
                content()
                    .buttonStyle(TimeMasterToolbarWideButtonStyle())
            }
            .sharedBackgroundVisibility(.hidden)
        } else {
            ToolbarItem(placement: placement) {
                content()
                    .buttonStyle(TimeMasterToolbarWideButtonStyle())
            }
        }
    }
#endif

    @ToolbarContentBuilder
    static func group<Content: View>(
        placement: ToolbarItemPlacement,
        @ViewBuilder content: @escaping () -> Content
    ) -> some ToolbarContent {
        if #available(iOS 26.0, macOS 26.0, *) {
            ToolbarItemGroup(placement: placement) {
                content()
                    .buttonStyle(TimeMasterToolbarWideButtonStyle())
            }
            .sharedBackgroundVisibility(.hidden)
        } else {
            ToolbarItemGroup(placement: placement) {
                content()
                    .buttonStyle(TimeMasterToolbarWideButtonStyle())
            }
        }
    }

#if os(macOS)
    static func iconItem<Content: View>(
        placement: AppToolbarPlacement,
        fileID: String = #fileID,
        line: Int = #line,
        column: Int = #column,
        @ViewBuilder content: () -> Content
    ) -> AppToolbarEntry {
        AppToolbarEntry(
            id: "\(fileID):\(line):\(column)",
            placement: placement,
            content: AnyView(content().buttonStyle(TimeMasterToolbarIconButtonStyle()))
        )
    }
#else
    @ToolbarContentBuilder
    static func iconItem<Content: View>(
        placement: ToolbarItemPlacement,
        @ViewBuilder content: @escaping () -> Content
    ) -> some ToolbarContent {
        if #available(iOS 26.0, macOS 26.0, *) {
            ToolbarItem(placement: placement) {
                content()
                    .buttonStyle(TimeMasterToolbarIconButtonStyle())
            }
            .sharedBackgroundVisibility(.hidden)
        } else {
            ToolbarItem(placement: placement) {
                content()
                    .buttonStyle(TimeMasterToolbarIconButtonStyle())
            }
        }
    }
#endif

    @ToolbarContentBuilder
    static func iconGroup<Content: View>(
        placement: ToolbarItemPlacement,
        @ViewBuilder content: @escaping () -> Content
    ) -> some ToolbarContent {
        if #available(iOS 26.0, macOS 26.0, *) {
            ToolbarItemGroup(placement: placement) {
                content()
                    .buttonStyle(TimeMasterToolbarIconButtonStyle())
            }
            .sharedBackgroundVisibility(.hidden)
        } else {
            ToolbarItemGroup(placement: placement) {
                content()
                    .buttonStyle(TimeMasterToolbarIconButtonStyle())
            }
        }
    }
}

struct TimeMasterToolbarIconButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        TimeMasterActionButtonStyle(circular: true)
            .makeBody(configuration: configuration)
    }
}

struct TimeMasterBackButton: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        Button {
            dismiss()
        } label: {
            Image(systemName: "chevron.left")
                .font(.system(size: 16, weight: .bold))
        }
        .buttonStyle(TimeMasterToolbarIconButtonStyle())
        .accessibilityLabel("Back")
    }
}


struct TimeMasterToolbarTextButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        TimeMasterActionButtonStyle()
            .makeBody(configuration: configuration)
            .font(TimeMasterFont.black(15, relativeTo: .subheadline))
    }
}

struct TimeMasterToolbarWideButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        TimeMasterActionButtonStyle(prominent: true)
            .makeBody(configuration: configuration)
            .font(TimeMasterFont.black(17, relativeTo: .body))
    }
}

// MARK: - IconColorPicker

struct IconColorPicker: View {
    @Binding var selectedHex: String

    var body: some View {
        HStack(spacing: 10) {
            ForEach(Theme.iconColors, id: \.hex) { colorDef in
                let isSelected = selectedHex == colorDef.hex
                ZStack {
                    // Selection ring
                    Circle()
                        .stroke(Color.white.opacity(isSelected ? 0.9 : 0), lineWidth: 2)
                        .frame(width: 38, height: 38)
                    // Color fill
                    Circle()
                        .fill(Color(hex: colorDef.hex))
                        .frame(width: 28, height: 28)
                        .overlay(
                            Group {
                                if isSelected {
                                    Image(systemName: "checkmark")
                                        .font(.system(size: 11, weight: .bold))
                                        .foregroundColor(colorDef.hex == "FFFFFF" ? .black : .white)
                                }
                            }
                        )
                }
                .onTapGesture { selectedHex = colorDef.hex }
                .keyNavTarget(shape: .circle) { selectedHex = colorDef.hex }
            }
        }
    }
}

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3:
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6:
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8:
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}