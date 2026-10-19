import SwiftUI
#if os(iOS)
import UIKit
#endif

private enum LocalProfileSheet: String, Identifiable {
    case edit, compose, settings, collectibles, verification, report
    var id: String { rawValue }
}

struct ProfileView: View {
    let onOpenRanked: (RankedVariation) -> Void
    @EnvironmentObject private var profileStore: LocalProfileStore
    @EnvironmentObject private var workoutStore: WorkoutStore
    @EnvironmentObject private var outdoorStore: OutdoorActivityStore
    @EnvironmentObject private var musicLibraryStore: MusicLibraryStore
    @EnvironmentObject private var outdoorPreferencesStore: OutdoorRecordingPreferencesStore
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var selectedActivity: OutdoorActivity?
    @State private var showingHistory = false
    @State private var selectedTab: LocalProfileTab = .posts
    @State private var sheet: LocalProfileSheet?
    @State private var asVisitor = false
    @State private var biographyExpanded = false
    @ScaledMetric(relativeTo: .title) private var avatarSize: CGFloat = 88

    private var profile: LocalUserProfile { profileStore.profile }
    private var canSeeDetails: Bool { !asVisitor || !profile.isPrivate }
    private var tabs: [LocalProfileTab] {
        guard asVisitor else { return LocalProfileTab.allCases }
        return profile.isPrivate ? [] : profile.visibleTabs
    }
    private var activeTab: LocalProfileTab? { tabs.contains(selectedTab) ? selectedTab : tabs.first }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: ProfileStyle.inset) {
                    if asVisitor { visitorNotice }
                    if profileStore.isReadOnly { storageNotice }
                    header
                    if !canSeeDetails {
                        ProfileEmptyState(symbol: "lock", title: "This profile is private", detail: "Only the name, handle and profile artwork are visible in this read-only visitor preview.")
                    } else if tabs.isEmpty {
                        ProfileEmptyState(symbol: "eye.slash", title: "No visible tabs", detail: "This profile has hidden all of its content tabs from the visitor preview.")
                    } else {
                        tabBar
                        tabContent
                    }
                    Text("Local profile · Nothing is published online")
                        .font(TimeMasterFont.caption()).foregroundStyle(ProfileStyle.secondary)
                }
                .frame(maxWidth: ProfileStyle.readableWidth)
                .frame(maxWidth: .infinity)
                .padding(ProfileStyle.inset)
            }
            .background(Theme.background.ignoresSafeArea())
            .foregroundStyle(.white)
            .navigationTitle(asVisitor ? "Visitor preview" : "Profile")
