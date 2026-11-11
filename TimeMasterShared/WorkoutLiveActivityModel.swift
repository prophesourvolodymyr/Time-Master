#if os(iOS)
import Foundation

struct WorkoutLivePosition: Equatable {
    enum Style: Equatable {
        case dots
        case bar
    }

    static let maxDots = 10

    let style: Style
    let current: Int
    let count: Int

    var fraction: Double {
        Double(current + 1) / Double(count)
    }

    init?(index: Int?, count: Int?, maxDots: Int = WorkoutLivePosition.maxDots) {
        guard let index, let count, count >= 2 else { return nil }
        self.count = count
        self.current = min(count - 1, max(0, index - 1))
        self.style = count > maxDots ? .bar : .dots
    }
}

enum WorkoutLiveNext: String {
    case exercise
    case section
    case finish
}

@available(iOS 17.0, *)
extension WorkoutActivityAttributes.ContentState {
    var progressLength: Int {
        max(phaseDuration, remainingSeconds)
    }

    var runningInterval: ClosedRange<Date>? {
        guard !isPaused, let end = phaseEndDate, progressLength > 0 else { return nil }
        return end.addingTimeInterval(-TimeInterval(progressLength))...end
    }

    var elapsedFraction: Double {
        guard progressLength > 0 else { return 0 }
        return min(1, max(0, 1 - Double(remainingSeconds) / Double(progressLength)))
    }

    var position: WorkoutLivePosition? {
        WorkoutLivePosition(index: itemIndex, count: itemCount)
    }

    var nextKindValue: WorkoutLiveNext? {
        if let nextKind, let kind = WorkoutLiveNext(rawValue: nextKind) { return kind }
        return nextTitle == nil ? nil : .exercise
    }

    var hasNext: Bool {
        phase != .completed && (nextKindValue != nil || nextArtworkName != nil)
    }

    var workoutFraction: Double? {
        if phase == .completed { return 1 }
        guard sectionCount > 0 else { return nil }
        var within = 0.0
        if let itemIndex, let itemCount, itemCount > 0 {
            within = Double(min(itemCount, max(0, itemIndex - 1))) / Double(itemCount)
        } else if sectionCount == 1 {
            return nil
        }
        let section = Double(min(sectionCount - 1, max(0, sectionIndex)))
        return min(1, (section + within) / Double(sectionCount))
    }

    func spokenSummary(workoutName: String) -> String {
        if phase == .completed {
            var parts = ["Workout complete"]
            if elapsedSeconds > 0 {
                parts.append("total time \(Self.spokenDuration(elapsedSeconds))")
            }
            return parts.joined(separator: ", ")
        }
        var parts: [String] = []
        if isPaused { parts.append("Paused") }
        switch phase {
        case .warmUp: parts.append("Warm up")
        case .prepare: parts.append("Get ready")
        case .active: parts.append(title.isEmpty ? workoutName : title)
        case .setRest, .sectionRest: parts.append("Rest")
        case .completed: break
        }
        switch nextKindValue {
        case .exercise?: parts.append(nextTitle.map { "up next \($0)" } ?? "up next exercise")
        case .section?: parts.append(nextTitle.map { "up next section \($0)" } ?? "up next section")
        case .finish?: parts.append("up next finish")
        case nil: break
        }
        if let position {
            let noun = isBundle ? "exercise" : "set"
            parts.append("\(noun) \(position.current + 1) of \(position.count)")
        }
        if sectionCount > 1 {
            parts.append("section \(min(sectionCount, sectionIndex + 1)) of \(sectionCount)")
        }
        return parts.joined(separator: ", ")
    }

    static func spokenDuration(_ seconds: Int) -> String {
        let formatter = DateComponentsFormatter()
        formatter.unitsStyle = .full
        formatter.allowedUnits = [.hour, .minute, .second]
        formatter.zeroFormattingBehavior = .dropAll
        return formatter.string(from: TimeInterval(max(0, seconds))) ?? ""
    }

    static func clock(seconds: Int, showsHours: Bool) -> String {
        let total = max(0, seconds)
        if showsHours && total >= 3600 {
            return String(format: "%d:%02d:%02d", total / 3600, (total % 3600) / 60, total % 60)
        }
        return String(format: "%d:%02d", total / 60, total % 60)
    }
}
#endif
