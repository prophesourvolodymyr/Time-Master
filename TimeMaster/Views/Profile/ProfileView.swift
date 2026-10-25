import SwiftUI
#if os(iOS)
import UIKit
#endif

enum LocalProfileSheet: String, Identifiable {
    case edit, compose, settings, collectibles, verification, report, rankedAccount, actions
    var id: String { rawValue }
}

struct ProfileView: View {
    let onOpenRanked: ((RankedVariation) -> Void)?
    let previewOnly: Bool
    let onPreviewClose: (() -> Void)?
    @EnvironmentObject var profileStore: LocalProfileStore
    @ObservedObject var rankedAccount = RankedAccountStore.shared
    @AppStorage("tm.ranked.family") var rankedFamily: RankedFamily = .pushUps
    @AppStorage("tm.ranked.pushUp") var rankedPushUp: RankedVariation = .standardPushUp
    @AppStorage("tm.ranked.squat") var rankedSquat: RankedVariation = .standardSquat
    @AppStorage("tm.ranked.core") var rankedCore: RankedVariation = .forearmPlank
    @EnvironmentObject private var workoutStore: WorkoutStore
    @EnvironmentObject private var outdoorStore: OutdoorActivityStore
    @EnvironmentObject private var musicLibraryStore: MusicLibraryStore
    @EnvironmentObject private var outdoorPreferencesStore: OutdoorRecordingPreferencesStore
    @Environment(\.accessibilityReduceMotion) var reduceMotion
    @Environment(\.dismiss) var dismiss
    @Environment(\.everRasterizedContent) var rasterizedContent
    @Environment(\.everPageTravelActive) var pageTravelActive
    @Environment(\.collectiblePreviewItem) var collectiblePreviewItem
    @Environment(\.verificationPreviewTier) var verificationPreviewTier
    @State private var selectedActivity: OutdoorActivity?
    @State private var showingHistory = false
    @State var selectedTab: LocalProfileTab = .posts
    @State var sheet: LocalProfileSheet?
    @State var asVisitor = false
    @State var biographyExpanded = false
    @State var isChromeVisible = false
    @State var detailsHeight: CGFloat = 0
    @State var identityHeight: CGFloat = 0
    @ScaledMetric(relativeTo: .body) var compactHeight = EverLayout.minimumTouchTarget + EverSpacing.x8 + EverSpacing.x1
    @ScaledMetric(relativeTo: .body) var expandedAvatarSize = EverLayout.minimumTouchTarget * 2.4
    @ScaledMetric(relativeTo: .body) var compactAvatarSize = EverLayout.minimumTouchTarget + EverSpacing.x2
    @ScaledMetric(relativeTo: .body) var tabHeight = EverLayout.minimumTouchTarget + EverSpacing.x3

    init(
        onOpenRanked: ((RankedVariation) -> Void)? = nil,
        previewOnly: Bool = false,
        onPreviewClose: (() -> Void)? = nil
    ) {
        self.onOpenRanked = onOpenRanked
        self.previewOnly = previewOnly
        self.onPreviewClose = onPreviewClose
    }

