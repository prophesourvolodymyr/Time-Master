import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.slotNavigationContentBounds) private var navigationBounds
    private let isPresentedModally: Bool

    init(isPresentedModally: Bool = false) {
        self.isPresentedModally = isPresentedModally
    }

    private var initialDestination: SettingsDestination? {
        #if DEBUG
        return ProcessInfo.processInfo.environment["TIMEMASTER_QA_SETTINGS_DESTINATION"].flatMap(SettingsDestination.init(rawValue:))
        #else
        return nil
        #endif
    }

    var body: some View {
        NavigationStack {
            SettingsRootContent(initialDestination: initialDestination)
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
        .everScreenBackground()
        .everSheetBackground()
        .environment(\.slotNavigationContentBounds, isPresentedModally ? nil : navigationBounds)
    }
}
