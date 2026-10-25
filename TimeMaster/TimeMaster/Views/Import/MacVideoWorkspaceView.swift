#if os(macOS)
import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct MacVideoWorkspaceView: View {
    @ObservedObject var model: MacVideoWorkspaceModel
    var onClose: () -> Void

    @State private var pasteText = ""
    @State private var showImporter = false
    @State private var isDropTargeted = false
    @State private var pendingRemoval: MacVideoWorkspaceItem?

    private var detectedLinks: [URL] { ImportLinkParser.links(in: pasteText) }

    var body: some View {
        HStack(spacing: 0) {
            mainArea
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            if !model.items.isEmpty {
                Divider().overlay(Theme.separator)
                sidebar
                    .frame(width: 292)
            }
        }
        .background(Theme.background)
        .task { await model.checkDownloader() }
        .onAppear { model.start() }
        .fileImporter(isPresented: $showImporter, allowedContentTypes: [.movie], allowsMultipleSelection: true) { result in
            if case .success(let urls) = result { model.addLocalFiles(urls) }
            if case .failure(let error) = result { model.message = error.localizedDescription }
        }
        .alert("Couldn’t add video", isPresented: Binding(
            get: { model.message != nil },
            set: { if !$0 { model.message = nil } }
        )) {
            Button("OK", role: .cancel) { model.message = nil }
        } message: {
            Text(model.message ?? "")
        }
        .confirmationDialog(
            "Remove this video?",
            isPresented: Binding(get: { pendingRemoval != nil }, set: { if !$0 { pendingRemoval = nil } }),
            titleVisibility: .visible,
            presenting: pendingRemoval
        ) { item in
            Button("Remove “\(item.title)”", role: .destructive) { model.remove(item) }
            Button("Keep", role: .cancel) {}
        } message: { _ in
            Text("Clips and stills already saved to your exercise pages stay. Anything still staged is discarded.")
        }
    }

    @ViewBuilder
    private var mainArea: some View {
        if let item = model.selectedItem {
            MacVideoWorkspaceDetail(
                item: item,
                onBackToAdd: { model.selectedID = nil },
                onRetry: { model.retry(item) },
                onRemove: { pendingRemoval = item }
            )
            .id(item.id)
        } else {
            addPanel
        }
    }

    private var addPanel: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(spacing: 12) {
                if !model.items.isEmpty {
                    Button {
                        model.selectedID = model.items.first?.id
                    } label: {
                        Label("Videos", systemImage: "chevron.left")
                            .font(TimeMasterFont.rowTitle())
                    }
                    .buttonStyle(TimeMasterActionButtonStyle())
                }
                TimeMasterPageTitle("Add Videos", size: 30, relativeTo: .title)
                Spacer()
                downloaderBadge
            }

            VStack(alignment: .leading, spacing: 10) {
                Label("Paste links", systemImage: "link")
                    .font(TimeMasterFont.black(15, relativeTo: .subheadline))
                ZStack(alignment: .topLeading) {
                    TextEditor(text: $pasteText)
                        .font(TimeMasterFont.body(16))
                        .scrollContentBackground(.hidden)
                        .padding(10)
                        .frame(minHeight: 130, maxHeight: 190)
                        .background(Theme.surface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .overlay {
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .strokeBorder(detectedLinks.isEmpty ? Theme.separator : Theme.toolbarOrange.opacity(0.6), lineWidth: 1)
                        }
                    if pasteText.isEmpty {
                        Text("https://…")
                            .font(TimeMasterFont.body(16))
                            .foregroundStyle(Theme.textSecondary)
                            .padding(.horizontal, 15)
                            .padding(.vertical, 18)
                            .allowsHitTesting(false)
                    }
                }
                if !detectedLinks.isEmpty {
                    ScrollView {
                        VStack(spacing: 6) {
                            ForEach(detectedLinks, id: \.absoluteString) { url in
                                HStack(spacing: 10) {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundStyle(Theme.toolbarOrange)
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
                                .frame(minHeight: 40)
                                .background(Theme.surface2, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                            }
                        }
                    }
                    .frame(maxHeight: 170)
                }
                Button {
                    if model.addLinks(in: pasteText) { pasteText = "" }
                } label: {
                    Label(detectedLinks.count > 1 ? "Add \(detectedLinks.count) Links" : "Add Link", systemImage: "plus")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(TimeMasterActionButtonStyle(prominent: true, minimumSize: 48))
                .disabled(detectedLinks.isEmpty)
            }

            fileDropArea
            Spacer(minLength: 0)
        }
        .padding(28)
        .frame(maxWidth: 760, maxHeight: .infinity, alignment: .topLeading)
        .frame(maxWidth: .infinity)
    }

    private var fileDropArea: some View {
        Button { showImporter = true } label: {
            VStack(spacing: 10) {
                Image(systemName: "film.stack")
                    .font(.system(size: 34, weight: .semibold))
                Text("Choose or drop videos")
                    .font(TimeMasterFont.black(16, relativeTo: .headline))
            }
            .foregroundStyle(isDropTargeted ? Theme.toolbarOrange : Theme.textPrimary)
            .frame(maxWidth: .infinity, minHeight: 130)
            .background(Theme.surface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(isDropTargeted ? Theme.toolbarOrange : Theme.separator, style: StrokeStyle(lineWidth: 1.5, dash: [7, 5]))
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Choose videos from this Mac")
        .onDrop(of: [.fileURL], isTargeted: $isDropTargeted) { providers in
            for provider in providers {
                provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { data, _ in
                    guard let data = data as? Data,
                          let url = URL(dataRepresentation: data, relativeTo: nil),
                          UTType(filenameExtension: url.pathExtension)?.conforms(to: .movie) == true else { return }
                    Task { @MainActor in model.addLocalFiles([url]) }
                }
            }
            return true
        }
    }

    @ViewBuilder
    private var downloaderBadge: some View {
        if model.isCheckingDownloader {
            TmaxLoadingIndicator(size: 16)
        } else if let version = model.downloaderVersion {
            Label("yt-dlp \(version)", systemImage: "checkmark.circle.fill")
                .font(TimeMasterFont.caption())
                .foregroundStyle(.green)
        } else {
            Label("yt-dlp missing", systemImage: "exclamationmark.triangle.fill")
                .font(TimeMasterFont.caption())
                .foregroundStyle(.orange)
                .help("Install with: brew install yt-dlp ffmpeg")
        }
    }

    private var sidebar: some View {
        VStack(spacing: 0) {
            HStack {
                Label("\(model.items.count)", systemImage: "film.stack")
                    .font(TimeMasterFont.black(15, relativeTo: .subheadline))
                Spacer()
                Button("Add videos", systemImage: "plus") { model.selectedID = nil }
                    .labelStyle(.iconOnly)
                    .buttonStyle(TimeMasterToolbarIconButtonStyle())
            }
            .padding(.horizontal, 14)
            .frame(height: 52)
            Divider().overlay(Theme.separator)
            List {
                ForEach(model.items) { item in
                    MacVideoWorkspaceRow(item: item, isSelected: model.selectedID == item.id)
                        .contentShape(Rectangle())
                        .onTapGesture { model.select(item) }
                        .listRowInsets(EdgeInsets(top: 4, leading: 10, bottom: 4, trailing: 10))
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            Button("Remove", systemImage: "trash", role: .destructive) { pendingRemoval = item }
                        }
                        .swipeActions(edge: .leading, allowsFullSwipe: true) {
                            Button("Remove", systemImage: "trash", role: .destructive) { pendingRemoval = item }
                        }
                        .contextMenu {
                            Button("Remove", systemImage: "trash", role: .destructive) { pendingRemoval = item }
                        }
                        .accessibilityAction(named: "Remove video") { pendingRemoval = item }
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
        }
        .background(Theme.surface)
    }
}

private struct MacVideoWorkspaceRow: View {
    @ObservedObject var item: MacVideoWorkspaceItem
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: 8, style: .continuous).fill(Theme.surface2)
                if let thumbnail = item.thumbnail {
                    Image(nsImage: thumbnail)
                        .resizable()
                        .scaledToFill()
                } else if item.status.isActive || item.status == .queued {
                    TmaxLoadingIndicator(size: 16)
                } else {
                    Image(systemName: item.symbolName).foregroundStyle(Theme.textSecondary)
                }
            }
            .frame(width: 68, height: 44)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            VStack(alignment: .leading, spacing: 3) {
                Text(item.title)
                    .font(TimeMasterFont.black(14, relativeTo: .subheadline))
                    .lineLimit(1)
                statusLine
            }
            Spacer(minLength: 0)
        }
        .padding(8)
        .background(isSelected ? Theme.toolbarOrange.opacity(0.22) : Color.clear, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(isSelected ? Theme.toolbarOrange.opacity(0.7) : Theme.separator, lineWidth: 1)
        }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(isSelected ? [.isSelected, .isButton] : .isButton)
    }

    @ViewBuilder
    private var statusLine: some View {
        switch item.status {
        case .ready:
            Label(item.duration.map(formatted) ?? "Ready", systemImage: "checkmark.circle.fill")
                .font(TimeMasterFont.caption())
                .foregroundStyle(.green)
        case .failed:
            Label("Couldn’t import", systemImage: "exclamationmark.triangle.fill")
                .font(TimeMasterFont.caption())
                .foregroundStyle(.orange)
        default:
            Text(item.status.label)
                .font(TimeMasterFont.caption())
                .foregroundStyle(Theme.textSecondary)
        }
    }

    private func formatted(_ seconds: Double) -> String {
        let total = Int(seconds.rounded())
        return String(format: "%d:%02d", total / 60, total % 60)
    }
}

private struct MacVideoWorkspaceDetail: View {
    @ObservedObject var item: MacVideoWorkspaceItem
    let onBackToAdd: () -> Void
    let onRetry: () -> Void
    let onRemove: () -> Void

    var body: some View {
        if item.status == .ready, let source = item.source, let editor = item.editor {
            MacVideoEditorView(source: source, model: editor, onBack: onBackToAdd)
        } else {
            VStack(spacing: 16) {
                if item.status.isActive || item.status == .queued {
                    TmaxLoadingIndicator(size: 34)
                    Text(item.status.label)
                        .font(TimeMasterFont.black(18, relativeTo: .headline))
                } else {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 36))
                        .foregroundStyle(.orange)
                    Text(item.status.error ?? item.status.label)
                        .font(TimeMasterFont.body(16))
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: 420)
                    HStack(spacing: 10) {
                        Button("Retry", systemImage: "arrow.clockwise", action: onRetry)
                            .buttonStyle(TimeMasterActionButtonStyle(prominent: true))
                        if !item.originURL.isFileURL {
                            Button("Open Link", systemImage: "safari") { NSWorkspace.shared.open(item.originURL) }
                                .buttonStyle(TimeMasterActionButtonStyle())
                        }
                        Button("Remove", systemImage: "trash", role: .destructive, action: onRemove)
                            .buttonStyle(TimeMasterActionButtonStyle())
                    }
                }
                Text(item.originURL.isFileURL ? item.originURL.lastPathComponent : item.originURL.absoluteString)
                    .font(TimeMasterFont.caption())
                    .foregroundStyle(Theme.textSecondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .frame(maxWidth: 420)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}
#endif
