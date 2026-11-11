import SwiftUI
import TimeMasterCore

/// A skill page's to-do list: tick things off, add your own (Return keeps the next line ready), nest with Tab and
/// Shift-Tab or a swipe, split the list with section dividers, and give a to-do an icon, pictures and links to
/// workouts, pages, files and the web. The agent's to-dos and yours live in the same list.
struct SkillTodoSection: View {
    let pageID: String

    @EnvironmentObject private var store: DatabaseStore
    @EnvironmentObject private var workoutStore: WorkoutStore
    @EnvironmentObject private var navigationState: DatabaseNavigationState
    @Environment(\.openURL) private var openURL
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @AppStorage("tm.todos.hidesDone") private var hidesDone = false
    @State private var focus: Focus?
    @State private var draft = Draft()
    @State private var collapsed: Set<String> = []
    @State private var pendingDelete: TodoItem?
    @State private var editor: ChecklistEditorRoute?
    @State private var iconTarget: IconTarget?
    @State private var renamingSectionID: String?
    @State private var errorMessage: String?
    @State private var gallerySelection: URL?

    private enum Focus: Hashable {
        case row(String)
        case draft
    }

    /// Where the next to-do goes: under `parentID` (the top level without one), right after the sibling `afterID`
    /// (the end of that level without one).
    private struct Draft: Equatable {
        var parentID: String?
        var afterID: String?
        var text = ""
    }

    private struct IconTarget: Identifiable { let id: String }

    /// A line on screen: a section divider or a to-do with its level and place among its siblings.
    private struct Line: Identifiable {
        let item: TodoItem
        let depth: Int
        let parentID: String?
        let index: Int
        let siblings: [TodoItem]
        var id: String { item.id }
    }

    var body: some View {
        let todos = store.checklist(TodoItem.self, of: pageID)
        let lines = visibleLines(todos, parentID: nil, depth: 1)
        let active = validated(draft, in: todos)
        let place = slot(for: active, in: lines)
        VStack(alignment: .leading, spacing: 4) {
            ChecklistSectionHeader(
                symbol: "checklist", title: "To-do", done: todos.progressDone, total: todos.progressTotal,
                addLabel: "New to-do", onAdd: { editor = .create(parentID: nil, index: nil) }
            ) {
                Toggle(isOn: $hidesDone) { Label("Hide what's done", systemImage: "eye.slash") }
                Button { addSection(in: todos, after: nil) } label: { Label("Add a section", systemImage: "text.badge.plus") }
            }
            .padding(.bottom, 4)
            if let errorMessage {
                ChecklistErrorBanner(message: errorMessage) { self.errorMessage = nil }
            }
            if todos.isEmpty {
                stateLine(symbol: "checklist", text: "Nothing to do yet")
            } else if hidesDone, todos.progressTotal > 0, todos.openCount == 0 {
                stateLine(symbol: "checkmark.seal.fill", text: "All done")
            }
            LazyVStack(alignment: .leading, spacing: 0) {
                ForEach(Array(lines.enumerated()), id: \.element.id) { position, line in
                    if position == place.index { draftRow(depth: place.depth, active: active, todos: todos) }
                    lineView(line, todos: todos)
                }
                if place.index >= lines.count { draftRow(depth: place.depth, active: active, todos: todos) }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .sheet(item: $editor) { route in
            ChecklistEditorSheet<TodoItem>(pageID: pageID, route: route, existing: existing(for: route))
                .environmentObject(store)
                .environmentObject(workoutStore)
        }
        .sheet(item: $iconTarget) { target in
            ChecklistIconChooserSheet<TodoItem>(pageID: pageID, entryID: target.id)
                .environmentObject(store)
        }
        .confirmationDialog(
            "Delete this to-do?",
            isPresented: Binding(get: { pendingDelete != nil }, set: { if !$0 { pendingDelete = nil } }),
            titleVisibility: .visible,
            presenting: pendingDelete
        ) { item in
            Button("Delete", role: .destructive) { remove(item.id) }
            Button("Cancel", role: .cancel) {}
        } message: { item in
            Text("“\(item.title)” and \(item.children.flattened().count) inside")
        }
        .checklistGallery(pageID: pageID, selection: $gallerySelection)
    }

    private func stateLine(symbol: String, text: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: symbol)
                .foregroundStyle(Theme.toolbarOrange)
            Text(text)
                .font(TimeMasterFont.secondary())
                .foregroundStyle(Theme.textSecondary)
        }
        .padding(.vertical, 6)
    }

