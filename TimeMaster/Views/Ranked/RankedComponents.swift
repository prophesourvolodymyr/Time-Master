import SwiftUI

private let rankedMetricInk = LinearGradient(
    colors: [.white, .white.opacity(0.78)],
    startPoint: .top,
    endPoint: .bottom
)

private let rankedAccentMetricInk = LinearGradient(
    colors: [Theme.toolbarOrange, Theme.toolbarOrange.opacity(0.78)],
    startPoint: .top,
    endPoint: .bottom
)

struct RankedIconAction: View {
    let symbol: String
    let label: String
    var id: String? = nil
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.body.weight(.semibold))
                .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
        }
        .buttonStyle(TimeMasterToolbarIconButtonStyle())
        .accessibilityLabel(label)
        .accessibilityIdentifier(id ?? label)
        .help(label)
    }
}

struct RankedCloseButton: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        RankedIconAction(symbol: "xmark", label: "Close", id: "ranked-sheet-close") { dismiss() }
    }
}

struct RankedInfoButton: View {
    let label: String
    let message: String
    var symbol = "info"
    @State private var showsInfo = false

    var body: some View {
        RankedIconAction(symbol: symbol, label: label) { showsInfo = true }
            .alert(label, isPresented: $showsInfo) {
                Button("OK", role: .cancel) { }
            } message: { Text(message) }
            .accessibilityHint(message)
    }
}

struct RankedMetric: View {
    let value: String
    let unit: String
    var emphasized = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: EverSpacing.x1) {
            Text(value)
                .font(TimeMasterFont.title().monospacedDigit())
                .foregroundStyle(emphasized ? rankedAccentMetricInk : rankedMetricInk)
                .tracking(-0.4)
                .contentTransition(.opacity)
                .animation(reduceMotion ? nil : .easeOut(duration: 0.18), value: value)
            Text(unit)
                .font(TimeMasterFont.micro())
                .foregroundStyle(ProfileStyle.secondary)
        }
        .lineLimit(1)
        .minimumScaleFactor(0.6)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(unit)
        .accessibilityValue(value)
    }
}

struct RankedMovementArt: View {
    let variation: RankedVariation

    private var marker: String? {
        switch variation {
        case .widePushUp, .wideSquat: "arrow.left.and.right"
        case .closePushUp, .narrowSquat: "arrow.right.and.line.vertical.and.arrow.left"
        case .pausedPushUp, .pausedSquat: "pause.fill"
        case .tempoPushUp: "metronome.fill"
        case .diamondPushUp: "diamond.fill"
        case .wallHandstandPushUp: "rectangle.portrait.fill"
        case .freestandingHandstandPushUp: "arrow.up"
        case .planchePushUp: "arrow.up.right"
        case .leftSidePlank: "arrow.left"
        case .rightSidePlank: "arrow.right"
        default: nil
        }
    }

    var body: some View {
        Image(variation.assetName)
            .resizable()
            .scaledToFit()
            .overlay(alignment: .bottomTrailing) {
                if let marker {
                    Image(systemName: marker)
                        .font(.caption2.weight(.bold))
                        .dynamicTypeSize(...DynamicTypeSize.large)
                        .foregroundStyle(Theme.toolbarOrange)
                        .padding(EverSpacing.x1)
                        .background(Theme.background.opacity(0.85), in: Circle())
                }
            }
            .accessibilityHidden(true)
    }
}

