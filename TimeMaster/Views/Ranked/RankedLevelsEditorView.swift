import SwiftUI

struct RankedLevelsEditorView: View {
    @EnvironmentObject private var profileStore: LocalProfileStore
    @Environment(\.dismiss) private var dismiss
    @State private var draft = RankedLevels()
    @State private var original = RankedLevels()
    @State private var hasLoaded = false
    @State private var editing: RankedVariation?
    @State private var showsDiscard = false
    @State private var errorMessage: String?
    @ScaledMetric(relativeTo: .body) private var artSize: CGFloat = 64

    private var hasChanges: Bool { hasLoaded && draft != original }

    var body: some View {
        NavigationStack {
            ProfileSettingsPage(title: "Elo levels") {
                ProfileSettingsSection(title: "Overall profile level", footer: "Chosen by you, not calculated from movement levels. These are local profile levels, not verified competitive ratings.") {
                    RankedLevelPicker(value: $draft.overall)
                        .padding(ProfileStyle.inset)
                }
                ForEach(RankedFamily.allCases) { family in
                    ProfileSettingsSection(title: family.title) {
                        ForEach(family.variations) { variation in
                            Button { editing = variation } label: {
                                HStack(spacing: ProfileStyle.spacing) {
                                    RankedMovementArt(variation: variation).frame(width: artSize, height: artSize)
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(variation.title).font(TimeMasterFont.rowTitle())
                                            .fixedSize(horizontal: false, vertical: true)
                                        Text(draft[variation].map { "\($0.formatted()) Elo" } ?? "Unplaced")
                                            .font(TimeMasterFont.caption().monospacedDigit())
                                            .foregroundStyle(ProfileStyle.secondary)
                                    }
                                    Spacer()
                                    RankedBadgeView(elo: draft[variation])
                                    Image(systemName: "chevron.right").font(.caption.weight(.semibold))
                                        .foregroundStyle(ProfileStyle.secondary)
                                }
                                .padding(ProfileStyle.spacing)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(TimeMasterCardButtonStyle())
                            .accessibilityLabel("Edit \(variation.fullTitle) level")
                            .accessibilityValue(draft[variation].map { "\($0) Elo" } ?? "Unplaced")
                            .accessibilityIdentifier("ranked-edit-\(variation.rawValue)")
                            if variation != family.variations.last {
                                Divider()
                                    .overlay(Theme.separator)
                                    .padding(.leading, artSize + ProfileStyle.spacing * 2)
                            }
                        }
                    }
                }
            }
            .disabled(profileStore.isReadOnly)
#if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
#endif
            .toolbar {
                AppToolbar.item(placement: .cancellationAction) {
                    Button("Cancel") {
                        if hasChanges { showsDiscard = true } else { dismiss() }
                    }
                    .accessibilityIdentifier("ranked-levels-cancel")
                }
                AppToolbar.item(placement: .confirmationAction) {
                    Button("Save", action: save)
                        .disabled(!hasChanges || profileStore.isReadOnly)
                        .accessibilityIdentifier("ranked-levels-save")
                }
            }
            .interactiveDismissDisabled(hasChanges)
            .confirmationDialog("Discard Elo level changes?", isPresented: $showsDiscard, titleVisibility: .visible) {
                Button("Discard changes", role: .destructive) { dismiss() }
                Button("Keep editing", role: .cancel) {}
            }
            .profileErrorAlert($errorMessage)
            .onAppear {
                guard !hasLoaded else { return }
                draft = profileStore.rankedLevels
                original = draft
                hasLoaded = true
            }
            .sheet(item: $editing) { variation in
                NavigationStack {
                    ScrollView {
                        VStack(spacing: ProfileStyle.inset) {
                            RankedMovementArt(variation: variation).aspectRatio(1.8, contentMode: .fit)
                            RankedLevelPicker(value: levelBinding(for: variation))
                        }
                        .padding(ProfileStyle.inset)
                        .frame(maxWidth: ProfileStyle.readableWidth)
                        .frame(maxWidth: .infinity)
                    }
                    .scrollIndicators(.hidden)
                    .background(Theme.background.ignoresSafeArea()).foregroundStyle(.white)
                    .navigationTitle(variation.fullTitle)
#if os(iOS)
                    .navigationBarTitleDisplayMode(.inline)
#endif
                    .toolbar {
                        AppToolbar.item(placement: .confirmationAction) { Button("Done") { editing = nil } }
                    }
                }
                .tint(Theme.toolbarOrange)
            }
        }
        .tint(Theme.toolbarOrange)
    }

