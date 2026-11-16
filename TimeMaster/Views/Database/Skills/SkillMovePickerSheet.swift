import SwiftUI
import TimeMasterCore

/// "Move to…": the pages a sub-skill can move inside (skills, tutorials and plain folders), each with the titles of
/// the pages above it, searchable by either. The page itself, everything below it and the page it already sits in are
/// not offered.
struct SkillMovePickerSheet: View {
    /// The page being moved (a manifest id).
    let pageID: String

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var store: DatabaseStore
    @State private var query = ""

    private struct Candidate: Identifiable {
        let page: ExercisePage
        /// "Guitar › Chords": the titles above it.
        let trail: String
        /// The trail and the title, what the list sorts by.
        let sortKey: String

        var id: String { page.manifest.id }
    }

    private var candidates: [Candidate] {
        let pages = store.allPagesFlat
        var byID: [String: ExercisePage] = [:]
        for page in pages where byID[page.manifest.id] == nil { byID[page.manifest.id] = page }
        var excluded: Set<String> = [pageID]
        var pending = byID[pageID]?.manifest.childIDs ?? []
        while let next = pending.popLast() {
            guard excluded.insert(next).inserted else { continue }
            pending.append(contentsOf: byID[next]?.manifest.childIDs ?? [])
        }
        if let parentID = byID[pageID]?.manifest.parentID { excluded.insert(parentID) }

        func trail(of page: ExercisePage) -> String {
            var titles: [String] = []
            var seen: Set<String> = [page.manifest.id]
            var current = page.manifest.parentID.flatMap { byID[$0] }
            while let ancestor = current, seen.insert(ancestor.manifest.id).inserted {
                titles.insert(ancestor.title, at: 0)
                current = ancestor.manifest.parentID.flatMap { byID[$0] }
            }
            return titles.joined(separator: " › ")
        }

        let text = query.trimmingCharacters(in: .whitespacesAndNewlines)
        return pages
            .filter { page in
                !excluded.contains(page.manifest.id) && page.isContainer && page.pageType != .exercise && !page.isNote
            }
            .map { page -> Candidate in
                let path = trail(of: page)
                return Candidate(page: page, trail: path, sortKey: path.isEmpty ? page.title : path + " › " + page.title)
            }
            .filter { text.isEmpty || $0.page.title.localizedCaseInsensitiveContains(text) || $0.trail.localizedCaseInsensitiveContains(text) }
            .sorted { $0.sortKey.localizedStandardCompare($1.sortKey) == .orderedAscending }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                let shown = candidates
                if shown.isEmpty {
                    VStack(spacing: 10) {
                        Image(systemName: "tray")
                            .font(.system(size: 34))
                            .foregroundStyle(Theme.textSecondary)
                        Text(query.isEmpty ? "No page can hold it" : "No match")
                            .font(TimeMasterFont.secondary())
                            .foregroundStyle(Theme.textSecondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, 60)
                } else {
                    LazyVStack(spacing: SkillMetrics.s2) {
                        ForEach(shown) { candidate in
                            row(candidate)
                        }
                    }
                    .padding(SkillMetrics.s5)
                    .frame(maxWidth: 640)
                    .frame(maxWidth: .infinity)
                }
            }
            .background(Theme.background.ignoresSafeArea())
            .searchable(text: $query)
            .timeMasterNavigationTitle("Move to…")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                AppToolbar.item(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
        .keyNavHost()
        .skillErrorAlert()
        #if os(macOS)
        .frame(minWidth: 480, idealWidth: 520, minHeight: 520, idealHeight: 640)
        #endif
    }

    private func row(_ candidate: Candidate) -> some View {
        let page = candidate.page
        return Button {
            move(into: page)
        } label: {
            HStack(spacing: SkillMetrics.s3) {
                if page.isSkillLike {
                    SkillPageIconTile(page: page, size: 32, tilesSymbols: true)
                } else {
                    Image(systemName: "folder")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Theme.toolbarOrange)
                        .frame(width: 32, height: 32)
                        .skillTile(cornerRadius: 10)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(TimeMasterFont.initialCapitalizedTitle(page.title))
                        .font(TimeMasterFont.rowTitle())
                        .foregroundStyle(Theme.textPrimary)
                        .lineLimit(1)
                    if !candidate.trail.isEmpty {
                        Text(candidate.trail)
                            .font(TimeMasterFont.caption())
                            .foregroundStyle(Theme.textSecondary)
                            .lineLimit(1)
                    }
                }
                Spacer(minLength: 0)
                Image(systemName: "arrow.turn.down.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Theme.textSecondary)
            }
            .padding(.horizontal, SkillMetrics.s3)
            .frame(minHeight: SkillMetrics.row)
            .modifier(TimeMasterCardSurface(cornerRadius: SkillMetrics.fieldRadius, flat: true))
            .contentShape(RoundedRectangle(cornerRadius: SkillMetrics.fieldRadius, style: .continuous))
        }
        .buttonStyle(SkillPressButtonStyle())
        .accessibilityLabel("Move inside \(page.title)")
    }

    private func move(into target: ExercisePage) {
        if SkillErrorCenter.shared.attempt("Move the sub-skill", { try store.moveSkillPage(pageID, into: target.manifest.id) }) {
            EverHaptic.success()
            dismiss()
        }
    }
}
