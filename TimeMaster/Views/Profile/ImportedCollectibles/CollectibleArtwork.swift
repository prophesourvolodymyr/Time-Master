import SwiftUI

struct CollectibleArtwork: View {
    let item: CollectibleItem
    let profile: LocalUserProfile
    var playbackID: Int = 0
    var active: Bool = true
    var personalization: Double = 1

    var body: some View {
        GeometryReader { geometry in
            let unit = min(geometry.size.width, geometry.size.height)
            let avatarSize = max(18, unit * 0.78)
            let gap = max(4, unit * 0.065)
            ZStack {
                if item.category == .badge {
                    CollectibleBadgeSkin(item: item, active: active)
                        .overlay(alignment: .bottom) {
                            Text("PREVIEW")
                                .font(TimeMasterFont.caption())
                                .foregroundStyle(EverColor.textPrimary)
                                .padding(EverSpacing.x1)
                                .background(EverColor.background, in: Capsule())
                        }
                    .padding(unit * 0.08)
                    .frame(width: min(geometry.size.width, unit * 1.2), height: unit)
                } else if item.category == .name {
                    ZStack {
                        CollectibleName(text: item.name, item: item, active: false)
                            .opacity(1 - personalization)
                        CollectibleName(text: profile.displayName, item: item, active: active)
                            .opacity(personalization)
                    }
                        .font(.custom("Inter-Black", size: max(EverSpacing.x4, min(geometry.size.width * 0.15, geometry.size.height * 0.6)), relativeTo: .headline))
                        .lineLimit(1)
                        .minimumScaleFactor(0.55)
                        .padding(.horizontal, geometry.size.width * 0.06)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if item.category == .avatar {
                    ZStack {
                        avatar(size: avatarSize)
                        CollectibleAvatarRing(item: item, active: active)
                    }
                    .frame(width: avatarSize, height: avatarSize)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    VStack(spacing: gap) {
                        avatar(size: avatarSize)
                            .frame(width: avatarSize, height: avatarSize)
                        Text(personalization > 0.5 ? profile.displayName : item.name)
                            .font(TimeMasterFont.caption())
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                            .frame(maxWidth: unit * 0.86)
                    }
                    .frame(maxWidth: geometry.size.width, maxHeight: geometry.size.height)
                }
                if item.category == .entrance {
                    RoundedRectangle(cornerRadius: EverRadius.card)
                        .strokeBorder(CollectibleArtworkPalette.colors(for: item)[0].opacity(0.4), lineWidth: 1)
                        .padding(unit * 0.07)
                    CollectibleEntrance(item: item, trigger: playbackID, active: active)
                        .padding(max(2, unit * 0.03))
                }
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
            .clipped()
        }
        .clipped()
        .allowsHitTesting(false)
        .accessibilityElement()
        .accessibilityLabel("\(item.name), \(item.category.title), for \(profile.displayName)")
    }

    private func avatar(size: CGFloat) -> some View {
        ZStack {
            Image(systemName: "person.crop.circle.fill")
                .resizable()
                .scaledToFit()
                .foregroundStyle(EverColor.textSecondary)
                .opacity(1 - personalization)
            ProfileAvatar(profile: profile, size: size)
                .opacity(personalization)
        }
    }
}
