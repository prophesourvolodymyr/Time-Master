// SlotNavigationBadges.swift
//
// The red counts on the pages of the bar and the wheel, from real state: workouts planned for today and not done yet
// (Schedule), a workout waiting to be resumed (Workouts), and the coach waiting for an answer or having replied while
// another page was open (AI Coach). Only the bar's and the wheel's badges observe this, so a change redraws nothing else.

import SwiftUI
import Combine

@MainActor
final class SlotNavigationBadges: ObservableObject {
    @Published private(set) var counts: [String: Int] = [:]

    private var cancellables: Set<AnyCancellable> = []
    private var pending = 0
    private var resumable = false
    private var awaitingApproval = false
    private var coachUnseen = false
    private var shownPage: String?
    private var coachWorking = false
    private weak var workoutStore: WorkoutStore?

    func count(for id: String) -> Int {
        counts[id] ?? 0
    }

    func connect(workoutStore: WorkoutStore, aiStore: AIStore, resume: WorkoutResumeManager) {
        guard self.workoutStore !== workoutStore else { return }
        self.workoutStore = workoutStore
        cancellables.removeAll()

        let dayChanges = NotificationCenter.default.publisher(for: .NSCalendarDayChanged).map { _ in () }
        let scheduleChanges = Publishers.MergeMany(
            workoutStore.$weeklySchedule.map { _ in () }.eraseToAnyPublisher(),
            workoutStore.$scheduleActivity.map { _ in () }.eraseToAnyPublisher(),
            workoutStore.$historyEntries.map { _ in () }.eraseToAnyPublisher(),
            workoutStore.$workouts.map { _ in () }.eraseToAnyPublisher(),
            dayChanges.eraseToAnyPublisher()
        )
        scheduleChanges
            .debounce(for: .milliseconds(350), scheduler: DispatchQueue.main)
            .sink { [weak self] in self?.refreshSchedule() }
            .store(in: &cancellables)

        resume.$hasResumableWorkout
            .removeDuplicates()
            .sink { [weak self] value in
                self?.resumable = value
                self?.publish()
            }
            .store(in: &cancellables)

        aiStore.$pendingApproval
            .map { $0 != nil }
            .removeDuplicates()
            .sink { [weak self] value in
                self?.awaitingApproval = value
                self?.publish()
            }
            .store(in: &cancellables)

        aiStore.$isLoading.combineLatest(aiStore.$isAgentRunning)
            .map { $0 || $1 }
            .removeDuplicates()
            .sink { [weak self] working in self?.coachWorkingChanged(working) }
            .store(in: &cancellables)

        refreshSchedule()
    }

    /// The page on screen: opening the coach clears its reply mark.
    func pageShown(_ id: String?) {
        shownPage = id
        if id == SlotNavigationDestination.coach.rawValue, coachUnseen {
            coachUnseen = false
            publish()
        }
    }

    private func coachWorkingChanged(_ working: Bool) {
        defer { coachWorking = working }
        guard coachWorking, !working, shownPage != SlotNavigationDestination.coach.rawValue else { return }
        coachUnseen = true
        publish()
    }

    private func refreshSchedule() {
        guard let workoutStore else { return }
        pending = workoutStore.scheduledWorkouts(for: Date()).filter { $0.status == .pending }.count
        publish()
    }

    private func publish() {
        var next: [String: Int] = [:]
        if pending > 0 { next[SlotNavigationDestination.schedule.rawValue] = pending }
        if resumable { next[SlotNavigationDestination.workouts.rawValue] = 1 }
        let coach = (awaitingApproval ? 1 : 0) + (coachUnseen ? 1 : 0)
        if coach > 0 { next[SlotNavigationDestination.coach.rawValue] = coach }
        if next != counts { counts = next }
    }
}

/// An iOS badge: a bold white count on a red capsule with a ring the colour of the surface under it, popping in with a
/// spring and bumping when the count changes.
struct SlotNavigationBadge: View {
    let count: Int
    var ring: Color = Theme.background
    var size: CGFloat = 20

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var bump: CGFloat = 1

    var body: some View {
        let label = count > 99 ? "99+" : "\(count)"
        Text(label)
            .font(.system(size: size * 0.64, weight: .heavy, design: .rounded))
            .monospacedDigit()
            .foregroundStyle(.white)
            .lineLimit(1)
            .fixedSize()
            .padding(.horizontal, label.count > 1 ? size * 0.3 : 0)
            .frame(minWidth: size, minHeight: size)
            .background {
                Capsule(style: .continuous)
                    .fill(LinearGradient(
                        colors: [Color(hex: "FF5A4F"), Color(hex: "FF3B30"), Color(hex: "E5251B")],
                        startPoint: .top, endPoint: .bottom
                    ))
                    .overlay {
                        Capsule(style: .continuous)
                            .strokeBorder(Color.white.opacity(0.28), lineWidth: 0.6)
                            .blendMode(.plusLighter)
                    }
                    .shadow(color: Color(hex: "FF3B30").opacity(0.45), radius: 4, y: 1)
            }
            .padding(2)
            .background(Capsule(style: .continuous).fill(ring))
            .scaleEffect(bump)
            .transition(reduceMotion ? .opacity : .scale(scale: 0.2).combined(with: .opacity))
            .onChange(of: count) { _ in
                guard !reduceMotion else { return }
                bump = 1.28
                withAnimation(.spring(response: 0.32, dampingFraction: 0.42)) { bump = 1 }
            }
            .accessibilityHidden(true)
    }

    static func accessibilityText(_ count: Int) -> String? {
        guard count > 0 else { return nil }
        return count == 1 ? "1 notification" : "\(count) notifications"
    }
}
