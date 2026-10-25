import SwiftUI

struct MediaCommentBubble: View {
    let text: String
    @ScaledMetric(relativeTo: .body) private var cornerRadius: CGFloat = 18

    var body: some View {
        MediaCommentMarkdown(text: text)
            .padding(12)
            .background(Theme.surface2, in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .environment(\.openURL, OpenURLAction { url in
                ["http", "https"].contains(url.scheme?.lowercased() ?? "") ? .systemAction : .discarded
            })
    }

}
