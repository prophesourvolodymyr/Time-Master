import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    private let isPresentedModally: Bool

    init(isPresentedModally: Bool = false) {
        self.isPresentedModally = isPresentedModally
    }

    var body: some View {
        NavigationStack {
            SettingsRootContent(initialDestination: nil)
                .toolbar {
                    if isPresentedModally {
                        ToolbarItem(placement: .cancellationAction) {
                            Button { dismiss() } label: {
                                EverPillTabLabel(title: "Close", symbol: "xmark", isSelected: true)
                            }
                            .buttonStyle(EverPillTabButtonStyle(isSelected: true))
                        }
                    }
                }
        }
    }
}
