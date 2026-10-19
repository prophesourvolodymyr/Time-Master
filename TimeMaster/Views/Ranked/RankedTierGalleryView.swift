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
                    Text("PICK YOUR LEAGUE").font(TimeMasterFont.title())
                    Text("Profile-selected levels, not earned competitive ratings.")
                        .font(TimeMasterFont.secondary()).foregroundStyle(ProfileStyle.secondary)
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: tileWidth), spacing: ProfileStyle.spacing)], spacing: ProfileStyle.spacing) {
                        ForEach(RankedTier.allCases) { tier in
                            VStack(spacing: 8) {
                                Image(tier.assetName).resizable().scaledToFit()
                                    .aspectRatio(1.2, contentMode: .fit).accessibilityHidden(true)
                                Text(tier.title).font(TimeMasterFont.rowTitle())
                                Text("\(tier.minimum.formatted())+ Elo").font(TimeMasterFont.caption())
                                    .foregroundStyle(ProfileStyle.secondary)
                                if RankedTier.level(for: profileStore.rankedLevels.overall) == tier {
                                    Label("Your level", systemImage: "checkmark.circle.fill")
                                        .font(TimeMasterFont.caption()).foregroundStyle(Theme.toolbarOrange)
                                }
                            }
                            .padding(ProfileStyle.spacing)
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                            .background(Theme.surface, in: RoundedRectangle(cornerRadius: ProfileStyle.corner))
                            .accessibilityElement(children: .combine)
                        }
                    }
                    Button("Edit profile levels") { showsEditor = true }
                        .buttonStyle(RankedActionStyle())
                        .disabled(profileStore.isReadOnly)
                        .accessibilityIdentifier("ranked-gallery-edit")
                }
                .padding(ProfileStyle.inset)
                .frame(maxWidth: ProfileStyle.readableWidth)
                .frame(maxWidth: .infinity)
            }
            .background(Theme.background.ignoresSafeArea())
            .foregroundStyle(.white)
            .navigationTitle("Rank collection")
#if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
#endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Close") { dismiss() } }
            }
            .sheet(isPresented: $showsEditor) { RankedLevelsEditorView() }
        }
        .tint(Theme.toolbarOrange)
    }
}
