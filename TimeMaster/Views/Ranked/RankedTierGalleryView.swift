import SwiftUI

struct RankedTierGalleryView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var profileStore: LocalProfileStore
    @ScaledMetric(relativeTo: .body) private var tileWidth: CGFloat = 144
    @State private var showsEditor = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: ProfileStyle.inset) {
                    Text("YOUR LEAGUE").font(TimeMasterFont.title())
                        .accessibilityAddTraits(.isHeader)
                    HStack(spacing: ProfileStyle.spacing) {
                        RankedBadgeView(elo: profileStore.rankedLevels.overall)
                        VStack(alignment: .leading, spacing: 4) {
                            Text(RankedTier.level(for: profileStore.rankedLevels.overall)?.title ?? "Unplaced")
                                .font(TimeMasterFont.heading())
                            Text(profileStore.rankedLevels.overall.map { "\($0.formatted()) Elo · Overall profile level" } ?? "Choose your overall profile level")
                                .font(TimeMasterFont.caption().monospacedDigit())
                                .foregroundStyle(ProfileStyle.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        Spacer(minLength: 0)
                    }
                    .padding(ProfileStyle.inset)
                    .modifier(TimeMasterCardSurface(flat: true))
                    .accessibilityElement(children: .combine)
                    Text("Local display levels, not earned competitive ratings.")
                        .font(TimeMasterFont.secondary())
                        .foregroundStyle(ProfileStyle.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: tileWidth), spacing: ProfileStyle.spacing)], spacing: ProfileStyle.spacing) {
                        ForEach(RankedTier.allCases) { tier in
                            VStack(spacing: 8) {
                                Image(tier.assetName).resizable().scaledToFit()
                                    .aspectRatio(1, contentMode: .fit).accessibilityHidden(true)
                                Text(tier.title).font(TimeMasterFont.rowTitle())
                                Text("\(tier.minimum.formatted())+ Elo")
                                    .font(TimeMasterFont.caption().monospacedDigit())
                                    .foregroundStyle(ProfileStyle.secondary)
                            }
                            .padding(ProfileStyle.spacing)
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                            .modifier(TimeMasterCardSurface(flat: true))
                            .overlay(alignment: .topTrailing) {
                                if RankedTier.level(for: profileStore.rankedLevels.overall) == tier {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundStyle(Theme.toolbarOrange)
                                        .padding(ProfileStyle.spacing)
                                        .accessibilityHidden(true)
                                }
                            }
                            .accessibilityElement(children: .combine)
                            .accessibilityValue(RankedTier.level(for: profileStore.rankedLevels.overall) == tier ? "Your overall profile level" : "")
                        }
                    }
                    if profileStore.isReadOnly {
                        Text("Level editing is unavailable because the saved profile could not be read. Your original file is preserved.")
                            .font(TimeMasterFont.caption())
                            .foregroundStyle(ProfileStyle.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .padding(ProfileStyle.inset)
                .frame(maxWidth: ProfileStyle.readableWidth)
                .frame(maxWidth: .infinity)
            }
            .safeAreaInset(edge: .bottom, spacing: 0) {
                Button { showsEditor = true } label: {
                    Text("Edit profile levels")
                        .frame(maxWidth: .infinity, minHeight: ProfileStyle.touchTarget)
                }
                .buttonStyle(TimeMasterToolbarWideButtonStyle())
                .disabled(profileStore.isReadOnly)
                .accessibilityIdentifier("ranked-gallery-edit")
                .padding(ProfileStyle.inset)
                .frame(maxWidth: ProfileStyle.readableWidth)
                .frame(maxWidth: .infinity)
                .background(Theme.background)
            }
            .scrollIndicators(.hidden)
            .background(Theme.background.ignoresSafeArea())
            .foregroundStyle(.white)
            .navigationTitle("Rank collection")
#if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
#endif
            .toolbar {
                AppToolbar.item(placement: .cancellationAction) { Button("Close") { dismiss() } }
            }
            .sheet(isPresented: $showsEditor) { RankedLevelsEditorView() }
        }
        .tint(Theme.toolbarOrange)
    }
}