    // MARK: Lines

    private func visibleLines(_ items: [TodoItem], parentID: String?, depth: Int) -> [Line] {
        var result: [Line] = []
        for (index, item) in items.enumerated() {
            if item.isSection {
                result.append(Line(item: item, depth: depth, parentID: parentID, index: index, siblings: items))
                continue
            }
            if hidesDone && item.isDone { continue }
            result.append(Line(item: item, depth: depth, parentID: parentID, index: index, siblings: items))
            if !collapsed.contains(item.id) {
                result += visibleLines(item.children, parentID: item.id, depth: depth + 1)
            }
        }
        return result
    }

    @ViewBuilder
    private func lineView(_ line: Line, todos: [TodoItem]) -> some View {
        if line.item.isSection {
            ChecklistSectionDivider(
                title: line.item.title,
                iconName: line.item.iconName,
                iconType: line.item.iconType,
                colorHex: line.item.colorHex,
                canMoveUp: line.index > 0,
                canMoveDown: line.index < line.siblings.count - 1,
                renamesOnAppear: renamingSectionID == line.item.id,
                onRename: { rename(line.item.id, to: $0, was: line.item.title) },
                onMove: { delta in step(line.item.id, by: delta) },
                onEdit: { editor = .edit(line.item.id) },
                onDelete: { remove(line.item.id) }
            )
            .padding(.top, 10)
            .onAppear {
                guard renamingSectionID == line.item.id else { return }
                DispatchQueue.main.async { renamingSectionID = nil }
            }
            .id(line.item.id)
        } else {
            todoRow(line)
        }
    }

    private func todoRow(_ line: Line) -> some View {
        let item = line.item
        let workouts = workoutStore.workouts
        let page = store.page(manifestID: pageID)
        let above = line.index > 0 ? line.siblings[line.index - 1] : nil
        var targets: [String: ChecklistLinkTarget] = [:]
        for link in item.links { targets[link.id] = store.checklistTarget(of: link, on: pageID, workouts: workouts) }
        return TodoRowView(
            item: item,
            depth: line.depth,
            hasChildren: !item.children.isEmpty,
            isCollapsed: collapsed.contains(item.id),
            canIndent: above.map { !$0.isSection } ?? false,
            canOutdent: line.parentID != nil,
            canMoveUp: line.index > 0,
            canMoveDown: line.index < line.siblings.count - 1,
            isFocused: focus == .row(item.id),
            artwork: ChecklistArtwork.resolve(item, pageID: pageID, store: store, workouts: workouts),
            targets: targets,
            pictureURLs: item.imageFilenames.compactMap { store.checklistPictureURL($0, on: pageID) },
            linkMetadata: page?.manifest.linkMetadata ?? [],
            comments: page?.manifest.mediaComments ?? [:],
            actions: TodoRowActions(
                toggle: { toggle(item) },
                toggleCollapse: { toggleCollapse(item.id) },
                focusChanged: { focused in
                    if focused { focus = .row(item.id) } else if focus == .row(item.id) { focus = nil }
                },
                commitTitle: { rename(item.id, to: $0, was: item.title) },
                submit: { text in
                    rename(item.id, to: text, was: item.title)
                    draft = Draft(parentID: line.parentID, afterID: item.id)
                    focus = .draft
                },
                indent: { indent(item.id) },
                outdent: { outdent(item.id) },
                addSubTodo: {
                    collapsed.remove(item.id)
                    draft = Draft(parentID: item.id, afterID: nil)
                    focus = .draft
                },
                edit: { editor = .edit(item.id) },
                chooseIcon: { iconTarget = IconTarget(id: item.id) },
                moveUp: { step(item.id, by: -1) },
                moveDown: { step(item.id, by: 1) },
                remove: { askToRemove(item) },
                openLink: { _, target in
                    ChecklistLinkOpener.open(target, navigation: navigationState, openURL: openURL) { gallerySelection = $0 }
                },
                playWorkout: ChecklistLinkOpener.start,
                removeLink: { link in
                    perform { try store.updateChecklistEntry(TodoItem.self, item.id, in: pageID) { $0.links.removeAll { $0.id == link.id } } }
                },
                openPicture: { gallerySelection = $0 }
            )
        )
        .id(item.id)
    }

