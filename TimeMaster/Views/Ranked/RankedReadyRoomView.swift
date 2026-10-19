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
                .scrollIndicators(.hidden)
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
                    Label("ARENA PREVIEW", systemImage: "viewfinder")
                        .font(TimeMasterFont.caption())
                        .foregroundStyle(Theme.toolbarOrange)
                    Text(mode.title.uppercased()).font(TimeMasterFont.title())
                        .accessibilityAddTraits(.isHeader)
                }
                Spacer(minLength: ProfileStyle.spacing)
                Button(action: { dismiss() }) {
                    Label("Close arena", systemImage: "xmark").labelStyle(.iconOnly)
                        .font(.headline)
                }
                .buttonStyle(TimeMasterToolbarIconButtonStyle())
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
            .modifier(TimeMasterCardSurface(flat: true))
            HStack(alignment: .top, spacing: ProfileStyle.spacing) {
                guide("iphone.gen3.radiowaves.left.and.right", title: "Phone steady")
                guide("figure.stand", title: "Full body")
                guide("sun.max", title: "Good lighting")
            }
            HStack(alignment: .top, spacing: 8) {
                Image(systemName: "info.circle")
                    .accessibilityHidden(true)
                Text("Preview only. Matchmaking and camera tracking are not connected; no Elo is awarded.")
                    .fixedSize(horizontal: false, vertical: true)
            }
            .font(TimeMasterFont.caption())
            .foregroundStyle(ProfileStyle.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            Button { dismiss() } label: {
                Text("Back to lobby")
                    .frame(maxWidth: .infinity, minHeight: ProfileStyle.touchTarget)
            }
            .buttonStyle(TimeMasterToolbarWideButtonStyle())
            .accessibilityIdentifier("ranked-back-to-lobby")
        }
        .padding(ProfileStyle.inset)
        .frame(maxWidth: ProfileStyle.readableWidth, maxHeight: scrolls ? nil : .infinity)
        .frame(maxWidth: .infinity)
    }

    private var versusStage: some View {
        GeometryReader { geometry in
            ZStack {
                Ellipse().fill(Theme.toolbarOrange.opacity(0.08))
                    .frame(width: geometry.size.width * 0.8, height: geometry.size.height * 0.7)
                    .accessibilityHidden(true)
                HStack(spacing: ProfileStyle.inset) {
                    VStack(spacing: 8) {
                        RankedMovementArt(variation: variation)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                        Text(profileStore.profile.displayName).font(TimeMasterFont.rowTitle())
                            .lineLimit(2).multilineTextAlignment(.center)
                        HStack(spacing: 4) {
                            RankedBadgeView(elo: profileStore.rankedLevels[variation])
                            Text(profileStore.rankedLevels[variation].map { "\($0.formatted()) Elo" } ?? "Unplaced")
                                .font(TimeMasterFont.caption().monospacedDigit())
                                .foregroundStyle(ProfileStyle.secondary)
                        }
                    }
                    .padding(ProfileStyle.spacing)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .modifier(TimeMasterCardSurface(flat: true))
                    .accessibilityElement(children: .combine)
                    if mode == .duel {
                        VStack(spacing: ProfileStyle.spacing) {
                            Image(systemName: "person.crop.circle.badge.questionmark")
                                .font(.system(size: geometry.size.width * 0.16, weight: .light))
                                .foregroundStyle(ProfileStyle.secondary)
                                .frame(maxHeight: .infinity)
                                .accessibilityHidden(true)
                            Text("OPPONENT").font(TimeMasterFont.rowTitle())
                                .multilineTextAlignment(.center)
                            Text("Not connected")
                                .font(TimeMasterFont.caption())
                                .foregroundStyle(ProfileStyle.secondary)
                                .multilineTextAlignment(.center)
                        }
                        .padding(ProfileStyle.inset)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .modifier(TimeMasterCardSurface(flat: true))
                        .accessibilityElement(children: .combine)
                    }
                }
                if mode == .duel {
                    Text("VS").font(TimeMasterFont.rowTitle())
                        .foregroundStyle(.black)
                        .frame(width: ProfileStyle.touchTarget, height: ProfileStyle.touchTarget)
                        .background(Theme.toolbarOrange, in: Circle())
                        .overlay {
                            Circle().strokeBorder(Theme.background, lineWidth: 4)
                                .allowsHitTesting(false)
                        }
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
        .padding(.vertical, ProfileStyle.spacing)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.surface2, in: RoundedRectangle(cornerRadius: ProfileStyle.spacing, style: .continuous))
        .accessibilityElement(children: .combine)
    }
}
