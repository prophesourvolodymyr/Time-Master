import SwiftUI

private struct CollectiblePreviewItemKey: EnvironmentKey {
    static let defaultValue: CollectibleItem? = nil
}

extension EnvironmentValues {
    var collectiblePreviewItem: CollectibleItem? {
        get { self[CollectiblePreviewItemKey.self] }
        set { self[CollectiblePreviewItemKey.self] = newValue }
    }
}

struct ProfileStyledAvatar: View {
    let profile: LocalUserProfile
    var size: CGFloat = 44
    @EnvironmentObject private var profileStore: LocalProfileStore
    @Environment(\.collectiblePreviewItem) private var preview

    private var item: CollectibleItem? {
        preview?.category == .avatar ? preview : CollectibleItem.selected(.avatar, in: profileStore.snapshot)
    }

    var body: some View {
        ZStack {
            ProfileAvatar(profile: profile, size: item == nil ? size : size * 0.78)
            if let item { CollectibleAvatarRing(item: item) }
        }
        .frame(width: size, height: size)
    }
}

struct ProfileStyledName: View {
    let text: String
    @EnvironmentObject private var profileStore: LocalProfileStore
    @Environment(\.collectiblePreviewItem) private var preview

    var body: some View {
        CollectibleName(text: text, item: preview?.category == .name ? preview : CollectibleItem.selected(.name, in: profileStore.snapshot))
    }
}

struct ProfileBannerDecoration: View {
    @EnvironmentObject private var profileStore: LocalProfileStore
    @Environment(\.collectiblePreviewItem) private var preview

    var body: some View {
        if let item = preview?.category == .entrance ? preview : CollectibleItem.selected(.entrance, in: profileStore.snapshot) {
            CollectibleEntrance(item: item)
        }
    }
}

struct ProfileBadgePreview: View {
    @EnvironmentObject private var profileStore: LocalProfileStore
    @Environment(\.collectiblePreviewItem) private var preview

    private var item: CollectibleItem? {
        preview?.category == .badge ? preview : CollectibleItem.selected(.badge, in: profileStore.snapshot)
    }

    var body: some View {
        if profileStore.snapshot.badgePreview != nil || preview?.category == .badge {
            HStack(spacing: EverSpacing.x2) {
                if let item {
                    CollectibleBadgeSkin(item: item)
                        .frame(width: EverLayout.minimumTouchTarget, height: EverLayout.minimumTouchTarget)
                } else if let tier = profileStore.snapshot.badgePreview {
                    ProfileVerificationBadge(tier: tier)
                        .frame(width: EverLayout.minimumTouchTarget, height: EverLayout.minimumTouchTarget)
                }
                Text("\(profileStore.snapshot.badgePreview?.title ?? "Cosmetic") · Preview")
                    .font(TimeMasterFont.caption())
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Badge appearance preview. Not identity verification.")
        }
    }
}

struct ProfileCollectiblesView: View {
    var body: some View {
        NavigationStack {
            CollectibleShopView()
        }
    }
}

struct CollectibleProfileCover: View {
    let profile: LocalUserProfile

    var body: some View {
        GeometryReader { geometry in
            Group {
                if let filename = profile.bannerFilename, let image = PhotoManager.shared.loadPhoto(filename: filename) {
                    platformImage(image).resizable().scaledToFill()
                } else {
                    ProfileCoverArtwork()
                }
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
            .clipped()
        }
        .accessibilityHidden(true)
    }
}
