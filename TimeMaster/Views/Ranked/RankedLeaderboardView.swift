import SwiftUI

struct RankedLeaderboardView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var profileStore: LocalProfileStore
    @State private var variation: RankedVariation
    @State private var showsPreview = false
    @State private var selectedOpponent: RankedExampleStanding?

    init(initialVariation: RankedVariation) {
        _variation = State(initialValue: initialVariation)
    }

    var body: some View {
        NavigationStack {
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: ProfileStyle.inset) {
                        variationPicker
                        localLevel
                        ProfileEmptyState(symbol: "network.slash", title: "No online standings", detail: "Online rankings are not connected. There is no live position or competitive Elo for this movement.")
                        Toggle(isOn: $showsPreview) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Preview standings").font(TimeMasterFont.rowTitle())
                                Text("Show an illustrative layout, not real players or ratings.")
                                    .font(TimeMasterFont.caption()).foregroundStyle(ProfileStyle.secondary)
                            }
                            .fixedSize(horizontal: false, vertical: true)
                        }
                        .padding(ProfileStyle.inset)
                        .modifier(TimeMasterCardSurface(flat: true))
                        .accessibilityIdentifier("ranked-leaderboard-preview")
                        if showsPreview {
                            VStack(alignment: .leading, spacing: ProfileStyle.spacing) {
                                Label("Example standings · No live rankings", systemImage: "eye")
                                    .font(TimeMasterFont.rowTitle())
                                    .foregroundStyle(Theme.toolbarOrange)
                                    .accessibilityAddTraits(.isHeader)
                                Text("\(variation.fullTitle) only. All positions and Elo below are invented for this preview, including your example position. Your local profile levels are unchanged.")
                                    .font(TimeMasterFont.secondary()).foregroundStyle(ProfileStyle.secondary)
                                Button {
                                    proxy.scrollTo("ranked-example-you", anchor: .center)
                                } label: {
                                    Label("Jump to my example position", systemImage: "arrow.down.to.line")
                                        .frame(maxWidth: .infinity, minHeight: ProfileStyle.touchTarget)
                                }
                                .buttonStyle(TimeMasterSelectionButtonStyle(isSelected: false))
                                .accessibilityIdentifier("ranked-leaderboard-jump")
                            }
                            .fixedSize(horizontal: false, vertical: true)
                            VStack(spacing: 0) {
                                ForEach(RankedExampleStanding.rows) { standing in
                                    if standing.isYou {
                                        standingRow(standing)
                                            .id("ranked-example-you")
                                    } else {
                                        Button { selectedOpponent = standing } label: {
                                            standingRow(standing)
                                        }
                                        .buttonStyle(TimeMasterCardButtonStyle())
                                        .accessibilityHint("Opens an example public profile, not a real user")
                                    }
                                    if standing.id != RankedExampleStanding.rows.last?.id {
                                        Divider().overlay(Theme.surface2).padding(.horizontal, ProfileStyle.inset)
                                    }
                                }
                            }
                            .modifier(TimeMasterCardSurface(flat: true))
                        }
                    }
                    .padding(ProfileStyle.inset)
                    .frame(maxWidth: ProfileStyle.readableWidth)
                    .frame(maxWidth: .infinity)
                }
                .scrollIndicators(.hidden)
                .background(Theme.background.ignoresSafeArea())
            }
            .safeAreaInset(edge: .bottom, spacing: 0) {
                if showsPreview {
                    Label("Example standings · No live rankings", systemImage: "eye")
                        .font(TimeMasterFont.caption())
                        .foregroundStyle(Theme.toolbarOrange)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(ProfileStyle.inset)
                        .frame(maxWidth: .infinity)
                        .background(Theme.background)
                }
            }
            .foregroundStyle(.white)
            .navigationTitle("Leaderboard")
