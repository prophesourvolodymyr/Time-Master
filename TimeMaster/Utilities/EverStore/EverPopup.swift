import SwiftUI
#if canImport(UIKit)
import UIKit
#elseif os(macOS)
import AppKit
#endif

struct EverPopup<Content: View, Actions: View>: View {
    let title: String
    var message: String?
    var step: String?
    var output: String?
    var diagnosticLog: String
    var canDismiss: Bool
    var onBack: (() -> Void)?
    let onEscape: () -> Void
    let content: () -> Content
    let actions: () -> Actions

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.everPopupStepMotion) private var stepMotion
    @AccessibilityFocusState private var titleIsFocused: Bool

    init(
        title: String,
        message: String? = nil,
        step: String? = nil,
        output: String? = nil,
        diagnosticLog: String = "",
        canDismiss: Bool = true,
        onBack: (() -> Void)? = nil,
        onEscape: @escaping () -> Void,
        @ViewBuilder content: @escaping () -> Content,
        @ViewBuilder actions: @escaping () -> Actions
    ) {
        self.title = title
        self.message = message
        self.step = step
        self.output = output
        self.diagnosticLog = diagnosticLog
        self.canDismiss = canDismiss
        self.onBack = onBack
        self.onEscape = onEscape
        self.content = content
        self.actions = actions
    }

    var body: some View {
        Group {
#if os(macOS)
        VStack(alignment: .leading, spacing: EverSpacing.x4) {
            header
            popupContent
            HStack(spacing: EverSpacing.x2) {
                Spacer(minLength: 0)
                actions()
            }
            .buttonStyle(TimeMasterActionButtonStyle(minimumSize: EverLayout.minimumTouchTarget,
                                                    horizontalPadding: EverSpacing.x4))
        }
        .padding(EverSpacing.x5)
        .frame(minWidth: EverLayout.popupMaximumWidth,
               idealWidth: EverLayout.popupMaximumWidth,
               maxWidth: EverLayout.maximumReadableWidth)
        .fixedSize(horizontal: false, vertical: true)
        .background(EverColor.background)
        .background(EverPopupStepAnchor(id: "\(step ?? "")|\(title)"))
#else
        GeometryReader { geometry in
            ZStack {
                EverColor.background.opacity(0.64)
                    .ignoresSafeArea()
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: EverSpacing.x4) {
                    header
                    popupContent
                    VStack(spacing: EverSpacing.x2) { actions() }
                        .buttonStyle(EverSecondaryButtonStyle())
                }
                .padding(EverSpacing.x4)
                .frame(maxWidth: min(EverLayout.popupMaximumWidth, max(0, geometry.size.width - EverSpacing.x3 * 2)))
                .background { EverSurfaceMaterial(radius: EverRadius.popup) }
                .shadow(color: .black.opacity(0.4), radius: EverSpacing.x7, y: EverSpacing.x3)
                .background(EverPopupStepAnchor(id: "\(step ?? "")|\(title)"))
                .environment(\.everPopupCompact, geometry.size.height < EverLayout.standardRowMinimum * 10)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
#endif
        }
        .foregroundStyle(EverColor.textPrimary)
        .preferredColorScheme(.dark)
        .accessibilityElement(children: .contain)
        .accessibilityAddTraits(.isModal)
        .accessibilityAction(.escape) { if canDismiss { onEscape() } }
#if os(macOS)
        .onExitCommand { if canDismiss { onEscape() } }
#endif
        .onAppear { titleIsFocused = true }
        .onChange(of: title) { _ in titleIsFocused = true }
    }

    private var popupContent: some View {
        VStack(alignment: .leading, spacing: EverSpacing.x3) {
            if let message, !message.isEmpty { EverPopupMessage(text: message) }
            content()
            if let output { EverOperationOutput(text: output) }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var header: some View {
        HStack(alignment: .top, spacing: EverSpacing.x2) {
            if let onBack {
                Button {
                    stepMotion?.back()
                    onBack()
                } label: {
                    Label("Back", systemImage: "chevron.left").labelStyle(.iconOnly)
                        .frame(minWidth: EverLayout.minimumTouchTarget, minHeight: EverLayout.minimumTouchTarget)
                }
                .buttonStyle(EverPressButtonStyle())
                .disabled(!canDismiss)
            }
            VStack(alignment: .leading, spacing: EverSpacing.x1) {
                if let step {
                    Text(step)
                        .font(TimeMasterFont.caption())
                        .foregroundStyle(EverColor.textTertiary)
                }
                Text(title)
                    .font(TimeMasterFont.heading())
                    .accessibilityAddTraits(.isHeader)
                    .accessibilityFocused($titleIsFocused)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            if !diagnosticLog.isEmpty, output == nil {
                Button {
#if canImport(UIKit)
                    UIPasteboard.general.setItems(
                        [["public.utf8-plain-text": NotificationDiagnostics.sanitize(diagnosticLog)]],
                        options: [.localOnly: true]
                    )
#elseif os(macOS)
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(NotificationDiagnostics.sanitize(diagnosticLog), forType: .string)
#endif
                } label: {
                    Label("Copy details", systemImage: "doc.on.doc").labelStyle(.iconOnly)
                        .frame(minWidth: EverLayout.minimumTouchTarget, minHeight: EverLayout.minimumTouchTarget)
                }
                .buttonStyle(EverPressButtonStyle())
            }
            Button {
                if canDismiss { onEscape() }
            } label: {
                Label("Close", systemImage: "xmark").labelStyle(.iconOnly)
                    .font(TimeMasterFont.secondary())
                    .frame(minWidth: EverLayout.minimumTouchTarget, minHeight: EverLayout.minimumTouchTarget)
                    .background(EverColor.surfaceSecondary, in: Circle())
            }
            .buttonStyle(EverPressButtonStyle())
            .disabled(!canDismiss)
            .accessibilityHint(canDismiss ? "Close this flow" : "Wait for the current operation to finish safely")
        }
    }
}

struct EverPopupMessage: View {
    let text: String
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.everPopupCompact) private var compact
    @State private var page = 0

    private var pageLength: Int { dynamicTypeSize.isAccessibilitySize ? 90 : compact ? 180 : 360 }
    private var pages: [String] {
        var result = [String]()
        var remaining = text[...]
        while !remaining.isEmpty {
            let end = remaining.index(remaining.startIndex, offsetBy: pageLength, limitedBy: remaining.endIndex) ?? remaining.endIndex
            result.append(String(remaining[..<end]))
            remaining = remaining[end...]
        }
        return result
    }

    var body: some View {
        let parts = pages
        VStack(alignment: .leading, spacing: EverSpacing.x2) {
            Text(parts.isEmpty ? "" : parts[min(page, parts.count - 1)])
                .font(TimeMasterFont.secondary())
                .foregroundStyle(EverColor.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
            if parts.count > 1 {
                EverPopupPagination(page: $page, count: parts.count)
            }
        }
        .onChange(of: text) { _ in page = 0 }
        .onChange(of: pageLength) { _ in page = 0 }
    }
}

struct EverPopupPagination: View {
    @Binding var page: Int
    let count: Int

    var body: some View {
        HStack(spacing: EverSpacing.x3) {
            Button {
                page = max(0, page - 1)
                EverHaptic.selection()
            } label: {
                Label("Previous page", systemImage: "chevron.left").labelStyle(.iconOnly)
                    .frame(minWidth: EverLayout.minimumTouchTarget, minHeight: EverLayout.minimumTouchTarget)
            }
            .disabled(page == 0)
            Spacer(minLength: 0)
            Text("\(min(page + 1, max(count, 1))) of \(max(count, 1))")
                .font(TimeMasterFont.caption())
                .monospacedDigit()
                .foregroundStyle(EverColor.textSecondary)
                .accessibilityLabel("Page \(page + 1) of \(count)")
            Spacer(minLength: 0)
            Button {
                page = min(max(0, count - 1), page + 1)
                EverHaptic.selection()
            } label: {
                Label("Next page", systemImage: "chevron.right").labelStyle(.iconOnly)
                    .frame(minWidth: EverLayout.minimumTouchTarget, minHeight: EverLayout.minimumTouchTarget)
            }
            .disabled(page >= count - 1)
        }
        .buttonStyle(EverPressButtonStyle())
    }
}

struct EverOperationOutput: View {
    let text: String

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @ScaledMetric(relativeTo: .caption) private var lineHeight = EverSpacing.x6
    @State private var current = ""
    @State private var previous = ""

    var body: some View {
        HStack(spacing: EverSpacing.x3) {
            TmaxLoadingIndicator(size: 20)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 0) {
                Text(previous)
                    .foregroundStyle(EverColor.textTertiary)
                    .frame(height: lineHeight)
                ZStack(alignment: .leading) {
                    Text(current.isEmpty ? "Waiting for output…" : current)
                        .id(current)
                        .transition(reduceMotion ? .opacity : .asymmetric(
                            insertion: .move(edge: .bottom).combined(with: .opacity),
                            removal: .move(edge: .top).combined(with: .opacity)
                        ))
                }
                .frame(height: lineHeight)
                Color.clear.frame(height: lineHeight)
            }
            .font(TimeMasterFont.caption())
            .lineLimit(1)
            .truncationMode(.middle)
            .frame(maxWidth: .infinity, alignment: .leading)
            .clipped()
            .mask {
                LinearGradient(stops: [
                    .init(color: .clear, location: 0),
                    .init(color: .white, location: 0.35),
                    .init(color: .white, location: 0.65),
                    .init(color: .clear, location: 1)
                ], startPoint: .top, endPoint: .bottom)
            }
        }
        .padding(.horizontal, EverSpacing.x3)
        .background(EverColor.surfaceSecondary, in: RoundedRectangle(cornerRadius: EverRadius.field, style: .continuous))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Live operation output")
        .accessibilityValue(current.isEmpty ? "Waiting for output" : current)
        .accessibilityIdentifier("import-output")
        .onAppear { update(animate: false) }
        .onChange(of: text) { _ in update(animate: true) }
    }

    private func update(animate: Bool) {
        let lines = text.split(whereSeparator: \.isNewline).suffix(2)
        let latest = lines.last.map { NotificationDiagnostics.sanitize(String($0)) } ?? ""
        guard latest != current else { return }
        withAnimation(animate ? (reduceMotion ? EverMotion.opacityOnly : EverMotion.state) : nil) {
            previous = lines.dropLast().last.map { NotificationDiagnostics.sanitize(String($0)) } ?? current
            current = latest
        }
    }
}

enum NotificationDiagnostics {
    private static let redactions: [(NSRegularExpression, String)] = [
        (#"(?is)-----BEGIN [^-]*PRIVATE KEY-----.*?-----END [^-]*PRIVATE KEY-----"#, "[private key removed]"),
        (#"(?im)^\s*(?:authorization|proxy-authorization|cookie|set-cookie)\s*[:=].*$"#, "[credential header removed]"),
        (#"(?i)\b(?:Bearer|Basic)\s+[A-Za-z0-9+/_.=\-]+"#, "[authorization removed]"),
        (#"(?i)([\"']?(?:password|passwd|passphrase|secret|access[_-]?token|refresh[_-]?token|id[_-]?token|token|api[_-]?key|client[_-]?secret|authorization|cookie|pairing[_-]?(?:record|data)|device[_-]?udid|udid)[\"']?\s*[:=]\s*)(?:\"(?:\\.|[^\"])*\"|'[^']*'|[^\s,;&}]+)"#, "$1[redacted]"),
        (#"\beyJ[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+\b"#, "[token removed]"),
        (#"(?i)/(?:private/)?(?:var/mobile|var/containers|Users|home)/[^\s\"<>]+"#, "[private path removed]")
    ].compactMap { pattern, replacement in
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
        return (regex, replacement)
    }
    private static let urls = try? NSRegularExpression(pattern: #"(?i)\b(?:https?|file)://[^\s<>\"']+"#)

    static func sanitize(_ text: String) -> String {
        var result = text
        if let urls {
            let matches = urls.matches(in: result, range: NSRange(result.startIndex..., in: result))
            for match in matches.reversed() {
                guard let range = Range(match.range, in: result),
                      var components = URLComponents(string: String(result[range])) else { continue }
                if components.scheme?.lowercased() == "file" {
                    result.replaceSubrange(range, with: "[private file URL removed]")
                    continue
                }
                components.user = nil
                components.password = nil
                components.fragment = nil
                if let items = components.queryItems {
                    components.queryItems = items.map { URLQueryItem(name: $0.name, value: "REDACTED") }
                }
                result.replaceSubrange(range, with: components.string ?? "[URL removed]")
            }
        }
        for (regex, replacement) in redactions {
            result = regex.stringByReplacingMatches(in: result, range: NSRange(result.startIndex..., in: result), withTemplate: replacement)
        }
        return result
    }
}
