import SwiftUI
import TimeMasterCore

/// Search results of the Skills page: every page inside the listed skills whose title, notes, comments, links,
/// groups, to-dos or milestones hold the query, by skill under the page's category sections (a section with no match
/// is left out), each hit with the line that matched.
struct SkillsSearchResults: View {
    let query: String
    /// The listed skills by section, in the order the page shows them.
    let sections: [SkillCategorySection]
    let library: SkillLibrary
    let onOpen: (ExercisePage) -> Void

    private static let hitsPerSkill = 40

    private struct ResultGroup: Identifiable {
        let root: ExercisePage
        let hits: [ExercisePage]
        var id: String { root.manifest.id }
    }

    private struct ResultSection: Identifiable {
        let category: SkillCategory
        let groups: [ResultGroup]
        var id: SkillCategory { category }
    }

    private var resultSections: [ResultSection] {
        sections.compactMap { section in
            let groups = section.entries.compactMap { entry -> ResultGroup? in
                let root = entry.page
                let hits = ([root] + library.pages(below: root)).filter { SkillSearchSnippet.matches($0.manifest, query: query) }
                return hits.isEmpty ? nil : ResultGroup(root: root, hits: Array(hits.prefix(Self.hitsPerSkill)))
            }
            return groups.isEmpty ? nil : ResultSection(category: section.category, groups: groups)
        }
    }

    var body: some View {
        let results = resultSections
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
            LazyVStack(alignment: .leading, spacing: 26) {
                ForEach(results) { section in
                    VStack(alignment: .leading, spacing: 16) {
                        SkillCategoryHeader(category: section.category, count: section.groups.count)
                        ForEach(section.groups) { group in
                            VStack(alignment: .leading, spacing: 8) {
                                header(group, category: section.category)
                                ForEach(group.hits, id: \.manifest.id) { page in
                                    hitRow(page, root: group.root, category: section.category)
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    private func header(_ group: ResultGroup, category: SkillCategory) -> some View {
        HStack(spacing: 8) {
            SkillCardIcon(page: group.root, category: category, size: 22)
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

    private func hitRow(_ page: ExercisePage, root: ExercisePage, category: SkillCategory) -> some View {
        let snippet = SkillSearchSnippet.make(for: page.manifest, query: query)
        let path = library.pathText(of: page, below: root)
        return Button {
            onOpen(page)
        } label: {
            HStack(spacing: 12) {
                SkillCardIcon(page: page, category: category, size: 40)
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
        .buttonStyle(SkillsPressStyle(cornerRadius: 14))
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
