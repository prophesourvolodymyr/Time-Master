import XCTest

extension XCUIApplication {
    /// A workout interrupted by an earlier run is offered for resuming over the Home page and blocks every tap behind
    /// it; discard it so the test starts clean.
    func discardSavedWorkoutIfOffered(timeout: TimeInterval = 5) {
        let discard = buttons.matching(NSPredicate(format: "label == %@", "Discard session"))
        guard discard.firstMatch.waitForExistence(timeout: timeout) else { return }
        discard.firstMatch.tap()
        let confirmation = sheets.buttons["Discard session"].firstMatch
        if confirmation.waitForExistence(timeout: 3) {
            confirmation.tap()
        } else if discard.count > 1 {
            discard.element(boundBy: discard.count - 1).tap()
        }
        _ = buttons["Resume workout"].firstMatch.waitForNonExistence(timeout: 5)
    }
}