struct RankedEloBadge: View {
    let variation: RankedVariation
    let elo: Int?
    var compact = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        GeometryReader { geometry in
            let side = max(1, min(geometry.size.width, geometry.size.height))
            ZStack {
                Image("RankedEloCrest")
                    .resizable()
                    .scaledToFit()
                    .saturation(elo == nil ? 0.2 : 1)
                VStack(spacing: side * 0.015) {
                    RankedMovementArt(variation: variation)
                        .frame(width: side * 0.48, height: side * 0.25)
                    Text(elo.map { $0.formatted() } ?? "—")
                        .font(.custom("Inter-Black", fixedSize: side * (compact ? 0.25 : 0.19)).monospacedDigit())
                        .foregroundStyle(rankedMetricInk)
                        .tracking(-side * 0.003)
                        .contentTransition(.opacity)
                        .animation(reduceMotion ? nil : .easeOut(duration: 0.18), value: elo)
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                    if !compact {
                        Text("Elo")
                            .font(.custom("Inter-Regular", fixedSize: side * 0.08))
                            .tracking(side * 0.006)
                            .foregroundStyle(.white.opacity(0.7))
                    }
                }
                .frame(width: side * 0.63)
                .offset(y: side * 0.025)
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(variation.fullTitle) earned Elo")
        .accessibilityValue(elo.map { "\($0.formatted()) Elo" } ?? "No earned rating")
    }
}

struct RankedMovementTile: View {
    let variation: RankedVariation
    let elo: Int?
    let mode: RankedMode
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: ProfileStyle.spacing) {
                RankedMovementArt(variation: variation)
                    .aspectRatio(1.4, contentMode: .fit)
                HStack {
                    Image(systemName: variation.isTimedHold ? "timer" : "repeat")
                        .foregroundStyle(ProfileStyle.secondary)
                    Spacer(minLength: 0)
                    if mode == .duel {
                        Text(elo.map { "\($0.formatted()) Elo" } ?? "— Elo")
                            .font(TimeMasterFont.caption().monospacedDigit())
                    } else {
                        Image(systemName: "person.fill")
                            .foregroundStyle(ProfileStyle.secondary)
                    }
                    if variation.isAdvanced && mode == .duel {
                        Image(systemName: "lock.fill").foregroundStyle(ProfileStyle.secondary)
                    }
                }
            }
            .padding(ProfileStyle.spacing)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .overlay(alignment: .topTrailing) {
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.white)
                        .padding(EverSpacing.x2)
                }
            }
        }
        .buttonStyle(TimeMasterSelectionButtonStyle(isSelected: isSelected))
        .foregroundStyle(.white)
        .accessibilityLabel(variation.fullTitle)
        .accessibilityValue(mode == .practice ? "Practice" : elo.map { "\($0) earned Elo" } ?? "No earned rating")
        .accessibilityHint(variation.isAdvanced ? "Practice only. Rated verification is unavailable." : "Select this exact movement")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .accessibilityIdentifier("ranked-variation-\(variation.rawValue)")
    }
}

struct RankedFamilyPicker: View {
    @Binding var family: RankedFamily

    var body: some View {
        HStack(spacing: ProfileStyle.spacing) {
            ForEach(RankedFamily.allCases) { option in
                Button { family = option } label: {
                    RankedMovementArt(variation: option.variations[0])
                        .frame(height: ProfileStyle.touchTarget)
                        .frame(maxWidth: .infinity)
                        .padding(EverSpacing.x2)
                        .overlay(alignment: .topTrailing) {
                            if family == option {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(.white)
                                    .padding(EverSpacing.x1)
                            }
                        }
                }
                .buttonStyle(TimeMasterSelectionButtonStyle(isSelected: family == option))
                .accessibilityLabel(option.title)
                .accessibilityAddTraits(family == option ? .isSelected : [])
                .accessibilityIdentifier("ranked-family-\(option.rawValue)")
            }
        }
    }
}

struct RankedProfileSummary: View {
    @ObservedObject private var account = RankedAccountStore.shared
    let variation: RankedVariation
    var compact = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            RankedEloBadge(variation: variation, elo: account.rating(for: variation)?.rating, compact: compact)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .overlay(alignment: .topTrailing) {
                    if account.loading {
                        TmaxLoadingIndicator(size: 14)
                    } else if account.stale {
                        Image(systemName: "wifi.slash")
                            .font(.caption2)
                            .foregroundStyle(Theme.toolbarOrange)
                    }
                }
                .contentShape(Rectangle())
        }
        .buttonStyle(TimeMasterCardButtonStyle())
        .accessibilityLabel("\(variation.fullTitle) earned Elo")
        .accessibilityValue(account.rating(for: variation)?.label ?? "No earned rating")
        .accessibilityHint(account.identity == nil ? "Sign in to load your rating" : "Open your movement ratings")
        .accessibilityIdentifier("profile-earned-elo")
        .task { await account.restore() }
    }
}

