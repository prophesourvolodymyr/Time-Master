#if os(macOS)
import AppKit
import SwiftUI
import UniformTypeIdentifiers

enum MacVideoDropReader {
    static func movieURLs(from providers: [NSItemProvider]) async -> [URL] {
        var urls: [URL] = []
        for provider in providers where provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) {
            guard let url = await fileURL(from: provider),
                  UTType(filenameExtension: url.pathExtension)?.conforms(to: .movie) == true else { continue }
            urls.append(url)
        }
        return urls
    }

    private static func fileURL(from provider: NSItemProvider) async -> URL? {
        await withCheckedContinuation { continuation in
            provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, _ in
                if let data = item as? Data, let url = URL(dataRepresentation: data, relativeTo: nil) {
                    continuation.resume(returning: url)
                } else if let url = item as? URL {
                    continuation.resume(returning: url)
                } else {
                    continuation.resume(returning: nil)
                }
            }
        }
    }
}

struct MacVideoAddSourcesSheet: View {
    @ObservedObject var model: MacVideoWorkspaceModel
    let onClose: () -> Void

    @State private var pasteText = ""
    @State private var showImporter = false
    @State private var isDropTargeted = false
    @State private var errorText: String?
    @FocusState private var pasteFocused: Bool

    private static let visibleLinkRows = 3

    private var links: [URL] { ImportLinkParser.links(in: pasteText) }

    private static let charactersPerLine = 56
    private static let lineHeight: CGFloat = 21
    private static let maximumEditorLines = 8

