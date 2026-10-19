import SwiftUI

enum RankedMatchIssue: String, CaseIterable, Identifiable {
    case cameraDenied, framing, lighting, offline, noOpponent, opponentLeft, limit
    var id: String { rawValue }
    var title: String {
        switch self {
        case .cameraDenied: "Camera access is off"
        case .framing: "Move a little farther back"
        case .lighting: "Find a brighter spot"
        case .offline: "Connection interrupted"
        case .noOpponent: "Still looking for a fair match"
        case .opponentLeft: "Your opponent left"
        case .limit: "Time to recover"
        }
    }
    var symbol: String {
        switch self {
        case .cameraDenied: "camera.fill"
        case .framing: "viewfinder"
        case .lighting: "sun.max.fill"
        case .offline: "wifi.exclamationmark"
        case .noOpponent: "person.2.slash"
        case .opponentLeft: "person.crop.circle.badge.minus"
        case .limit: "hourglass"
        }
    }
    var message: String {
        switch self {
        case .cameraDenied: "Camera access would be needed for a verified match. This UI preview does not request or use your camera."
        case .framing: "Keep your hands, feet, and full movement inside the frame."
        case .lighting: "Face a light source. Keep your whole body visible without strong backlighting."
        case .offline: "Before Go, a connection interruption does not use a match slot."
        case .noOpponent: "A longer wait must not force an unfair skill gap. Keep searching or return to the lobby."
        case .opponentLeft: "The round never started. No match slot was used."
        case .limit: "All variations in this exercise family share ten started matches per rolling four hours."
        }
    }
}

struct RankedCameraSetupView: View {
    let variation: RankedVariation
    let mode: RankedMode
    let onContinue: () -> Void
    let onRules: () -> Void
    @ScaledMetric(relativeTo: .largeTitle) private var stageHeight: CGFloat = 250

    var body: some View {
        VStack(spacing: ProfileStyle.inset) {
            VStack(spacing: 6) {
                Text("Position your phone").font(TimeMasterFont.display())
                    .accessibilityAddTraits(.isHeader)
                Text(variation.fullTitle).font(TimeMasterFont.secondary())
                    .foregroundStyle(ProfileStyle.secondary)
            }
            .multilineTextAlignment(.center)
            ZStack {
                RoundedRectangle(cornerRadius: ProfileStyle.corner)
                    .fill(Theme.surface)
                RankedMovementArt(variation: variation)
                    .padding(ProfileStyle.inset * 2)
                RoundedRectangle(cornerRadius: ProfileStyle.corner)
                    .strokeBorder(Theme.toolbarOrange.opacity(0.65), style: StrokeStyle(lineWidth: 2, dash: [12, 10]))
                    .padding(ProfileStyle.inset)
                VStack {
                    Label("FRAMING GUIDE", systemImage: "viewfinder")
                        .font(TimeMasterFont.micro())
                        .foregroundStyle(Theme.toolbarOrange)
                    Spacer(minLength: ProfileStyle.inset)
                    Text("Illustration · Camera not connected")
                        .font(TimeMasterFont.caption())
                        .foregroundStyle(ProfileStyle.secondary)
                }
                .padding(ProfileStyle.inset)
            }
            .frame(height: stageHeight)
            .accessibilityLabel("Camera framing illustration for \(variation.fullTitle)")
            HStack(alignment: .top, spacing: ProfileStyle.spacing) {
                guidance("figure.stand", "Full body")
                guidance("iphone", "Phone steady")
                guidance("sun.max", "Good light")
            }
            Button(action: onRules) {
                HStack {
                    Label("Movement & camera guide", systemImage: "play.rectangle")
                    Spacer(minLength: ProfileStyle.spacing)
                    Image(systemName: "chevron.right").accessibilityHidden(true)
                }
                .font(TimeMasterFont.secondary())
                .padding(ProfileStyle.inset)
                .modifier(TimeMasterCardSurface(flat: true))
            }
            .buttonStyle(TimeMasterCardButtonStyle())
            .accessibilityIdentifier("ranked-camera-rules")
            Button(action: onContinue) {
                Label(mode == .duel ? "Preview search" : "Preview practice", systemImage: mode == .duel ? "person.2" : "play.fill")
                    .frame(maxWidth: .infinity, minHeight: ProfileStyle.touchTarget)
            }
            .buttonStyle(TimeMasterToolbarWideButtonStyle())
            .accessibilityIdentifier("ranked-camera-continue")
            Text("UI walkthrough only. Camera checks and movement verification are not connected.")
                .font(TimeMasterFont.caption()).foregroundStyle(ProfileStyle.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func guidance(_ symbol: String, _ title: String) -> some View {
        VStack(spacing: 8) {
            Image(systemName: symbol).font(.title2).foregroundStyle(Theme.toolbarOrange)
                .accessibilityHidden(true)
            Text(title).font(TimeMasterFont.caption()).multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, ProfileStyle.spacing)
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: ProfileStyle.corner))
        .accessibilityElement(children: .combine)
    }
}

struct RankedSearchView: View {
    let variation: RankedVariation
    let remaining: Int
    let onOpponent: () -> Void
    let onCancel: () -> Void
    @EnvironmentObject private var profileStore: LocalProfileStore
    @ScaledMetric(relativeTo: .largeTitle) private var avatarSize: CGFloat = 88

