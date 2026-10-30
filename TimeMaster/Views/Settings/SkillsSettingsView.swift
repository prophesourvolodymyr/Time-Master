import SwiftUI

/// Settings → Skills: what a skill card and row show.
struct SkillsSettingsView: View {
    @AppStorage(SkillSettings.showsCardCoversKey) private var showsCovers = true
    @AppStorage(SkillSettings.autoIconStyleKey) private var autoIconRaw = SkillAutoIcon.Style.emoji.rawValue

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                VStack(alignment: .leading, spacing: 8) {
                    Toggle(isOn: $showsCovers) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Covers on cards")
                                .font(TimeMasterFont.rowTitle())
                                .foregroundStyle(Theme.textPrimary)
                            Text("A sub-skill that picked a cover shows it on its board card and list row.")
                                .font(TimeMasterFont.caption())
                                .foregroundStyle(Theme.textSecondary)
                        }
                    }
                    .tint(Theme.toolbarOrange)
                }
                .padding(14)
                .background(Theme.surface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))

                VStack(alignment: .leading, spacing: 10) {
                    Text("Icons from titles")
                        .font(TimeMasterFont.rowTitle())
                        .foregroundStyle(Theme.textPrimary)
                    Text("A skill with no icon of its own takes one from its title: “Card shake” gets a card.")
                        .font(TimeMasterFont.caption())
                        .foregroundStyle(Theme.textSecondary)
                    HStack(spacing: 6) {
                        ForEach(SkillAutoIcon.Style.allCases, id: \.rawValue) { style in
                            SkillChoicePill(title: style.title, isSelected: autoIconRaw == style.rawValue) {
                                autoIconRaw = style.rawValue
                            }
                        }
                    }
                }
                .padding(14)
                .background(Theme.surface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            .padding(20)
            .frame(maxWidth: 640)
            .frame(maxWidth: .infinity)
        }
        .background(Theme.background.ignoresSafeArea())
        .timeMasterNavigationTitle("Skills")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
    }
}
