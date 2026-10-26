import SwiftUI
#if os(macOS)
import ServiceManagement
#endif

struct MenuBarSettingsPage: View {
    @ObservedObject private var preferences = MenuBarPreferences.shared
    @Environment(\.menuBarActions) private var actions
#if os(macOS)
    @State private var launchEnabled = SMAppService.mainApp.status == .enabled
    @State private var launchStatusText: String?
#endif

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                menuBarSection
                levelSection
                momentsSection
                popupSection
#if os(macOS)
                systemSection
#endif
                HStack(spacing: 8) {
                    MenuBarCompactButton(title: "Open Tmax", symbol: "macwindow", fillsWidth: true) {
                        actions.showMainWindow()
                    }
                    MenuBarCompactButton(title: "Quit Tmax", symbol: "power", fillsWidth: true) {
                        actions.quit()
                    }
                }
            }
            .padding(14)
        }
        .scrollIndicators(.hidden)
    }

    private func toggleRow(_ title: String, detail: String? = nil, isOn: Binding<Bool>) -> some View {
        Toggle(isOn: isOn) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(TimeMasterFont.rowTitle())
                    .foregroundStyle(Theme.textPrimary)
                if let detail {
                    Text(detail)
                        .font(TimeMasterFont.caption())
                        .foregroundStyle(Theme.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .toggleStyle(.switch)
        .tint(Theme.toolbarOrange)
        .frame(minHeight: 36)
    }

    private var menuBarSection: some View {
        VStack(spacing: 8) {
            MenuBarSectionTitle(title: "Menu bar")
            MenuBarCard(padding: 12) {
                VStack(spacing: 8) {
                    toggleRow(
                        "Show menu bar icon",
                        isOn: $preferences.isEnabled
                    )
                    .help("Restore it from View › Show Tmax in Menu Bar.")
                    toggleRow("Show timer", isOn: $preferences.showsLabel)
                }
            }
        }
    }

    private var levelSection: some View {
        VStack(spacing: 8) {
            MenuBarSectionTitle(title: "Workout tips")
            VStack(spacing: 8) {
                ForEach(MenuBarLevel.allCases) { level in
                    Button {
                        preferences.level = level
                    } label: {
                        HStack(alignment: .top, spacing: 10) {
                            Image(systemName: preferences.level == level ? "largecircle.fill.circle" : "circle")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(preferences.level == level ? Theme.toolbarOrange : Theme.textSecondary)
                                .accessibilityHidden(true)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(level.title)
                                    .font(TimeMasterFont.rowTitle())
                                    .foregroundStyle(Theme.textPrimary)
                                Text(level.detail)
                                    .font(TimeMasterFont.caption())
                                    .foregroundStyle(Theme.textSecondary)
                                    .multilineTextAlignment(.leading)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            Spacer(minLength: 0)
                        }
                        .padding(12)
                        .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                        .modifier(TimeMasterCardSurface(cornerRadius: 14, emphasized: preferences.level == level, flat: true))
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(MenuBarRowButtonStyle())
                    .accessibilityAddTraits(preferences.level == level ? .isSelected : [])
                }
            }
        }
    }

    private var momentsSection: some View {
        VStack(spacing: 8) {
            MenuBarSectionTitle(
                title: "Moments",
                trailing: preferences.level == .quiet ? "Glance or Alert only" : nil
            )
            MenuBarCard(padding: 12) {
                VStack(spacing: 8) {
                    ForEach(MenuBarMomentKind.allCases) { kind in
                        toggleRow(
                            kind.title,
                            isOn: Binding(
                                get: { preferences.isMomentEnabled(kind) },
                                set: { preferences.setMoment(kind, enabled: $0) }
                            )
                        )
                    }
                }
                .opacity(preferences.level == .quiet ? 0.5 : 1)
                .disabled(preferences.level == .quiet)
            }
        }
    }

    private var popupSection: some View {
        VStack(spacing: 8) {
            MenuBarSectionTitle(title: "Inside this popup")
            MenuBarCard(padding: 12) {
                VStack(spacing: 8) {
                    toggleRow("Show quotes", isOn: $preferences.showsQuotes)
                    toggleRow("Show suggestions", isOn: $preferences.showsSuggestions)
                    toggleRow(
                        "Quiet while using Tmax",
                        isOn: $preferences.calmWhenTmaxIsFront
                    )
                    .help("Suppress tips and sounds while the workout window is in front.")
                }
            }
        }
    }

#if os(macOS)
    private var systemSection: some View {
        VStack(spacing: 8) {
            MenuBarSectionTitle(title: "System")
            MenuBarCard(padding: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    toggleRow(
                        "Open Tmax at login",
                        isOn: Binding(
                            get: { launchEnabled },
                            set: { setLaunchAtLogin($0) }
                        )
                    )
                    if let launchStatusText {
                        Text(launchStatusText)
                            .font(TimeMasterFont.caption())
                            .foregroundStyle(Theme.toolbarOrange)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        }
    }

    private func setLaunchAtLogin(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
            launchStatusText = nil
        } catch {
            launchStatusText = error.localizedDescription
        }
        let status = SMAppService.mainApp.status
        launchEnabled = status == .enabled
        if status == .requiresApproval {
            launchStatusText = "Approve Tmax in System Settings › General › Login Items."
        }
    }
#endif
}
