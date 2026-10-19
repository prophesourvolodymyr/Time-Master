import SwiftUI

extension ProfileView {
    var membershipButton: some View {
        ProfileCheckmarkEntryButton(
            hasMembership: profileStore.snapshot.badgePreview != nil,
            isPaused: sheet == .verification
        ) {
            sheet = .verification
        }
        .accessibilityIdentifier("profile-verification")
    }

    var marketplaceButton: some View {
        Button { sheet = .collectibles } label: {
            Image(systemName: "bag.badge.plus")
                .font(.body.weight(.semibold))
                .frame(width: EverLayout.minimumTouchTarget, height: EverLayout.minimumTouchTarget)
                .contentShape(Circle())
        }
        .buttonStyle(EverSpecularButtonStyle(radius: EverLayout.minimumTouchTarget / 2, horizontalPadding: 0))
        .accessibilityLabel("Collectibles")
        .accessibilityIdentifier("profile-marketplace")
    }
    func backButton(size: CGFloat = EverLayout.minimumTouchTarget) -> some View {
        Button {
            if let onPreviewClose { onPreviewClose() } else { dismiss() }
        } label: {
            Image(systemName: "chevron.left")
                .font(.body.weight(.semibold))
                .frame(width: size, height: size)
                .contentShape(Circle())
        }
        .buttonStyle(EverSpecularButtonStyle(radius: size / 2, horizontalPadding: 0))
        .accessibilityLabel("Back")
        .accessibilityIdentifier("profile-back")
    }

    func profileActions(size: CGFloat = EverLayout.minimumTouchTarget) -> some View {
        Menu {
            profileActionItems
        } label: {
            Image(systemName: "square.and.pencil")
                .font(.body.weight(.semibold))
                .frame(width: size, height: size)
                .contentShape(Circle())
        }
        .buttonStyle(EverSpecularButtonStyle(radius: size / 2, horizontalPadding: 0))
        .accessibilityLabel("Profile actions")
        .accessibilityIdentifier("profile-options")
    }
}
