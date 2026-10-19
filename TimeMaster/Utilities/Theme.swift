import SwiftUI

struct Theme {
    // Defined but ONLY used in AnalyticsView.swift
    static let primary       = Color(hex: "FF6B35")
    static let accent        = Color(hex: "4ECDC4")
    static let restAccent = Color(hex: "FF9500")
    static let toolbarOrange = Color(hex: "FF7A00")
    // App-wide monochrome palette
    static let background    = Color(hex: "0A0A0A")
    static let surface       = Color(hex: "141414")
    static let surface2      = Color(hex: "1C1C1C")
    static let textPrimary   = Color.white
    static let textSecondary = Color.white.opacity(0.45)
    static let separator     = Color.white.opacity(0.08)
    static let controlCornerRadius: CGFloat = 9

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
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.985 : 1)
            .opacity(configuration.isPressed ? 0.82 : 1)
            .animation(reduceMotion ? nil : .spring(response: 0.25, dampingFraction: 0.9),
                       value: configuration.isPressed)
    }
}

struct TimeMasterSelectionButtonStyle: ButtonStyle {
    var isSelected = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline.weight(isSelected ? .semibold : .medium))
            .foregroundStyle(isSelected ? Theme.background : Theme.textPrimary)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .frame(minHeight: 44)
            .background(
                isSelected ? Theme.toolbarOrange : Theme.surface2,
                in: RoundedRectangle(cornerRadius: Theme.controlCornerRadius, style: .continuous)
            )
            .opacity(configuration.isPressed ? 0.72 : 1)
    }
}

struct TimeMasterInsetControlStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(Theme.textPrimary)
            .frame(minWidth: 44, minHeight: 44)
            .modifier(TimeMasterCardSurface(cornerRadius: Theme.controlCornerRadius, flat: true))
            .opacity(configuration.isPressed ? 0.72 : 1)
    }
}

struct TimeMasterDisclosureIndicator: View {
    var systemImage = "chevron.right"

    var body: some View {
        Image(systemName: systemImage)
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(Theme.textPrimary.opacity(0.8))
            .frame(width: 44, height: 44)
            .modifier(TimeMasterCardSurface(cornerRadius: Theme.controlCornerRadius, flat: true))
            .accessibilityHidden(true)
    }
}
 
enum AppToolbar {
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
    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    @ViewBuilder
    func makeBody(configuration: Configuration) -> some View {
        #if os(iOS)
        configuration.label
            .foregroundStyle(.white)
            .frame(minWidth: 44, minHeight: 44)
            .modifier(
                TimeMasterPrivateGlassSurface(
                    cornerRadius: Theme.controlCornerRadius,
                    isInteractive: true,
                    tint: isEnabled ? Theme.toolbarOrange : Theme.surface2,
                    tintOpacity: isEnabled ? 0.52 : 0.26
                )
            )
            .clipShape(RoundedRectangle(cornerRadius: Theme.controlCornerRadius, style: .continuous))
            .scaleEffect(reduceMotion || !configuration.isPressed ? 1 : 0.92)
            .opacity(!isEnabled ? 0.45 : configuration.isPressed ? 0.82 : 1)
            .animation(
                reduceMotion ? .none : .spring(response: 0.22, dampingFraction: 0.88),
                value: configuration.isPressed
            )
        #else
        fallback(configuration)
        #endif
    }

    @ViewBuilder
    private func fallback(_ configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(.white)
            .frame(minWidth: 44, minHeight: 44)
            .background {
                RoundedRectangle(cornerRadius: Theme.controlCornerRadius, style: .continuous)
                    .fill(isEnabled
                          ? Theme.toolbarOrange.opacity(reduceTransparency ? 0.9 : 0.52)
                          : Theme.surface2)
                if !reduceTransparency {
                    RoundedRectangle(cornerRadius: Theme.controlCornerRadius, style: .continuous)
                        .fill(.ultraThinMaterial)
                }
            }
            .overlay {
                RoundedRectangle(cornerRadius: Theme.controlCornerRadius, style: .continuous)
                    .strokeBorder(
                        Color.white.opacity(reduceTransparency ? 0.24 : 0.18),
                        lineWidth: 1
                    )
            }
            .overlay(alignment: .top) {
                Capsule()
                    .fill(Color.white.opacity(reduceTransparency ? 0.28 : 0.12))
                    .frame(width: 16, height: 1)
                    .offset(y: 1)
            }
            .clipShape(RoundedRectangle(cornerRadius: Theme.controlCornerRadius, style: .continuous))
            .shadow(
                color: reduceTransparency ? .clear : Color.black.opacity(0.28),
                radius: 8,
                y: 3
            )
            .scaleEffect(reduceMotion || !configuration.isPressed ? 1 : 0.92)
            .opacity(!isEnabled ? 0.45 : configuration.isPressed ? 0.82 : 1)
            .animation(
                reduceMotion ? .none : .spring(response: 0.22, dampingFraction: 0.88),
                value: configuration.isPressed
            )
    }
}
struct TimeMasterToolbarIconSurface: ViewModifier {
    let size: CGFloat

    init(size: CGFloat = 36) {
        self.size = size
    }

    func body(content: Content) -> some View {
        content
            .foregroundStyle(.white)
            .frame(width: size, height: size)
            .modifier(
                TimeMasterPrivateGlassSurface(
                    cornerRadius: Theme.controlCornerRadius,
                    isInteractive: true,
                    tint: Theme.toolbarOrange,
                    tintOpacity: 0.52
                )
            )
            .clipShape(RoundedRectangle(cornerRadius: Theme.controlCornerRadius, style: .continuous))
            .frame(minWidth: 44, minHeight: 44)
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
        .buttonStyle(.plain)
        .modifier(TimeMasterToolbarIconSurface(size: 38))
        .accessibilityLabel("Back")
    }
}


struct TimeMasterToolbarTextButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .frame(minHeight: 44)
            .modifier(
                TimeMasterPrivateGlassSurface(
                    cornerRadius: Theme.controlCornerRadius,
                    isInteractive: true,
                    tint: isEnabled ? Theme.toolbarOrange : Theme.surface2,
                    tintOpacity: isEnabled ? 0.48 : 0.26
                )
            )
            .clipShape(RoundedRectangle(cornerRadius: Theme.controlCornerRadius, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: Theme.controlCornerRadius, style: .continuous)
                    .stroke(
                        isEnabled ? Theme.toolbarOrange.opacity(0.7) : Color.white.opacity(0.12),
                        lineWidth: 1
                    )
            }
            .opacity(!isEnabled ? 0.45 : configuration.isPressed ? 0.78 : 1)
    }
}

struct TimeMasterToolbarWideButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @ViewBuilder
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, 14)
            .padding(.vertical, 6)
            .frame(minHeight: 44)
            .modifier(
                TimeMasterPrivateGlassSurface(
                    cornerRadius: Theme.controlCornerRadius,
                    isInteractive: true,
                    tint: isEnabled ? Theme.toolbarOrange : Theme.surface2,
                    tintOpacity: isEnabled ? 0.52 : 0.26
                )
            )
            .clipShape(RoundedRectangle(cornerRadius: Theme.controlCornerRadius, style: .continuous))
            .scaleEffect(reduceMotion || !configuration.isPressed ? 1 : 0.96)
            .opacity(!isEnabled ? 0.45 : configuration.isPressed ? 0.82 : 1)
            .animation(
                reduceMotion ? .none : .spring(response: 0.22, dampingFraction: 0.88),
                value: configuration.isPressed
            )
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