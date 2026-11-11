import SwiftUI
import PhotosUI
import UniformTypeIdentifiers

/// Presents the photo library or the file picker and hands back a local copy of what was picked (a temporary file
/// the caller copies into the page; it is removed afterwards).
struct ChecklistPictureImporter: ViewModifier {
    enum Source: Identifiable {
        case photos
        case files

        var id: Self { self }
    }

    @Binding var source: Source?
    /// Any file instead of pictures only (attachments).
    var anyFile = false
    let onPicked: (URL) -> Void

    @State private var photoItem: PhotosPickerItem?

    func body(content: Content) -> some View {
        content
            .photosPicker(
                isPresented: Binding(get: { source == .photos }, set: { if !$0, source == .photos { source = nil } }),
                selection: $photoItem,
                matching: anyFile ? .any(of: [.images, .videos]) : .images
            )
            .fileImporter(
                isPresented: Binding(get: { source == .files }, set: { if !$0, source == .files { source = nil } }),
                allowedContentTypes: anyFile ? [.item] : [.image],
                allowsMultipleSelection: false
            ) { result in
                guard case .success(let urls) = result, let url = urls.first else { return }
                let scoped = url.startAccessingSecurityScopedResource()
                defer { if scoped { url.stopAccessingSecurityScopedResource() } }
                let copy = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + "-" + url.lastPathComponent)
                do {
                    try FileManager.default.copyItem(at: url, to: copy)
                    defer { try? FileManager.default.removeItem(at: copy) }
                    onPicked(copy)
                } catch {
                    SkillErrorCenter.shared.report("Add the file", error)
                }
            }
            .onChange(of: photoItem) { item in
                guard let item else { return }
                photoItem = nil
                Task { @MainActor in
                    let isVideo = item.supportedContentTypes.contains { $0.conforms(to: .audiovisualContent) }
                    if isVideo, let movie = try? await item.loadTransferable(type: MovieFile.self) {
                        defer { try? FileManager.default.removeItem(at: movie.url) }
                        onPicked(movie.url)
                        return
                    }
                    guard let data = try? await item.loadTransferable(type: Data.self) else {
                        SkillErrorCenter.shared.message = "Add the picture: it could not be read."
                        return
                    }
                    let ext = item.supportedContentTypes.first { $0.conforms(to: .image) }?.preferredFilenameExtension ?? "jpg"
                    let file = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + "." + ext)
                    do {
                        try data.write(to: file, options: .atomic)
                        defer { try? FileManager.default.removeItem(at: file) }
                        onPicked(file)
                    } catch {
                        SkillErrorCenter.shared.report("Add the picture", error)
                    }
                }
            }
    }
}

extension View {
    /// Photos or Files for a picture (or any file with `anyFile`); `onPicked` gets a temporary local copy.
    func checklistPictureImporter(source: Binding<ChecklistPictureImporter.Source?>, anyFile: Bool = false, onPicked: @escaping (URL) -> Void) -> some View {
        modifier(ChecklistPictureImporter(source: source, anyFile: anyFile, onPicked: onPicked))
    }
}
