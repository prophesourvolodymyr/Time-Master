import SwiftUI

struct MarkdownSlashItem: Identifiable {
    enum Action {
        case kind(MarkdownBlock.Kind)
        case image
        case linkCard
    }

    let id: String
    let title: String
    let symbol: String
    let keywords: [String]
    let action: Action

    static let all: [MarkdownSlashItem] = [
        MarkdownSlashItem(id: "text", title: "Text", symbol: "textformat", keywords: ["paragraph", "plain"], action: .kind(.paragraph)),
        MarkdownSlashItem(id: "h1", title: "Heading 1", symbol: "textformat.size.larger", keywords: ["title", "h1", "#"], action: .kind(.heading(1))),
        MarkdownSlashItem(id: "h2", title: "Heading 2", symbol: "textformat.size", keywords: ["h2", "##", "subtitle"], action: .kind(.heading(2))),
        MarkdownSlashItem(id: "h3", title: "Heading 3", symbol: "textformat.size.smaller", keywords: ["h3", "###"], action: .kind(.heading(3))),
        MarkdownSlashItem(id: "bullet", title: "Bulleted list", symbol: "list.bullet", keywords: ["list", "ul", "-"], action: .kind(.bullet)),
        MarkdownSlashItem(id: "numbered", title: "Numbered list", symbol: "list.number", keywords: ["list", "ol", "1."], action: .kind(.numbered)),
        MarkdownSlashItem(id: "todo", title: "To-do list", symbol: "checkmark.square", keywords: ["task", "checkbox", "check"], action: .kind(.todo(false))),
        MarkdownSlashItem(id: "quote", title: "Quote", symbol: "text.quote", keywords: ["callout", ">"], action: .kind(.quote)),
        MarkdownSlashItem(id: "code", title: "Code", symbol: "chevron.left.forwardslash.chevron.right", keywords: ["snippet", "```"], action: .kind(.code(""))),
        MarkdownSlashItem(id: "divider", title: "Divider", symbol: "minus", keywords: ["line", "rule", "---"], action: .kind(.divider)),
        MarkdownSlashItem(id: "image", title: "Image", symbol: "photo", keywords: ["picture", "photo", "media"], action: .image),
        MarkdownSlashItem(id: "card", title: "Link card", symbol: "link", keywords: ["bookmark", "thumbnail", "embed", "url"], action: .linkCard)
    ]

    static func matches(_ query: String) -> [MarkdownSlashItem] {
        let needle = query.trimmingCharacters(in: .whitespaces).lowercased()
        guard !needle.isEmpty else { return all }
        return all.filter { item in
            item.title.lowercased().contains(needle) || item.keywords.contains { $0.lowercased().hasPrefix(needle) }
        }
    }
}

struct MarkdownSlashState: Equatable {
    var blockID: UUID
    var query: String
}

struct MarkdownPasteOffer: Equatable, Identifiable {
    var id = UUID()
    var blockID: UUID
    var url: URL
}

struct MarkdownLinkMetadata {
    var title: String?
    var thumbnailURL: String?
}

@MainActor
final class MarkdownEditorSession: ObservableObject {
    @Published private(set) var document: MarkdownDocument
    @Published private(set) var focus: MarkdownFocusRequest?
    @Published private(set) var focusedBlockID: UUID?
    @Published private(set) var slash: MarkdownSlashState?
    @Published private(set) var pasteOffer: MarkdownPasteOffer?
    @Published var imagePickerTarget: UUID?
    @Published var thumbnailPickerTarget: UUID?
    @Published var linkPromptTarget: UUID?
    @Published var errorMessage: String?

    var fetchMetadata: (URL) async -> MarkdownLinkMetadata? = { url in
        guard let metadata = await LinkMetadataFetcher.fetchMetadata(for: [url.absoluteString], existing: []).first else { return nil }
        return MarkdownLinkMetadata(
            title: LinkMetadataFetcher.usableTitle(metadata.title, platform: metadata.platform),
            thumbnailURL: metadata.thumbnailURL
        )
    }
    var assets: MarkdownAssets?
    var onEmit: (String) -> Void = { _ in }
    private(set) var lastEmitted: String
    private var controllers: [UUID: MarkdownTextController] = [:]
    private var offerTask: Task<Void, Never>?

