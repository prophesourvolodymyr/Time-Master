import SwiftUI

struct PlayerCoverImage: View {
    let url: URL?
    let symbol: String
    var height: CGFloat = 160

    var body: some View {
        Color.clear
            .frame(maxWidth: .infinity)
            .frame(height: height)
            .overlay {
                if let url {
                    AsyncCoverImage(url: url, fallbackIcon: symbol, height: height, overlayGradient: false)
                } else {
                    ZStack {
                        LinearGradient(
                            colors: [.white.opacity(0.18), .white.opacity(0.06)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                        Image(systemName: symbol)
                            .font(.system(size: max(18, height * 0.3), weight: .semibold))
                            .foregroundStyle(.white.opacity(0.45))
                    }
                }
            }
            .clipped()
            .accessibilityHidden(true)
    }
}
