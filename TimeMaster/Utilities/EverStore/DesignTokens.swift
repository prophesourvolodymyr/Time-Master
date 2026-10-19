import SwiftUI

enum EverColor {
    static let background = Theme.background
    static let surfacePrimary = Theme.surface
    static let surfaceSecondary = Theme.surface2
    static let surfacePressed = Color(white: 26 / 255)
    static let borderSubtle = Theme.separator
    static let borderStrong = Color(white: 58 / 255)
    static let textPrimary = Theme.textPrimary
    static let textSecondary = ProfileStyle.secondary
    static let textTertiary = Theme.textSecondary
    static let disabledSurface = Color(red: 32 / 255, green: 32 / 255, blue: 32 / 255)
    static let disabledContent = Color(red: 102 / 255, green: 102 / 255, blue: 102 / 255)
    static let accent = Theme.toolbarOrange
    static let onAccent = Color.black
    static let success = Color(red: 50 / 255, green: 215 / 255, blue: 75 / 255)
    static let warning = Color(red: 1, green: 214 / 255, blue: 10 / 255)
    static let error = Color(red: 1, green: 69 / 255, blue: 58 / 255)
}

enum EverSpacing {
    static let x1: CGFloat = 4
    static let x2: CGFloat = 8
    static let x3: CGFloat = 12
    static let x4: CGFloat = 16
    static let x5: CGFloat = 20
    static let x6: CGFloat = 24
    static let x7: CGFloat = 32
    static let x8: CGFloat = 40
}

enum EverRadius {
    static let card: CGFloat = 16
    static let button: CGFloat = 14
    static let field: CGFloat = 12
    static let popup: CGFloat = 24
}

enum EverLayout {
    static let phoneInset: CGFloat = 20
    static let regularInset: CGFloat = 32
    static let maximumReadableWidth: CGFloat = 720
    static let minimumTouchTarget: CGFloat = 44
    static let standardRowMinimum: CGFloat = 56
    static let primaryButtonMinimum: CGFloat = 50
    static let popupMaximumWidth: CGFloat = 480
}

extension View {
    func everScreenBackground() -> some View {
        background(EverColor.background.ignoresSafeArea())
    }

    @ViewBuilder
    func everSheetBackground() -> some View {
        if #available(iOS 16.4, macOS 13.3, *) {
            self.presentationBackground(EverColor.background)
        } else {
            self
        }
    }

    func everReadableWidth() -> some View {
        frame(maxWidth: EverLayout.maximumReadableWidth, alignment: .leading)
            .frame(maxWidth: .infinity, alignment: .center)
    }
}