#if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
#endif
            .toolbar {
                ToolbarItem(placement: .primaryAction) { profileMenu }
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

    private var header: some View {
        VStack(spacing: ProfileStyle.spacing) {
            banner
            HStack(spacing: 8) {
                achievementSide(isLeading: true)
                ProfileStyledAvatar(profile: profile, size: avatarSize)
                    .background(Theme.background, in: Circle())
                    .overlay { Circle().strokeBorder(Theme.background, lineWidth: 4).allowsHitTesting(false) }
                achievementSide(isLeading: false)
            }
            .padding(.top, -avatarSize / 2)
            .padding(.horizontal, 4)
            VStack(spacing: 4) {
                ProfileStyledName(text: profile.displayName)
                    .multilineTextAlignment(.center).accessibilityAddTraits(.isHeader)
                if canSeeDetails, !profile.location.isEmpty {
                    Label(profile.location, systemImage: "mappin.and.ellipse")
                        .font(TimeMasterFont.caption()).foregroundStyle(ProfileStyle.secondary)
                }
                Text("@\(profile.handle)").font(TimeMasterFont.secondary()).foregroundStyle(ProfileStyle.secondary)
                if asVisitor {
                    ProfileBadgePreview()
                } else if profileStore.snapshot.badgePreview != nil {
                    Button { sheet = .verification } label: { ProfileBadgePreview() }
                        .buttonStyle(.plain).frame(minHeight: ProfileStyle.touchTarget)
                }
            }
            .frame(maxWidth: .infinity)
            if !asVisitor {
                RankedProfileSummary { selectedTab = .ranked }
            }
            if canSeeDetails {
                HStack(alignment: .center, spacing: ProfileStyle.spacing) {
                    biographyButton
                    Spacer(minLength: 0)
                    socialLinks
                }
                if biographyExpanded, !profile.biography.isEmpty {
                    Text(profile.biography).font(TimeMasterFont.body()).textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    private var banner: some View {
        Rectangle().fill(Theme.surface2)
            .overlay {
                if let filename = profile.bannerFilename, let image = PhotoManager.shared.loadPhoto(filename: filename) {
                    GeometryReader { geometry in
                        platformImage(image).resizable().scaledToFill()
                            .frame(width: geometry.size.width, height: geometry.size.height).clipped()
                    }
                }
            }
            .overlay { ProfileBannerDecoration() }
            .aspectRatio(2.6, contentMode: .fit)
            .clipShape(RoundedRectangle(cornerRadius: ProfileStyle.corner, style: .continuous))
            .overlay(alignment: .topTrailing) {
                if !asVisitor {
                    HStack(spacing: 8) {
                        Button { sheet = .compose } label: {
                            Image(systemName: "plus").font(.body.weight(.semibold))
                                .frame(width: ProfileStyle.touchTarget, height: ProfileStyle.touchTarget)
                                .background(Theme.background.opacity(0.9), in: Circle())
                        }
                        .accessibilityLabel("Create post").accessibilityIdentifier("profile-create-post")
                        Button { sheet = .edit } label: {
                            Text("Edit").font(TimeMasterFont.rowTitle())
                                .padding(.horizontal, ProfileStyle.inset)
                                .frame(minHeight: ProfileStyle.touchTarget)
                                .background(Theme.background.opacity(0.9), in: Capsule())
                        }
                        .accessibilityLabel("Edit profile").accessibilityIdentifier("profile-edit")
                    }
                    .buttonStyle(TimeMasterCardButtonStyle())
                    .disabled(profileStore.isReadOnly)
                    .padding(8)
                    .oneHandedActionSource()
                }
            }
    }

    @ViewBuilder
    private func achievementSide(isLeading: Bool) -> some View {
        if canSeeDetails && (!asVisitor || profile.showAchievements) {
            ProfileAchievementStrip(isLeading: isLeading).frame(maxWidth: .infinity)
        } else {
            Color.clear.frame(maxWidth: .infinity).frame(height: ProfileStyle.touchTarget)
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

    private var tabBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(tabs) { tab in
                    Button { selectedTab = tab } label: {
                        ProfilePillLabel(title: tab.title, symbol: tab.symbol, isSelected: activeTab == tab)
                    }
                    .buttonStyle(TimeMasterCardButtonStyle())
                    .accessibilityAddTraits(activeTab == tab ? .isSelected : [])
                    .accessibilityIdentifier("profile-tab-\(tab.rawValue)")
                }
            }
        }
    }

    @ViewBuilder
    private var tabContent: some View {
        switch activeTab {
        case .posts: LocalPostsView(asVisitor: asVisitor)
        case .reposted: LocalPostsView(asVisitor: asVisitor, repostsOnly: true)
        case .activity: activityContent
        case .ranked: RankedProfileSection(onOpenRanked: onOpenRanked)
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
                    ProfileSettingsRow(icon: "clock.arrow.circlepath", title: "All Activity History", detail: "Your workouts and outdoor sessions")
                        .modifier(TimeMasterCardSurface(flat: true))
                }
                .buttonStyle(.plain)
                if !workoutStore.historyEntries.isEmpty {
                    Text("Recent workouts").font(TimeMasterFont.heading())
                    ForEach(workoutStore.historyEntries.sorted { $0.completedAt > $1.completedAt }.prefix(10)) { entry in
                        Button { showingHistory = true } label: {
                            ProfileSettingsRow(icon: entry.isPartial ? "clock.badge.exclamationmark" : "checkmark.circle", title: entry.workoutName, detail: "\(entry.completedAt.formatted(date: .abbreviated, time: .omitted)) · \(entry.isPartial ? "Partial workout" : "Completed workout")")
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
            Button("Return to my profile") { asVisitor = false }.buttonStyle(ProfilePrimaryButtonStyle())
        }
    }

    private var storageNotice: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Profile storage unavailable").font(TimeMasterFont.heading())
            Text("The saved file is preserved. Changes are disabled until it can be loaded.")
                .font(TimeMasterFont.secondary()).foregroundStyle(ProfileStyle.secondary)
            Button("Retry loading profile") { profileStore.reload() }.buttonStyle(ProfilePrimaryButtonStyle())
        }
    }

    private var profileMenu: some View {
        Menu {
            if asVisitor {
                Button("Return to my profile") { asVisitor = false }
                Button("Report profile") { sheet = .report }
            } else {
                Button("Visitor preview") { asVisitor = true }
                Button("Collectibles") { sheet = .collectibles }
                Button("Verification") { sheet = .verification }
                Button("Settings") { sheet = .settings }
                Button("All Activity History") { showingHistory = true }
            }
        } label: {
            Image(systemName: asVisitor ? "ellipsis" : "gearshape")
                .frame(width: ProfileStyle.touchTarget, height: ProfileStyle.touchTarget)
                .background(Theme.surface2, in: Circle())
        }
        .accessibilityLabel("Profile options").accessibilityIdentifier("profile-options")
        .oneHandedActionSource()
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
