import SwiftUI
import UniformTypeIdentifiers
#if os(iOS)
import PhotosUI
import UIKit
#endif

struct MarkdownEditorView: View {
    @Binding var text: String
    var assets: MarkdownAssets?
    var autofocus = false
    var showsBar = true
    var trailingSpace: CGFloat = 220
    @StateObject private var session: MarkdownEditorSession
    @State private var linkInput = ""
    @State private var showInlineLink = false
    @State private var inlineLabel = ""
    @State private var inlineAddress = ""
    #if os(iOS)
    @State private var pickedItem: PhotosPickerItem?
    #endif

    init(text: Binding<String>, assets: MarkdownAssets? = nil, autofocus: Bool = false, showsBar: Bool = true, trailingSpace: CGFloat = 220) {
        _text = text
        self.assets = assets
        self.autofocus = autofocus
        self.showsBar = showsBar
        self.trailingSpace = trailingSpace
        _session = StateObject(wrappedValue: MarkdownEditorSession(markdown: text.wrappedValue))
    }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 2) {
                    ForEach(Array(session.document.blocks.enumerated()), id: \.element.id) { index, block in
                        MarkdownBlockRow(
                            session: session,
                            block: block,
                            position: session.document.numberedPosition(at: index),
                            assets: assets
                        )
                        .id(block.id)
                    }
                    Color.clear
                        .frame(height: trailingSpace)
                        .contentShape(Rectangle())
                        .onTapGesture { session.focusEnd() }
                        .accessibilityHidden(true)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
            }
            .scrollDismissesKeyboard(.interactively)
            .onChange(of: session.focusedBlockID) { id in
                guard let id else { return }
                withAnimation(.easeOut(duration: 0.2)) { proxy.scrollTo(id) }
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) { bottomChrome }
        .onAppear {
            configure()
            if autofocus { session.focusEnd() }
        }
        .onChange(of: text) { session.load(markdown: $0) }
        #if os(iOS)
        .modifier(MarkdownPickers(session: session, pickedItem: $pickedItem))
        #else
        .modifier(MarkdownPickers(session: session))
        #endif
        .alert("Add link card", isPresented: Binding(
            get: { session.linkPromptTarget != nil },
            set: { if !$0 { session.linkPromptTarget = nil } }
        )) {
            TextField("https://", text: $linkInput)
            Button("Add") {
                session.insertURLFromPrompt(linkInput)
                linkInput = ""
            }
            Button("Cancel", role: .cancel) {
                session.linkPromptTarget = nil
                linkInput = ""
            }
        } message: {
            Text("Paste a link. It becomes a card with a thumbnail.")
        }
        .alert("Insert link", isPresented: $showInlineLink) {
            TextField("Text", text: $inlineLabel)
            TextField("https://", text: $inlineAddress)
            Button("Insert") { insertInlineLink() }
            Button("Cancel", role: .cancel) {}
        }
        .alert("Editor", isPresented: Binding(
            get: { session.errorMessage != nil },
            set: { if !$0 { session.errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(session.errorMessage ?? "")
        }
    }

    private func configure() {
        session.assets = assets
        session.onEmit = { markdown in
            if text != markdown { text = markdown }
        }
    }

    private func insertInlineLink() {
        guard let controller = session.focusedController else { return }
        let address = inlineAddress.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let url = MarkdownLinkDetector.url(in: address) ?? MarkdownLinkDetector.url(in: "https://" + address) else {
            session.errorMessage = "Enter a valid web link."
            return
        }
        controller.insertLink(label: inlineLabel.trimmingCharacters(in: .whitespacesAndNewlines), url: url)
        inlineLabel = ""
        inlineAddress = ""
    }

    private var bottomChrome: some View {
        VStack(spacing: 8) {
            if let slash = session.slash {
                slashMenu(slash)
            }
            if let offer = session.pasteOffer {
                offerBar(offer)
            }
            if showsBar {
                formattingBar
            }
        }
        .padding(.horizontal, 12)
        .padding(.top, 4)
        .padding(.bottom, 8)
        .animation(.easeOut(duration: 0.15), value: session.pasteOffer)
        .animation(.easeOut(duration: 0.15), value: session.slash)
    }

    @ViewBuilder
    private func slashMenu(_ slash: MarkdownSlashState) -> some View {
        let items = MarkdownSlashItem.matches(slash.query)
        if !items.isEmpty {
            ScrollView {
                VStack(spacing: 0) {
                    ForEach(items) { item in
                        Button {
                            session.apply(item)
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: item.symbol)
                                    .font(.system(size: 15, weight: .semibold))
                                    .frame(width: 28)
                                    .foregroundStyle(Theme.toolbarOrange)
                                Text(item.title)
                                    .font(TimeMasterFont.rowTitle())
                                    .foregroundStyle(Theme.textPrimary)
                                Spacer()
                            }
                            .padding(.horizontal, 14)
                            .padding(.vertical, 10)
                            .contentShape(Rectangle())
                        }
                        .keyNavPlainButtonStyle(shape: .roundedRectangle(cornerRadius: 8))
                    }
                }
            }
            .frame(maxHeight: 230)
            .background(Theme.surface2, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(Color.white.opacity(0.08), lineWidth: 1))
            .accessibilityLabel("Block menu")
        }
    }

    private func offerBar(_ offer: MarkdownPasteOffer) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "link")
                .foregroundStyle(Theme.toolbarOrange)
                .accessibilityLabel("Pasted link")
            Spacer(minLength: 4)
            Button("Thumbnail card") { session.acceptOffer() }
                .buttonStyle(TimeMasterActionButtonStyle(prominent: true, minimumSize: 36, horizontalPadding: 12))
                .lineLimit(1)
                .fixedSize(horizontal: true, vertical: false)
                .accessibilityHint("Turns the pasted link into a card with a thumbnail")
            Button("Titled link") { session.acceptOfferAsTitledLink() }
                .buttonStyle(TimeMasterActionButtonStyle(minimumSize: 36, horizontalPadding: 12))
                .lineLimit(1)
                .fixedSize(horizontal: true, vertical: false)
            Button {
                session.dismissOffer()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 12, weight: .bold))
            }
            .buttonStyle(TimeMasterActionButtonStyle(circular: true, minimumSize: 36))
            .accessibilityLabel("Keep as plain link")
        }
        .font(TimeMasterFont.black(13, relativeTo: .footnote))
        .padding(8)
        .background(Theme.surface2, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(Theme.toolbarOrange.opacity(0.4), lineWidth: 1))
    }

    private var formattingBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 4) {
                barButton("bold", "Bold", shortcut: "b") { session.focusedController?.wrap(prefix: "**", suffix: "**", placeholder: "bold") }
                barButton("italic", "Italic", shortcut: "i") { session.focusedController?.wrap(prefix: "*", suffix: "*", placeholder: "italic") }
                barButton("strikethrough", "Strikethrough", shortcut: nil) { session.focusedController?.wrap(prefix: "~~", suffix: "~~", placeholder: "text") }
                barButton("chevron.left.forwardslash.chevron.right", "Inline code", shortcut: "e") { session.focusedController?.wrap(prefix: "`", suffix: "`", placeholder: "code") }
                barButton("link", "Link", shortcut: "k") { beginInlineLink() }
                Divider().frame(height: 22)
                turnIntoMenu
                barButton("increase.indent", "Indent", shortcut: nil) { adjustIndent(1) }
                barButton("decrease.indent", "Outdent", shortcut: nil) { adjustIndent(-1) }
                Divider().frame(height: 22)
                barButton("photo", "Insert image", shortcut: nil) {
                    session.imagePickerTarget = session.focusedBlockID ?? session.document.blocks.last?.id
                }
                .disabled(assets == nil)
                barButton("rectangle.on.rectangle", "Insert link card", shortcut: nil) {
                    session.linkPromptTarget = session.focusedBlockID ?? session.document.blocks.last?.id
                }
                #if os(iOS)
                Divider().frame(height: 22)
                barButton("keyboard.chevron.compact.down", "Hide keyboard", shortcut: nil) {
                    UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                }
                #endif
            }
            .padding(6)
        }
        .background(Theme.surface2, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(Color.white.opacity(0.08), lineWidth: 1))
    }

    private var turnIntoMenu: some View {
        Menu {
            ForEach(MarkdownSlashItem.all) { item in
                if case .kind(let kind) = item.action {
                    Button {
                        if let id = session.focusedBlockID { session.turnInto(kind, id: id) }
                    } label: {
                        Label(item.title, systemImage: item.symbol)
                    }
                }
            }
        } label: {
            Image(systemName: "textformat")
                .font(.system(size: 15, weight: .semibold))
                .frame(width: 38, height: 38)
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .fixedSize()
        .keyNavTarget(shape: .roundedRectangle(cornerRadius: 10))
        .accessibilityLabel("Turn into")
    }

    private func barButton(_ symbol: String, _ label: String, shortcut: KeyEquivalent?, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 15, weight: .semibold))
                .frame(width: 38, height: 38)
        }
        .keyNavPlainButtonStyle(shape: .roundedRectangle(cornerRadius: 10))
        .foregroundStyle(Theme.textPrimary)
        .modifier(MarkdownShortcut(key: shortcut))
        .accessibilityLabel(label)
    }

    private func beginInlineLink() {
        guard let controller = session.focusedController else { return }
        let range = controller.selectedRange
        if range.length > 0, let block = session.focusedBlock {
            let source = block.text as NSString
            if NSMaxRange(range) <= source.length { inlineLabel = source.substring(with: range) }
        }
        inlineAddress = ""
        showInlineLink = true
    }

    private func adjustIndent(_ delta: Int) {
        guard let id = session.focusedBlockID else { return }
        session.changeIndent(id, by: delta)
    }
}

