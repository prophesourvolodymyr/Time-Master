import SwiftUI

struct ProfileCheckmarkEntryButton: View {
    let hasMembership: Bool
    let isPaused: Bool
    let action: () -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    @State private var phrase = 0

    private static let phrases = [("PREVIEW", "STYLES"), ("MAKE IT", "YOURS"), ("EXPLORE", "STYLES")]
    private var rotates: Bool { !hasMembership && !isPaused && scenePhase == .active }

    var body: some View {
        Button(action: action) {
            HStack(spacing: EverSpacing.x2) {
                if hasMembership {
                    Text("Preview")
                } else {
                    Text(Self.phrases[phrase].0)
                        .id("profile-cta-leading-\(phrase)")
                        .transition(reduceMotion ? .opacity : .push(from: .bottom))
                    ProfileVerificationBadge(tier: .blue, size: EverSpacing.x4 + EverSpacing.x1, animated: true)
                        .accessibilityHidden(true)
                    Text(Self.phrases[phrase].1)
                        .id("profile-cta-trailing-\(phrase)")
                        .transition(reduceMotion ? .opacity : .push(from: .bottom))
                }
            }
            .font(TimeMasterFont.label())
            .lineLimit(1)
            .fixedSize(horizontal: true, vertical: false)
        }
        .buttonStyle(EverSpecularButtonStyle(isPrimary: true))
        .accessibilityLabel("Preview checkmark styles")
        .task(id: rotates) {
            guard rotates else { return }
            while !Task.isCancelled {
                do { try await Task.sleep(nanoseconds: 5_000_000_000) }
                catch { return }
                withAnimation(reduceMotion ? nil : EverMotion.state) {
                    phrase = (phrase + 1) % Self.phrases.count
                }
            }
        }
    }

}
