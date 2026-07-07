#if os(macOS)
import SwiftUI
import AppKit
import UniformTypeIdentifiers

struct MacFilePicker {
    static func openPanel(
        allowedTypes: [UTType] = [.image, .movie, .jpeg, .png, .heic],
        allowsMultiple: Bool = true,
        completion: @escaping ([URL]) -> Void
    ) {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = allowedTypes
        panel.allowsMultipleSelection = allowsMultiple
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.begin { response in
            if response == .OK {
                completion(panel.urls)
            }
        }
    }

    static func openPanelSingle(
        allowedTypes: [UTType] = [.text, .pdf, UTType(filenameExtension: "md") ?? .plainText],
        completion: @escaping (URL?) -> Void
    ) {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = allowedTypes
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.begin { response in
            if response == .OK {
                completion(panel.urls.first)
            } else {
                completion(nil)
            }
        }
    }
}

struct MacFilePickerModifier: ViewModifier {
    @Binding var isPresented: Bool
    let allowedTypes: [UTType]
    let allowsMultiple: Bool
    let onResult: ([URL]) -> Void

    func body(content: Content) -> some View {
        content
            .onChange(of: isPresented) { _, newValue in
                guard newValue else { return }
                MacFilePicker.openPanel(
                    allowedTypes: allowedTypes,
                    allowsMultiple: allowsMultiple
                ) { urls in
                    isPresented = false
                    onResult(urls)
                }
            }
    }
}

struct MacFilePickerSingleModifier: ViewModifier {
    @Binding var isPresented: Bool
    let allowedTypes: [UTType]
    let onResult: (URL?) -> Void

    func body(content: Content) -> some View {
        content
            .onChange(of: isPresented) { _, newValue in
                guard newValue else { return }
                MacFilePicker.openPanelSingle(
                    allowedTypes: allowedTypes
                ) { url in
                    isPresented = false
                    onResult(url)
                }
            }
    }
}

extension View {
    func macFilePicker(
        isPresented: Binding<Bool>,
        allowedTypes: [UTType] = [.image, .movie, .jpeg, .png, .heic],
        allowsMultiple: Bool = true,
        onResult: @escaping ([URL]) -> Void
    ) -> some View {
        modifier(MacFilePickerModifier(
            isPresented: isPresented,
            allowedTypes: allowedTypes,
            allowsMultiple: allowsMultiple,
            onResult: onResult
        ))
    }

    func macFilePickerSingle(
        isPresented: Binding<Bool>,
        allowedTypes: [UTType] = [.text, .pdf, UTType(filenameExtension: "md") ?? .plainText],
        onResult: @escaping (URL?) -> Void
    ) -> some View {
        modifier(MacFilePickerSingleModifier(
            isPresented: isPresented,
            allowedTypes: allowedTypes,
            onResult: onResult
        ))
    }
}
#endif