#if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
#endif
            .toolbar {
                AppToolbar.item(placement: .cancellationAction) { Button("Close") { dismiss() } }
            }
            .sheet(item: $selectedOpponent) { opponent in
                RankedExampleOpponentView(opponent: opponent, variation: variation)
            }
        }
        .tint(Theme.toolbarOrange)
    }

    private var variationPicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("EXACT MOVEMENT").font(TimeMasterFont.caption()).foregroundStyle(ProfileStyle.secondary)
            Picker("Movement", selection: $variation) {
                ForEach(RankedFamily.allCases) { family in
                    SwiftUI.Section(family.title) {
                        ForEach(family.variations) { item in
                            Text(item.fullTitle).tag(item)
                        }
                    }
                }
            }
            .pickerStyle(.menu)
            .frame(maxWidth: .infinity, minHeight: ProfileStyle.touchTarget, alignment: .leading)
            .accessibilityIdentifier("ranked-leaderboard-variation")
            Text(variation.fullTitle).font(TimeMasterFont.heading())
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)
            Text("Every variation has its own standings. Rep movements and timed holds are never combined.")
                .font(TimeMasterFont.secondary()).foregroundStyle(ProfileStyle.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var localLevel: some View {
        HStack(alignment: .top, spacing: ProfileStyle.spacing) {
            RankedBadgeView(elo: profileStore.rankedLevels[variation]).accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 4) {
                Text("Your local profile level").font(TimeMasterFont.rowTitle())
                Text(profileStore.rankedLevels[variation].map { "\($0.formatted()) Elo · Editable display value" } ?? "Unplaced · No local level selected")
                    .font(TimeMasterFont.secondary().monospacedDigit())
                    .foregroundStyle(ProfileStyle.secondary)
                Text("Not a leaderboard position or earned rating.")
                    .font(TimeMasterFont.caption()).foregroundStyle(ProfileStyle.secondary)
            }
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(ProfileStyle.inset)
        .modifier(TimeMasterCardSurface(flat: true))
        .accessibilityElement(children: .combine)
    }

    private func standingRow(_ standing: RankedExampleStanding) -> some View {
        HStack(alignment: .top, spacing: ProfileStyle.spacing) {
            Text("#\(standing.id)")
                .font(TimeMasterFont.rowTitle().monospacedDigit())
                .foregroundStyle(standing.isYou ? Theme.toolbarOrange : ProfileStyle.secondary)
                .frame(minWidth: 30, minHeight: ProfileStyle.touchTarget, alignment: .center)
            VStack(alignment: .leading, spacing: 5) {
                Text(standing.isYou ? profileStore.profile.displayName : standing.name)
                    .font(TimeMasterFont.rowTitle())
                if standing.isYou {
                    Label("You · Example position", systemImage: "person.crop.circle.fill")
                        .font(TimeMasterFont.caption()).foregroundStyle(Theme.toolbarOrange)
                } else {
                    Text("Example public player").font(TimeMasterFont.caption()).foregroundStyle(ProfileStyle.secondary)
                }
                Text("\(standing.elo.formatted()) example Elo")
                    .font(TimeMasterFont.secondary().monospacedDigit()).foregroundStyle(ProfileStyle.secondary)
            }
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
            if !standing.isYou {
                Image(systemName: "chevron.right").font(.caption).foregroundStyle(ProfileStyle.secondary)
                    .padding(.top, ProfileStyle.spacing).accessibilityHidden(true)
            }
        }
        .padding(ProfileStyle.inset)
        .frame(maxWidth: .infinity, minHeight: ProfileStyle.touchTarget, alignment: .leading)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }
}

private struct RankedExampleStanding: Identifiable {
    let id: Int
    let name: String
    let elo: Int
    var isYou: Bool = false

    static let rows: [Self] = [
        .init(id: 1, name: "Alex", elo: 2_240),
        .init(id: 2, name: "Jordan", elo: 1_960),
        .init(id: 3, name: "Sam", elo: 1_720),
        .init(id: 4, name: "Taylor", elo: 1_480),
        .init(id: 5, name: "You", elo: 1_260, isYou: true),
        .init(id: 6, name: "Morgan", elo: 1_080)
    ]
}

private struct RankedExampleOpponentView: View {
    let opponent: RankedExampleStanding
    let variation: RankedVariation
    @Environment(\.dismiss) private var dismiss
    @State private var showsRules = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: ProfileStyle.inset) {
                    Label("Example public profile", systemImage: "eye")
                        .font(TimeMasterFont.rowTitle()).foregroundStyle(Theme.toolbarOrange)
                    VStack(alignment: .leading, spacing: ProfileStyle.spacing) {
                        Image(systemName: "person.crop.circle.fill").font(.largeTitle)
                            .foregroundStyle(ProfileStyle.secondary).accessibilityHidden(true)
                        Text(opponent.name).font(TimeMasterFont.title())
                            .accessibilityAddTraits(.isHeader)
                        Text("Illustrative opponent · Not a real account")
                            .font(TimeMasterFont.secondary()).foregroundStyle(ProfileStyle.secondary)
                        Divider().overlay(Theme.surface2)
                        Text(variation.fullTitle).font(TimeMasterFont.heading())
                        Text("#\(opponent.id) · \(opponent.elo.formatted()) example Elo")
                            .font(TimeMasterFont.body().monospacedDigit())
                        Text("A sample public identity for this movement’s standings layout. No real player information, verified result or competitive history is available.")
                            .font(TimeMasterFont.secondary()).foregroundStyle(ProfileStyle.secondary)
                    }
                    .padding(ProfileStyle.inset)
                    .modifier(TimeMasterCardSurface(flat: true))
                    RankedMovementArt(variation: variation)
                        .frame(height: 160).frame(maxWidth: .infinity)
                    Button { showsRules = true } label: {
                        Label("View movement rules", systemImage: "list.bullet.clipboard")
                            .frame(maxWidth: .infinity, minHeight: ProfileStyle.touchTarget)
                    }
                    .buttonStyle(TimeMasterToolbarWideButtonStyle())
                }
                .fixedSize(horizontal: false, vertical: true)
                .padding(ProfileStyle.inset)
                .frame(maxWidth: ProfileStyle.readableWidth)
                .frame(maxWidth: .infinity)
            }
            .scrollIndicators(.hidden)
            .background(Theme.background.ignoresSafeArea())
            .foregroundStyle(.white)
            .navigationTitle("Example opponent")
#if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
#endif
            .toolbar {
                AppToolbar.item(placement: .cancellationAction) { Button("Close") { dismiss() } }
            }
            .sheet(isPresented: $showsRules) { RankedRulesView(variation: variation) }
        }
        .tint(Theme.toolbarOrange)
    }
}