    init(markdown: String) {
        var document = MarkdownDocument(markdown: markdown)
        document.ensureTrailingParagraph()
        self.document = document
        lastEmitted = markdown
    }

    func load(markdown: String) {
        guard markdown != lastEmitted else { return }
        var document = MarkdownDocument(markdown: markdown)
        document.ensureTrailingParagraph()
        self.document = document
        lastEmitted = markdown
        slash = nil
        pasteOffer = nil
    }

    func controller(for id: UUID) -> MarkdownTextController {
        if let existing = controllers[id] { return existing }
        let controller = MarkdownTextController()
        controllers[id] = controller
        return controller
    }

    var focusedController: MarkdownTextController? {
        focusedBlockID.flatMap { controllers[$0] }
    }

    var focusedBlock: MarkdownBlock? {
        focusedBlockID.flatMap { id in document.blocks.first { $0.id == id } }
    }

    func placeholder(for block: MarkdownBlock) -> String {
        guard block.text.isEmpty else { return "" }
        switch block.kind {
        case .heading(let level): return "Heading \(level)"
        case .bullet, .numbered: return "List"
        case .todo: return "To-do"
        case .quote: return "Quote"
        case .code: return "Code"
        case .paragraph:
            if focusedBlockID == block.id { return "Type '/' for blocks" }
            return document.blocks.count <= 1 ? "Write something…" : ""
        default: return ""
        }
    }

    func handlers(for id: UUID) -> MarkdownTextHandlers {
        MarkdownTextHandlers(
            onFocus: { [weak self] in self?.didFocus(id) },
            onChange: { [weak self] text, selection in self?.textChanged(id, text: text, selection: selection) },
            onSelection: { _ in },
            onReturn: { [weak self] caret in self?.returnPressed(id, caret: caret) ?? false },
            onBackspaceAtStart: { [weak self] in self?.backspaceAtStart(id) ?? false },
            onTab: { [weak self] backwards in self?.tab(id, backwards: backwards) ?? false },
            onPasteString: { [weak self] string, selection in self?.pasteString(id, string: string, selection: selection) ?? false },
            onPasteImage: { [weak self] data in self?.pasteImage(id, data: data) ?? false },
            onMoveUp: { [weak self] in self?.moveFocus(from: id, forward: false) ?? false },
            onMoveDown: { [weak self] in self?.moveFocus(from: id, forward: true) ?? false },
            liveText: { [weak self] in
                guard let self, let index = self.document.index(of: id) else { return nil }
                return self.document.blocks[index].text
            }
        )
    }

    func didFocus(_ id: UUID) {
        if focusedBlockID != id { focusedBlockID = id }
    }

    func textChanged(_ id: UUID, text: String, selection: NSRange) {
        guard let index = document.index(of: id) else { return }
        guard document.blocks[index].text != text else { return }
        document.blocks[index].text = text
        if let caret = document.applyShortcut(id: id, caret: selection.location) {
            request(caret)
        }
        refreshSlash(for: id)
        if let offer = pasteOffer, offer.blockID == id,
           !(document.blocks.first { $0.id == id }?.text.contains(offer.url.absoluteString) ?? false) {
            dismissOffer()
        }
        commit()
    }

    func returnPressed(_ id: UUID, caret: Int) -> Bool {
        guard let index = document.index(of: id) else { return false }
        if document.blocks[index].isCode {
            let next = MarkdownBlock()
            document.insert(next, after: id)
            request(MarkdownCaret(blockID: next.id, location: 0))
            commit()
            return true
        }
        if let slash, slash.blockID == id, let first = MarkdownSlashItem.matches(slash.query).first {
            apply(first)
            return true
        }
        guard let target = document.splitBlock(id: id, caret: caret) else { return false }
        slash = nil
        request(target)
        commit()
        return true
    }

    func backspaceAtStart(_ id: UUID) -> Bool {
        guard let target = document.deleteBackwardAtStart(id: id) else { return false }
        request(target)
        commit()
        return true
    }

    func tab(_ id: UUID, backwards: Bool) -> Bool {
        guard let block = document.blocks.first(where: { $0.id == id }) else { return false }
        if block.isCode { return false }
        if block.isListItem {
            document.changeIndent(id: id, by: backwards ? -1 : 1)
            commit()
        }
        return true
    }

