import SwiftUI
import TimeMasterCore

/// A selectable pill in the skill sheets (orange when chosen).
struct SkillChoicePill: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(TimeMasterFont.rowTitle())
                .foregroundStyle(isSelected ? Color.black : Theme.textPrimary)
                .padding(.horizontal, 13)
                .padding(.vertical, 9)
                .frame(maxWidth: .infinity)
                .background(isSelected ? Theme.toolbarOrange : Theme.surface2, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(isSelected ? Theme.toolbarOrange : Theme.toolbarOrange.opacity(0.28), lineWidth: 1)
                }
        }.keyNavPlainButtonStyle()
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

/// The eight palette colours, "automatic" and a free colour.
struct SkillColorPicker: View {
    @Binding var selection: String?
    /// The colour drawn for "automatic" (a type without a colour).
    var automaticHex: String = "8B7CFF"
    var allowsAutomatic = false

    @State private var custom = Color(hex: "8B7CFF")

    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 44), spacing: 10)], spacing: 10) {
            if allowsAutomatic {
                swatch(hex: nil, color: Color(hex: automaticHex).opacity(0.5), label: "Automatic")
            }
            ForEach(SkillColors.palette, id: \.self) { hex in
                swatch(hex: hex, color: Color(hex: hex), label: hex)
            }
            ColorPicker("Custom colour", selection: Binding(
                get: { custom },
                set: { newValue in
                    custom = newValue
                    selection = newValue.skillHexString
                }
            ), supportsOpacity: false)
            .labelsHidden()
            .frame(width: 44, height: 44)
        }
        .onAppear {
            if let hex = SkillColors.normalizedHex(selection) { custom = Color(hex: hex) }
        }
    }

    private func swatch(hex: String?, color: Color, label: String) -> some View {
        let normalized = SkillColors.normalizedHex(selection)
        let isSelected = hex == nil ? normalized == nil : normalized == hex
        return Button {
            selection = hex
        } label: {
            Circle()
                .fill(color)
                .frame(width: 34, height: 34)
                .overlay {
                    Circle().strokeBorder(Color.white.opacity(isSelected ? 0.95 : 0.12), lineWidth: isSelected ? 3 : 1)
                }
                .frame(width: 44, height: 44)
        }.keyNavPlainButtonStyle()
        .accessibilityLabel(hex == nil ? "Automatic colour" : "Colour \(label)")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

extension Color {
    /// `RRGGBB` of a SwiftUI colour in sRGB.
    var skillHexString: String? {
        #if os(iOS)
        let native = UIColor(self)
        var red: CGFloat = 0, green: CGFloat = 0, blue: CGFloat = 0, alpha: CGFloat = 0
        guard native.getRed(&red, green: &green, blue: &blue, alpha: &alpha) else { return nil }
        #else
        guard let native = NSColor(self).usingColorSpace(.sRGB) else { return nil }
        let red = native.redComponent, green = native.greenComponent, blue = native.blueComponent
        #endif
        func byte(_ value: CGFloat) -> Int { Int((min(1, max(0, value)) * 255).rounded()) }
        return String(format: "%02X%02X%02X", byte(red), byte(green), byte(blue))
    }
}

/// A symbol or an emoji for a type or a group.
struct SkillIconPicker: View {
    @Binding var iconName: String
    @Binding var iconType: SkillBoardIconType

    private static let symbols = [
        "tag.fill", "star.fill", "flag.fill", "flame.fill", "bolt.fill", "target", "checkmark.seal.fill", "sparkles",
        "book.closed.fill", "graduationcap.fill", "lightbulb.fill", "hammer.fill", "wrench.and.screwdriver.fill",
        "music.note", "paintbrush.fill", "camera.fill", "figure.run", "dumbbell.fill", "heart.fill", "moon.fill",
        "clock.fill", "calendar", "pin.fill", "exclamationmark.triangle.fill"
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                SkillChoicePill(title: "Symbol", isSelected: iconType == .system) {
                    if iconType != .system { iconName = "tag.fill" }
                    iconType = .system
                }
                SkillChoicePill(title: "Emoji", isSelected: iconType == .emoji) {
                    if iconType != .emoji { iconName = "" }
                    iconType = .emoji
                }
            }
            if iconType == .emoji {
                TextField("Choose an emoji", text: $iconName)
                    .textFieldStyle(.plain)
                    .font(.system(size: 28))
                    .multilineTextAlignment(.center)
                    .padding(12)
                    .background(Theme.surface, in: RoundedRectangle(cornerRadius: 10))
                    .foregroundStyle(Theme.textPrimary)
                    .onChange(of: iconName) { value in
                        if let first = value.first(where: { $0.isEmoji }) {
                            if value != String(first) { iconName = String(first) }
                        } else if !value.isEmpty {
                            iconName = ""
                        }
                    }
            } else {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 6), spacing: 8) {
                    ForEach(Self.symbols, id: \.self) { symbol in
                        let isSelected = iconName == symbol
                        Button {
                            iconName = symbol
                        } label: {
                            Image(systemName: symbol)
                                .font(.system(size: 17, weight: .semibold))
                                .foregroundStyle(isSelected ? Color.black : Theme.textPrimary)
                                .frame(maxWidth: .infinity, minHeight: 42)
                                .background(isSelected ? Theme.toolbarOrange : Theme.surface, in: RoundedRectangle(cornerRadius: 10))
                                .overlay {
                                    RoundedRectangle(cornerRadius: 10)
                                        .stroke(isSelected ? Theme.toolbarOrange : Theme.toolbarOrange.opacity(0.22), lineWidth: 1)
                                }
                        }.keyNavPlainButtonStyle()
                        .accessibilityLabel(symbol)
                        .accessibilityAddTraits(isSelected ? .isSelected : [])
                    }
                }
            }
        }
    }
}

private extension Character {
    var isEmoji: Bool {
        guard let scalar = unicodeScalars.first else { return false }
        return scalar.properties.isEmojiPresentation || (scalar.properties.isEmoji && unicodeScalars.count > 1)
    }
}
