#if os(macOS)
import AppKit
import SwiftUI

struct MacVideoWorkspaceView: View {
    @ObservedObject var model: MacVideoWorkspaceModel

    @AppStorage("tm.mac.videoWorkspace.sidebarWidth") private var storedSidebarWidth = 300.0
    @State private var dragStartWidth: CGFloat?
    @State private var liveSidebarWidth: CGFloat?
    @State private var showAddSheet = false
    @State private var didAutoPresent = false
    @State private var isDropTargeted = false
    @State private var pendingRemoval: MacVideoWorkspaceItem?
    @State private var showImporter = false
    @State private var widthBeforeCollapse: Double?
    @State private var handleHovering = false

    private let sidebarRange: ClosedRange<CGFloat> = 88...520
    private let defaultSidebarWidth: CGFloat = 300
    private let editorMinimumWidth: CGFloat = 640

    var body: some View {
        GeometryReader { geometry in
            let sidebarWidth = clampedSidebarWidth(available: geometry.size.width)
            HStack(spacing: 0) {
                mainArea
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                if !model.items.isEmpty {
                    sidebarHandle(available: geometry.size.width, current: sidebarWidth)
                    sidebar(width: sidebarWidth)
                        .frame(width: sidebarWidth)
                }
            }
        }
        .background(Theme.background)
        .background {
            MacVideoWorkspaceShortcuts(
                onAdd: { showAddSheet = true },
                onImport: { showImporter = true },
                onToggleSidebar: toggleSidebar
            )
        }
        .overlay {
            if isDropTargeted {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Theme.toolbarOrange.opacity(0.14))
                    .padding(8)
                    .allowsHitTesting(false)
            }
        }
        .onDrop(of: [.fileURL], isTargeted: $isDropTargeted) { providers in
            Task { @MainActor in
                let urls = await MacVideoDropReader.movieURLs(from: providers)
                if !urls.isEmpty { model.addLocalFiles(urls) }
            }
            return true
        }
        .task { await model.checkDownloader() }
        .onAppear {
            model.start()
            if model.items.isEmpty, !didAutoPresent {
                didAutoPresent = true
                showAddSheet = true
            }
        }
        .sheet(isPresented: $showAddSheet) {
            MacVideoAddSourcesSheet(model: model) { showAddSheet = false }
        }
        .fileImporter(isPresented: $showImporter, allowedContentTypes: [.movie], allowsMultipleSelection: true) { result in
            switch result {
            case .success(let urls):
                if !urls.isEmpty { model.addLocalFiles(urls) }
            case .failure(let error):
                model.message = error.localizedDescription
            }
        }
        .alert("Couldn’t add video", isPresented: Binding(
            get: { model.message != nil && !showAddSheet },
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

    private func clampedSidebarWidth(available: CGFloat) -> CGFloat {
        let upper = max(sidebarRange.lowerBound, min(sidebarRange.upperBound, available - editorMinimumWidth))
        let requested = liveSidebarWidth ?? CGFloat(storedSidebarWidth)
        return min(max(requested, sidebarRange.lowerBound), upper)
    }

    @ViewBuilder
    private var mainArea: some View {
        if let item = model.selectedItem {
            MacVideoWorkspaceDetail(
                item: item,
                onRetry: { model.retry(item) },
                onRemove: { pendingRemoval = item }
            )
            .id(item.id)
        } else {
            emptyState
        }
    }

    private var emptyState: some View {
        VStack(spacing: 18) {
            Image(systemName: "film.stack")
                .font(.system(size: 44, weight: .semibold))
                .foregroundStyle(Theme.textSecondary)
                .accessibilityHidden(true)
            Button {
                showAddSheet = true
            } label: {
                Label("Add Videos", systemImage: "plus")
                    .font(TimeMasterFont.black(16, relativeTo: .headline))
            }
            .buttonStyle(TimeMasterActionButtonStyle(prominent: true, minimumSize: 52, horizontalPadding: 22))
            .help("Add videos (⌘I) or import files (⌘O)")
            .accessibilityIdentifier("workspace-add-videos-empty")
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func sidebarHandle(available: CGFloat, current: CGFloat) -> some View {
        Color.clear
            .frame(width: 10)
            .overlay {
                Rectangle()
                    .fill(Theme.toolbarOrange.opacity(handleHovering || liveSidebarWidth != nil ? 0.7 : 0))
                    .frame(width: 2)
                    .animation(.easeOut(duration: 0.15), value: handleHovering)
                    .allowsHitTesting(false)
            }
            .contentShape(Rectangle())
            .onHover { handleHovering = $0 }
            .macResizeCursor()
            .gesture(
                DragGesture(minimumDistance: 1, coordinateSpace: .global)
                    .onChanged { value in
                        let start = dragStartWidth ?? current
                        dragStartWidth = start
                        NSCursor.resizeLeftRight.set()
                        liveSidebarWidth = clampedWidth(start - value.translation.width, available: available)
                    }
                    .onEnded { _ in
                        if let liveSidebarWidth { storedSidebarWidth = Double(liveSidebarWidth) }
                        liveSidebarWidth = nil
                        dragStartWidth = nil
                    }
            )
            .onTapGesture(count: 2) { storedSidebarWidth = Double(defaultSidebarWidth) }
            .accessibilityElement()
            .accessibilityLabel("Resize video list")
            .accessibilityValue("\(Int(current)) points wide")
            .accessibilityIdentifier("workspace-sidebar-handle")
            .accessibilityAdjustableAction { direction in
                let step: CGFloat = direction == .increment ? 24 : -24
                storedSidebarWidth = Double(clampedWidth(current + step, available: available))
            }
    }

    private func clampedWidth(_ value: CGFloat, available: CGFloat) -> CGFloat {
        let upper = max(sidebarRange.lowerBound, min(sidebarRange.upperBound, available - editorMinimumWidth))
        return min(max(value, sidebarRange.lowerBound), upper)
    }

    private func toggleSidebar() {
        guard !model.items.isEmpty else { return }
        if storedSidebarWidth > Double(sidebarRange.lowerBound) + 1 {
            widthBeforeCollapse = storedSidebarWidth
            storedSidebarWidth = Double(sidebarRange.lowerBound)
        } else {
            storedSidebarWidth = widthBeforeCollapse ?? Double(defaultSidebarWidth)
            widthBeforeCollapse = nil
        }
    }

    private func sidebar(width: CGFloat) -> some View {
        let isCompact = width < 150
        return VStack(spacing: 0) {
            HStack {
                if !isCompact {
                    Label("\(model.items.count)", systemImage: "film.stack")
                        .font(TimeMasterFont.black(15, relativeTo: .subheadline))
                    Spacer(minLength: 0)
                }
                Button("Add videos", systemImage: "plus") { showAddSheet = true }
                    .labelStyle(.iconOnly)
                    .buttonStyle(TimeMasterToolbarIconButtonStyle())
                    .help("Add videos (⌘I) or import files (⌘O)")
                    .accessibilityIdentifier("workspace-add-videos")
                if isCompact { Spacer(minLength: 0) }
            }
            .padding(.horizontal, isCompact ? 0 : 14)
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            List {
                ForEach(model.items) { item in
                    MacVideoWorkspaceRow(item: item, isSelected: model.selectedID == item.id, width: width)
                        .contentShape(Rectangle())
                        .onTapGesture { model.select(item) }
                        .listRowInsets(EdgeInsets(top: 4, leading: isCompact ? 8 : 10, bottom: 4, trailing: isCompact ? 8 : 10))
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
    let width: CGFloat

    private var isCompact: Bool { width < 150 }
    private var thumbnailWidth: CGFloat {
        isCompact ? max(48, width - 36) : min(176, max(64, (width - 40) * 0.38))
    }

    var body: some View {
        Group {
            if isCompact {
                MacVideoWorkspaceThumbnail(item: item, width: thumbnailWidth)
                    .frame(maxWidth: .infinity)
            } else {
                HStack(spacing: 10) {
                    MacVideoWorkspaceThumbnail(item: item, width: thumbnailWidth)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(item.title)
                            .font(TimeMasterFont.black(14, relativeTo: .subheadline))
                            .lineLimit(width > 300 ? 2 : 1)
                        statusLine
                    }
                    Spacer(minLength: 0)
                }
            }
        }
        .padding(isCompact ? 6 : 8)
        .background(isSelected ? Theme.toolbarOrange.opacity(0.22) : Color.clear, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .help(item.title)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(item.title)
        .accessibilityValue(item.status.label)
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

private struct MacVideoWorkspaceThumbnail: View {
    @ObservedObject var item: MacVideoWorkspaceItem
    let width: CGFloat

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8, style: .continuous).fill(Theme.surface2)
            if let thumbnail = item.thumbnail {
                Image(nsImage: thumbnail)
                    .resizable()
                    .scaledToFill()
            } else if item.status.isActive || item.status == .queued {
                TmaxLoadingIndicator(size: 16)
            } else {
                Image(systemName: item.symbolName)
                    .foregroundStyle(Theme.textSecondary)
            }
        }
        .frame(width: width, height: width * 0.62)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(alignment: .bottomTrailing) { badge }
    }

    @ViewBuilder
    private var badge: some View {
        switch item.status {
        case .ready:
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.white, .green)
                .padding(3)
        case .failed:
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.black, .orange)
                .padding(3)
        default:
            EmptyView()
        }
    }
}

private struct MacVideoWorkspaceDetail: View {
    @ObservedObject var item: MacVideoWorkspaceItem
    let onRetry: () -> Void
    let onRemove: () -> Void

    var body: some View {
        if item.status == .ready, let source = item.source, let editor = item.editor {
            MacVideoEditorView(source: source, model: editor, title: item.title)
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

private struct MacVideoWorkspaceShortcuts: View {
    let onAdd: () -> Void
    let onImport: () -> Void
    let onToggleSidebar: () -> Void

    var body: some View {
        Group {
            Button("Add videos", action: onAdd)
                .keyboardShortcut("i", modifiers: .command)
            Button("Import video files", action: onImport)
                .keyboardShortcut("o", modifiers: .command)
            Button("Show or hide the video list", action: onToggleSidebar)
                .keyboardShortcut("s", modifiers: [.command, .control])
        }
        .opacity(0)
        .frame(width: 0, height: 0)
        .accessibilityHidden(true)
    }
}
#endif
