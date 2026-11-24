import SwiftUI

struct SkillGalleryCover: View {
    let page: ExercisePage
    let onOpen: () -> Void

    static let aspect: CGFloat = 16.0 / 10.0

    var body: some View {
        let radius = SkillMetrics.fieldRadius
        SkillGalleryCoverLayout {
            GeometryReader { proxy in
                AsyncCoverImage(
                    url: page.galleryCoverURL,
                    fallbackIcon: PageKindStyle.symbol(page),
                    height: proxy.size.height,
                    contentMode: .fill,
                    overlayGradient: false
                )
                .frame(width: proxy.size.width, height: proxy.size.height)
                .clipped()
            }
        }
        .modifier(PageCoverTap(page: page, cornerRadius: 0, glyphSize: 30, onOpen: onOpen))
        .clipShape(
            UnevenRoundedRectangle(
                topLeadingRadius: radius,
                bottomLeadingRadius: 0,
                bottomTrailingRadius: 0,
                topTrailingRadius: radius,
                style: .continuous
            )
        )
    }
}

private struct SkillGalleryCoverLayout: Layout {
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width.flatMap { $0.isFinite ? $0 : nil } ?? 240
        return CGSize(width: width, height: width / SkillGalleryCover.aspect)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        for subview in subviews {
            subview.place(at: bounds.origin, anchor: .topLeading, proposal: ProposedViewSize(width: bounds.width, height: bounds.height))
        }
    }
}
