import SwiftUI


struct EverSpecularRim<Surface: InsettableShape>: View {
    let shape: Surface
    var isLightBase = false

    var body: some View {
        shape
            .strokeBorder((isLightBase ? Color.black : Color.white).opacity(isLightBase ? 0.25 : 0.2), lineWidth: 1)
            .overlay {
                shape.strokeBorder(
                    LinearGradient(
                        colors: [.white.opacity(0.35), .white.opacity(0.04), .white.opacity(0.15)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
            }
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }
}


struct EverActionButtonStyle: ButtonStyle {
    var isPrimary = false
    var horizontalPadding: CGFloat = EverSpacing.x3

    func makeBody(configuration: Configuration) -> some View {
        TimeMasterActionButtonStyle(
            prominent: isPrimary,
            horizontalPadding: horizontalPadding
        )
        .makeBody(configuration: configuration)
    }
}