struct RankedRatingTile: View {
    let variation: RankedVariation
    let rating: RankedRating?
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: EverSpacing.x2) {
                RankedEloBadge(variation: variation, elo: rating?.rating)
                    .aspectRatio(1, contentMode: .fit)
                if let rating, rating.provisional {
                    HStack(spacing: EverSpacing.x1) {
                        Image(systemName: "flag.checkered")
                        Text("\(rating.games)/5").monospacedDigit()
                    }
                    .font(TimeMasterFont.micro())
                    .foregroundStyle(ProfileStyle.secondary)
                }
            }
            .padding(EverSpacing.x2)
            .modifier(TimeMasterCardSurface(flat: true))
            .contentShape(Rectangle())
        }
        .buttonStyle(TimeMasterCardButtonStyle())
        .accessibilityLabel(variation.fullTitle)
        .accessibilityValue(rating?.label ?? "No earned rating")
    }
}

struct RankedMovementPicker: View {
    @Binding var variation: RankedVariation
    @ObservedObject private var account = RankedAccountStore.shared
    @State private var family: RankedFamily = .pushUps
    @State private var showsOptions = false

    var body: some View {
        Button { family = variation.family; showsOptions = true } label: {
            HStack(spacing: EverSpacing.x2) {
                RankedMovementArt(variation: variation)
                    .frame(width: ProfileStyle.touchTarget, height: ProfileStyle.touchTarget)
                Image(systemName: "chevron.down").font(.caption.weight(.semibold))
            }
        }
        .buttonStyle(TimeMasterToolbarWideButtonStyle())
        .accessibilityLabel("Choose exact movement")
        .accessibilityValue(variation.fullTitle)
        .accessibilityIdentifier("ranked-exercise-picker")
        .sheet(isPresented: $showsOptions) {
            NavigationStack {
                ScrollView {
                    VStack(spacing: ProfileStyle.inset) {
                        RankedFamilyPicker(family: $family)
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: ProfileStyle.touchTarget * 3))], spacing: ProfileStyle.spacing) {
                            ForEach(family.variations) { option in
                                RankedMovementTile(variation: option, elo: account.rating(for: option)?.rating, mode: .duel, isSelected: variation == option) {
                                    variation = option
                                    showsOptions = false
                                }
                            }
                        }
                    }
                    .padding(ProfileStyle.inset)
                    .frame(maxWidth: ProfileStyle.readableWidth)
                    .frame(maxWidth: .infinity)
                }
                .background(Theme.background.ignoresSafeArea())
                .toolbar { AppToolbar.iconItem(placement: .confirmationAction) { RankedCloseButton() } }
            }
            .tint(Theme.toolbarOrange)
            .preferredColorScheme(.dark)
        }
    }
}

struct RankedOutcomeIcon: View {
    let match: RankedMatch?
    var practice = false

    private var symbol: String {
        guard !practice else { return "checkmark.circle" }
        guard let match else { return "clock.badge.questionmark" }
        switch match.state {
        case "completed", "forfeited":
            if match.winner == nil { return "equal.circle" }
            return match.winner == match.you?.publicID ? "trophy.fill" : "flag.slash"
        case "invalid": return "shield.slash"
        case "cancelled": return "xmark.circle"
        default: return "clock"
        }
    }

    var body: some View {
        Image(systemName: symbol)
            .foregroundStyle(Theme.toolbarOrange)
            .accessibilityLabel(practice ? "Practice complete" : match?.outcomeTitle ?? "Verification pending")
    }
}
