import SwiftUI

struct RankedLeaderboardView: View {
    @ObservedObject private var account = RankedAccountStore.shared
    @State private var variation: RankedVariation
    @State private var rows: [RankedStanding] = []
    @State private var me: RankedStanding?
    @State private var cursor: String?
    @State private var loading = false
    @State private var error: String?
    @State private var selectedPlayer: RankedStanding?
    @State private var showsAccount = false
    @State private var requestVersion = 0

    init(initialVariation: RankedVariation) { _variation = State(initialValue: initialVariation) }

    var body: some View {
        NavigationStack {
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: ProfileStyle.inset) {
                        TimeMasterPageTitle("Leaderboard", size: 26, relativeTo: .title3)
                        HStack {
                            RankedMovementPicker(variation: $variation)
                            Spacer()
                            RankedIconAction(symbol: "arrow.clockwise", label: "Refresh standings", id: "ranked-standings-refresh") { Task { await load() } }
                                .disabled(loading || account.identity == nil)
                            RankedIconAction(symbol: "person.badge.key", label: "Ranked account", id: "ranked-standings-account") { showsAccount = true }
                        }
                        if account.identity == nil {
                            RankedInfoButton(label: "Sign in for standings", message: "Each exact movement has a separate earned rating. Sign in to load real standings; local display values are never used.", symbol: "person.crop.circle")
                        } else {
                            if let me {
                                Button {
                                    Task {
                                        await load(aroundMe: true)
                                        withAnimation { proxy.scrollTo(me.publicID, anchor: .center) }
                                    }
                                } label: {
                                    HStack {
                                        Image(systemName: "scope")
                                        Text("Your position · #\(me.position)").font(TimeMasterFont.rowTitle()).monospacedDigit()
                                    }
                                }
                                .buttonStyle(TimeMasterToolbarWideButtonStyle()).disabled(loading)
                                .accessibilityLabel("Jump to my position, \(me.position)")
                                .accessibilityIdentifier("ranked-my-position")
                            } else {
                                RankedInfoButton(label: "No public placement", message: account.identity?.listed == false ? "Your account is not listed publicly. Manage visibility in Ranked account." : "Complete a verified match to earn this movement's rating.", symbol: "person.crop.circle.badge.questionmark")
                            }
                            if rows.isEmpty && !loading && error == nil {
                                RankedInfoButton(label: "No competitors yet", message: "Verified public ratings for this exact movement will appear here.", symbol: "list.number")
                            }
                            LazyVStack(spacing: ProfileStyle.spacing) {
                                ForEach(rows) { row in
                                    Button { selectedPlayer = row } label: {
                                        HStack(spacing: ProfileStyle.spacing) {
                                            Text("#\(row.position)").font(TimeMasterFont.rowTitle().monospacedDigit())
                                            VStack(alignment: .leading, spacing: EverSpacing.x1) {
                                                Text(row.displayName).font(TimeMasterFont.rowTitle()).lineLimit(1)
                                                if row.games < 5 {
                                                    Label("Placement \(row.games)/5", systemImage: "flag.checkered")
                                                        .font(TimeMasterFont.caption()).foregroundStyle(ProfileStyle.secondary)
                                                }
                                                if row.publicID == account.identity?.publicID {
                                                    Text("You").font(TimeMasterFont.micro()).foregroundStyle(Theme.toolbarOrange)
                                                }
                                            }
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                            RankedEloBadge(variation: variation, elo: row.rating)
                                                .frame(width: ProfileStyle.touchTarget * 1.75, height: ProfileStyle.touchTarget * 1.75)
                                        }
                                        .padding(ProfileStyle.spacing).modifier(TimeMasterCardSurface(flat: true)).contentShape(Rectangle())
                                    }
                                    .buttonStyle(TimeMasterCardButtonStyle()).id(row.publicID)
                                    .accessibilityElement(children: .ignore)
                                    .accessibilityLabel("\(row.displayName), position \(row.position)")
                                    .accessibilityValue("\(row.rating) Elo, \(row.games) rated matches")
                                    .accessibilityIdentifier("ranked-standing-\(row.publicID)")
                                }
                            }
                            if cursor != nil {
                                RankedIconAction(symbol: "chevron.down", label: "Load more standings", id: "ranked-standings-more") { Task { await load(more: true) } }
                                    .disabled(loading)
                            }
                        }
                        if loading { TmaxLoadingIndicator().frame(maxWidth: .infinity) }
                        if let error { RankedServiceNotice(message: (rows.isEmpty ? "" : "Last fetched standings · ") + error, retry: { Task { await load() } }) }
                    }
                    .padding(ProfileStyle.inset).frame(maxWidth: ProfileStyle.readableWidth).frame(maxWidth: .infinity)
                }.scrollIndicators(.hidden).background(Theme.background.ignoresSafeArea())
            }
            .foregroundStyle(.white)
            .toolbar { AppToolbar.iconItem(placement: .confirmationAction) { RankedCloseButton() } }
            .sheet(item: $selectedPlayer) { RankedPublicPlayerView(publicID: $0.publicID) }
            .sheet(isPresented: $showsAccount) { RankedAccountView() }
            .task(id: variation.rawValue + (account.identity?.publicID ?? "")) {
                requestVersion += 1
                rows = []; me = nil; cursor = nil; error = nil; loading = false
                await account.restore()
                if account.identity != nil { await load() }
            }
        }.tint(Theme.toolbarOrange)
    }

    private func load(more: Bool = false, aroundMe: Bool = false) async {
        guard !loading else { return }
        let version = requestVersion
        loading = true
        defer { if version == requestVersion { loading = false } }
        do {
            let page = try await account.leaderboard(variation, cursor: more ? cursor : nil, aroundMe: aroundMe)
            guard version == requestVersion, !Task.isCancelled else { return }
            if more {
                let ids = Set(rows.map(\.publicID))
                rows += page.rows.filter { !ids.contains($0.publicID) }
            } else { rows = page.rows }
            me = page.me
            cursor = page.nextCursor
            error = nil
        } catch { if version == requestVersion { self.error = error.localizedDescription } }
    }
}

