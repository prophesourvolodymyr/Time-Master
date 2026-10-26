import SwiftUI

@MainActor
final class MenuBarPopupNavigation: ObservableObject {
    static let shared = MenuBarPopupNavigation()

    @Published var page: MenuBarPage = .home

    private init() {}
}

struct MenuBarPopupRoot: View {
    @ObservedObject var startup: TmaxStartupModel

    var body: some View {
        MenuBarPopupContent(store: startup.workoutStore, status: startup.status)
    }
}

struct MenuBarPopupContent: View {
    let store: WorkoutStore?
    let status: String
    @ObservedObject private var live = WorkoutLiveSession.shared
    @ObservedObject private var navigation = MenuBarPopupNavigation.shared
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(spacing: 0) {
            MenuBarPopupHeader(page: navigation.page, store: store)
            Rectangle().fill(Theme.separator).frame(height: 1)
            content
                .id(navigation.page)
                .transition(.opacity)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            Rectangle().fill(Theme.separator).frame(height: 1)
            MenuBarPageBar(selection: $navigation.page)
        }
        .frame(width: MenuBarPopupMetrics.width, height: MenuBarPopupMetrics.height)
        .background(Theme.background)
        .foregroundStyle(Theme.textPrimary)
        .font(TimeMasterFont.body())
        .preferredColorScheme(.dark)
        .animation(reduceMotion ? nil : .easeOut(duration: 0.15), value: navigation.page)
        .onChange(of: live.isActive) { active in
            if active { navigation.page = .home }
        }
    }

    @ViewBuilder
    private var content: some View {
        switch navigation.page {
        case .coach:
            MenuBarCoachPage()
        case .settings:
            MenuBarSettingsPage()
        case .home, .activity, .workouts, .schedule:
            if let store {
                switch navigation.page {
                case .activity: MenuBarActivityPage(store: store)
                case .workouts: MenuBarWorkoutsPage(store: store)
                case .schedule: MenuBarSchedulePage(store: store)
                default: MenuBarHomePage(store: store)
                }
            } else {
                VStack(spacing: 12) {
                    ProgressView()
                        .controlSize(.small)
                        .tint(Theme.toolbarOrange)
                    Text(status)
                        .font(TimeMasterFont.secondary())
                        .foregroundStyle(Theme.textSecondary)
                        .multilineTextAlignment(.center)
                }
                .padding(24)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .accessibilityElement(children: .combine)
            }
        }
    }
}

private struct MenuBarPopupHeader: View {
    let page: MenuBarPage
    let store: WorkoutStore?
    @ObservedObject private var live = WorkoutLiveSession.shared

    var body: some View {
        HStack(alignment: .center, spacing: 8) {
            TimeMasterPageTitle(page.title, size: 30, relativeTo: .title)
                .lineLimit(1)
            Spacer(minLength: 8)
            if let state = live.state {
                MenuBarChip(text: state.isPaused ? "PAUSED" : "LIVE", tint: Theme.toolbarOrange, filled: !state.isPaused)
                    .accessibilityLabel(state.isPaused ? "Workout paused" : "Workout live")
            } else if let store {
                MenuBarStreakChip(store: store)
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 12)
        .padding(.bottom, 8)
    }
}

private struct MenuBarStreakChip: View {
    @ObservedObject var store: WorkoutStore

    var body: some View {
        let streak = store.streakInfo().current
        HStack(spacing: 4) {
            Image(systemName: "flame.fill")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(Theme.toolbarOrange)
            Text("\(streak)")
                .font(TimeMasterFont.black(14, relativeTo: .subheadline))
                .foregroundStyle(Theme.textPrimary)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(Capsule().fill(Theme.surface2))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(streak) day streak")
    }
}

private struct MenuBarPageBar: View {
    @Binding var selection: MenuBarPage

    var body: some View {
        HStack(spacing: 2) {
            ForEach(MenuBarPage.allCases) { page in
                Button {
                    selection = page
                } label: {
                    VStack(spacing: 3) {
                        Image(systemName: page.symbol)
                            .font(.system(size: 16, weight: .semibold))
                        Text(page.title)
                            .font(TimeMasterFont.black(10, relativeTo: .caption2))
                            .lineLimit(1)
                    }
                    .foregroundStyle(selection == page ? Theme.toolbarOrange : Theme.textSecondary)
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(selection == page ? Theme.toolbarOrange.opacity(0.14) : .clear)
                    )
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(page.title)
                .accessibilityAddTraits(selection == page ? .isSelected : [])
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
    }
}