    private var editorHeight: CGFloat {
        let lines = pasteText.components(separatedBy: "\n").reduce(0) { total, line in
            total + max(1, Int((Double(line.count) / Double(Self.charactersPerLine)).rounded(.up)))
        }
        let visible = min(max(lines, 4), Self.maximumEditorLines)
        return CGFloat(visible) * Self.lineHeight + 28
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            header
            pasteSection
            if !links.isEmpty { linkList }
            orLabel
            fileArea
            if let errorText {
                Label(errorText, systemImage: "exclamationmark.triangle.fill")
                    .font(TimeMasterFont.caption())
                    .foregroundStyle(.orange)
            }
            footer
        }
        .padding(24)
        .frame(width: 580)
        .background(Theme.background)
        .presentationBackground(Theme.background)
        .preferredColorScheme(.dark)
        .fileImporter(isPresented: $showImporter, allowedContentTypes: [.movie], allowsMultipleSelection: true) { result in
            switch result {
            case .success(let urls):
                guard !urls.isEmpty else { return }
                model.addLocalFiles(urls)
                onClose()
            case .failure(let error):
                errorText = error.localizedDescription
            }
        }
        .onAppear { pasteFocused = true }
        .accessibilityIdentifier("workspace-add-sheet")
    }

    private var header: some View {
        HStack(spacing: 14) {
            Image(systemName: "video.badge.plus")
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(Theme.toolbarOrange)
                .frame(width: 48, height: 48)
                .background(Theme.toolbarOrange.opacity(0.16), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 3) {
                Text("Add Videos")
                    .font(TimeMasterFont.heading())
                downloaderLine
            }
            Spacer(minLength: 0)
        }
    }

    @ViewBuilder
    private var downloaderLine: some View {
        if !model.isCheckingDownloader, model.downloaderVersion == nil {
            Label("yt-dlp missing · brew install yt-dlp ffmpeg", systemImage: "exclamationmark.triangle.fill")
                .font(TimeMasterFont.caption())
                .foregroundStyle(.orange)
        }
    }

    private var pasteSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label("Links", systemImage: "link")
                    .font(TimeMasterFont.rowTitle())
                Spacer()
                Button("Paste", systemImage: "doc.on.clipboard", action: pasteFromClipboard)
                    .buttonStyle(TimeMasterActionButtonStyle(minimumSize: 36, horizontalPadding: 12))
            }
            ZStack(alignment: .topLeading) {
                TextEditor(text: $pasteText)
                    .focused($pasteFocused)
                    .font(TimeMasterFont.body(15))
                    .scrollContentBackground(.hidden)
                    .scrollIndicators(.hidden)
                    .autocorrectionDisabled()
                    .padding(10)
                    .accessibilityLabel("Video links")
                if pasteText.isEmpty {
                    Text("https://…")
                        .font(TimeMasterFont.body(15))
                        .foregroundStyle(Theme.textSecondary)
                        .padding(.horizontal, 15)
                        .padding(.vertical, 18)
                        .allowsHitTesting(false)
                        .accessibilityHidden(true)
                }
            }
            .frame(height: editorHeight)
            .background(Theme.surface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
    }

    private var linkList: some View {
        let visible = links.prefix(Self.visibleLinkRows)
        let hidden = links.count - visible.count
        return VStack(spacing: 6) {
            ForEach(Array(visible), id: \.absoluteString) { url in
                linkRow(url)
            }
            if hidden > 0 {
                Text("+ \(hidden) more \(hidden == 1 ? "link" : "links")")
                    .font(TimeMasterFont.caption())
                    .foregroundStyle(Theme.textSecondary)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 2)
            }
        }
    }

    private func linkRow(_ url: URL) -> some View {
        HStack(spacing: 10) {
            Image(systemName: ImportLinkParser.symbolName(for: url))
                .foregroundStyle(Theme.toolbarOrange)
                .frame(width: 22)
            Text(url.host?.replacingOccurrences(of: "www.", with: "") ?? "")
                .font(TimeMasterFont.black(14, relativeTo: .subheadline))
            Text(url.path.isEmpty ? url.absoluteString : url.path)
                .font(TimeMasterFont.caption())
                .foregroundStyle(Theme.textSecondary)
                .lineLimit(1)
                .truncationMode(.middle)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 12)
        .frame(height: 40)
        .background(Theme.surface2, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private var orLabel: some View {
        Text("or")
            .font(TimeMasterFont.caption())
            .foregroundStyle(Theme.textSecondary)
            .frame(maxWidth: .infinity)
    }

    private var fileArea: some View {
        Button { showImporter = true } label: {
            HStack(spacing: 14) {
                Image(systemName: "film.stack")
                    .font(.system(size: 26, weight: .semibold))
                Text("Choose or drop videos")
                    .font(TimeMasterFont.black(16, relativeTo: .headline))
                Spacer(minLength: 0)
            }
            .foregroundStyle(isDropTargeted ? Theme.toolbarOrange : Theme.textPrimary)
            .padding(.horizontal, 20)
            .frame(maxWidth: .infinity, minHeight: 76)
            .background(
                isDropTargeted ? Theme.toolbarOrange.opacity(0.16) : Theme.surface,
                in: RoundedRectangle(cornerRadius: 14, style: .continuous)
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Choose videos from this Mac")
        .keyboardShortcut("o", modifiers: .command)
        .help("Choose videos from this Mac (⌘O)")
        .onDrop(of: [.fileURL], isTargeted: $isDropTargeted) { providers in
            Task { @MainActor in
                let urls = await MacVideoDropReader.movieURLs(from: providers)
                guard !urls.isEmpty else { return }
                model.addLocalFiles(urls)
                onClose()
            }
            return true
        }
    }

    private var footer: some View {
        HStack(spacing: 10) {
            Spacer(minLength: 0)
            Button("Cancel", action: onClose)
                .keyboardShortcut(.cancelAction)
                .buttonStyle(MacVideoNeutralButtonStyle())
            Button(links.count > 1 ? "Add \(links.count) Links" : "Add Link", action: addLinks)
                .keyboardShortcut(.defaultAction)
                .buttonStyle(TimeMasterActionButtonStyle(prominent: true))
                .disabled(links.isEmpty)
        }
    }

    private func pasteFromClipboard() {
        guard let text = NSPasteboard.general.string(forType: .string), !text.isEmpty else { return }
        pasteText += (pasteText.isEmpty || pasteText.hasSuffix("\n") ? "" : "\n") + text
        errorText = nil
    }

    private func addLinks() {
        if model.addLinks(in: pasteText) {
            onClose()
        } else {
            errorText = model.message
            model.message = nil
        }
    }
}

private struct MacVideoNeutralButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        let shape = RoundedRectangle(cornerRadius: Theme.controlCornerRadius, style: .continuous)
        configuration.label
            .font(TimeMasterFont.label())
            .foregroundStyle(Theme.textPrimary)
            .padding(.horizontal, 18)
            .frame(minHeight: 44)
            .background(Theme.surface2, in: shape)
            .contentShape(shape)
            .opacity(configuration.isPressed ? 0.8 : 1)
    }
}
#endif
