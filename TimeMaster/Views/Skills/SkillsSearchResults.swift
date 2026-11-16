import SwiftUI
import TimeMasterCore

/// Search results of the Skills page: every page inside the listed skills whose title, notes, comments, links,
/// groups, to-dos or milestones hold the query, grouped by skill, each with the line that matched.
struct SkillsSearchResults: View {
    let query: String
    /// The top-level skills, in the order the page shows them.
    let roots: [ExercisePage]
    let library: SkillLibrary
    let onOpen: (ExercisePage) -> Void

    private static let hitsPerSkill = 40

    private struct ResultGroup: Identifiable {
        let root: ExercisePage
        let hits: [ExercisePage]
        var id: String { root.manifest.id }
    }

    private var groups: [ResultGroup] {
        roots.compactMap { root in
            let hits = ([root] + library.pages(below: root)).filter { SkillSearchSnippet.matches($0.manifest, query: query) }
            return hits.isEmpty ? nil : ResultGroup(root: root, hits: Array(hits.prefix(Self.hitsPerSkill)))
        }
    }

    var body: some View {
        let results = groups
        if results.isEmpty {
            VStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 34, weight: .semibold))
                    .foregroundStyle(Theme.textSecondary)
                Text("Nothing called “\(query)”")
                    .font(TimeMasterFont.sectionTitle())
                    .foregroundStyle(Theme.textPrimary)
                    .multilineTextAlignment(.center)
                Text("Try a word from a title, a note or a link.")
                    .font(TimeMasterFont.secondary())
                    .foregroundStyle(Theme.textSecondary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(.top, 48)
            .accessibilityElement(children: .combine)
        } else {
            LazyVStack(alignment: .leading, spacing: 20) {
                ForEach(results) { group in
                    VStack(alignment: .leading, spacing: 8) {
                        header(group)
                        ForEach(group.hits, id: \.manifest.id) { page in
                            hitRow(page, root: group.root)
                        }
                    }
                }
            }
        }
    }

    private func header(_ group: ResultGroup) -> some View {
        HStack(spacing: 8) {
            SkillPageIconTile(page: group.root, size: 20)
            Text(group.root.title)
                .font(TimeMasterFont.black(12, relativeTo: .caption))
                .tracking(1.0)
                .textCase(.uppercase)
                .foregroundStyle(Theme.textSecondary)
                .lineLimit(1)
            Spacer(minLength: 0)
            Text("\(group.hits.count)")
                .font(TimeMasterFont.technical())
                .foregroundStyle(Theme.textSecondary)
        }
        .padding(.horizontal, 4)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isHeader)
    }

    private func hitRow(_ page: ExercisePage, root: ExercisePage) -> some View {
        let snippet = SkillSearchSnippet.make(for: page.manifest, query: query)
        let path = library.pathText(of: page, below: root)
        return Button {
            onOpen(page)
        } label: {
            HStack(spacing: 12) {
                SkillPageIconTile(page: page, size: 30)
                    .frame(width: 40, height: 40)
                    .background(Color.black.opacity(0.22), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                VStack(alignment: .leading, spacing: 2) {
                    Text(page.title)
                        .font(TimeMasterFont.rowTitle())
                        .foregroundStyle(Theme.textPrimary)
                        .lineLimit(1)
                    Text(path.isEmpty ? kindLabel(page) : path)
                        .font(TimeMasterFont.caption())
                        .foregroundStyle(Theme.textSecondary)
                        .lineLimit(1)
                    if let snippet {
                        HStack(alignment: .firstTextBaseline, spacing: 5) {
                            Image(systemName: snippet.systemImage)
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(Theme.toolbarOrange)
                            Text(snippet.text)
                                .font(TimeMasterFont.caption())
                                .lineLimit(2)
                                .multilineTextAlignment(.leading)
                        }
                        .foregroundStyle(Theme.textPrimary.opacity(0.78))
                    }
                }
                Spacer(minLength: 8)
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(Theme.textSecondary)
                    .accessibilityHidden(true)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity, minHeight: 56, alignment: .leading)
            .modifier(TimeMasterCardSurface(cornerRadius: 14, flat: true))
            .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(TimeMasterCardButtonStyle())
        .keyNavShape(.roundedRectangle(cornerRadius: 14))
        .accessibilityLabel(page.title)
        .accessibilityValue(snippet?.text ?? (path.isEmpty ? kindLabel(page) : path))
    }

    private func kindLabel(_ page: ExercisePage) -> String {
        switch page.pageType {
        case .skill: "Skill"
        case .tutorial: "Tutorial"
        case .exercise: "Exercise"
        case .note: "Note"
        case nil: "Folder"
        }
    }
}
