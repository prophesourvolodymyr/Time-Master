import SwiftUI

/// Opens the page's media viewer at the file an entry's picture or file chip points at.
struct ChecklistGalleryModifier: ViewModifier {
    let pageID: String
    @Binding var selection: URL?

    @EnvironmentObject private var store: DatabaseStore
    @State private var index = 0

    func body(content: Content) -> some View {
        content
            .onChange(of: selection) { url in
                guard let url, let page = store.page(manifestID: pageID) else { return }
                index = page.mediaURLs.firstIndex(of: url) ?? 0
            }
            .mediaViewerCover(isPresented: Binding(get: { selection != nil }, set: { if !$0 { selection = nil } })) {
                if let page = store.page(manifestID: pageID) {
                    PageMediaGallery(
                        urls: page.mediaURLs,
                        selectedIndex: $index,
                        isPresented: Binding(get: { selection != nil }, set: { if !$0 { selection = nil } }),
                        comments: page.mediaCommentsByURL,
                        onSaveComment: { url, comment in
                            try store.updateMediaComment(pageID: pageID, filename: url.lastPathComponent, comment: comment)
                        },
                        opensEditor: false,
                        notesAssets: { _ in FolderMarkdownAssets(folder: store.folderURL(for: page)) },
                        workout: nil,
                        liveContext: nil
                    )
                }
            }
    }
}

extension View {
    func checklistGallery(pageID: String, selection: Binding<URL?>) -> some View {
        modifier(ChecklistGalleryModifier(pageID: pageID, selection: selection))
    }
}
