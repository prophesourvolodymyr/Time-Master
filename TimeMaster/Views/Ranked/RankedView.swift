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
    @ScaledMetric(relativeTo: .body) private var tileWidth: CGFloat = 144
    @ScaledMetric(relativeTo: .title) private var badgeSize: CGFloat = 56

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
                    ScrollView { lobby(scrolls: true) }
                        .scrollIndicators(.hidden)
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
                .frame(minHeight: badgeSize * 4, maxHeight: scrolls ? nil : .infinity)
            battleDock
        }
        .padding(ProfileStyle.inset)
        .frame(maxWidth: ProfileStyle.readableWidth, maxHeight: scrolls ? nil : .infinity)
        .frame(maxWidth: .infinity)
    }

    private var identityBar: some View {
        HStack(spacing: ProfileStyle.spacing) {
            Button(action: onOpenProfile) {
                HStack(spacing: 8) {
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
            .layoutPriority(1)
            .accessibilityLabel("Open \(account.identity?.displayName ?? profileStore.profile.displayName)'s profile")
            .accessibilityIdentifier("ranked-profile")
            Spacer(minLength: 0)
            Button { sheet = .settings } label: {
                Label("Settings", systemImage: "gearshape.fill").labelStyle(.iconOnly)
            }
            .buttonStyle(TimeMasterToolbarIconButtonStyle())
            .accessibilityIdentifier("ranked-settings")
        }
    }

    private var modePicker: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: tileWidth), spacing: ProfileStyle.spacing)], spacing: ProfileStyle.spacing) {
            ForEach(RankedMode.allCases) { option in
                Button {
                    withAnimation(reduceMotion ? nil : .easeOut(duration: 0.16)) { mode = option }
                } label: {
                    VStack(alignment: .leading, spacing: 8) {
                        Image(option.assetName).resizable().scaledToFit()
                            .clipShape(RoundedRectangle(cornerRadius: ProfileStyle.spacing, style: .continuous))
                            .accessibilityHidden(true)
                        HStack {
                            Label(option.title, systemImage: option.symbol)
                                .font(TimeMasterFont.rowTitle())
                                .fixedSize(horizontal: false, vertical: true)
                            Spacer(minLength: 0)
                            if mode == option {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(Theme.toolbarOrange).accessibilityHidden(true)
                            }
                        }
                        Text(option == .duel ? "Same movement · Nearby skill" : "Solo camera tracking")
                            .font(TimeMasterFont.caption())
                            .foregroundStyle(ProfileStyle.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(ProfileStyle.spacing)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    .modifier(TimeMasterCardSurface(flat: true))
                    .overlay {
                        if mode == option {
                            RoundedRectangle(cornerRadius: ProfileStyle.corner, style: .continuous)
                                .strokeBorder(Theme.toolbarOrange, lineWidth: 2)
                                .allowsHitTesting(false)
                        }
                    }
                    .contentShape(RoundedRectangle(cornerRadius: ProfileStyle.corner, style: .continuous))
                }
                .buttonStyle(TimeMasterCardButtonStyle())
                .accessibilityLabel(option.title)
                .accessibilityValue(option == .duel ? "Online competition" : "Solo camera-tracked Practice")
                .accessibilityAddTraits(mode == option ? .isSelected : [])
                .accessibilityIdentifier("ranked-mode-\(option.rawValue)")
            }
        }
    }

    private var fighterStage: some View {
        GeometryReader { geometry in
            ZStack {
                Text(mode == .duel ? "1V1" : "SOLO")
                    .font(.custom("Inter-Black", size: geometry.size.width * 0.38))
                    .foregroundStyle(.white.opacity(0.035))
                    .rotationEffect(.degrees(-12))
                    .offset(y: -geometry.size.height * 0.12)
                    .accessibilityHidden(true)
                Capsule()
                    .fill(Theme.toolbarOrange.opacity(0.10))
                    .frame(width: geometry.size.width * 0.36, height: geometry.size.height * 0.78)
                    .rotationEffect(.degrees(22))
                    .accessibilityHidden(true)
                Ellipse()
                    .fill(.white.opacity(0.07))
                    .frame(width: geometry.size.width * 0.62, height: geometry.size.height * 0.10)
                    .offset(y: geometry.size.height * 0.37)
                    .accessibilityHidden(true)
                Image("RankedHero").resizable().scaledToFit()
                    .padding(.top, badgeSize * 1.6)
                    .padding(.bottom, ProfileStyle.spacing)
                    .frame(width: geometry.size.width, height: geometry.size.height)
                    .accessibilityHidden(true)
                VStack {
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(mode == .duel ? "RANKED\nARENA" : "TRAINING\nGROUND")
                                .font(TimeMasterFont.title())
                                .fixedSize(horizontal: false, vertical: true)
                                .accessibilityAddTraits(.isHeader)
                            Text(selection.isTimedHold ? (mode == .duel ? "1V1 · HOLD TIME" : "SOLO · HOLD TIME") : (mode == .duel ? "1V1 · 60 SECONDS" : "SOLO · PRACTICE"))
                                .font(TimeMasterFont.caption())
                                .foregroundStyle(Theme.toolbarOrange)
                        }
                        Spacer(minLength: ProfileStyle.spacing)
                        Button { sheet = .ranks } label: {
                            VStack(spacing: 2) {
                                RankedBadgeView(elo: account.rating(for: selection)?.rating, size: badgeSize)
                                Text(RankedTier.level(for: account.rating(for: selection)?.rating)?.title ?? "Unplaced")
                                    .font(TimeMasterFont.caption())
                                    .foregroundStyle(ProfileStyle.secondary)
                                Image(systemName: "chevron.right")
                                    .font(.caption2.weight(.semibold))
                                    .foregroundStyle(ProfileStyle.secondary)
                                    .accessibilityHidden(true)
                            }
                        }
                        .buttonStyle(TimeMasterCardButtonStyle())
                        .accessibilityLabel("View rank collection")
                        .accessibilityValue(account.rating(for: selection)?.label ?? "Unplaced")
                        .accessibilityIdentifier("ranked-ranks")
                    }
                    Spacer(minLength: 0)
                }
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
            .accessibilityElement(children: .contain)
        }
    }

    private var battleDock: some View {
        VStack(spacing: ProfileStyle.spacing) {
            Button { sheet = .loadout } label: {
                HStack(spacing: ProfileStyle.spacing) {
                    RankedMovementArt(variation: selection)
                        .frame(width: badgeSize, height: badgeSize)
                    VStack(alignment: .leading, spacing: 4) {
                        Text("\(mode.title.uppercased()) · \(selection.isTimedHold ? "HOLD" : "REPS")").font(TimeMasterFont.caption())
                            .foregroundStyle(Theme.toolbarOrange)
                        Text(selection.fullTitle).font(TimeMasterFont.rowTitle())
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer(minLength: 0)
                    Image(systemName: "slider.horizontal.3")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(ProfileStyle.secondary)
                        .accessibilityHidden(true)
                }
                .padding(ProfileStyle.spacing)
                .modifier(TimeMasterCardSurface(flat: true))
                .contentShape(RoundedRectangle(cornerRadius: ProfileStyle.corner, style: .continuous))
            }
            .buttonStyle(TimeMasterCardButtonStyle())
            .accessibilityLabel("Change battle mode and movement")
            .accessibilityValue("\(mode.title), \(selection.fullTitle)")
            .accessibilityIdentifier("ranked-loadout")
            HStack(spacing: ProfileStyle.spacing) {
                Button { sheet = .rules } label: {
                    Label("Rules", systemImage: "list.bullet.clipboard")
                        .frame(maxWidth: .infinity, minHeight: ProfileStyle.touchTarget)
                }
                .accessibilityIdentifier("ranked-rules")
                Button { sheet = .leaderboard } label: {
                    Label("Leaderboard", systemImage: "list.number")
                        .frame(maxWidth: .infinity, minHeight: ProfileStyle.touchTarget)
                }
                .accessibilityIdentifier("ranked-leaderboard")
            }
            .font(TimeMasterFont.caption())
            .buttonStyle(TimeMasterCardButtonStyle())
            Button {
                if mode == .duel && account.identity == nil { sheet = .account }
                else if mode == .duel && account.allowance(for: selection.family)?.remaining == 0 { sheet = .limit }
                else {
                    if mode == .duel, let active = account.recoveryMatch { select(active.variation) }
                    showsBattle = true
                }
            } label: {
                Label(mode == .duel ? (account.recoveryMatch == nil ? "BATTLE" : "RESUME MATCH") : "PRACTICE", systemImage: mode == .duel ? "bolt.fill" : "play.fill")
                    .frame(maxWidth: .infinity, minHeight: ProfileStyle.touchTarget)
            }
            .buttonStyle(TimeMasterToolbarWideButtonStyle())
            .accessibilityLabel(mode == .duel ? "Enter online Ranked" : "Enter camera-tracked Practice")
            .accessibilityIdentifier("ranked-battle")
            HStack(spacing: ProfileStyle.spacing) {
                Button { sheet = .history } label: {
                    Label("Recent rounds", systemImage: "clock.arrow.circlepath")
                        .frame(minHeight: ProfileStyle.touchTarget)
                }
                .accessibilityIdentifier("ranked-history")
                Spacer(minLength: 0)
                Button { sheet = .limit } label: {
                    Text(selection.family == .core ? "Core · No family limit" : account.allowance(for: selection.family)?.remaining.map { "\($0)/10 · Remaining" } ?? "View allowance")
                        .monospacedDigit().frame(minHeight: ProfileStyle.touchTarget)
                }
                .accessibilityIdentifier("ranked-allowance")
            }
            .buttonStyle(TimeMasterCardButtonStyle())
            .font(TimeMasterFont.caption()).foregroundStyle(ProfileStyle.secondary)
            Button { sheet = .account } label: {
                Label(account.identity == nil ? "Ranked account" : account.stale ? "Account · Reconnecting" : "Ranked account · Connected", systemImage: account.identity == nil ? "person.crop.circle" : "lock.shield")
                    .frame(minHeight: ProfileStyle.touchTarget)
            }
            .font(TimeMasterFont.caption()).buttonStyle(TimeMasterCardButtonStyle())
            .foregroundStyle(ProfileStyle.secondary)
        }
    }

    private var loadoutSheet: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: ProfileStyle.inset) {
                    Text("BATTLE MODE")
                        .font(TimeMasterFont.caption())
                        .foregroundStyle(ProfileStyle.secondary)
                        .accessibilityAddTraits(.isHeader)
                    modePicker
                    movementPicker
                }
                .animation(nil, value: family)
                .padding(ProfileStyle.inset)
                .frame(maxWidth: ProfileStyle.readableWidth)
                .frame(maxWidth: .infinity)
            }
            .safeAreaInset(edge: .bottom, spacing: 0) {
                HStack(spacing: ProfileStyle.spacing) {
                    RankedMovementArt(variation: selection)
                        .frame(width: ProfileStyle.touchTarget, height: ProfileStyle.touchTarget)
                    VStack(alignment: .leading, spacing: 4) {
                        Text("SELECTED LOADOUT")
                            .font(TimeMasterFont.caption())
                            .foregroundStyle(ProfileStyle.secondary)
                        Text("\(mode.title) · \(selection.fullTitle)")
                            .font(TimeMasterFont.rowTitle())
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer(minLength: 0)
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(Theme.toolbarOrange)
                        .accessibilityHidden(true)
                }
                .padding(ProfileStyle.inset)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Theme.surface2)
                .accessibilityElement(children: .combine)
            }
            .background(Theme.background.ignoresSafeArea())
            .scrollIndicators(.hidden)
            .foregroundStyle(.white)
            .navigationTitle("Battle loadout")