private struct MarkdownShortcut: ViewModifier {
    let key: KeyEquivalent?

    func body(content: Content) -> some View {
        if let key {
            content.keyboardShortcut(key, modifiers: .command)
        } else {
            content
        }
    }
}

#if os(iOS)
private struct MarkdownPickers: ViewModifier {
    @ObservedObject var session: MarkdownEditorSession
    @Binding var pickedItem: PhotosPickerItem?

    private var presented: Binding<Bool> {
        Binding(
            get: { session.imagePickerTarget != nil || session.thumbnailPickerTarget != nil },
            set: { isPresented in
                guard !isPresented else { return }
                DispatchQueue.main.async {
                    if pickedItem == nil {
                        session.imagePickerTarget = nil
                        session.thumbnailPickerTarget = nil
                    }
                }
            }
        )
    }

    func body(content: Content) -> some View {
        content
            .photosPicker(isPresented: presented, selection: $pickedItem, matching: .images)
            .onChange(of: pickedItem) { item in
                guard let item else { return }
                Task {
                    let data = try? await item.loadTransferable(type: Data.self)
                    await MainActor.run {
                        pickedItem = nil
                        guard let data else {
                            session.imagePickerTarget = nil
                            session.thumbnailPickerTarget = nil
                            return
                        }
                        if session.thumbnailPickerTarget != nil {
                            session.importPickedThumbnail(data)
                        } else {
                            session.importPickedImage(data)
                        }
                    }
                }
            }
    }
}
#else
private struct MarkdownPickers: ViewModifier {
    @ObservedObject var session: MarkdownEditorSession