    // MARK: Draft (the line that adds a to-do)

    /// The draft as it applies now: when the entry it points at is gone or moved, it goes back to the end.
    private func validated(_ draft: Draft, in todos: [TodoItem]) -> Draft {
        var result = draft
        if let parent = draft.parentID, todos.entry(parent) == nil { result.parentID = nil; result.afterID = nil }
        if let after = result.afterID, todos.entry(after) == nil || todos.parentID(of: after) != result.parentID {
            result.afterID = nil
        }
        return result
    }

    /// Where the draft line sits among the lines, and at which level: after the whole visible subtree of the entry
    /// it follows, or at the end.
    private func slot(for draft: Draft, in lines: [Line]) -> (index: Int, depth: Int) {
        let depth = draft.parentID.flatMap { id in lines.first { $0.id == id }?.depth }.map { $0 + 1 } ?? 1
        guard let anchorID = draft.afterID ?? draft.parentID, let start = lines.firstIndex(where: { $0.id == anchorID }) else {
            return (lines.count, draft.parentID == nil ? 1 : depth)
        }
        var end = start + 1
        if !lines[start].item.isSection {
            while end < lines.count, lines[end].depth > lines[start].depth { end += 1 }
        }
        return (end, depth)
    }

    private func draftRow(depth: Int, active: Draft, todos: [TodoItem]) -> some View {
        HStack(alignment: .top, spacing: 6) {
            Color.clear.frame(width: 18, height: 34)
            Image(systemName: "plus.circle")
                .font(.system(size: 22, weight: .regular))
                .foregroundStyle(focus == .draft ? Theme.toolbarOrange : Theme.textSecondary.opacity(0.7))
                .frame(width: 34, height: 34)
                .accessibilityHidden(true)
            TodoTextField(
                text: $draft.text,
                placeholder: active.parentID == nil ? "Add a to-do…" : "Add a sub-to-do…",
                isFocused: focus == .draft,
                onFocusChange: { focused in
                    if focused {
                        focus = .draft
                    } else if focus == .draft {
                        focus = nil
                        if draft.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { draft = Draft() }
                    }
                },
                onSubmit: { submitDraft(active) },
                onIndent: { indentDraft(active, todos: todos) },
                onOutdent: { outdentDraft(active, todos: todos) },
                onDeleteWhenEmpty: { outdentDraft(active, todos: todos) },
                onCancel: { focus = nil }
            )
            .padding(.top, 7)
            .accessibilityLabel(active.parentID == nil ? "Add a to-do" : "Add a sub-to-do")
            if active.parentID == nil {
                Button { addSection(in: todos, after: active.afterID) } label: {
                    Image(systemName: "text.badge.plus")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Theme.textSecondary)
                        .frame(width: 34, height: 34)
                        .contentShape(Rectangle())
                }
                .keyNavPlainButtonStyle()
                .help("Add a section")
                .accessibilityLabel("Add a section")
            }
        }
        .padding(.leading, CGFloat(depth - 1) * TodoRowView.indentStep)
        .padding(.vertical, 3)
        .id("todo-draft")
    }

    private func submitDraft(_ active: Draft) {
        let text = draft.text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else {
            // Return on an empty line steps back a level, and at the top level ends the entry.
            if active.parentID != nil {
                outdentDraft(active, todos: store.checklist(TodoItem.self, of: pageID))
            } else {
                focus = nil
                draft = Draft()
            }
            return
        }
        perform {
            let added: TodoItem = try store.addChecklistEntry(TodoItem.self, title: text, to: pageID, under: active.parentID, after: active.afterID)
            EverHaptic.selection()
            draft = Draft(parentID: active.parentID, afterID: added.id)
            focus = .draft
        }
    }

    /// Tab on the draft line: it becomes a sub-to-do of the to-do just above it (never of a section).
    private func indentDraft(_ active: Draft, todos: [TodoItem]) {
        let siblings = active.parentID.flatMap { todos.entry($0)?.children } ?? todos
        let aboveID = active.afterID ?? siblings.last?.id
        guard let aboveID, let above = todos.entry(aboveID), !above.isSection else { return }
        guard (todos.depth(of: aboveID) ?? 0) + 1 <= TodoItem.maxDepth else { return }
        collapsed.remove(aboveID)
        draft = Draft(parentID: aboveID, afterID: nil, text: draft.text)
        focus = .draft
    }

    /// Shift-Tab (or Backspace on an empty line): the draft steps out a level, after the to-do it was under.
    private func outdentDraft(_ active: Draft, todos: [TodoItem]) {
        guard let parent = active.parentID else { return }
        draft = Draft(parentID: todos.parentID(of: parent), afterID: parent, text: draft.text)
        focus = .draft
    }

    // MARK: Changes

    private func addSection(in todos: [TodoItem], after afterID: String?) {
        let typed = draft.text.trimmingCharacters(in: .whitespacesAndNewlines)
        var index: Int?
        if let afterID, let position = todos.firstIndex(where: { $0.id == afterID }) { index = position + 1 }
        perform {
            let section: TodoItem = try store.addChecklistSection(TodoItem.self, title: typed.isEmpty ? "New section" : typed, to: pageID, at: index)
            if typed.isEmpty { renamingSectionID = section.id }
            draft = Draft(parentID: nil, afterID: section.id)
            EverHaptic.selection()
        }
    }

    private func toggle(_ item: TodoItem) {
        perform { try store.setChecklistEntry(TodoItem.self, item.id, done: !item.isDone, in: pageID) }
        EverHaptic.selection()
    }

    private func toggleCollapse(_ id: String) {
        withAnimation(reduceMotion ? nil : .easeOut(duration: 0.2)) {
            if collapsed.contains(id) { collapsed.remove(id) } else { collapsed.insert(id) }
        }
    }

    private func rename(_ id: String, to text: String, was old: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, trimmed != old else { return }
        perform { try store.updateChecklistEntry(TodoItem.self, id, in: pageID) { $0.title = trimmed } }
    }

    private func indent(_ id: String) {
        perform {
            if try store.indentChecklistEntry(TodoItem.self, id, in: pageID) {
                EverHaptic.selection()
                if let parent = store.checklist(TodoItem.self, of: pageID).parentID(of: id) { collapsed.remove(parent) }
            }
        }
    }

    private func outdent(_ id: String) {
        perform {
            if try store.outdentChecklistEntry(TodoItem.self, id, in: pageID) { EverHaptic.selection() }
        }
    }

    private func step(_ id: String, by delta: Int) {
        perform { try store.stepChecklistEntry(TodoItem.self, id, by: delta, in: pageID) }
    }

    private func askToRemove(_ item: TodoItem) {
        if item.children.isEmpty { remove(item.id) } else { pendingDelete = item }
    }

    private func remove(_ id: String) {
        perform { try store.removeChecklistEntry(TodoItem.self, id, from: pageID) }
    }

    private func existing(for route: ChecklistEditorRoute) -> TodoItem? {
        guard case .edit(let id) = route else { return nil }
        return store.checklist(TodoItem.self, of: pageID).entry(id)
    }

    private func perform(_ change: () throws -> Void) {
        do {
            try change()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
