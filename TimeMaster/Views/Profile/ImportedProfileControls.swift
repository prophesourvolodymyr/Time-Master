import SwiftUI

extension ProfileView {
    var membershipButton: some View {
        RankedIconAction(symbol: "checkmark.seal", label: "Checkmark styles", id: "profile-verification", showsLabel: false) {
            sheet = .verification
        }
        .accessibilityValue(profileStore.snapshot.badgePreview == nil ? "Not verified" : "Local style preview, not verification")
    }

    var marketplaceButton: some View {
        RankedIconAction(symbol: "bag.badge.plus", label: "Collectibles", id: "profile-marketplace", showsLabel: false) {
            sheet = .collectibles
        }
    }

    func backButton(size: CGFloat = EverLayout.minimumTouchTarget) -> some View {
        RankedIconAction(symbol: "chevron.left", label: "Back", id: "profile-back", showsLabel: false) {
            if let onPreviewClose { onPreviewClose() } else { dismiss() }
        }
        .frame(width: size, height: size)
    }

    func profileActions(size: CGFloat = EverLayout.minimumTouchTarget) -> some View {
        RankedIconAction(symbol: "ellipsis", label: "Profile actions", id: "profile-options", showsLabel: false) {
            sheet = .actions
        }
        .frame(width: size, height: size)
    }

    var profileActionsSheet: some View {
        NavigationStack {
            ScrollView {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: EverLayout.minimumTouchTarget * 2))], spacing: EverSpacing.x5) {
                    if asVisitor {
                        profileMenuAction("Return to my profile", symbol: "person.crop.circle") {
                            asVisitor = false
                            sheet = nil
                        }
                        profileMenuAction("Report profile", symbol: "flag") { sheet = .report }
                    } else {
                        profileMenuAction("Edit profile", symbol: "pencil") { sheet = .edit }
                            .disabled(profileStore.isReadOnly)
                        profileMenuAction("New post", symbol: "square.and.pencil") { sheet = .compose }
                            .disabled(profileStore.isReadOnly)
                        profileMenuAction("Visitor preview", symbol: "eye") {
                            asVisitor = true
                            sheet = nil
                        }
                        profileMenuAction("Collectibles", symbol: "bag") { sheet = .collectibles }
                        profileMenuAction("Checkmark styles", symbol: "checkmark.seal") { sheet = .verification }
                        profileMenuAction("Settings", symbol: "gearshape") { sheet = .settings }
                        profileMenuAction("All Activity History", symbol: "clock.arrow.circlepath", action: openProfileHistory)
                        profileMenuAction("Ranked account", symbol: "person.badge.key") { sheet = .rankedAccount }
                    }
                }
                .padding(EverLayout.phoneInset)
                .frame(maxWidth: ProfileStyle.readableWidth)
                .frame(maxWidth: .infinity)
            }
            .background(Theme.background.ignoresSafeArea())
            .toolbar {
                AppToolbar.iconItem(placement: .confirmationAction) {
                    RankedIconAction(symbol: "xmark", label: "Close Profile actions", id: "profile-actions-close", showsLabel: false) { sheet = nil }
                }
            }
        }
        .tint(Theme.toolbarOrange)
        .preferredColorScheme(.dark)
#if os(iOS)
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
#endif
    }

    private func profileMenuAction(_ title: String, symbol: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.title2.weight(.semibold))
                .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
                .frame(maxWidth: .infinity, minHeight: EverLayout.minimumTouchTarget * 1.5)
                .contentShape(Rectangle())
        }
        .buttonStyle(TimeMasterToolbarWideButtonStyle())
        .accessibilityLabel(title)
        .help(title)
    }
}