struct RankedPublicPlayerView: View {
    let publicID: String
    @ObservedObject private var account = RankedAccountStore.shared
    @State private var player: RankedPublicPlayer?
    @State private var error: String?
    @State private var selectedVariation: RankedVariation?
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: ProfileStyle.inset) {
                    if let player {
                        HStack {
                            Label(player.displayName, systemImage: "person.crop.circle.fill").font(TimeMasterFont.title())
                            Spacer()
                            RankedInfoButton(label: "Public player", message: "Only the public competitive alias and earned exercise ratings are shared here. Private profiles, posts, account identifiers and camera images are never exposed.", symbol: "lock.shield")
                        }
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: ProfileStyle.touchTarget * 3))], spacing: ProfileStyle.spacing) {
                            ForEach(player.ratings) { rating in
                                RankedRatingTile(variation: rating.variation, rating: rating) { selectedVariation = rating.variation }
                            }
                        }
                    } else if error == nil {
                        TmaxLoadingState(title: "Loading player…")
                            .allowsHitTesting(false)
                    }
                    if let error { RankedServiceNotice(message: error) }
                }
                .padding(ProfileStyle.inset).frame(maxWidth: ProfileStyle.readableWidth).frame(maxWidth: .infinity)
            }
            .background(Theme.background.ignoresSafeArea()).foregroundStyle(.white)
            .toolbar { AppToolbar.iconItem(placement: .confirmationAction) { RankedCloseButton() } }
            .sheet(item: $selectedVariation) { RankedLeaderboardView(initialVariation: $0) }
            .task(id: publicID + (account.identity?.publicID ?? "")) {
                player = nil
                error = nil
                do { player = try await account.api.request("v1/players/\(publicID)") }
                catch { self.error = error.localizedDescription }
            }
        }.tint(Theme.toolbarOrange)
    }
}
