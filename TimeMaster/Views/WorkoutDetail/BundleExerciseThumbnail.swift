import SwiftUI

struct BundleExerciseThumbnail: View {
    let slot: SetSlot
    var size: CGFloat = 54

    var body: some View {
        BundlePageThumbnail(pageID: slot.exercisePageID, size: size)
    }
}

struct BundlePageThumbnail: View {
    @EnvironmentObject private var databaseStore: DatabaseStore
    let pageID: UUID?
    var size: CGFloat = 54
    var fallbackIcon = "figure.boxing"

    var body: some View {
        let page = pageID.flatMap { databaseStore.page(id: $0) }
        AsyncCoverImage(
            url: page?.coverImageURL,
            fallbackIcon: page?.effectiveWorkoutType?.iconName ?? fallbackIcon,
            fallbackColor: Theme.toolbarOrange,
            height: size,
            overlayGradient: false
        )
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: BuilderMetrics.thumbnailRadius(size), style: .continuous))
        .accessibilityHidden(true)
    }
}
