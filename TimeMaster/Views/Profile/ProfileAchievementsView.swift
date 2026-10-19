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

struct ProfileAchievementStrip: View {
    let isLeading: Bool
    @State private var showsAchievements = false

    private var items: [ProfileAchievementPlaceholder] {
        ProfileAchievementPlaceholder.catalog.filter { $0.id.isMultiple(of: 2) == isLeading }
    }

    var body: some View {
        GeometryReader { geometry in
            let slots = max(1, Int((geometry.size.width + 4) / 48))
            let visibleCount = slots >= items.count ? items.count : max(0, slots - 1)
            VStack(spacing: 4) {
                HStack(spacing: 4) {
                    ForEach(items.prefix(visibleCount)) { item in
                        Button { showsAchievements = true } label: {
                            Image(systemName: item.symbol)
                                .font(.system(size: 19, weight: .medium))
                                .foregroundStyle(ProfileStyle.secondary)
                                .frame(width: 44, height: 44)
                                .background(Theme.surface2, in: Circle())
                        }
                        .accessibilityLabel("\(item.title), achievement placeholder. Coming later.")
                    }
                    if visibleCount < items.count {
                        Button { showsAchievements = true } label: {
                            Text("+\(items.count - visibleCount)")
                                .font(TimeMasterFont.caption())
                                .foregroundStyle(.white)
                                .frame(width: 44, height: 44)
                                .background(Theme.surface2, in: Circle())
                        }
                        .accessibilityLabel("Show \(items.count - visibleCount) more achievement placeholders. Coming later.")
                    }
                }
                .buttonStyle(.plain)
                Text("Coming later")
                    .font(TimeMasterFont.caption())
                    .foregroundStyle(ProfileStyle.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: isLeading ? .trailing : .leading)
        }
        .frame(minWidth: 44, minHeight: 84)
        .sheet(isPresented: $showsAchievements) { ProfileAchievementsView() }
    }
}

struct ProfileAchievementsView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ProfileSettingsPage(title: "Achievements") {
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
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }.frame(minWidth: 44, minHeight: 44)
                }
            }
        }
        .tint(.white)
        .preferredColorScheme(.dark)
    }
}
