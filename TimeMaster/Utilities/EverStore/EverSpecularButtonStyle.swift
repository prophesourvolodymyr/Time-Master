import SwiftUI

struct EverSpecularButtonEffect: ViewModifier {
    let isPressed: Bool
    let isEnabled: Bool
    var radius: CGFloat = 18
    var isLightBase = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.isFocused) private var isFocused
    @State private var pressFeedback = false
    @State private var releaseTask: Task<Void, Never>?

    private var engaged: Bool { isEnabled && (isPressed || pressFeedback) }

    func body(content: Content) -> some View {
        content
            .overlay {
                RoundedRectangle(cornerRadius: radius, style: .circular)
                    .fill((isLightBase ? Color.black : Color.white).opacity(engaged ? 0.15 : 0))
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
            }
            .overlay {
                EverSpecularRim(
                    shape: RoundedRectangle(cornerRadius: radius, style: .circular),
                    isLightBase: isLightBase
                )
            }
            .overlay {
                if isFocused {
                    RoundedRectangle(cornerRadius: radius)
                        .stroke(Color.white.opacity(0.75), lineWidth: 2)
                        .padding(-3)
                        .allowsHitTesting(false)
                        .accessibilityHidden(true)
                }
            }
            .scaleEffect(engaged && !reduceMotion ? 0.965 : 1)
            .opacity(isEnabled ? 1 : 0.55)
            .animation(reduceMotion ? nil : (engaged ? EverMotion.press : EverMotion.release), value: engaged)
            .contentShape(RoundedRectangle(cornerRadius: radius))
            .onDisappear {
                releaseTask?.cancel()
                releaseTask = nil
                pressFeedback = false
            }
            .onChange(of: isPressed) { pressed in
                releaseTask?.cancel()
                if pressed {
                    pressFeedback = true
                } else {
                    releaseFeedback()
                }
            }
    }

    private func releaseFeedback() {
        releaseTask?.cancel()
        releaseTask = Task { @MainActor in
            do { try await Task.sleep(nanoseconds: 120_000_000) }
            catch { return }
            pressFeedback = false
            releaseTask = nil
        }
    }

}

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


struct EverSpecularButtonStyle: ButtonStyle {
    var radius: CGFloat = 18
    var isPrimary = false
    var horizontalPadding: CGFloat = EverSpacing.x3
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.horizontal, horizontalPadding)
            .frame(minWidth: EverLayout.minimumTouchTarget, minHeight: EverLayout.minimumTouchTarget)
            .foregroundStyle(isPrimary ? EverColor.onAccent : EverColor.textPrimary)
            .background(isPrimary ? EverColor.accent : EverColor.background, in: RoundedRectangle(cornerRadius: radius, style: .circular))
            .modifier(EverSpecularButtonEffect(isPressed: configuration.isPressed, isEnabled: isEnabled, radius: radius, isLightBase: isPrimary))
    }
}

