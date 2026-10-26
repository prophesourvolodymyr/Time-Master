import Foundation

extension Notification.Name {
    static let openAppPage = Notification.Name("com.timemaster.openAppPage")
}

enum AppCommandRequest: Equatable {
    case startWorkout(UUID?)
    case openPage(destination: String, coachPrompt: String?)
    case openWorkoutDetail(UUID)
    case newWorkout

    fileprivate var kind: Int {
        switch self {
        case .startWorkout: 0
        case .openPage: 1
        case .openWorkoutDetail: 2
        case .newWorkout: 3
        }
    }
}

struct AppCommandQueue {
    private(set) var pending: [AppCommandRequest] = []

    mutating func enqueue(_ request: AppCommandRequest) {
        pending.removeAll { $0.kind == request.kind }
        pending.append(request)
    }

    mutating func drain() -> [AppCommandRequest] {
        defer { pending.removeAll() }
        return pending
    }
}

@MainActor
enum AppCommandBus {
    private static var queue = AppCommandQueue()
    private static var isReady = false

    static func setReady(_ ready: Bool) {
        isReady = ready
        guard ready else { return }
        deliver(queue.drain())
    }

    static func startWorkout(_ workoutID: UUID?) {
        send(.startWorkout(workoutID))
    }

    static func openPage(_ destination: SlotNavigationDestination, coachPrompt: String? = nil) {
        send(.openPage(destination: destination.rawValue, coachPrompt: coachPrompt))
    }

    static func openWorkoutDetail(_ workoutID: UUID) {
        send(.openWorkoutDetail(workoutID))
    }

    static func newWorkout() {
        send(.newWorkout)
    }

    static func showMainWindow() {
#if os(macOS)
        MacMainWindow.show()
#endif
    }

    private static func send(_ request: AppCommandRequest) {
        showMainWindow()
        if isReady {
            deliver([request])
        } else {
            queue.enqueue(request)
        }
    }

    private static func deliver(_ requests: [AppCommandRequest]) {
        for request in requests {
            switch request {
            case .startWorkout(let workoutID):
                NotificationCenter.default.post(
                    name: .launchWorkout,
                    object: nil,
                    userInfo: workoutID.map { ["workoutID": $0] }
                )
            case .openPage(let destination, let coachPrompt):
                var info: [String: Any] = ["destination": destination]
                if let coachPrompt, !coachPrompt.isEmpty { info["coachPrompt"] = coachPrompt }
                NotificationCenter.default.post(name: .openAppPage, object: nil, userInfo: info)
            case .openWorkoutDetail(let workoutID):
                NotificationCenter.default.post(
                    name: .openWorkoutDetail,
                    object: nil,
                    userInfo: ["workoutID": workoutID]
                )
            case .newWorkout:
                NotificationCenter.default.post(
                    name: .openAppPage,
                    object: nil,
                    userInfo: ["destination": SlotNavigationDestination.workouts.rawValue]
                )
                DispatchQueue.main.async {
                    NotificationCenter.default.post(name: .newWorkoutCommand, object: nil)
                }
            }
        }
    }
}
