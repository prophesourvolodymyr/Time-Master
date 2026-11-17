import Foundation

/// What a Done tap on an untimed set does. A fresh guard belongs to each set; the player measures `elapsed` from the
/// moment the set itself starts (preparation excluded, pauses excluded).
///
/// - From `threshold` seconds on, Done finishes the set at once.
/// - Earlier, the first tap only teases ("Are you a superhuman?"), the second asks "Are you sure you're done?", and
///   once that question has been answered any further early tap skips the set without asking again.
struct EarlyDoneGuard: Equatable {
    enum Outcome: Equatable {
        /// Done at or after the threshold: the set is complete.
        case complete
        /// First early tap: the playful popup; the set keeps running.
        case superhuman
        /// Second early tap: ask "Are you sure you're done?".
        case confirm
        /// An early finish the user insisted on: leave the set.
        case skip
    }

    enum Stage: Equatable {
        case fresh
        case teased
        case asked
    }

    static let threshold = 20

    private(set) var stage = Stage.fresh

    mutating func pressDone(elapsed: Int) -> Outcome {
        guard elapsed < Self.threshold else { return .complete }
        switch stage {
        case .fresh:
            stage = .teased
            return .superhuman
        case .teased:
            stage = .asked
            return .confirm
        case .asked:
            return .skip
        }
    }
}
