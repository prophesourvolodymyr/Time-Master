#if os(macOS)
import AppKit
import SwiftUI

struct MenuBarTip: Equatable {
    var title: String
    var message: String?
    var quote: String?
    var symbol: String
    var isRest: Bool

    var announcement: String {
        [title, message, quote].compactMap { $0 }.joined(separator: ". ")
    }
}

private struct MenuBarGlanceTipView: View {
    let tip: MenuBarTip
    let onOpen: () -> Void
    let onMute: () -> Void
    let onClose: () -> Void
    let onHover: (Bool) -> Void

    private var tint: Color { tip.isRest ? Theme.accent : Theme.toolbarOrange }

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Button(action: onOpen) {
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: tip.symbol)
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(tint)
                        .frame(width: 32, height: 32)
                        .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(tint.opacity(0.16)))
                        .accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(tip.title)
                            .font(TimeMasterFont.black(15, relativeTo: .subheadline))
                            .foregroundStyle(Theme.textPrimary)
                            .lineLimit(2)
                        if let message = tip.message {
                            Text(message)
                                .font(TimeMasterFont.secondary())
                                .foregroundStyle(Theme.textSecondary)
                                .lineLimit(2)
                        }
                        if let quote = tip.quote {
                            Text(quote)
                                .font(TimeMasterFont.blackItalic(12, relativeTo: .caption))
                                .foregroundStyle(Theme.textSecondary)
                                .lineLimit(3)
                                .padding(.top, 2)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(tip.announcement)
            .accessibilityHint("Opens the Tmax menu bar popup")
            VStack(spacing: 6) {
                Button(action: onClose) {
                    Image(systemName: "xmark")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(Theme.textSecondary)
                        .frame(width: 22, height: 22)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Dismiss")
                Button(action: onMute) {
                    Image(systemName: "bell.slash.fill")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(Theme.textSecondary)
                        .frame(width: 22, height: 22)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Mute tips for this workout")
                .help("Mute tips for this workout")
            }
        }
        .padding(12)
        .frame(width: 320)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous).fill(Theme.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(tint.opacity(0.5), lineWidth: 1)
        )
        .padding(8)
        .onHover(perform: onHover)
        .preferredColorScheme(.dark)
    }
}

private final class MenuBarTipPanel: NSPanel {
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}

@MainActor
final class MenuBarGlanceTipController {
    var onOpen: () -> Void = {}
    var onMute: () -> Void = {}

    private var panel: MenuBarTipPanel?
    private var hideItem: DispatchWorkItem?
    private var isHovering = false
    private var generation: UInt64 = 0

    private static let visibleSeconds: TimeInterval = 4
    private static let hoverGraceSeconds: TimeInterval = 1.5

    var isShowing: Bool { panel?.isVisible == true }

    func show(_ tip: MenuBarTip, below anchor: NSRect) {
        generation &+= 1
        let view = MenuBarGlanceTipView(
            tip: tip,
            onOpen: { [weak self] in
                self?.hide(animated: false)
                self?.onOpen()
            },
            onMute: { [weak self] in
                self?.hide(animated: true)
                self?.onMute()
            },
            onClose: { [weak self] in self?.hide(animated: true) },
            onHover: { [weak self] hovering in self?.hoverChanged(hovering) }
        )
        let hosting = NSHostingView(rootView: view)
        let size = hosting.fittingSize

        let panel = self.panel ?? makePanel()
        self.panel = panel
        panel.contentView = hosting
        panel.setContentSize(size)
        panel.setFrameOrigin(origin(for: size, below: anchor))

        let reduceMotion = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
        isHovering = false
        if panel.isVisible {
            panel.alphaValue = 1
        } else {
            panel.alphaValue = reduceMotion ? 1 : 0
            panel.orderFrontRegardless()
            if !reduceMotion {
                NSAnimationContext.runAnimationGroup { context in
                    context.duration = 0.18
                    panel.animator().alphaValue = 1
                }
            }
        }
        NSAccessibility.post(
            element: NSApp as Any,
            notification: .announcementRequested,
            userInfo: [
                .announcement: tip.announcement,
                .priority: NSAccessibilityPriorityLevel.medium.rawValue
            ]
        )
        scheduleHide(after: Self.visibleSeconds)
    }

    func hide(animated: Bool) {
        hideItem?.cancel()
        hideItem = nil
        generation &+= 1
        let hidingGeneration = generation
        guard let panel, panel.isVisible else { return }
        let reduceMotion = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
        if animated && !reduceMotion {
            NSAnimationContext.runAnimationGroup({ context in
                context.duration = 0.18
                panel.animator().alphaValue = 0
            }, completionHandler: { [weak self, weak panel] in
                Task { @MainActor in
                    guard self?.generation == hidingGeneration else { return }
                    panel?.orderOut(nil)
                }
            })
        } else {
            panel.orderOut(nil)
        }
    }

    private func hoverChanged(_ hovering: Bool) {
        isHovering = hovering
        if hovering {
            hideItem?.cancel()
            hideItem = nil
        } else {
            scheduleHide(after: Self.hoverGraceSeconds)
        }
    }

    private func scheduleHide(after seconds: TimeInterval) {
        hideItem?.cancel()
        let item = DispatchWorkItem { [weak self] in
            guard let self, !self.isHovering else { return }
            self.hide(animated: true)
        }
        hideItem = item
        DispatchQueue.main.asyncAfter(deadline: .now() + seconds, execute: item)
    }

    private func makePanel() -> MenuBarTipPanel {
        let panel = MenuBarTipPanel(
            contentRect: NSRect(x: 0, y: 0, width: 336, height: 80),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: true
        )
        panel.isFloatingPanel = true
        panel.level = .statusBar
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.hidesOnDeactivate = false
        panel.becomesKeyOnlyIfNeeded = true
        panel.isReleasedWhenClosed = false
        return panel
    }

    private func origin(for size: NSSize, below anchor: NSRect) -> NSPoint {
        let screen = NSScreen.screens.first { $0.frame.intersects(anchor) } ?? NSScreen.main
        let visible = screen?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1440, height: 900)
        let x = min(max(anchor.midX - size.width / 2, visible.minX + 4), visible.maxX - size.width - 4)
        let y = min(anchor.minY - size.height - 2, visible.maxY - size.height)
        return NSPoint(x: x, y: y)
    }
}
#endif
