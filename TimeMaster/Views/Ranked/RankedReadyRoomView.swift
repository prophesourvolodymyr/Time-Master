import SwiftUI

struct RankedReadyRoomView: View {
    let variation: RankedVariation
    let mode: RankedMode
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var profileStore: LocalProfileStore
    @ScaledMetric(relativeTo: .title) private var badgeSize: CGFloat = 56

    var body: some View {
        ViewThatFits(in: .vertical) {
            arena(scrolls: false)
            ScrollView { arena(scrolls: true) }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.background.ignoresSafeArea())
        .foregroundStyle(.white)
        .tint(Theme.toolbarOrange)
    }

    private func arena(scrolls: Bool) -> some View {
        VStack(spacing: ProfileStyle.inset) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("ARENA PREVIEW").font(TimeMasterFont.caption())
                        .foregroundStyle(Theme.toolbarOrange)
                    Text(mode.title.uppercased()).font(TimeMasterFont.title())
                        .accessibilityAddTraits(.isHeader)
                }
                Spacer(minLength: ProfileStyle.spacing)
                Button(action: { dismiss() }) {
                    Label("Close arena", systemImage: "xmark").labelStyle(.iconOnly)
                        .font(.headline)
                        .frame(width: ProfileStyle.touchTarget, height: ProfileStyle.touchTarget)
                        .background(Theme.surface2, in: Circle())
                }
                .buttonStyle(TimeMasterCardButtonStyle())
                .accessibilityIdentifier("ranked-ready-close")
            }
            versusStage
                .frame(minHeight: badgeSize * 4, maxHeight: scrolls ? nil : .infinity)
            HStack(spacing: ProfileStyle.spacing) {
                RankedMovementArt(variation: variation)
                    .frame(width: badgeSize, height: badgeSize)
                VStack(alignment: .leading, spacing: 4) {
                    Text(variation.fullTitle).font(TimeMasterFont.heading())
                        .fixedSize(horizontal: false, vertical: true)
                    Text(mode == .duel ? variation.battleRule : "Your pace · No Elo change")
                        .font(TimeMasterFont.caption()).foregroundStyle(ProfileStyle.secondary)
                    Text(variation.cue).font(TimeMasterFont.caption())
                        .foregroundStyle(ProfileStyle.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
            }
            .padding(ProfileStyle.spacing)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.surface2, in: RoundedRectangle(cornerRadius: ProfileStyle.inset))
            HStack(alignment: .top, spacing: ProfileStyle.spacing) {
                guide("iphone.gen3.radiowaves.left.and.right", title: "Phone steady")
                guide("figure.stand", title: "Full body")
                guide("sun.max", title: "Good lighting")
            }
            Text("Preview only. Matchmaking and camera tracking are not connected; no Elo is awarded.")
                .font(TimeMasterFont.caption()).foregroundStyle(ProfileStyle.secondary)
                .fixedSize(horizontal: false, vertical: true)
            Button("Back to lobby") { dismiss() }
                .buttonStyle(RankedActionStyle())
                .accessibilityIdentifier("ranked-back-to-lobby")
        }
        .padding(ProfileStyle.inset)
        .frame(maxWidth: ProfileStyle.readableWidth, maxHeight: scrolls ? nil : .infinity)
        .frame(maxWidth: .infinity)
    }

    private var versusStage: some View {
        GeometryReader { geometry in
            ZStack {
                Capsule().fill(Theme.toolbarOrange.opacity(0.10))
                    .frame(width: geometry.size.width * 0.38, height: geometry.size.height * 0.85)
                    .rotationEffect(.degrees(22))
                    .accessibilityHidden(true)
                HStack(spacing: ProfileStyle.inset) {
                    VStack(spacing: 4) {
                        Image("RankedHero").resizable().scaledToFit()
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .accessibilityHidden(true)
                        Text(profileStore.profile.displayName).font(TimeMasterFont.rowTitle())
                            .lineLimit(2).multilineTextAlignment(.center)
                        HStack(spacing: 4) {
                            RankedBadgeView(elo: profileStore.rankedLevels[variation])
                            Text(profileStore.rankedLevels[variation].map { "\($0.formatted()) Elo" } ?? "Unplaced")
                                .font(TimeMasterFont.caption().monospacedDigit())
                        }
                    }
                    .frame(maxWidth: .infinity)
                    if mode == .duel {
                        VStack(spacing: ProfileStyle.spacing) {
                            Image(systemName: "person.fill")
                                .font(.system(size: geometry.size.width * 0.20, weight: .black))
                                .foregroundStyle(.white.opacity(0.12))
                                .frame(maxHeight: .infinity)
                                .accessibilityHidden(true)
                            Text("OPPONENT").font(TimeMasterFont.rowTitle())
                            Text("Not connected").font(TimeMasterFont.caption())
                                .foregroundStyle(ProfileStyle.secondary)
                        }
                        .padding(ProfileStyle.inset)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(.white.opacity(0.035), in: RoundedRectangle(cornerRadius: ProfileStyle.corner))
                    }
                }
                if mode == .duel {
                    Text("VS").font(TimeMasterFont.title())
                        .foregroundStyle(.black)
                        .frame(width: badgeSize, height: badgeSize)
                        .background(Theme.toolbarOrange, in: Circle())
                        .accessibilityLabel("Versus")
                }
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
        }
    }

    private func guide(_ symbol: String, title: String) -> some View {
        VStack(spacing: 8) {
            Image(systemName: symbol).font(.title2).foregroundStyle(Theme.toolbarOrange).accessibilityHidden(true)
            Text(title).font(TimeMasterFont.caption()).multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
    }
}
