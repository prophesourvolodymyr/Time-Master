import SwiftUI

struct RankedAccountView: View {
    @ObservedObject private var account = CloudAccountStore.shared

    var body: some View {
        NavigationStack {
            CloudAccountSettingsView()
                .toolbar {
                    AppToolbar.item(placement: .confirmationAction) {
                        RankedCloseButton().disabled(account.busy)
                    }
                }
                .interactiveDismissDisabled(account.busy)
        }
        .tint(Theme.toolbarOrange)
        .environment(\.slotNavigationContentBounds, nil)
    }
}

struct RankedServiceNotice: View {
    let message: String
    var retry: (() -> Void)?
    var body: some View {
        HStack(alignment: .top, spacing: ProfileStyle.spacing) {
            Image(systemName: "exclamationmark.triangle")
                .foregroundStyle(Theme.toolbarOrange)
                .accessibilityHidden(true)
            Text(message)
                .font(TimeMasterFont.caption())
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
            if let retry { RankedIconAction(symbol: "arrow.clockwise", label: "Retry", action: retry) }
        }
        .padding(ProfileStyle.spacing).frame(maxWidth: .infinity)
        .modifier(TimeMasterCardSurface(flat: true))
        .accessibilityIdentifier("ranked-service-notice")
    }
}