    var body: some View {
        VStack(spacing: ProfileStyle.inset * 2) {
            VStack(spacing: 8) {
                Text("Find your match").font(TimeMasterFont.display())
                    .accessibilityAddTraits(.isHeader)
                Text(variation.fullTitle).font(TimeMasterFont.secondary())
                    .foregroundStyle(ProfileStyle.secondary)
            }
            .multilineTextAlignment(.center)
            ZStack {
                Circle().stroke(Theme.separator, lineWidth: 1)
                Circle().stroke(Theme.toolbarOrange.opacity(0.22), lineWidth: 1)
                    .padding(ProfileStyle.inset * 2)
                HStack(spacing: ProfileStyle.inset * 2) {
                    ProfileStyledAvatar(profile: profileStore.profile, size: avatarSize)
                    Image(systemName: "ellipsis").font(.title2).foregroundStyle(ProfileStyle.secondary)
                    Image(systemName: "person.crop.circle.badge.questionmark")
                        .font(.system(size: avatarSize, weight: .ultraLight))
                        .foregroundStyle(ProfileStyle.secondary)
                }
                .padding(ProfileStyle.inset * 2)
            }
            .aspectRatio(1.6, contentMode: .fit)
            .accessibilityLabel("Your profile and an unknown opponent; search layout preview")
            VStack(spacing: ProfileStyle.spacing) {
                Label("Search layout preview", systemImage: "magnifyingglass")
                    .font(TimeMasterFont.heading())
                Text("No matchmaking service is connected.")
                    .font(TimeMasterFont.secondary()).foregroundStyle(ProfileStyle.secondary)
                HStack {
                    Label("Same exercise", systemImage: "checkmark")
                    Spacer(minLength: ProfileStyle.spacing)
                    Text("Nearby skill")
                }
                .font(TimeMasterFont.caption()).foregroundStyle(ProfileStyle.secondary)
                Divider().overlay(Theme.separator)
                Label("\(remaining) / 10 preview slots", systemImage: "bolt.shield")
                    .font(TimeMasterFont.secondary().monospacedDigit())
            }
            .multilineTextAlignment(.center)
            .padding(ProfileStyle.inset)
            .frame(maxWidth: .infinity)
            .modifier(TimeMasterCardSurface(flat: true))
            VStack(spacing: ProfileStyle.spacing) {
                Button(action: onOpponent) {
                    Label("Preview opponent found", systemImage: "person.2.fill")
                        .frame(maxWidth: .infinity, minHeight: ProfileStyle.touchTarget)
                }
                .buttonStyle(TimeMasterToolbarWideButtonStyle())
                .accessibilityIdentifier("ranked-search-opponent")
                Button("Cancel search", action: onCancel)
                    .buttonStyle(TimeMasterToolbarWideButtonStyle())
                    .accessibilityIdentifier("ranked-search-cancel")
                Text("Cancel freely · No rating change · No slot used")
                    .font(TimeMasterFont.caption()).foregroundStyle(ProfileStyle.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

struct RankedOpponentReadyView: View {
    let variation: RankedVariation
    let onReady: () -> Void
    let onRules: () -> Void
    let onOpponent: () -> Void
    @EnvironmentObject private var profileStore: LocalProfileStore
    @ScaledMetric(relativeTo: .title) private var avatarSize: CGFloat = 72

    var body: some View {
        VStack(spacing: ProfileStyle.inset * 2) {
            VStack(spacing: 8) {
                Text("Opponent found").font(TimeMasterFont.display())
                    .accessibilityAddTraits(.isHeader)
                Text("Same exercise. Same rules.").font(TimeMasterFont.secondary())
                    .foregroundStyle(ProfileStyle.secondary)
            }
            .multilineTextAlignment(.center)
            HStack(alignment: .top, spacing: ProfileStyle.spacing) {
                VStack(spacing: ProfileStyle.spacing) {
                    ProfileStyledAvatar(profile: profileStore.profile, size: avatarSize)
                    Text(profileStore.profile.displayName).font(TimeMasterFont.rowTitle())
                        .lineLimit(2).multilineTextAlignment(.center)
                    RankedBadgeView(elo: profileStore.rankedLevels[variation])
                    Text(profileStore.rankedLevels[variation].map { "\($0.formatted()) · Local level" } ?? "Unplaced · Local level")
                        .font(TimeMasterFont.caption()).foregroundStyle(ProfileStyle.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                Text("VS").font(TimeMasterFont.heading())
                    .foregroundStyle(Theme.toolbarOrange).padding(.top, avatarSize / 2)
                    .accessibilityHidden(true)
                Button(action: onOpponent) {
                    VStack(spacing: ProfileStyle.spacing) {
                        Image("RankedMode_duel").resizable().scaledToFill()
                            .frame(width: avatarSize, height: avatarSize).clipShape(Circle())
                            .accessibilityHidden(true)
                        Text("Alex").font(TimeMasterFont.rowTitle())
                        RankedBadgeView(elo: 1_040)
                        Text("1,040 · Example level").font(TimeMasterFont.caption())
                            .foregroundStyle(ProfileStyle.secondary)
                        Text("EXAMPLE OPPONENT").font(TimeMasterFont.micro())
                            .foregroundStyle(Theme.toolbarOrange)
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(TimeMasterCardButtonStyle())
                .accessibilityLabel("View example opponent Alex")
                .accessibilityIdentifier("ranked-ready-opponent")
            }
            .padding(ProfileStyle.inset)
            .modifier(TimeMasterCardSurface(flat: true))
            Button(action: onRules) {
                HStack(spacing: ProfileStyle.spacing) {
                    RankedMovementArt(variation: variation)
                        .frame(width: avatarSize, height: avatarSize)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(variation.fullTitle).font(TimeMasterFont.rowTitle())
                        Text(variation.battleRule).font(TimeMasterFont.caption())
                            .foregroundStyle(ProfileStyle.secondary)
                    }
                    Spacer(minLength: 0)
                    Image(systemName: "chevron.right").accessibilityHidden(true)
                }
                .padding(ProfileStyle.spacing)
                .modifier(TimeMasterCardSurface(flat: true))
            }
            .buttonStyle(TimeMasterCardButtonStyle())
            Label("Example opponent ready", systemImage: "checkmark.circle.fill")
                .font(TimeMasterFont.secondary()).foregroundStyle(ProfileStyle.secondary)
            Button(action: onReady) {
                Label("I'm ready · Preview countdown", systemImage: "checkmark")
                    .frame(maxWidth: .infinity, minHeight: ProfileStyle.touchTarget)
            }
            .buttonStyle(TimeMasterToolbarWideButtonStyle())
            .accessibilityIdentifier("ranked-ready-confirm")
            Text("No live opponent · No camera verification · No Elo change")
                .font(TimeMasterFont.caption()).foregroundStyle(ProfileStyle.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

struct RankedMatchIssueView: View {
    let issue: RankedMatchIssue
    let onRetry: () -> Void
    let onCancel: () -> Void
    @ScaledMetric(relativeTo: .largeTitle) private var iconSize: CGFloat = 64

    var body: some View {
        VStack(spacing: ProfileStyle.inset * 2) {
            Image(systemName: issue.symbol).font(.system(size: iconSize, weight: .light))
                .foregroundStyle(Theme.toolbarOrange)
                .padding(ProfileStyle.inset * 2)
                .background(Theme.surface, in: Circle()).accessibilityHidden(true)
            Text(issue.title).font(TimeMasterFont.display())
                .accessibilityAddTraits(.isHeader)
            Text(issue.message).font(TimeMasterFont.body())
                .foregroundStyle(ProfileStyle.secondary)
            Button(action: onRetry) {
                Text(issue == .noOpponent ? "Keep searching" : "Return to preparation")
                    .frame(maxWidth: .infinity, minHeight: ProfileStyle.touchTarget)
            }
            .buttonStyle(TimeMasterToolbarWideButtonStyle())
            .accessibilityIdentifier("ranked-issue-retry")
            Button("Return to lobby", action: onCancel)
                .buttonStyle(TimeMasterToolbarWideButtonStyle())
                .accessibilityIdentifier("ranked-issue-cancel")
            Text("Problem-state preview · No real match is running")
                .font(TimeMasterFont.caption()).foregroundStyle(ProfileStyle.secondary)
        }
        .multilineTextAlignment(.center)
        .fixedSize(horizontal: false, vertical: true)
        .accessibilityIdentifier("ranked-issue-\(issue.rawValue)")
    }
}