    var profile: LocalUserProfile { profileStore.profile }
    var canSeeDetails: Bool { !asVisitor || !profile.isPrivate }
    var isProfileRoot: Bool { !previewOnly }
    var palette: StoreProfilePalette { .midnight }
    var collectibleArtworkActive: Bool { isChromeVisible && !rasterizedContent && !pageTravelActive }
    var selectedStats: [ProfileAchievementSide] {
        canSeeDetails && (!asVisitor || profile.showAchievements) ? ProfileAchievementSide.allCases : []
    }
    func collectible(_ category: CollectibleCategory) -> CollectibleItem? {
        collectiblePreviewItem?.category == category
            ? collectiblePreviewItem
            : CollectibleItem.selected(category, in: profileStore.snapshot)
    }
    var tabs: [LocalProfileTab] {
        guard asVisitor else {
            return LocalProfileTab.allCases.filter { $0 != .ranked || onOpenRanked != nil }
        }
        return profile.isPrivate ? [] : profile.visibleTabs
    }
    var activeTab: LocalProfileTab? { tabs.contains(selectedTab) ? selectedTab : tabs.first }
    var rankedVariation: RankedVariation {
        switch rankedFamily {
        case .pushUps: rankedPushUp.family == .pushUps ? rankedPushUp : .standardPushUp
        case .squats: rankedSquat.family == .squats ? rankedSquat : .standardSquat
        case .core: rankedCore.family == .core ? rankedCore : .forearmPlank
        }
    }
    var showsEarnedElo: Bool { !asVisitor && onOpenRanked != nil }
    var earnedEloBadgeHeight: CGFloat { EverLayout.minimumTouchTarget * 2.4 }

    func expandedProfileAvatar(width: CGFloat) -> CGFloat {
        min(expandedAvatarSize, max(EverLayout.minimumTouchTarget, (width - EverLayout.phoneInset * 2) / 3))
    }

    func profileCoverHeight(width: CGFloat) -> CGFloat {
        #if os(macOS)
        min(width / 3, expandedAvatarSize + EverSpacing.x4)
        #else
        width / 2
        #endif
    }

    func profileIdentityTop(width: CGFloat) -> CGFloat {
        let avatar = expandedProfileAvatar(width: width)
        #if os(macOS)
        let clearance = max(avatar / 2, showsEarnedElo ? earnedEloBadgeHeight / 2 : 0)
        #else
        let clearance = showsEarnedElo ? avatar * 0.55 + earnedEloBadgeHeight / 2 : avatar / 2
        #endif
        return profileCoverHeight(width: width) + clearance + EverSpacing.x3
    }

    func expandedProfileCore(width: CGFloat) -> CGFloat {
        #if os(macOS)
        let artworkHeight = profileCoverHeight(width: width) + expandedProfileAvatar(width: width) / 2
        #else
        let artworkHeight = EverProfileGeometry.expandedCore(coverHeight: profileCoverHeight(width: width), avatarSize: expandedProfileAvatar(width: width))
        #endif
        return max(
            artworkHeight,
            profileIdentityTop(width: width) + identityHeight + EverSpacing.x2
                + EverLayout.minimumTouchTarget + EverSpacing.x2
        )
    }
    func openRankedRating() {
        if rankedAccount.identity == nil || onOpenRanked == nil { sheet = .rankedAccount }
        else { selectedTab = .ranked }
    }

    func openProfileHistory() {
        sheet = nil
        showingHistory = true
    }

