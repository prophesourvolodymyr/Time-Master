import ObjectiveC
import XCTest

/// Lets a scene skip XCUITest's wait-for-idle while the app runs endless animations (timers, live maps).
enum Quiescence {
    nonisolated(unsafe) static var enabled = true
    nonisolated(unsafe) private static var installed = false

    static func install() {
        guard !installed, let processClass = NSClassFromString("XCUIApplicationProcess") else { return }
        installed = true
        let single = NSSelectorFromString("waitForQuiescenceIncludingAnimationsIdle:")
        if let method = class_getInstanceMethod(processClass, single) {
            typealias Original = @convention(c) (AnyObject, Selector, Bool) -> Void
            let original = unsafeBitCast(method_getImplementation(method), to: Original.self)
            let replacement: @convention(block) (AnyObject, Bool) -> Void = { process, animations in
                if enabled { original(process, single, animations) }
            }
            method_setImplementation(method, imp_implementationWithBlock(replacement))
        }
        let preEvent = NSSelectorFromString("waitForQuiescenceIncludingAnimationsIdle:isPreEvent:")
        if let method = class_getInstanceMethod(processClass, preEvent) {
            typealias Original = @convention(c) (AnyObject, Selector, Bool, Bool) -> Void
            let original = unsafeBitCast(method_getImplementation(method), to: Original.self)
            let replacement: @convention(block) (AnyObject, Bool, Bool) -> Void = { process, animations, isPreEvent in
                if enabled { original(process, preEvent, animations, isPreEvent) }
            }
            method_setImplementation(method, imp_implementationWithBlock(replacement))
        }
    }
}