    func moveFocus(from id: UUID, forward: Bool) -> Bool {
        guard let index = document.index(of: id) else { return false }
        let target = forward ? document.nextTextualIndex(after: index) : document.previousTextualIndex(before: index)
        guard let target else { return false }
        let length = (document.blocks[target].text as NSString).length
        request(MarkdownCaret(blockID: document.blocks[target].id, location: forward ? 0 : length))
        return true
    }

    func pasteString(_ id: UUID, string: String, selection: NSRange) -> Bool {
        let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
        if let url = MarkdownLinkDetector.url(in: trimmed) {
            offer(url, in: id)
            return false
        }
        guard trimmed.contains("\n") else { return false }
        let parsed = MarkdownDocument(markdown: string).blocks
        guard parsed.count > 1 || parsed.first.map({ !$0.isParagraph }) == true else { return false }
        insert(parsed, replacingSelection: selection, in: id)
        return true
    }

    func pasteImage(_ id: UUID, data: Data) -> Bool {
        guard assets != nil else { return false }
        insertImage(data: data, near: id)
        return true
    }

    func insertImage(data: Data, near id: UUID?) {
        guard let assets else { return }
        do {
            let path = try assets.importImage(data: data)
            let block = MarkdownBlock(kind: .image(path), text: "")
            place(block, near: id)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func setThumbnail(data: Data, for id: UUID) {
        guard let assets, let index = document.index(of: id), case .linkCard(let url, _) = document.blocks[index].kind else { return }
        do {
            let path = try assets.importImage(data: data)
            document.blocks[index].kind = .linkCard(url: url, thumbnail: path)
            commit()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func removeThumbnail(for id: UUID) {
        guard let index = document.index(of: id), case .linkCard(let url, _) = document.blocks[index].kind else { return }
        document.blocks[index].kind = .linkCard(url: url, thumbnail: nil)
        commit()
    }

    func convertCardToLink(_ id: UUID) {
        guard let index = document.index(of: id), case .linkCard(let url, _) = document.blocks[index].kind else { return }
        let title = document.blocks[index].text.isEmpty ? url : document.blocks[index].text
        document.blocks[index] = MarkdownBlock(id: id, kind: .paragraph, text: "[\(title)](<\(url)>)")
        commit()
    }

    func insertLinkCard(url: URL, near id: UUID?, replacing replaceID: UUID? = nil) {
        let info = PageLinkInfo(urlString: url.absoluteString, metadata: nil)
        let card = MarkdownBlock(
            kind: .linkCard(url: url.absoluteString, thumbnail: info.thumbnailURL?.absoluteString),
            text: info.title
        )
        if let replaceID, let index = document.index(of: replaceID) {
            document.blocks[index] = MarkdownBlock(id: card.id, kind: card.kind, text: card.text)
            document.ensureTrailingParagraph()
            if let next = document.nextTextualIndex(after: index) {
                request(MarkdownCaret(blockID: document.blocks[next].id, location: 0))
            }
            commit()
        } else {
            place(card, near: id)
        }
        enrich(cardID: card.id, url: url)
    }

    func acceptOffer() {
        guard let offer = pasteOffer, let index = document.index(of: offer.blockID) else {
            dismissOffer()
            return
        }
        let block = document.blocks[index]
        let remaining = block.text.replacingOccurrences(of: offer.url.absoluteString, with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        dismissOffer()
        if remaining.isEmpty, block.isParagraph {
            insertLinkCard(url: offer.url, near: nil, replacing: block.id)
        } else {
            document.blocks[index].text = remaining
            insertLinkCard(url: offer.url, near: block.id)
        }
    }

    func acceptOfferAsTitledLink() {
        guard let offer = pasteOffer, let index = document.index(of: offer.blockID) else {
            dismissOffer()
            return
        }
        dismissOffer()
        let url = offer.url
        let info = PageLinkInfo(urlString: url.absoluteString, metadata: nil)
        let markdown = "[\(info.title)](<\(url.absoluteString)>)"
        document.blocks[index].text = document.blocks[index].text.replacingOccurrences(of: url.absoluteString, with: markdown)
        request(MarkdownCaret(blockID: document.blocks[index].id, location: (document.blocks[index].text as NSString).length))
        commit()
        Task { [weak self] in
            guard let self else { return }
            let metadata = await self.fetchMetadata(url)
            guard let title = metadata?.title, let current = self.document.index(of: offer.blockID) else { return }
            let updated = self.document.blocks[current].text.replacingOccurrences(of: markdown, with: "[\(title)](<\(url.absoluteString)>)")
            guard updated != self.document.blocks[current].text else { return }
            self.document.blocks[current].text = updated
            self.commit()
        }
    }

    func dismissOffer() {
        offerTask?.cancel()
        offerTask = nil
        pasteOffer = nil
    }

    func apply(_ item: MarkdownSlashItem) {
        guard let slash, let index = document.index(of: slash.blockID) else { return }
        let id = slash.blockID
        self.slash = nil
        document.blocks[index].text = ""
        switch item.action {
        case .kind(let kind):
            document.convert(id: id, to: kind)
            if kind == .divider, let next = document.nextTextualIndex(after: index) {
                request(MarkdownCaret(blockID: document.blocks[next].id, location: 0))
            } else {
                request(MarkdownCaret(blockID: id, location: 0))
            }
        case .image:
            imagePickerTarget = id
        case .linkCard:
            linkPromptTarget = id
        }
        commit()
    }

    func turnInto(_ kind: MarkdownBlock.Kind, id: UUID) {
        document.convert(id: id, to: kind)
        request(MarkdownCaret(blockID: id, location: (document.blocks.first { $0.id == id }?.text as NSString?)?.length ?? 0))
        commit()
    }

    func toggleTodo(_ id: UUID) {
        document.toggleTodo(id: id)
        commit()
    }

    func changeIndent(_ id: UUID, by delta: Int) {
        document.changeIndent(id: id, by: delta)
        commit()
    }

    func delete(_ id: UUID) {
        let caret = document.remove(id: id)
        document.ensureTrailingParagraph()
        if let caret { request(caret) }
        commit()
    }

    func duplicate(_ id: UUID) {
        guard let copy = document.duplicate(id: id) else { return }
        request(MarkdownCaret(blockID: copy, location: 0))
        commit()
    }

    func move(_ id: UUID, offset: Int) {
        document.move(id: id, offset: offset)
        commit()
    }

    func focusEnd() {
        document.ensureTrailingParagraph()
        if let last = document.blocks.last {
            request(MarkdownCaret(blockID: last.id, location: (last.text as NSString).length))
        }
    }

    func insertURLFromPrompt(_ string: String) {
        guard let url = MarkdownLinkDetector.url(in: string.trimmingCharacters(in: .whitespacesAndNewlines)) ??
                MarkdownLinkDetector.url(in: "https://" + string.trimmingCharacters(in: .whitespacesAndNewlines)) else {
            errorMessage = "Enter a valid web link."
            return
        }
        if let target = linkPromptTarget, let index = document.index(of: target), document.blocks[index].isParagraph, document.blocks[index].text.isEmpty {
            insertLinkCard(url: url, near: nil, replacing: target)
        } else {
            insertLinkCard(url: url, near: linkPromptTarget ?? focusedBlockID)
        }
        linkPromptTarget = nil
    }

    func importPickedImage(_ data: Data) {
        let target = imagePickerTarget
        imagePickerTarget = nil
        if let target, let index = document.index(of: target), document.blocks[index].isParagraph, document.blocks[index].text.isEmpty {
            guard let assets else { return }
            do {
                let path = try assets.importImage(data: data)
                document.blocks[index] = MarkdownBlock(id: document.blocks[index].id, kind: .image(path), text: "")
                document.ensureTrailingParagraph()
                if let next = document.nextTextualIndex(after: index) {
                    request(MarkdownCaret(blockID: document.blocks[next].id, location: 0))
                }
                commit()
            } catch {
                errorMessage = error.localizedDescription
            }
        } else {
            insertImage(data: data, near: target ?? focusedBlockID)
        }
    }

    func importPickedThumbnail(_ data: Data) {
        guard let target = thumbnailPickerTarget else { return }
        thumbnailPickerTarget = nil
        setThumbnail(data: data, for: target)
    }

    private func place(_ block: MarkdownBlock, near id: UUID?) {
        if let id, let index = document.index(of: id),
           document.blocks[index].isParagraph, document.blocks[index].text.isEmpty {
            document.blocks[index] = MarkdownBlock(id: block.id, kind: block.kind, text: block.text)
        } else {
            document.insert(block, after: id ?? document.blocks.last?.id)
        }
        document.ensureTrailingParagraph()
        if let index = document.index(of: block.id), let next = document.nextTextualIndex(after: index) {
            request(MarkdownCaret(blockID: document.blocks[next].id, location: 0))
        }
        commit()
    }

    private func insert(_ blocks: [MarkdownBlock], replacingSelection selection: NSRange, in id: UUID) {
        guard let index = document.index(of: id) else { return }
        let block = document.blocks[index]
        let source = block.text as NSString
        let range = MediaCommentFormatting.clamped(selection, in: block.text)
        let before = source.substring(to: range.location)
        let after = source.substring(from: NSMaxRange(range))
        var inserted = blocks
        if before.isEmpty, block.isParagraph {
            document.blocks.remove(at: index)
            document.blocks.insert(contentsOf: inserted, at: index)
        } else {
            document.blocks[index].text = before
            document.blocks.insert(contentsOf: inserted, at: index + 1)
        }
        if !after.isEmpty {
            let tail = MarkdownBlock(kind: .paragraph, text: after)
            let last = inserted.last?.id ?? id
            document.insert(tail, after: last)
            inserted.append(tail)
        }
        document.ensureTrailingParagraph()
        if let last = inserted.last, let lastIndex = document.index(of: last.id) {
            let length = (document.blocks[lastIndex].text as NSString).length
            if document.blocks[lastIndex].isTextual {
                request(MarkdownCaret(blockID: last.id, location: after.isEmpty ? length : 0))
            }
        }
        commit()
    }

    private func enrich(cardID: UUID, url: URL) {
        Task { [weak self] in
            guard let self else { return }
            let metadata = await self.fetchMetadata(url)
            guard let metadata, let index = self.document.index(of: cardID),
                  case .linkCard(let currentURL, let currentThumbnail) = self.document.blocks[index].kind,
                  currentURL == url.absoluteString else { return }
            if let title = metadata.title {
                self.document.blocks[index].text = title
            }
            if currentThumbnail == nil, let candidate = Self.absoluteThumbnail(metadata.thumbnailURL, relativeTo: url) {
                self.document.blocks[index].kind = .linkCard(url: currentURL, thumbnail: candidate)
            }
            self.commit()
        }
    }

    private static func absoluteThumbnail(_ candidate: String?, relativeTo page: URL) -> String? {
        guard let candidate = candidate?.trimmingCharacters(in: .whitespacesAndNewlines), !candidate.isEmpty else { return nil }
        if candidate.hasPrefix("//") { return "https:" + candidate }
        guard let resolved = URL(string: candidate, relativeTo: page)?.absoluteURL,
              let scheme = resolved.scheme?.lowercased(), scheme == "http" || scheme == "https" else { return nil }
        return resolved.absoluteString
    }

    private func offer(_ url: URL, in id: UUID) {
        pasteOffer = MarkdownPasteOffer(blockID: id, url: url)
        offerTask?.cancel()
        offerTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 9_000_000_000)
            guard !Task.isCancelled else { return }
            self?.pasteOffer = nil
        }
    }

    private func refreshSlash(for id: UUID) {
        guard let block = document.blocks.first(where: { $0.id == id }),
              block.isParagraph, block.text.hasPrefix("/"), block.text.count <= 24, !block.text.contains("\n") else {
            if slash != nil { slash = nil }
            return
        }
        let state = MarkdownSlashState(blockID: id, query: String(block.text.dropFirst()))
        if slash != state { slash = state }
    }

    private func request(_ caret: MarkdownCaret) {
        focus = MarkdownFocusRequest(blockID: caret.blockID, location: caret.location)
        focusedBlockID = caret.blockID
    }

    private func commit() {
        let markdown = document.markdown
        guard markdown != lastEmitted else { return }
        lastEmitted = markdown
        onEmit(markdown)
    }
}
