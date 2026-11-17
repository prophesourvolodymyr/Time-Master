import SwiftUI

/// The full-screen answer to an early Done on an untimed set (see `EarlyDoneGuard`). It only answers; the player
/// decides what each answer does.
struct PlayerEarlyDonePopup: View {
    enum Kind: Equatable {
        /// First early tap: one "Yes" that only closes the popup.
        case superhuman
        /// Second early tap: "Yes, I'm done" leaves the set, "Not yet" keeps it running.
        case confirm
    }

    let kind: Kind
    let elapsed: Int
    let onClose: () -> Void
    let onConfirm: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @AccessibilityFocusState private var titleFocused: Bool
    @State private var glowing = false

    private var identifier: String {
        kind == .superhuman ? "player.early.superhuman" : "player.early.confirm"
    }

    private var title: String {
        kind == .superhuman ? "Are you a superhuman? 😂" : "Are you sure you're done?"
    }

    private var message: String {
        kind == .superhuman
            ? "No way you finished by that time."
            : "Only \(PlayerTime.spoken(elapsed)) into this set."
    }

    var body: some View {
        ZStack {
            Color.black.opacity(0.84)
                .ignoresSafeArea()
                .contentShape(Rectangle())
                .accessibilityHidden(true)
            GeometryReader { proxy in
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 28) {
                        orb
                        VStack(spacing: 10) {
                            Text(title)
                                .font(TimeMasterFont.black(30, relativeTo: .title))
                                .foregroundStyle(.white)
                                .multilineTextAlignment(.center)
                                .fixedSize(horizontal: false, vertical: true)
                                .accessibilityAddTraits(.isHeader)
                                .accessibilityFocused($titleFocused)
                            Text(message)
                                .font(TimeMasterFont.body(17, relativeTo: .body))
                                .foregroundStyle(.white.opacity(0.7))
                                .multilineTextAlignment(.center)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        buttons
                    }
                    .frame(maxWidth: EverLayout.popupMaximumWidth)
                    .padding(28)
                    .frame(maxWidth: .infinity, minHeight: proxy.size.height)
                }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityAddTraits(.isModal)
        .accessibilityAction(.escape, onClose)
        .accessibilityIdentifier(identifier)
        .keyNavHost()
        .onAppear {
            titleFocused = true
            guard !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 1.3).repeatForever(autoreverses: true)) { glowing = true }
        }
    }

    private var orb: some View {
        ZStack {
            Circle()
                .fill(RadialGradient(
                    colors: [Theme.toolbarOrange.opacity(0.6), Theme.toolbarOrange.opacity(0)],
                    center: .center, startRadius: 40, endRadius: 150
                ))
                .frame(width: 300, height: 300)
                .scaleEffect(glowing ? 1.1 : 0.92)
                .opacity(glowing ? 1 : 0.75)
            Circle()
                .fill(Theme.toolbarOrange)
                .frame(width: 128, height: 128)
                .shadow(color: Theme.toolbarOrange.opacity(0.9), radius: glowing ? 44 : 28)
                .shadow(color: Theme.toolbarOrange.opacity(0.45), radius: 90)
            Image(systemName: kind == .superhuman ? "bolt.fill" : "hourglass")
                .font(.system(size: 58, weight: .black))
                .foregroundStyle(.black)
        }
        .frame(height: 220)
        .accessibilityHidden(true)
    }

    @ViewBuilder
    private var buttons: some View {
        switch kind {
        case .superhuman:
            answer("Yes", prominent: true, id: "player.early.superhuman.yes", action: onClose)
                .keyboardShortcut(.defaultAction)
                .overlay {
                    // A single answer also takes Escape: a second, invisible shortcut that closes the same way.
                    Button("Close", action: onClose)
                        .keyboardShortcut(.cancelAction)
                        .opacity(0)
                        .allowsHitTesting(false)
                        .accessibilityHidden(true)
                }
        case .confirm:
            let layout = dynamicTypeSize.isAccessibilitySize
                ? AnyLayout(VStackLayout(spacing: 12))
                : AnyLayout(HStackLayout(spacing: 12))
            layout {
                answer("Not yet", prominent: false, id: "player.early.confirm.no", action: onClose)
                    .keyboardShortcut(.cancelAction)
                answer("Yes, I'm done", prominent: true, id: "player.early.confirm.yes", action: onConfirm)
                    .keyboardShortcut(.defaultAction)
            }
        }
    }

    private func answer(_ title: String, prominent: Bool, id: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(TimeMasterFont.black(18, relativeTo: .headline))
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(TimeMasterActionButtonStyle(prominent: prominent, minimumSize: 56, fillsWidth: true))
        .accessibilityIdentifier(id)
    }
}