    var body: some View {
        NavigationStack {
            EverProfileScaffold(
                compactHeight: compactHeight,
                expandedHeaderHeight: { width in
                    expandedProfileCore(width: width) + detailsHeight
                },
                tabHeight: tabHeight
            ) { width, progress in
                let expandedCore = expandedProfileCore(width: width)
                collapsingChrome(
                    width: width, coverHeight: profileCoverHeight(width: width),
                    expandedCore: expandedCore, expandedHeight: expandedCore + detailsHeight,
                    progress: progress
                )
            } content: {
                VStack(alignment: .leading, spacing: EverSpacing.x4) {
                    if asVisitor { visitorNotice }
                    if profileStore.isReadOnly { storageNotice }
                    if !canSeeDetails {
                        ProfileEmptyState(symbol: "lock", title: "This profile is private", detail: "Only the name, handle and profile artwork are visible in this read-only visitor preview.")
                    } else if tabs.isEmpty {
                        ProfileEmptyState(symbol: "eye.slash", title: "No visible tabs", detail: "This profile has hidden all of its content tabs from the visitor preview.")
                    } else {
                        tabContent
                    }
                    Text("Local profile · Nothing is published online")
                        .font(TimeMasterFont.caption()).foregroundStyle(ProfileStyle.secondary)
                }
                .padding(EverLayout.phoneInset)
                .frame(maxWidth: EverLayout.maximumReadableWidth)
                .frame(maxWidth: .infinity, alignment: .top)
                .allowsHitTesting(!previewOnly)
            }
            #if os(macOS)
            .frame(maxWidth: EverLayout.maximumReadableWidth)
            .frame(maxWidth: .infinity)
            #endif
            .background(palette.background)
            .background(EverColor.background.ignoresSafeArea())
            .foregroundStyle(palette.foreground)
            .environment(\.storeProfilePalette, palette)
            .tint(palette.foreground)
            .navigationTitle("")
            #if os(iOS)
            .toolbar(.hidden, for: .navigationBar)
            #endif
            .onAppear {
                guard !rasterizedContent, !isChromeVisible else { return }
                if reduceMotion || pageTravelActive || isProfileRoot {
                    isChromeVisible = true
                } else {
                    withAnimation(.easeInOut(duration: 0.36)) { isChromeVisible = true }
                }
            }
            .task {
                guard !previewOnly, !rasterizedContent else { return }
                await rankedAccount.restore()
                if rankedAccount.identity != nil { await rankedAccount.refresh() }
            }
            .oneHandedActions(id: "profile", actions: ownerActions)
            .navigationDestination(isPresented: $showingHistory) {
                HistoryView().environmentObject(outdoorStore)
            }
            .sheet(item: $sheet) { destination in
                switch destination {
                case .edit: LocalProfileEditorView()
                case .compose: LocalPostComposerView()
                case .settings: SettingsView(isPresentedModally: true)
                case .collectibles: ProfileCollectiblesView()
                case .verification: ProfileVerificationView()
                case .report: LocalProfileReportView()
                case .rankedAccount: RankedAccountView()
                case .actions: profileActionsSheet
                }
            }
#if os(iOS)
            .fullScreenCover(
                item: Binding(
                    get: { UIDevice.current.userInterfaceIdiom == .phone ? selectedActivity : nil },
                    set: { selectedActivity = $0 }
                )
            ) { activity in
                OutdoorRouteRecordingView(
                    kind: activity.kind, store: outdoorStore,
                    preferences: outdoorPreferencesStore, musicLibrary: musicLibraryStore,
                    initialActivityID: activity.id
                )
            }
#endif
            .profileErrorAlert($profileStore.errorMessage)
            .onChange(of: asVisitor) { _ in
                selectedTab = tabs.first ?? .posts
                biographyExpanded = false
            }
        }
        .tint(.white)
    }

