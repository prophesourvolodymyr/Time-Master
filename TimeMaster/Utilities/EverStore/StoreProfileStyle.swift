import SwiftUI
#if os(iOS)
import UIKit
#else
import AppKit
#endif

struct StoreProfileColor: Equatable {
    var red: Double
    var green: Double
    var blue: Double

    init(_ red: Double, _ green: Double, _ blue: Double) {
        self.red = red
        self.green = green
        self.blue = blue
    }

    init(_ color: Color) {
        #if os(iOS)
        let resolved = UIColor(color)
        #else
        let resolved = NSColor(color).usingColorSpace(.deviceRGB) ?? .black
        #endif
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 1
        resolved.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        self.init(Double(red), Double(green), Double(blue))
    }

    var color: Color { Color(red: red, green: green, blue: blue) }

    var ink: Color {
        func linear(_ value: Double) -> Double {
            value <= 0.04045 ? value / 12.92 : pow((value + 0.055) / 1.055, 2.4)
        }
        let luminance = linear(red) * 0.2126 + linear(green) * 0.7152 + linear(blue) * 0.0722
        return luminance > 0.179 ? .black : .white
    }
}

struct StoreProfilePalette: Equatable {
    var primary: StoreProfileColor
    var secondary: StoreProfileColor
    var colors: [StoreProfileColor]

    var background: Color { primary.color }
    var surface: Color { secondary.color }
    var foreground: Color { primary.ink }
    var secondaryText: Color { primary.ink.opacity(0.7) }
    var surfaceForeground: Color { secondary.ink }
    var surfaceSecondaryText: Color { secondary.ink.opacity(0.7) }

    var forSurface: StoreProfilePalette {
        StoreProfilePalette(primary: secondary, secondary: secondary, colors: colors)
    }

    func highlight(_ index: Int) -> Color {
        colors.isEmpty ? foreground : colors[index % colors.count].color
    }

    static let midnight = StoreProfilePalette(
        primary: StoreProfileColor(Theme.background),
        secondary: StoreProfileColor(Theme.surface),
        colors: [StoreProfileColor(1, 1, 1), StoreProfileColor(0.81, 0.94, 0.46)]
    )

    static let presets: [(name: String, palette: StoreProfilePalette)] = [
        ("Midnight", .midnight),
        ("Paper", StoreProfilePalette(primary: StoreProfileColor(0.95, 0.94, 0.9), secondary: StoreProfileColor(1, 0.99, 0.96), colors: [StoreProfileColor(0.22, 0.33, 0.28), StoreProfileColor(0.73, 0.28, 0.2)])),
        ("Moss", StoreProfilePalette(primary: StoreProfileColor(0.1, 0.17, 0.13), secondary: StoreProfileColor(0.17, 0.26, 0.2), colors: [StoreProfileColor(0.77, 0.9, 0.53), StoreProfileColor(0.47, 0.73, 0.66)])),
        ("Plum", StoreProfilePalette(primary: StoreProfileColor(0.22, 0.12, 0.24), secondary: StoreProfileColor(0.34, 0.21, 0.36), colors: [StoreProfileColor(0.97, 0.72, 0.79), StoreProfileColor(0.72, 0.68, 0.95)]))
    ]
}


enum StoreProfileStatStyle: String, CaseIterable, Identifiable {
    case outline = "Outline"
    case filled = "Filled"
    case rounded = "Rounded"
    var id: String { rawValue }
}

private struct StoreProfilePaletteKey: EnvironmentKey {
    static let defaultValue: StoreProfilePalette? = nil
}

extension EnvironmentValues {
    var storeProfilePalette: StoreProfilePalette? {
        get { self[StoreProfilePaletteKey.self] }
        set { self[StoreProfilePaletteKey.self] = newValue }
    }
}
