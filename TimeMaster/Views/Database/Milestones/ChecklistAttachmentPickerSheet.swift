import SwiftUI
import TimeMasterCore

/// Attaches a file or a link of the page to an entry, or adds a new file to the page for it.
struct ChecklistAttachmentPickerSheet: View {
    let pageID: String
    let linkedURLs: Set<String>
    let onAddFile: () -> Void
    let onPick: (TodoLink) -> Void

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var store: DatabaseStore
    @ScaledMetric(relativeTo: .body) private var tile: CGFloat = 96

    var body: some View {
        let page = store.page(manifestID: pageID)
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: tile), spacing: 12)], spacing: 12) {
                        Button {
                            dismiss()
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35, execute: onAddFile)
                        } label: {
                            Image(systemName: "plus")
                                .font(.system(size: 22, weight: .semibold))
                                .foregroundStyle(Theme.toolbarOrange)
                                .frame(width: tile, height: tile)
                                .background(Theme.surface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                                .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(Theme.separator, style: StrokeStyle(lineWidth: 1, dash: [5])))
                        }
                        .keyNavPlainButtonStyle(shape: .roundedRectangle(cornerRadius: 14))
                        .accessibilityLabel("Add a file")
                        ForEach(page?.mediaURLs ?? [], id: \.self) { url in
                            fileTile(url)
                        }
                    }
                    ForEach(page?.manifest.linkURLs ?? [], id: \.self) { address in
                        linkRow(address, metadata: page?.manifest.linkMetadata ?? [])
                    }
                }
                .padding(20)
            }
            .background(Theme.background.ignoresSafeArea())
            .timeMasterNavigationTitle("Attach")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                AppToolbar.item(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .buttonStyle(TimeMasterToolbarTextButtonStyle())
                }
            }
        }
        .keyNavHost()
        #if os(macOS)
        .frame(minWidth: 520, minHeight: 480)
        #endif
    }

    private func fileTile(_ url: URL) -> some View {
        let link = TodoLink(target: .media(filename: url.lastPathComponent))
        let isLinked = linkedURLs.contains(link.url)
        return Button {
            onPick(link)
            dismiss()
        } label: {
            ZStack {
                Theme.surface
                if ChecklistMedia.isPicture(url.lastPathComponent) {
                    SkillLocalImage(url: url, maxPixel: 320)
                } else {
                    Image(systemName: ChecklistLook.symbol(forFile: url.lastPathComponent))
                        .font(.system(size: 26, weight: .semibold))
                        .foregroundStyle(Theme.toolbarOrange)
                }
            }
            .frame(width: tile, height: tile)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(isLinked ? Theme.toolbarOrange : Theme.separator, lineWidth: isLinked ? 3 : 1))
        }
        .keyNavPlainButtonStyle(shape: .roundedRectangle(cornerRadius: 14))
        .disabled(isLinked)
        .accessibilityLabel("Attach file \(url.lastPathComponent)")
    }

    private func linkRow(_ address: String, metadata: [LinkMetadata]) -> some View {
        let isLinked = linkedURLs.contains(address)
        let url = URL(string: address)
        return Button {
            onPick(TodoLink(url: address))
            dismiss()
        } label: {
            HStack(spacing: 10) {
                Image(systemName: url.map(ChecklistLinkChip.webSymbol) ?? "globe")
                    .foregroundStyle(Theme.toolbarOrange)
                    .frame(width: 24)
                Text(metadata.first { $0.url == address }?.title ?? url?.host ?? address)
                    .font(TimeMasterFont.rowTitle())
                    .foregroundStyle(Theme.textPrimary)
                    .lineLimit(1)
                Spacer(minLength: 0)
                if isLinked {
                    Image(systemName: "checkmark")
                        .foregroundStyle(Theme.toolbarOrange)
                }
            }
            .padding(12)
            .background(Theme.surface, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .contentShape(Rectangle())
        }
        .keyNavPlainButtonStyle()
        .disabled(isLinked)
    }
}
