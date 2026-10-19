import SwiftUI

struct RankedLeaderboardView: View {
    @Environment(\.dismiss) private var dismiss
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
                        Picker("Exact movement", selection: $variation) {
                            ForEach(RankedFamily.allCases) { family in
                                SwiftUI.Section(family.title) { ForEach(family.variations) { Text($0.fullTitle).tag($0) } }
                            }
                        }.pickerStyle(.menu).frame(minHeight: ProfileStyle.touchTarget)
                        Text(variation.fullTitle).font(TimeMasterFont.title()).accessibilityAddTraits(.isHeader)
                        if account.identity == nil {
                            ProfileEmptyState(symbol: "person.crop.circle", title: "Sign in for standings", detail: "Each exact movement has its own earned rating. Local profile display values are never used.")
                            Button("Ranked account") { showsAccount = true }.buttonStyle(TimeMasterToolbarWideButtonStyle())
                        } else {
                            if let me {
                                Button {
                                    Task {
                                        await load(aroundMe: true)
                                        withAnimation { proxy.scrollTo(me.publicID, anchor: .center) }
                                    }
                                } label: { Label("My position · #\(me.position)", systemImage: "scope") }
                                    .buttonStyle(TimeMasterToolbarWideButtonStyle()).disabled(loading)
                            } else {
                                Text(account.identity?.listed == false ? "Your account is not listed publicly. Manage visibility in Ranked account." : "Unplaced · Complete a verified match to earn this movement's rating.")
                                    .font(TimeMasterFont.secondary()).foregroundStyle(ProfileStyle.secondary)
                            }
                            if rows.isEmpty && !loading && error == nil {
                                ProfileEmptyState(symbol: "list.number", title: "No competitors yet", detail: "Verified public ratings for this exact movement will appear here.")
                            }
                            LazyVStack(spacing: ProfileStyle.spacing) {
                                ForEach(rows) { row in
                                    Button { selectedPlayer = row } label: {
                                        HStack(spacing: ProfileStyle.spacing) {
                                            Text("#\(row.position)").font(TimeMasterFont.rowTitle().monospacedDigit())
                                            VStack(alignment: .leading, spacing: 4) {
                                                Text(row.publicID == account.identity?.publicID ? "\(row.displayName) · You" : row.displayName).font(TimeMasterFont.rowTitle())
                                                Text("\(row.rating.formatted()) Elo" + (row.games < 5 ? " · Placement \(row.games)/5" : ""))
                                                    .font(TimeMasterFont.caption()).foregroundStyle(ProfileStyle.secondary)
                                            }.frame(maxWidth: .infinity, alignment: .leading)
                                            RankedBadgeView(elo: row.rating)
                                            Image(systemName: "chevron.right").font(.caption).foregroundStyle(ProfileStyle.secondary)
                                        }
                                        .padding(ProfileStyle.inset).modifier(TimeMasterCardSurface(flat: true)).contentShape(Rectangle())
                                    }
                                    .buttonStyle(TimeMasterCardButtonStyle()).id(row.publicID)
                                    .accessibilityElement(children: .combine)
                                }
                            }
                            if cursor != nil {
                                Button("Load more") { Task { await load(more: true) } }.buttonStyle(TimeMasterToolbarWideButtonStyle()).disabled(loading)
                            }
                            Button("Refresh standings") { Task { await load() } }.buttonStyle(TimeMasterToolbarWideButtonStyle()).disabled(loading)
                        }
                        if loading { ProgressView().frame(maxWidth: .infinity) }
                        if let error { RankedServiceNotice(message: (rows.isEmpty ? "" : "Last fetched standings · ") + error, retry: { Task { await load() } }) }
                    }
                    .padding(ProfileStyle.inset).frame(maxWidth: ProfileStyle.readableWidth).frame(maxWidth: .infinity)
                }.scrollIndicators(.hidden).background(Theme.background.ignoresSafeArea())
            }
            .foregroundStyle(.white).navigationTitle("Leaderboard")
            .toolbar { AppToolbar.item(placement: .confirmationAction) { Button("Close") { dismiss() } } }
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
    @Environment(\.dismiss) private var dismiss
    @State private var player: RankedPublicPlayer?
    @State private var error: String?
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: ProfileStyle.inset) {
                    if let player {
                        Label(player.displayName, systemImage: "person.crop.circle.fill").font(TimeMasterFont.title())
                        Text("Public competitive identity only").font(TimeMasterFont.caption()).foregroundStyle(ProfileStyle.secondary)
                        ForEach(player.ratings) { rating in
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(rating.variation.fullTitle).font(TimeMasterFont.rowTitle())
                                    Text(rating.label).font(TimeMasterFont.caption()).foregroundStyle(ProfileStyle.secondary)
                                }
                                Spacer()
                                RankedBadgeView(elo: rating.rating)
                            }.padding(ProfileStyle.inset).modifier(TimeMasterCardSurface(flat: true))
                        }
                    } else if error == nil { ProgressView() }
                    if let error { RankedServiceNotice(message: error) }
                }
                .padding(ProfileStyle.inset).frame(maxWidth: ProfileStyle.readableWidth).frame(maxWidth: .infinity)
            }
            .background(Theme.background.ignoresSafeArea()).foregroundStyle(.white).navigationTitle("Player")
            .toolbar { AppToolbar.item(placement: .confirmationAction) { Button("Close") { dismiss() } } }
            .task(id: publicID + (account.identity?.publicID ?? "")) {
                player = nil
                do { player = try await account.api.request("v1/players/\(publicID)") }
                catch { self.error = error.localizedDescription }
            }
        }.tint(Theme.toolbarOrange)
    }
}