#if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
#endif
            .toolbar {
                AppToolbar.item(placement: .confirmationAction) {
                    Button("Done") { sheet = nil }
                        .accessibilityIdentifier("ranked-loadout-done")
                }
            }
        }
        .tint(Theme.toolbarOrange)
    }

    private var movementPicker: some View {
        VStack(alignment: .leading, spacing: ProfileStyle.spacing) {
            HStack {
                Text("Movement").font(TimeMasterFont.heading())
                Spacer()
                Text("\(family.variations.count) movements").font(TimeMasterFont.caption()).foregroundStyle(ProfileStyle.secondary)
            }
            ViewThatFits(in: .horizontal) {
                familyPicker(vertical: false)
                familyPicker(vertical: true)
            }
            LazyVGrid(columns: [GridItem(.adaptive(minimum: tileWidth), spacing: ProfileStyle.spacing)], spacing: ProfileStyle.spacing) {
                ForEach(family.variations) { variation in
                    RankedMovementTile(variation: variation, elo: account.rating(for: variation)?.rating, mode: mode, isSelected: selection == variation) {
                        select(variation)
                    }
                }
            }
        }
    }

    private func familyPicker(vertical: Bool) -> some View {
        let layout = vertical ? AnyLayout(VStackLayout(spacing: 8)) : AnyLayout(HStackLayout(spacing: 8))
        return layout {
            ForEach(RankedFamily.allCases) { option in
                Button { family = option } label: {
                    Text(option.title)
                        .font(TimeMasterFont.rowTitle())
                        .fixedSize()
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(TimeMasterSelectionButtonStyle(isSelected: family == option))
                .accessibilityAddTraits(family == option ? .isSelected : [])
                .accessibilityIdentifier("ranked-family-\(option.rawValue)")
            }
        }
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
