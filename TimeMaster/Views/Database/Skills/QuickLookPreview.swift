import SwiftUI

#if os(iOS)
import UIKit
import QuickLook

/// In-app previews for documents, text, audio and other files Quick Look supports.
struct QuickLookPreview: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> QLPreviewController {
        let controller = QLPreviewController()
        controller.dataSource = context.coordinator
        return controller
    }

    func updateUIViewController(_ controller: QLPreviewController, context: Context) {
        if context.coordinator.url != url {
            context.coordinator.url = url
            controller.reloadData()
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator(url: url) }

    final class Coordinator: NSObject, QLPreviewControllerDataSource {
        var url: URL

        init(url: URL) { self.url = url }

        func numberOfPreviewItems(in controller: QLPreviewController) -> Int { 1 }

        func previewController(_ controller: QLPreviewController, previewItemAt index: Int) -> QLPreviewItem {
            url as NSURL
        }
    }
}
#elseif os(macOS)
import AppKit
import QuickLookUI

struct QuickLookPreview: NSViewRepresentable {
    let url: URL

    final class Coordinator {
        var preview: QLPreviewView?
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeNSView(context: Context) -> NSView {
        let container = NSView(frame: .zero)
        if let preview = QLPreviewView(frame: .zero, style: .normal) {
            preview.autostarts = true
            preview.previewItem = url as NSURL
            preview.translatesAutoresizingMaskIntoConstraints = false
            container.addSubview(preview)
            NSLayoutConstraint.activate([
                preview.leadingAnchor.constraint(equalTo: container.leadingAnchor),
                preview.trailingAnchor.constraint(equalTo: container.trailingAnchor),
                preview.topAnchor.constraint(equalTo: container.topAnchor),
                preview.bottomAnchor.constraint(equalTo: container.bottomAnchor),
            ])
            context.coordinator.preview = preview
        }
        return container
    }

    static func dismantleNSView(_ view: NSView, coordinator: Coordinator) {
        coordinator.preview?.close()
    }

    func updateNSView(_ view: NSView, context: Context) {
        guard let preview = context.coordinator.preview else { return }
        let current = (preview.previewItem as? NSURL) as URL?
        if current != url { preview.previewItem = url as NSURL }
    }
}
#endif
