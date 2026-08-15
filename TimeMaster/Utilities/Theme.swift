import SwiftUI

struct Theme {
    // Defined but ONLY used in AnalyticsView.swift
    static let primary       = Color(hex: "FF6B35")
    static let accent        = Color(hex: "4ECDC4")
    static let restAccent = Color(hex: "FF9500")

    // App-wide monochrome palette
    static let background    = Color(hex: "0A0A0A")
    static let surface       = Color(hex: "141414")
    static let surface2      = Color(hex: "1C1C1C")
    static let textPrimary   = Color.white
    static let textSecondary = Color.white.opacity(0.45)
    static let separator     = Color.white.opacity(0.08)

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
 
enum AppToolbar {
    @ToolbarContentBuilder
    static func item<Content: View>(
        placement: ToolbarItemPlacement,
        @ViewBuilder content: @escaping () -> Content
    ) -> some ToolbarContent {
        if #available(iOS 26.0, macOS 26.0, *) {
            ToolbarItem(placement: placement, content: content)
                .sharedBackgroundVisibility(.visible)
        } else {
            ToolbarItem(placement: placement, content: content)
        }
    }

    @ToolbarContentBuilder
    static func group<Content: View>(
        placement: ToolbarItemPlacement,
        @ViewBuilder content: @escaping () -> Content
    ) -> some ToolbarContent {
        if #available(iOS 26.0, macOS 26.0, *) {
            ToolbarItemGroup(placement: placement, content: content)
                .sharedBackgroundVisibility(.visible)
        } else {
            ToolbarItemGroup(placement: placement, content: content)
        }
    }
}

private struct AppOpeningFade<ID: Hashable>: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let id: ID
    @State private var isVisible = false

    func body(content: Content) -> some View {
        content
            .opacity(isVisible ? 1 : 0)
            .offset(y: isVisible || reduceMotion ? 0 : 8)
            .task(id: id) {
                guard !reduceMotion else {
                    isVisible = true
                    return
                }

                isVisible = false
                await Task.yield()

                guard !Task.isCancelled else { return }
                withAnimation(.smooth(duration: 0.32)) {
                    isVisible = true
                }
            }
    }
}

private struct AppHeaderFade: ViewModifier {
    func body(content: Content) -> some View {
        #if os(iOS)
        content
            .overlay(alignment: .top) {
                LinearGradient(
                    stops: [
                        .init(color: Theme.background.opacity(0.98), location: 0),
                        .init(color: Theme.background.opacity(0.9), location: 0.25),
                        .init(color: Theme.background.opacity(0.58), location: 0.58),
                        .init(color: Theme.background.opacity(0), location: 1)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: 140)
                .ignoresSafeArea(edges: .top)
                .allowsHitTesting(false)
            }
        #else
        content
        #endif
    }
}

extension View {
    func appOpeningFade<ID: Hashable>(id: ID) -> some View {
        modifier(AppOpeningFade(id: id))
    }

    func appHeaderFade() -> some View {
        modifier(AppHeaderFade())
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