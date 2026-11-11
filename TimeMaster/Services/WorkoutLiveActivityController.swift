#if os(iOS)
import ActivityKit
import Foundation

struct WorkoutLiveActivitySnapshot {
    let workoutID: UUID
    let workoutName: String
    let colorHex: String
    let phase: WorkoutPhase
    let title: String
    let subtitle: String
    let isPaused: Bool
    let remainingSeconds: Int
    let phaseDuration: Int
    let elapsedSeconds: Int
    let nextTitle: String?
    let startedAt: Date
    var itemIndex: Int? = nil
    var itemCount: Int? = nil
    var sectionIndex: Int = 0
    var sectionCount: Int = 0
    var isBundle: Bool = false
    var nextKind: String? = nil
    var artworkName: String? = nil
    var nextArtworkName: String? = nil
}

private func liveActivityText(_ text: String, limit: Int = 60) -> String {
    String(text.prefix(limit))
}

extension WorkoutLiveActivitySnapshot {
    var normalized: WorkoutLiveActivitySnapshot {
        let name = liveActivityText(workoutName)
        let heading = liveActivityText(title)
        let remaining = max(0, remainingSeconds)
        let count = itemCount.flatMap { $0 > 0 ? $0 : nil }
        let index = count.flatMap { count in itemIndex.map { min(count, max(1, $0)) } }
        let sections = max(0, sectionCount)
        return WorkoutLiveActivitySnapshot(
            workoutID: workoutID,
            workoutName: name,
            colorHex: liveActivityText(colorHex, limit: 12),
            phase: phase,
            title: heading.isEmpty ? name : heading,
            subtitle: liveActivityText(subtitle),
            isPaused: isPaused,
            remainingSeconds: remaining,
            phaseDuration: max(0, phaseDuration),
            elapsedSeconds: max(0, elapsedSeconds),
            nextTitle: nextTitle.flatMap { $0.isEmpty ? nil : liveActivityText($0) },
            startedAt: startedAt,
            itemIndex: index,
            itemCount: count,
            sectionIndex: sections == 0 ? 0 : min(sections - 1, max(0, sectionIndex)),
            sectionCount: sections,
            isBundle: isBundle,
            nextKind: nextKind.flatMap { WorkoutLiveNext(rawValue: $0) == nil ? nil : $0 },
            artworkName: artworkName.flatMap { Self.artworkFileName($0) },
            nextArtworkName: nextArtworkName.flatMap { Self.artworkFileName($0) }
        )
    }

    private static func artworkFileName(_ name: String) -> String? {
        name.isEmpty || name.count > WorkoutLiveActivityArtwork.maxFileNameLength ? nil : name
    }
}

@MainActor
final class WorkoutLiveActivityController {
    static let shared = WorkoutLiveActivityController()

    private static let staleGrace: TimeInterval = 15
    private static let endDateTolerance: TimeInterval = 2
    private static let completionLinger: TimeInterval = 120

    private var activity: AnyObject?
    private var pushed: WorkoutLiveActivitySnapshot?
    private var pushedEndDate: Date?
    private var dismissedWorkoutID: UUID?
    private var reconciledStrays = false
    private var pending: Task<Void, Never>?

    private init() {}

