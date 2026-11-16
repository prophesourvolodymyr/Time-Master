import SwiftUI
import TimeMasterCore

/// Moves a page to the top of the Database or inside another container, skill or tutorial (never inside itself), picked
/// from a searchable list that shows where each place sits.
struct ContainerMoveSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var store: DatabaseStore

    let page: ExercisePage

    @State private var query = ""
    @FocusState private var searchFocused: Bool

    private struct Place: Identifiable {
        /// nil: the top of the Database.
        let target: ExercisePage?
        let path: String
        let depth: Int

        var id: String { target?.manifest.id ?? "top" }
        var title: String { target?.title ?? "Top of the Database" }
    }

    private var trimmedQuery: String { query.trimmingCharacters(in: .whitespacesAndNewlines) }

    /// Every place the page can go, the top first, then the tree depth first; filtered by the query.
    private var places: [Place] {
        var result = [Place(target: nil, path: "", depth: 0)]
        func visit(_ pages: [ExercisePage], path: [String]) {
            for candidate in pages where candidate.isContainer && candidate.manifest.id != page.manifest.id {
                result.append(Place(target: candidate, path: path.joined(separator: " › "), depth: path.count))
                visit(candidate.children, path: path + [candidate.title])
            }
        }
        visit(store.rootPages, path: [])
        let needle = trimmedQuery
        guard !needle.isEmpty else { return result }
        return result.filter { place in
            guard place.target != nil else { return false }
            return "\(place.title) \(place.path)".range(of: needle, options: [.caseInsensitive, .diacriticInsensitive]) != nil
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.background.ignoresSafeArea()
                ScrollView {
                    VStack(alignment: .leading, spacing: 12) {
                        ContainerSearchField(text: $query, prompt: "Search containers", isFocused: $searchFocused)
                        let list = places
                        if list.isEmpty {
                            Text("No container called “\(trimmedQuery)”")
                                .font(TimeMasterFont.secondary())
                                .foregroundStyle(Theme.textSecondary)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 24)
                        } else {
                            LazyVStack(alignment: .leading, spacing: 8) {
                                ForEach(list) { place in
                                    row(place)
                                }
                            }
                        }
                    }
                    .padding(20)
                }
            }
            .timeMasterNavigationTitle("Move “\(page.title)”")
            .toolbar {
                AppToolbar.item(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
        .keyNavHost()
        .skillErrorAlert()
        .findCommand {
            searchFocused = true
            return true
        }
    }

    private func row(_ place: Place) -> some View {
        let isCurrent = place.target?.manifest.id == page.manifest.parentID
        return Button {
            move(to: place)
        } label: {
            HStack(spacing: 12) {
                icon(for: place)
                VStack(alignment: .leading, spacing: 2) {
                    Text(place.title)
                        .font(TimeMasterFont.rowTitle())
                        .foregroundStyle(Theme.textPrimary)
                        .lineLimit(1)
                    if !place.path.isEmpty {
                        Text(place.path)
                            .font(TimeMasterFont.caption())
                            .foregroundStyle(Theme.textSecondary)
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }
                }
                Spacer(minLength: 8)
                if isCurrent {
                    Text("Here now")
                        .font(TimeMasterFont.caption())
                        .foregroundStyle(Theme.toolbarOrange)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity, minHeight: 56, alignment: .leading)
            .modifier(TimeMasterCardSurface(cornerRadius: 14, flat: true))
        }
        .buttonStyle(ContainerTileButtonStyle(cornerRadius: 14))
        .disabled(isCurrent)
        .padding(.leading, trimmedQuery.isEmpty ? CGFloat(min(place.depth, 5)) * 14 : 0)
        .accessibilityLabel(place.title)
        .accessibilityValue(isCurrent ? "Here now" : place.path)
    }

    private func icon(for place: Place) -> some View {
        Group {
            if let target = place.target, target.isSkillLike {
                SkillPageIconTile(page: target, size: 30)
            } else {
                Image(systemName: place.target == nil ? "tray.full" : "folder.fill")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Theme.toolbarOrange)
            }
        }
        .frame(width: 36, height: 36)
        .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(Theme.surface2))
        .accessibilityHidden(true)
    }

    private func move(to place: Place) {
        let parentID = place.target?.manifest.id
        let order = place.target?.manifest.childIDs.count ?? store.rootPages.count
        let moved = SkillErrorCenter.shared.attempt("Move the page") {
            try store.movePage(id: page.manifest.id, newParentID: parentID, newOrder: order)
        }
        guard moved else { return }
        EverHaptic.success()
        dismiss()
    }
}
