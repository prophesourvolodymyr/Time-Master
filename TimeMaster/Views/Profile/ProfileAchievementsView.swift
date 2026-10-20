import SwiftUI

private struct ProfileAchievementPlaceholder: Identifiable {
    let id: Int
    let title: String
    let symbol: String

    static let catalog: [Self] = [
        .init(id: 0, title: "First step", symbol: "figure.walk"),
        .init(id: 1, title: "Finding rhythm", symbol: "metronome"),
        .init(id: 2, title: "Early start", symbol: "sunrise"),
        .init(id: 3, title: "Going further", symbol: "mountain.2"),
        .init(id: 4, title: "Daily practice", symbol: "calendar"),
        .init(id: 5, title: "Personal best", symbol: "flag.checkered"),
        .init(id: 6, title: "Long game", symbol: "hourglass"),
        .init(id: 7, title: "Time mastered", symbol: "sparkles")
    ]
}

enum ProfileAchievementSide: String, CaseIterable, Identifiable {
    case leading, trailing
    var id: String { rawValue }
}

struct ProfileAchievementIndicator: View {
    let isLeading: Bool
    var showAll = false
    let palette: StoreProfilePalette
    let compactProgress: CGFloat
    let collectible: CollectibleItem?
    let artworkActive: Bool
    @State private var showsAchievements = false

    var body: some View {
        let placeholderCount = ProfileAchievementPlaceholder.catalog.reduce(into: 0) { count, item in
            if showAll || item.id.isMultiple(of: 2) == isLeading { count += 1 }
        }
        Button { showsAchievements = true } label: {
            ProfileAchievementShield(
                title: "Later", value: "◇",
                detail: placeholderCount > 1 ? "+\(placeholderCount - 1) more" : nil,
                palette: palette, compactProgress: compactProgress,
                collectible: collectible, artworkActive: artworkActive
            )
        }
        .buttonStyle(EverPressButtonStyle())
        .frame(minWidth: EverLayout.minimumTouchTarget)
        .accessibilityLabel("Achievement placeholders. Coming later. Show all \(placeholderCount) placeholders.")
        .sheet(isPresented: $showsAchievements) { ProfileAchievementsView() }
    }
}

struct ProfileAchievementsView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            EverSettingsPage(title: "Achievements") {
                ProfileEmptyState(symbol: "sparkles", title: "Coming later", detail: "These are design placeholders, not unlocked achievements. No progress or awards are being tracked here yet.")
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 140), spacing: 12)], spacing: 12) {
                    ForEach(ProfileAchievementPlaceholder.catalog) { item in
                        VStack(alignment: .leading, spacing: 12) {
                            Image(systemName: item.symbol)
                                .font(.title).foregroundStyle(ProfileStyle.secondary)
                                .accessibilityHidden(true)
                            Text(item.title).font(TimeMasterFont.rowTitle())
                            Text("Placeholder · Coming later")
                                .font(TimeMasterFont.caption())
                                .foregroundStyle(ProfileStyle.secondary)
                        }
                        .frame(maxWidth: .infinity, minHeight: 130, alignment: .leading)
                        .padding(ProfileStyle.inset)
                        .modifier(TimeMasterCardSurface(flat: true))
                        .accessibilityElement(children: .combine)
                    }
                }
            }
            .toolbar {
                AppToolbar.item(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .tint(.white)
        .preferredColorScheme(.dark)
    }
}
