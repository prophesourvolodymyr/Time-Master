import SwiftUI

struct TmaxLoadingIndicator: View {
    private let title: String?
    private let size: CGFloat
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isVisible = false

    init(_ title: String? = nil, size: CGFloat = 24) {
        self.title = title
        self.size = size
    }

    var body: some View {
        ProgressView {
            if let title { Text(title) }
        }
        .progressViewStyle(TmaxActivityStyle(size: size))
        .opacity(isVisible ? 1 : 0)
        .animation(reduceMotion ? nil : .easeOut(duration: 0.15), value: isVisible)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(title ?? "Loading")
        .task {
            do {
                try await Task.sleep(nanoseconds: 120_000_000)
                isVisible = true
            } catch {}
        }
    }
}

private struct TmaxActivityStyle: ProgressViewStyle {
    let size: CGFloat

    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: 10) {
            TmaxCircularLoader()
                .frame(width: size, height: size)
            configuration.label
                .font(TimeMasterFont.secondary())
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
