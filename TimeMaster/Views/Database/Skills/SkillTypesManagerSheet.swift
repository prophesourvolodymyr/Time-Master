import SwiftUI
import TimeMasterCore

/// Every preset of a skill with the types in it. Open one to rename it, change its icon or edit its types; make a new one.
/// A preset is like a Notion "Select" property: a page wears one type of one of them.
struct SkillTypesManagerSheet: View {
    let rootID: String

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var store: DatabaseStore

    @State private var editor: SkillTypeEditorRoute?

    private var presets: [SkillTypePreset] { store.skillTypePresets(for: rootID) }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    Text("A preset holds the types you pick for your pages, like a Notion Select property. A page wears one type of one preset. Every skill keeps its own presets; each type has its own colour, icon and effect.")
                        .font(TimeMasterFont.secondary())
                        .foregroundStyle(Theme.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                    if presets.isEmpty {
                        Text("No presets yet. Make the first one.")
                            .font(TimeMasterFont.body(15))
                            .foregroundStyle(Theme.textSecondary)
                    }
                    ForEach(presets) { preset in
                        presetCard(preset)
                    }
                    Button {
                        editor = .newPreset
                    } label: {
                        Label("New preset", systemImage: "plus.square.on.square")
                    }
                    .foregroundStyle(Theme.toolbarOrange)
                }
                .padding(20)
                .frame(maxWidth: 640)
                .frame(maxWidth: .infinity)
            }
            .background(Theme.background.ignoresSafeArea())
            .timeMasterNavigationTitle("Presets")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                AppToolbar.item(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .keyNavHost()
        .sheet(item: $editor) { route in
            Group {
                switch route {
                case .newType, .editType:
                    SkillTypeEditorSheet(rootID: rootID, route: route)
                case .newPreset, .editPreset:
                    SkillTypePresetSheet(rootID: rootID, route: route)
                }
            }
            .environmentObject(store)
        }
        .skillErrorAlert()
        #if os(macOS)
        .frame(minWidth: 520, idealWidth: 560, minHeight: 520, idealHeight: 680)
        #endif
    }

    /// A preset's icon, name and count over a peek at its types; it opens the preset.
    private func presetCard(_ preset: SkillTypePreset) -> some View {
        let types = preset.orderedTypes
        return Button {
            editor = .editPreset(preset)
        } label: {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 10) {
                    SkillTypePresetIcon(preset: preset, size: 20)
                    Text(preset.title)
                        .font(TimeMasterFont.heading())
                        .foregroundStyle(Theme.textPrimary)
                        .lineLimit(1)
                    Spacer(minLength: 0)
                    Text("\(types.count)")
                        .font(TimeMasterFont.caption())
                        .foregroundStyle(Theme.textSecondary)
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Theme.textSecondary)
                }
                if types.isEmpty {
                    Text("No types yet.")
                        .font(TimeMasterFont.secondary())
                        .foregroundStyle(Theme.textSecondary)
                } else {
                    HStack(spacing: 6) {
                        ForEach(types.prefix(4)) { SkillTypeChip(type: $0) }
                        if types.count > 4 {
                            Text("+\(types.count - 4)")
                                .font(TimeMasterFont.caption())
                                .foregroundStyle(Theme.textSecondary)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.surface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .contentShape(Rectangle())
        }.keyNavPlainButtonStyle()
        .accessibilityLabel("\(preset.title), \(types.count) \(types.count == 1 ? "type" : "types")")
        .accessibilityHint("Opens the preset")
    }
}
