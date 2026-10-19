import Foundation
import CoreGraphics

struct SlotNavigationOverlayState {
    private(set) var isVisible = false
    private(set) var dismissalDeadline: ContinuousClock.Instant?

    mutating func reveal(at now: ContinuousClock.Instant, interacting: Bool) {
        isVisible = true
        interactionChanged(interacting, at: now)
    }

    mutating func interactionChanged(_ active: Bool, at now: ContinuousClock.Instant) {
        guard isVisible else { return }
        dismissalDeadline = active ? nil : now.advanced(by: .seconds(2))
    }

    mutating func dismiss() {
        isVisible = false
        dismissalDeadline = nil
    }

    @discardableResult
    mutating func dismissIfExpired(at now: ContinuousClock.Instant) -> Bool {
        guard let dismissalDeadline, now >= dismissalDeadline else { return false }
        dismiss()
        return true
    }

    static func acceptsReveal(start: CGPoint, translation: CGSize, viewportHeight: CGFloat) -> Bool {
        start.y >= max(0, viewportHeight - 56)
            && translation.height <= -48
            && abs(translation.height) > abs(translation.width) * 1.25
    }
}