    @ViewBuilder
    var expandedHeaderDetails: some View {
        if let tier = verificationPreviewTier ?? profileStore.snapshot.badgePreview {
            Text("\(tier.title) checkmark · Preview only")
                .font(TimeMasterFont.caption())
                .foregroundStyle(palette.secondaryText)
        }
        if canSeeDetails {
            if !profile.location.isEmpty {
                Label(profile.location, systemImage: "mappin.and.ellipse")
                    .font(TimeMasterFont.caption()).foregroundStyle(palette.secondaryText)
            }
            HStack(alignment: .center, spacing: EverSpacing.x3) {
                biographyButton
                Spacer(minLength: 0)
                socialLinks
            }
            if biographyExpanded, !profile.biography.isEmpty {
                Text(profile.biography).font(TimeMasterFont.secondary()).textSelection(.enabled)
                    .foregroundStyle(palette.secondaryText)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var biographyButton: some View {
        Button {
            if profile.biography.isEmpty && !asVisitor { sheet = .edit }
            else {
                withAnimation(reduceMotion ? nil : .easeOut(duration: 0.18)) { biographyExpanded.toggle() }
            }
        } label: {
            HStack(spacing: 4) {
                Text(profile.biography.isEmpty ? (asVisitor ? "No bio" : "Add bio") : String(profile.biography.prefix(8)) + (profile.biography.count > 8 ? "…" : ""))
                    .font(TimeMasterFont.secondary())
                if !profile.biography.isEmpty {
                    Image(systemName: biographyExpanded ? "chevron.up" : "chevron.down").font(.caption2)
                }
            }
            .frame(minHeight: ProfileStyle.touchTarget)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(asVisitor && profile.biography.isEmpty)
        .accessibilityLabel(profile.biography.isEmpty ? "Add biography" : biographyExpanded ? "Collapse biography" : "Expand biography")
        .accessibilityIdentifier("profile-biography")
    }

    @ViewBuilder
    private var socialLinks: some View {
        if (!asVisitor || profile.showLinks), !profile.links.isEmpty {
            HStack(spacing: 0) {
                ForEach(profile.links.prefix(3)) { link in
                    if let url = URL(string: link.url), ["http", "https"].contains(url.scheme?.lowercased() ?? "") {
                        Link(destination: url) {
                            Image(systemName: link.symbol).font(.body.weight(.medium))
                                .frame(width: ProfileStyle.touchTarget, height: ProfileStyle.touchTarget)
                                .background(Theme.surface2, in: Circle()).padding(2)
                        }
                        .accessibilityLabel("Open \(link.title)")
                    }
                }
            }
        } else {
            Label("Joined \(profile.createdAt.formatted(.dateTime.month(.abbreviated).year()))", systemImage: "calendar")
                .font(TimeMasterFont.caption()).foregroundStyle(ProfileStyle.secondary)
        }
    }


    @ViewBuilder
    private var tabContent: some View {
        switch activeTab {
        case .posts: LocalPostsView(asVisitor: asVisitor)
        case .reposted: LocalPostsView(asVisitor: asVisitor, repostsOnly: true)
        case .activity: activityContent
        case .ranked:
            if let onOpenRanked { RankedProfileSection(onOpenRanked: onOpenRanked) }
        case nil: EmptyView()
        }
    }

    private var activityContent: some View {
        VStack(alignment: .leading, spacing: ProfileStyle.spacing) {
            HStack(spacing: 8) {
                totalCard("Week", activities: activities(in: Calendar.current.dateInterval(of: .weekOfYear, for: Date())))
                totalCard("Month", activities: activities(in: Calendar.current.dateInterval(of: .month, for: Date())))
                totalCard("All time", activities: outdoorStore.profileActivities)
            }
            if !asVisitor {
                Button { showingHistory = true } label: {
                    EverActionRow(title: "All Activity History", detail: "Your workouts and outdoor sessions", symbol: "clock.arrow.circlepath")
                        .modifier(TimeMasterCardSurface(flat: true))
                }
                .buttonStyle(.plain)
                if !workoutStore.historyEntries.isEmpty {
                    Text("Recent workouts").font(TimeMasterFont.heading())
                    ForEach(workoutStore.historyEntries.sorted { $0.completedAt > $1.completedAt }.prefix(10)) { entry in
                        Button { showingHistory = true } label: {
                            EverActionRow(title: entry.workoutName, detail: "\(entry.completedAt.formatted(date: .abbreviated, time: .omitted)) · \(entry.isPartial ? "Partial workout" : "Completed workout")", symbol: entry.isPartial ? "clock.badge.exclamationmark" : "checkmark.circle")
                                .modifier(TimeMasterCardSurface(flat: true))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            Text("Outdoor activity").font(TimeMasterFont.heading())
            if outdoorStore.profileActivities.isEmpty {
                ProfileEmptyState(symbol: "figure.run.circle", title: "No outdoor activities yet", detail: "Public Run, Walk, and Bike activities appear here after you establish them from the route Library.")
            } else {
                ForEach(outdoorStore.profileActivities) { activity in
                    Group {
#if os(iOS)
                        if UIDevice.current.userInterfaceIdiom == .phone && !asVisitor {
                            Button { selectedActivity = activity } label: { activityRow(activity) }.buttonStyle(.plain)
                        } else { activityRow(activity) }
#else
                        activityRow(activity)
#endif
                    }
                    .padding(ProfileStyle.inset).modifier(TimeMasterCardSurface(flat: true))
                }
            }
        }
    }

    private func totalCard(_ title: String, activities: [OutdoorActivity]) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title).font(TimeMasterFont.caption()).foregroundStyle(ProfileStyle.secondary)
            Text(activities.count.formatted()).font(TimeMasterFont.heading()).monospacedDigit()
            Text(String(format: "%.1f km", activities.reduce(0) { $0 + $1.distanceMeters } / 1000))
                .font(TimeMasterFont.caption()).foregroundStyle(ProfileStyle.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(ProfileStyle.spacing).modifier(TimeMasterCardSurface(flat: true))
    }

    private func activityRow(_ activity: OutdoorActivity) -> some View {
        HStack(spacing: ProfileStyle.spacing) {
            Image(systemName: activity.kind.iconName).frame(width: ProfileStyle.touchTarget, height: ProfileStyle.touchTarget)
                .background(Theme.surface2, in: Circle())
            VStack(alignment: .leading, spacing: 4) {
                Text(activity.title).font(TimeMasterFont.rowTitle())
                Text(activity.startedAt, style: .date).font(TimeMasterFont.caption()).foregroundStyle(ProfileStyle.secondary)
            }
            Spacer(minLength: 0)
            Text(String(format: "%.2f km", activity.distanceMeters / 1000))
                .font(TimeMasterFont.caption()).monospacedDigit().foregroundStyle(ProfileStyle.secondary)
        }
    }

    private func activities(in interval: DateInterval?) -> [OutdoorActivity] {
        guard let interval else { return [] }
        return outdoorStore.profileActivities.filter { interval.contains($0.startedAt) }
    }

    private var visitorNotice: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Read-only visitor preview").font(TimeMasterFont.rowTitle())
            Text("This shows your visibility settings, not another signed-in account.")
                .font(TimeMasterFont.caption()).foregroundStyle(ProfileStyle.secondary)
            Button("Return to my profile") { asVisitor = false }.buttonStyle(EverPrimaryButtonStyle())
        }
    }

    private var storageNotice: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Profile storage unavailable").font(TimeMasterFont.heading())
            Text("The saved file is preserved. Changes are disabled until it can be loaded.")
                .font(TimeMasterFont.secondary()).foregroundStyle(ProfileStyle.secondary)
            Button("Retry loading profile") { profileStore.reload() }.buttonStyle(EverPrimaryButtonStyle())
        }
    }


    private var ownerActions: [ReachabilityAction] {
        guard !asVisitor else { return [] }
        return [
            ReachabilityAction("history", title: "Activity History") {
                Button { showingHistory = true } label: { Image(systemName: "clock.arrow.circlepath") }
                    .buttonStyle(TimeMasterToolbarIconButtonStyle()).accessibilityLabel("All Activity History")
            },
            ReachabilityAction("post", title: "New Post") {
                Button { sheet = .compose } label: { Image(systemName: "plus") }
                    .buttonStyle(TimeMasterToolbarIconButtonStyle()).disabled(profileStore.isReadOnly)
            },
            ReachabilityAction("edit", title: "Edit Profile") {
                Button { sheet = .edit } label: { Image(systemName: "pencil") }
                    .buttonStyle(TimeMasterToolbarIconButtonStyle()).disabled(profileStore.isReadOnly)
            },
            ReachabilityAction("settings", title: "Settings") {
                Button { sheet = .settings } label: { Image(systemName: "gearshape") }
                    .buttonStyle(TimeMasterToolbarIconButtonStyle())
            }
        ]
    }
}
