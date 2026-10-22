import SwiftUI

private enum RankedLobbySheet: String, Identifiable {
    case settings, account, ranks, loadout, rules, leaderboard, history, limit
    var id: String { rawValue }
}

struct RankedView: View {
    @EnvironmentObject private var profileStore: LocalProfileStore
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.slotNavigationContentBounds) private var navigationBounds
    @AppStorage("tm.ranked.mode") private var mode: RankedMode = .duel
    @AppStorage("tm.ranked.family") private var family: RankedFamily = .pushUps
    @AppStorage("tm.ranked.pushUp") private var pushUp: RankedVariation = .standardPushUp
    @AppStorage("tm.ranked.squat") private var squat: RankedVariation = .standardSquat
    @AppStorage("tm.ranked.core") private var core: RankedVariation = .forearmPlank
    @Binding var requestedVariation: RankedVariation?
    let onOpenProfile: () -> Void
    @State private var sheet: RankedLobbySheet?
    @State private var showsBattle = false
    @ObservedObject private var account = RankedAccountStore.shared
    private let artSize = ProfileStyle.touchTarget * 1.35

    private var selection: RankedVariation {
        switch family {
        case .pushUps: pushUp.family == .pushUps ? pushUp : .standardPushUp
        case .squats: squat.family == .squats ? squat : .standardSquat
        case .core: core.family == .core ? core : .forearmPlank
        }
    }

    var body: some View {
        NavigationStack {
            GeometryReader { viewport in
                let frame = viewport.frame(in: .global)
                let contentBounds = frame.intersection(navigationBounds ?? frame)
                ViewThatFits(in: .vertical) {
                    lobby(scrolls: false)
                    ScrollView { lobby(scrolls: true) }.scrollIndicators(.hidden)
                }
                .frame(maxWidth: .infinity)
                .frame(height: max(1, contentBounds.height), alignment: .top)
            }
            .background(Theme.background.ignoresSafeArea())
            .foregroundStyle(.white)
#if os(iOS)
            .toolbar(.hidden, for: .navigationBar)
#endif
            .sheet(item: $sheet) { destination in
                switch destination {
                case .settings: SettingsView(isPresentedModally: true)
                case .account: RankedAccountView()
                case .ranks: RankedTierGalleryView()
                case .loadout: loadoutSheet
                case .rules: RankedRulesView(variation: selection)
                case .leaderboard: RankedLeaderboardView(initialVariation: selection)
                case .history: RankedMatchHistoryView(mode: mode)
                case .limit: RankedMatchLimitView(family: selection.family)
                }
            }
#if os(iOS)
            .fullScreenCover(isPresented: $showsBattle) {
                RankedMatchFlowView(variation: selection, mode: mode)
            }
#else
            .sheet(isPresented: $showsBattle) {
                RankedMatchFlowView(variation: selection, mode: mode)
                    .frame(minWidth: ProfileStyle.readableWidth, minHeight: ProfileStyle.readableWidth)
            }
#endif
            .onAppear(perform: consumeRequest)
            .onChange(of: requestedVariation) { _ in consumeRequest() }
            .task { await account.restore(); if account.identity != nil { await account.refresh() } }
        }
        .tint(Theme.toolbarOrange)
    }

    private func lobby(scrolls: Bool) -> some View {
        VStack(spacing: ProfileStyle.spacing) {
            identityBar
            fighterStage
                .frame(minHeight: artSize * 3.5, maxHeight: scrolls ? nil : .infinity)
            battleDock
        }
        .padding(ProfileStyle.inset)
        .frame(maxWidth: ProfileStyle.readableWidth, maxHeight: scrolls ? nil : .infinity)
        .frame(maxWidth: .infinity)
        .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
    }

    private var identityBar: some View {
        HStack(spacing: ProfileStyle.spacing) {
            Button(action: onOpenProfile) {
                HStack(spacing: EverSpacing.x2) {
                    ProfileStyledAvatar(profile: profileStore.profile, size: ProfileStyle.touchTarget)
                    VStack(alignment: .leading, spacing: EverSpacing.x1) {
                        Text(account.rating(for: selection).map { "\($0.rating.formatted()) Elo" } ?? "— Elo")
                            .font(TimeMasterFont.rowTitle().monospacedDigit())
                            .foregroundStyle(Theme.toolbarOrange)
                            .accessibilityLabel("\(selection.fullTitle) earned Elo")
                            .accessibilityValue(account.rating(for: selection)?.label ?? "No earned rating")
                            .accessibilityIdentifier("ranked-identity-elo")
                        Text(account.identity?.displayName ?? profileStore.profile.displayName)
                            .font(TimeMasterFont.caption())
                            .accessibilityIdentifier("ranked-identity-username")
                    }
                    .lineLimit(1)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(TimeMasterCardButtonStyle())
            .accessibilityLabel("Open \(account.identity?.displayName ?? profileStore.profile.displayName)'s profile")
            .accessibilityIdentifier("ranked-profile")
            Spacer(minLength: 0)
            RankedIconAction(symbol: account.identity == nil ? "person.badge.key" : account.stale ? "wifi.exclamationmark" : "person.crop.circle.badge.checkmark", label: account.identity == nil ? "Sign in" : "Account", id: "ranked-account-entry") { sheet = .account }
                .accessibilityValue(account.identity == nil ? "Signed out" : account.stale ? "Reconnecting" : "Connected")
            RankedIconAction(symbol: "gearshape", label: "Settings", id: "ranked-settings") { sheet = .settings }
        }
    }

    private var fighterStage: some View {
        GeometryReader { geometry in
            ZStack {
                if mode == .duel {
                    Text("1V1")
                        .font(TimeMasterFont.black(geometry.size.width * 0.38))
                        .foregroundStyle(.white.opacity(0.035))
                        .rotationEffect(.degrees(-12))
                        .offset(y: -geometry.size.height * 0.12)
                        .accessibilityHidden(true)
                }
                Capsule()
                    .fill(Theme.toolbarOrange.opacity(0.10))
                    .frame(width: geometry.size.width * 0.36, height: geometry.size.height * 0.78)
                    .rotationEffect(.degrees(22))
                Ellipse()
                    .fill(.white.opacity(0.07))
                    .frame(width: geometry.size.width * 0.62, height: geometry.size.height * 0.10)
                    .offset(y: geometry.size.height * 0.37)
                Image("RankedHero").resizable().scaledToFit()
                    .padding(.top, artSize * 0.5)
                    .padding(.bottom, ProfileStyle.spacing)
                    .frame(width: geometry.size.width, height: geometry.size.height)
                    .accessibilityHidden(true)
                VStack {
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: EverSpacing.x1) {
                            Text("Round").font(TimeMasterFont.caption()).foregroundStyle(ProfileStyle.secondary)
                            RankedMetric(value: "60", unit: "s")
                        }
                        Spacer(minLength: ProfileStyle.spacing)
                        Button { sheet = .ranks } label: {
                            VStack(spacing: EverSpacing.x1) {
                                RankedEloBadge(variation: selection, elo: account.rating(for: selection)?.rating)
                                    .frame(width: artSize * 1.65, height: artSize * 1.65)
                                Text("Movement rank")
                                    .font(TimeMasterFont.black(12, relativeTo: .caption))
                            }
                        }
                        .buttonStyle(TimeMasterCardButtonStyle())
                        .accessibilityLabel("View \(selection.fullTitle) ranks")
                        .accessibilityValue(account.rating(for: selection)?.label ?? "No earned rating")
                        .accessibilityIdentifier("ranked-ranks")
                    }
                    Spacer(minLength: 0)
                }
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
        }
    }

    private var battleDock: some View {
        VStack(spacing: ProfileStyle.spacing) {
            Button { sheet = .loadout } label: {
                HStack(spacing: ProfileStyle.spacing) {
                    RankedMovementArt(variation: selection)
                        .frame(width: artSize, height: artSize)
                    VStack(alignment: .leading, spacing: EverSpacing.x1) {
                        Text(selection.fullTitle).font(TimeMasterFont.rowTitle())
                        Label(mode.title, systemImage: mode.symbol)
                            .font(TimeMasterFont.caption())
                            .foregroundStyle(.black)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    VStack(spacing: EverSpacing.x1) {
                        Image(systemName: "slider.horizontal.3").font(.title3.weight(.semibold))
                        Text("Change").font(TimeMasterFont.micro())
                    }
                }
                .padding(ProfileStyle.spacing)
            }
            .buttonStyle(TimeMasterToolbarWideButtonStyle())
            .accessibilityLabel("Change battle mode and movement")
            .accessibilityValue("\(mode.title), \(selection.fullTitle)")
            .accessibilityIdentifier("ranked-loadout")
            HStack(spacing: ProfileStyle.spacing) {
                RankedIconAction(symbol: "list.bullet.clipboard", label: "Rules", id: "ranked-rules") { sheet = .rules }
                    .frame(maxWidth: .infinity)
                RankedIconAction(symbol: "list.number", label: "Leaderboard", id: "ranked-leaderboard") { sheet = .leaderboard }
                    .frame(maxWidth: .infinity)
                RankedIconAction(symbol: "clock.arrow.circlepath", label: "History", id: "ranked-history") { sheet = .history }
                    .frame(maxWidth: .infinity)
                Button { sheet = .limit } label: {
                    VStack(spacing: EverSpacing.x1) {
                        HStack(spacing: EverSpacing.x1) {
                            Image(systemName: "hourglass").font(.caption)
                            Text(selection.family == .core ? "∞" : account.allowance(for: selection.family)?.remaining.map { "\($0)/10" } ?? "—/10")
                                .font(TimeMasterFont.black(12, relativeTo: .caption).monospacedDigit())
                        }
                        Text("Matches").font(TimeMasterFont.micro())
                            .lineLimit(nil)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .buttonStyle(TimeMasterToolbarWideButtonStyle())
                .accessibilityLabel("Competitive match allowance")
                .accessibilityValue(selection.family == .core ? "No family limit" : account.allowance(for: selection.family)?.remaining.map { "\($0) of 10 remaining" } ?? "Sign in to load")
                .accessibilityIdentifier("ranked-allowance")
            }
            Button {
                if mode == .duel && account.identity == nil { sheet = .account }
                else if mode == .duel && account.allowance(for: selection.family)?.remaining == 0 { sheet = .limit }
                else {
                    if mode == .duel, let active = account.recoveryMatch { select(active.variation) }
                    showsBattle = true
                }
            } label: {
                Label(mode == .practice ? "Enter Practice" : account.recoveryMatch != nil ? "Resume match" : account.identity == nil ? "Sign in to compete" : "Find a match",
                      systemImage: mode == .duel ? account.recoveryMatch == nil ? "bolt.fill" : "arrow.clockwise" : "play.fill")
                    .font(TimeMasterFont.label())
                    .frame(maxWidth: .infinity, minHeight: ProfileStyle.touchTarget)
            }
            .buttonStyle(TimeMasterToolbarWideButtonStyle())
            .accessibilityLabel(mode == .duel ? account.recoveryMatch == nil ? "Enter online Ranked" : "Resume match" : "Enter camera-tracked Practice")
            .accessibilityIdentifier("ranked-battle")
        }
    }

    private var modePicker: some View {
        HStack(spacing: ProfileStyle.spacing) {
            ForEach(RankedMode.allCases) { option in
                Button {
                    withAnimation(reduceMotion ? nil : .easeOut(duration: 0.16)) { mode = option }
                } label: {
                    VStack(spacing: EverSpacing.x1) {
                        Image(option.assetName).resizable().scaledToFit()
                            .aspectRatio(1.5, contentMode: .fit)
                        Text(option.title).font(TimeMasterFont.rowTitle())
                        Text(option == .duel ? "Online · Earn Elo" : "Solo · No Elo")
                            .font(TimeMasterFont.caption())
                            .foregroundStyle(mode == option ? .black : ProfileStyle.secondary)
                    }
                    .padding(EverSpacing.x2)
                    .frame(maxWidth: .infinity)
                    .overlay(alignment: .topTrailing) {
                        if mode == option {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.white).padding(EverSpacing.x2)
                        }
                    }
                }
                .buttonStyle(TimeMasterSelectionButtonStyle(isSelected: mode == option))
                .accessibilityLabel(option.title)
                .accessibilityValue(option == .duel ? "Online competition" : "Solo camera-tracked Practice")
                .accessibilityAddTraits(mode == option ? .isSelected : [])
                .accessibilityIdentifier("ranked-mode-\(option.rawValue)")
            }
        }
        .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
    }

    private var loadoutSheet: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: ProfileStyle.inset) {
                    TimeMasterPageTitle("Mode & movement", size: 26, relativeTo: .title3)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    modePicker
                    RankedFamilyPicker(family: $family)
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: ProfileStyle.touchTarget * 3))], spacing: ProfileStyle.spacing) {
                        ForEach(family.variations) { variation in
                            RankedMovementTile(variation: variation, elo: account.rating(for: variation)?.rating, mode: mode, isSelected: selection == variation) {
                                select(variation)
                            }
                        }
                    }
                }
                .animation(nil, value: family)
                .padding(ProfileStyle.inset)
                .frame(maxWidth: ProfileStyle.readableWidth).frame(maxWidth: .infinity)
            }
            .background(Theme.background.ignoresSafeArea())
            .scrollIndicators(.hidden)
            .foregroundStyle(.white)
            .toolbar {
                AppToolbar.item(placement: .confirmationAction) {
                    Button { sheet = nil } label: {
                        Label("Done", systemImage: "checkmark").font(TimeMasterFont.rowTitle())
                            .labelStyle(.titleAndIcon)
                    }
                    .accessibilityIdentifier("ranked-loadout-done")
                }
            }
        }
        .tint(Theme.toolbarOrange)
    }

    private func select(_ variation: RankedVariation) {
        family = variation.family
        switch family {
        case .pushUps: pushUp = variation
        case .squats: squat = variation
        case .core: core = variation
        }
    }

    private func consumeRequest() {
        guard let variation = requestedVariation else { return }
        select(variation)
        requestedVariation = nil
    }
}