    private var presented: Binding<Bool> {
        Binding(
            get: { session.imagePickerTarget != nil || session.thumbnailPickerTarget != nil },
            set: { isPresented in
                guard !isPresented else { return }
                DispatchQueue.main.async {
                    session.imagePickerTarget = nil
                    session.thumbnailPickerTarget = nil
                }
            }
        )
    }

    func body(content: Content) -> some View {
        content
            .fileImporter(isPresented: presented, allowedContentTypes: [.image]) { result in
                guard case .success(let url) = result else { return }
                let scoped = url.startAccessingSecurityScopedResource()
                defer { if scoped { url.stopAccessingSecurityScopedResource() } }
                guard let data = try? Data(contentsOf: url) else {
                    session.errorMessage = "That image could not be read."
                    return
                }
                if session.thumbnailPickerTarget != nil {
                    session.importPickedThumbnail(data)
                } else {
                    session.importPickedImage(data)
                }
            }
    }
}
#endif

private struct MarkdownBlockRow: View {
    @ObservedObject var session: MarkdownEditorSession
    let block: MarkdownBlock
    let position: Int
    let assets: MarkdownAssets?
    @State private var hovering = false

    private var isFocused: Bool { session.focusedBlockID == block.id }

    var body: some View {
        HStack(alignment: .top, spacing: 4) {
            content
                .frame(maxWidth: .infinity, alignment: .leading)
            handle
                .opacity(isFocused || hovering ? 1 : 0)
        }
        .padding(.leading, CGFloat(block.indent) * 24)
        .padding(.top, headingTopPadding)
        #if os(macOS)
        .onHover { hovering = $0 }
        #endif
    }

