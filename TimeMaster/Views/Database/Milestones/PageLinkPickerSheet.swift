import SwiftUI
import TimeMasterCore

/// Links a database page: every page as a tile with its cover (or its icon), searchable by title or path.
struct PageLinkPickerSheet: View {
    let excludedIDs: Set<String>
    let linkedIDs: Set<String>
    let onPick: (String) -> Void

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var store: DatabaseStore
    @State private var query = ""
    @ScaledMetric(relativeTo: .body) private var tileWidth: CGFloat = 150

    private var shown: [ExercisePage] {
        let text = query.trimmingCharacters(in: .whitespacesAndNewlines)
        let pages = store.allPagesFlat
            .filter { !excludedIDs.contains($0.manifest.id) }
            .sorted { $0.path.localizedStandardCompare($1.path) == .orderedAscending }
        guard !text.isEmpty else { return pages }
        return pages.filter { $0.title.localizedCaseInsensitiveContains(text) || trail(of: $0).localizedCaseInsensitiveContains(text) }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                if shown.isEmpty {
                    VStack(spacing: 10) {
                        Image(systemName: "doc.text.magnifyingglass")
                            .font(.system(size: 34))
                            .foregroundStyle(Theme.textSecondary)
                        Text("No match")
                            .font(TimeMasterFont.secondary())
                            .foregroundStyle(Theme.textSecondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, 60)
                } else {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: tileWidth), spacing: 14, alignment: .top)], spacing: 18) {
                        ForEach(shown) { page in
                            tile(page)
                        }
                    }
                    .padding(20)
                }
            }
            .background(Theme.background.ignoresSafeArea())
            .searchable(text: $query)
            .timeMasterNavigationTitle("Link a page")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                AppToolbar.item(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .buttonStyle(TimeMasterToolbarTextButtonStyle())
                }
            }
        }
        .keyNavHost()
        #if os(macOS)
        .frame(minWidth: 600, minHeight: 540)
        #endif
    }

    /// The titles of the pages above `page`, for telling apart pages with the same title.
    private func trail(of page: ExercisePage) -> String {
        store.breadcrumbs(for: page.id).dropLast().map(\.title).joined(separator: " › ")
    }

    private func tile(_ page: ExercisePage) -> some View {
        let isLinked = linkedIDs.contains(page.manifest.id)
        let shape = RoundedRectangle(cornerRadius: 14, style: .continuous)
        return Button {
            onPick(page.manifest.id)
            dismiss()
        } label: {
            VStack(alignment: .leading, spacing: 6) {
                ZStack {
                    Theme.surface
                    if let url = page.coverImageURL, ChecklistMedia.isPicture(url.lastPathComponent) {
                        SkillLocalImage(url: url, maxPixel: 480)
                    } else if page.isSkillLike {
                        SkillPageIconTile(page: page, size: 44)
                    } else {
                        Image(systemName: ChecklistLook.symbol(for: page))
                            .font(.system(size: 26, weight: .semibold))
                            .foregroundStyle(Theme.toolbarOrange)
                    }
                }
                .frame(height: tileWidth * 0.62)
                .clipShape(shape)
                .overlay(shape.strokeBorder(isLinked ? Theme.toolbarOrange : Theme.separator, lineWidth: isLinked ? 3 : 1))
                .overlay(alignment: .topLeading) {
                    Image(systemName: ChecklistLook.symbol(for: page))
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(5)
                        .background(Color.black.opacity(0.55), in: Circle())
                        .padding(6)
                }
                Text(page.title)
                    .font(TimeMasterFont.rowTitle())
                    .foregroundStyle(Theme.textPrimary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                let trail = trail(of: page)
                if !trail.isEmpty {
                    Text(trail)
                        .font(TimeMasterFont.micro())
                        .foregroundStyle(Theme.textSecondary)
                        .lineLimit(1)
                }
            }
            .contentShape(Rectangle())
        }
        .keyNavPlainButtonStyle(shape: .roundedRectangle(cornerRadius: 14))
        .accessibilityLabel(page.title)
        .accessibilityValue(isLinked ? "Linked" : "")
        .accessibilityAddTraits(isLinked ? .isSelected : [])
    }
}
