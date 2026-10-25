import SwiftUI

struct BundleExerciseThumbnail: View {
    @EnvironmentObject private var databaseStore: DatabaseStore
    let slot: SetSlot
    var size: CGFloat = 54

    var body: some View {
        let page = slot.exercisePageID.flatMap { databaseStore.page(id: $0) }
        AsyncCoverImage(
            url: page?.coverImageURL,
            fallbackIcon: page?.effectiveWorkoutType?.iconName ?? "figure.boxing",
            fallbackColor: Theme.toolbarOrange,
            height: size,
            overlayGradient: false
        )
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .accessibilityHidden(true)
    }
}