    private var headingTopPadding: CGFloat {
        if case .heading(let level) = block.kind { return level == 1 ? 10 : 6 }
        return 0
    }

    @ViewBuilder
    private var content: some View {
        switch block.kind {
        case .divider:
            Divider()
                .overlay(Theme.textSecondary.opacity(0.5))
                .padding(.vertical, 14)
                .contextMenu { blockActions }
        case .image(let path):
            MarkdownImageBlockView(path: path, alt: block.text, assets: assets)
                .padding(.vertical, 6)
                .contextMenu { blockActions }
        case .linkCard(let url, let thumbnail):
            MarkdownLinkCardView(title: block.text, url: url, thumbnail: thumbnail, assets: assets)
                .padding(.vertical, 6)
                .contextMenu {
                    Button("Choose thumbnail…") {
                        session.thumbnailPickerTarget = block.id
                    }
                    .disabled(assets == nil)
                    if thumbnail != nil {
                        Button("Remove thumbnail") { session.removeThumbnail(for: block.id) }
                    }
                    Button("Turn into plain link") { session.convertCardToLink(block.id) }
                    Divider()
                    blockActions
                }
        default:
            textRow
        }
    }

    private var textRow: some View {
        HStack(alignment: .top, spacing: 8) {
            marker
            MarkdownBlockTextView(
                blockID: block.id,
                text: block.text,
                kind: block.kind,
                placeholder: session.placeholder(for: block),
                controller: session.controller(for: block.id),
                focus: session.focus,
                handlers: session.handlers(for: block.id),
                concealsMarkup: session.editingBlockID != block.id
            )
        }
        .padding(block.isCode ? 8 : 0)
        .background {
            if block.isCode {
                RoundedRectangle(cornerRadius: 10, style: .continuous).fill(Color.white.opacity(0.05))
            }
        }
        .fixedSize(horizontal: false, vertical: block.kind == .quote)
    }

    @ViewBuilder
    private var marker: some View {
        switch block.kind {
        case .bullet:
            Text("\u{2022}")
                .font(TimeMasterFont.body(17))
                .foregroundStyle(Theme.textSecondary)
                .frame(width: 20, alignment: .center)
                .padding(.top, 5)
                .accessibilityHidden(true)
        case .numbered:
            Text("\(position).")
                .font(TimeMasterFont.body(17).monospacedDigit())
                .foregroundStyle(Theme.textSecondary)
                .frame(minWidth: 24, alignment: .trailing)
                .padding(.top, 7)
                .accessibilityHidden(true)
        case .todo(let done):
            Button {
                session.toggleTodo(block.id)
            } label: {
                Image(systemName: done ? "checkmark.square.fill" : "square")
                    .font(.system(size: 19))
                    .foregroundStyle(done ? Theme.toolbarOrange : Theme.textSecondary)
                    .frame(width: 24, height: 30)
            }
            .keyNavPlainButtonStyle(shape: .roundedRectangle(cornerRadius: 6))
            .padding(.top, 2)
            .accessibilityLabel(done ? "Completed task" : "Incomplete task")
        case .quote:
            RoundedRectangle(cornerRadius: 2)
                .fill(Theme.toolbarOrange)
                .frame(width: 3)
                .padding(.vertical, 4)
        default:
            EmptyView()
        }
    }

    private var handle: some View {
        Menu {
            Menu("Turn into") {
                ForEach(MarkdownSlashItem.all) { item in
                    if case .kind(let kind) = item.action {
                        Button {
                            session.turnInto(kind, id: block.id)
                        } label: {
                            Label(item.title, systemImage: item.symbol)
                        }
                    }
                }
            }
            blockActions
        } label: {
            Image(systemName: "ellipsis")
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(Theme.textSecondary)
                .frame(width: 28, height: 30)
                .contentShape(Rectangle())
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .fixedSize()
        .accessibilityLabel("Block options")
    }

    @ViewBuilder
    private var blockActions: some View {
        Button("Duplicate") { session.duplicate(block.id) }
        Button("Move up") { session.move(block.id, offset: -1) }
        Button("Move down") { session.move(block.id, offset: 1) }
        Button("Delete", role: .destructive) { session.delete(block.id) }
    }
}