    private func levelBinding(for variation: RankedVariation) -> Binding<Int?> {
        Binding(get: { draft[variation] }, set: { draft[variation] = $0 })
    }

    private func save() {
        do {
            try profileStore.updateRankedLevels(draft)
            dismiss()
        } catch { errorMessage = error.localizedDescription }
    }
}

private struct RankedLevelPicker: View {
    @Binding var value: Int?
    @ScaledMetric(relativeTo: .title) private var badgeSize: CGFloat = 112
    @ScaledMetric(relativeTo: .caption) private var tierWidth: CGFloat = 80

    private var sliderValue: Binding<Double> {
        Binding(get: { Double(value ?? 1_000) }, set: { value = Int($0.rounded()) })
    }
    private var stepperValue: Binding<Int> {
        Binding(get: { value ?? 1_000 }, set: { value = $0 })
    }

    var body: some View {
        VStack(spacing: ProfileStyle.spacing) {
            RankedBadgeView(elo: value, size: badgeSize)
            Text(value.map { "\($0.formatted()) Elo" } ?? "Unplaced")
                .font(TimeMasterFont.title().monospacedDigit())
                .accessibilityIdentifier("ranked-level-value")
            if value != nil {
                Text(RankedTier.level(for: value)?.title ?? "Unplaced").font(TimeMasterFont.secondary())
                    .foregroundStyle(ProfileStyle.secondary)
                    .accessibilityIdentifier("ranked-level-tier")
                Slider(value: sliderValue, in: Double(RankedLevels.range.lowerBound)...Double(RankedLevels.range.upperBound), step: 1)
                    .accessibilityLabel("Elo level")
                    .accessibilityIdentifier("ranked-level-slider")
                HStack {
                    Text(RankedLevels.range.lowerBound.formatted())
                    Spacer()
                    Text(RankedLevels.range.upperBound.formatted())
                }
                .font(TimeMasterFont.caption().monospacedDigit())
                .foregroundStyle(ProfileStyle.secondary)
                .accessibilityHidden(true)
                Stepper("Fine-tune Elo", value: stepperValue, in: RankedLevels.range)
                    .font(TimeMasterFont.secondary())
                    .accessibilityIdentifier("ranked-level-stepper")
                    .accessibilityValue(value.map { "\($0) Elo" } ?? "Unplaced")
            }
            if value == nil {
                Text("Choose a league to set your level.")
                    .font(TimeMasterFont.secondary())
                    .foregroundStyle(ProfileStyle.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            LazyVGrid(columns: [GridItem(.adaptive(minimum: tierWidth), spacing: 8)], spacing: 8) {
                ForEach(RankedTier.allCases) { tier in
                    Button { value = tier.minimum } label: {
                        VStack(spacing: 8) {
                            Image(tier.assetName).resizable().scaledToFit()
                                .frame(width: ProfileStyle.touchTarget, height: ProfileStyle.touchTarget)
                                .accessibilityHidden(true)
                            Text(tier.title).font(TimeMasterFont.caption())
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                    .buttonStyle(TimeMasterSelectionButtonStyle(isSelected: RankedTier.level(for: value) == tier))
                    .accessibilityLabel("Set \(tier.title), \(tier.minimum) Elo")
                    .accessibilityAddTraits(RankedTier.level(for: value) == tier ? .isSelected : [])
                    .accessibilityIdentifier("ranked-level-tier-\(tier.rawValue)")
                }
            }
            if value != nil {
                Button { value = nil } label: {
                    Text("Clear level").frame(maxWidth: .infinity)
                }
                .buttonStyle(TimeMasterSelectionButtonStyle())
                .accessibilityIdentifier("ranked-level-clear")
            }
        }
    }
}