    func sync(_ snapshot: WorkoutLiveActivitySnapshot) {
        if #available(iOS 17.0, *) {
            push(snapshot.normalized)
        }
    }

    func end(completed: Bool, elapsedSeconds: Int) {
        if #available(iOS 17.0, *) {
            finish(completed: completed, elapsedSeconds: elapsedSeconds)
        }
    }

    private func enqueue(_ operation: @escaping @MainActor () async -> Void) {
        let previous = pending
        pending = Task { @MainActor in
            await previous?.value
            await operation()
        }
    }

    private func record(_ snapshot: WorkoutLiveActivitySnapshot, endDate: Date?) {
        pushed = snapshot
        pushedEndDate = endDate
    }

    private func needsUpdate(for snapshot: WorkoutLiveActivitySnapshot, endDate: Date?) -> Bool {
        guard let last = pushed else { return true }
        guard last.phase == snapshot.phase,
              last.title == snapshot.title,
              last.subtitle == snapshot.subtitle,
              last.isPaused == snapshot.isPaused,
              last.nextTitle == snapshot.nextTitle,
              last.phaseDuration == snapshot.phaseDuration,
              last.itemIndex == snapshot.itemIndex,
              last.itemCount == snapshot.itemCount,
              last.sectionIndex == snapshot.sectionIndex,
              last.sectionCount == snapshot.sectionCount,
              last.isBundle == snapshot.isBundle,
              last.nextKind == snapshot.nextKind,
              last.artworkName == snapshot.artworkName,
              last.nextArtworkName == snapshot.nextArtworkName
        else { return true }
        guard let endDate, let lastEndDate = pushedEndDate else {
            return last.remainingSeconds != snapshot.remainingSeconds
        }
        return abs(endDate.timeIntervalSince(lastEndDate)) > Self.endDateTolerance
    }

    @available(iOS 17.0, *)
    private var trackedActivity: Activity<WorkoutActivityAttributes>? {
        activity as? Activity<WorkoutActivityAttributes>
    }

    @available(iOS 17.0, *)
    private static func isLive(_ activity: Activity<WorkoutActivityAttributes>) -> Bool {
        activity.activityState != .ended && activity.activityState != .dismissed
    }

    @available(iOS 17.0, *)
    private static func phase(for phase: WorkoutPhase) -> WorkoutActivityAttributes.ContentState.Phase {
        switch phase {
        case .warmUp: .warmUp
        case .prepare: .prepare
        case .active: .active
        case .setRest: .setRest
        case .sectionRest: .sectionRest
        }
    }

    @available(iOS 17.0, *)
    private static func state(
        from snapshot: WorkoutLiveActivitySnapshot,
        endDate: Date?
    ) -> WorkoutActivityAttributes.ContentState {
        WorkoutActivityAttributes.ContentState(
            phase: phase(for: snapshot.phase),
            title: snapshot.title,
            subtitle: snapshot.subtitle,
            isPaused: snapshot.isPaused,
            remainingSeconds: snapshot.remainingSeconds,
            phaseDuration: snapshot.phaseDuration,
            phaseEndDate: endDate,
            nextTitle: snapshot.nextTitle,
            elapsedSeconds: snapshot.elapsedSeconds,
            itemIndex: snapshot.itemIndex,
            itemCount: snapshot.itemCount,
            sectionIndex: snapshot.sectionIndex,
            sectionCount: snapshot.sectionCount,
            isBundle: snapshot.isBundle,
            nextKind: snapshot.nextKind,
            artworkName: snapshot.artworkName,
            nextArtworkName: snapshot.nextArtworkName
        )
    }

    @available(iOS 17.0, *)
    private static func completedState(elapsedSeconds: Int) -> WorkoutActivityAttributes.ContentState {
        WorkoutActivityAttributes.ContentState(
            phase: .completed,
            title: "Workout complete",
            subtitle: "",
            isPaused: false,
            remainingSeconds: 0,
            phaseDuration: 0,
            phaseEndDate: nil,
            nextTitle: nil,
            elapsedSeconds: max(0, elapsedSeconds)
        )
    }

    @available(iOS 17.0, *)
    private func adoptStrayActivities(for snapshot: WorkoutLiveActivitySnapshot) {
        let workoutID = snapshot.workoutID
        guard !reconciledStrays else { return }
        reconciledStrays = true
        WorkoutLiveActivityArtwork.prune(keeping: [snapshot.artworkName, snapshot.nextArtworkName].compactMap { $0 })
        for stray in Activity<WorkoutActivityAttributes>.activities where Self.isLive(stray) {
            if activity == nil, stray.attributes.workoutID == workoutID.uuidString {
                activity = stray
            } else {
                enqueue { await stray.end(nil, dismissalPolicy: .immediate) }
            }
        }
    }

    @available(iOS 17.0, *)
    private func push(_ snapshot: WorkoutLiveActivitySnapshot) {
        adoptStrayActivities(for: snapshot)

        var current = trackedActivity
        if let existing = current, !Self.isLive(existing) {
            activity = nil
            pushed = nil
            pushedEndDate = nil
            dismissedWorkoutID = snapshot.workoutID
            current = nil
        }
        guard dismissedWorkoutID != snapshot.workoutID else { return }

        let endDate: Date? = snapshot.isPaused
            ? nil
            : Date().addingTimeInterval(TimeInterval(snapshot.remainingSeconds))

        if let current {
            guard needsUpdate(for: snapshot, endDate: endDate) || current.activityState == .stale else { return }
            let content = ActivityContent(
                state: Self.state(from: snapshot, endDate: endDate),
                staleDate: endDate?.addingTimeInterval(Self.staleGrace)
            )
            record(snapshot, endDate: endDate)
            enqueue { await current.update(content) }
        } else {
            guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
            let attributes = WorkoutActivityAttributes(
                workoutID: snapshot.workoutID.uuidString,
                workoutName: snapshot.workoutName,
                colorHex: snapshot.colorHex,
                startedAt: snapshot.startedAt
            )
            let content = ActivityContent(
                state: Self.state(from: snapshot, endDate: endDate),
                staleDate: endDate?.addingTimeInterval(Self.staleGrace)
            )
            do {
                activity = try Activity<WorkoutActivityAttributes>.request(
                    attributes: attributes,
                    content: content,
                    pushType: nil
                )
                record(snapshot, endDate: endDate)
            } catch {
                return
            }
        }
    }

    @available(iOS 17.0, *)
    private func finish(completed: Bool, elapsedSeconds: Int) {
        let tracked = trackedActivity
        activity = nil
        pushed = nil
        pushedEndDate = nil
        dismissedWorkoutID = nil
        reconciledStrays = true

        let others = Activity<WorkoutActivityAttributes>.activities.filter {
            Self.isLive($0) && $0.id != tracked?.id
        }

        if let tracked, Self.isLive(tracked) {
            if completed {
                let content = ActivityContent(
                    state: Self.completedState(elapsedSeconds: elapsedSeconds),
                    staleDate: nil
                )
                let dismissal = ActivityUIDismissalPolicy.after(Date().addingTimeInterval(Self.completionLinger))
                enqueue { await tracked.end(content, dismissalPolicy: dismissal) }
            } else {
                enqueue { await tracked.end(nil, dismissalPolicy: .immediate) }
            }
        }
        for other in others {
            enqueue { await other.end(nil, dismissalPolicy: .immediate) }
        }
        enqueue { [weak self] in
            guard self?.activity == nil else { return }
            WorkoutLiveActivityArtwork.prune(keeping: [String]())
        }
    }
}
#endif
