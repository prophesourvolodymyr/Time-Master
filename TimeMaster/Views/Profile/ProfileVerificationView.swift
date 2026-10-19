import SwiftUI

extension LocalVerificationProgress {
    init(profile: LocalUserProfile, history: [WorkoutHistoryEntry], activities: [OutdoorActivity], now: Date = Date(), calendar: Calendar = .current) {
        let indoor = history.map {
            LocalTrainingSession(id: $0.id.uuidString, completedAt: $0.completedAt, isComplete: !$0.isPartial)
        }
        let outdoor = activities.map {
            LocalTrainingSession(
                id: $0.id.uuidString,
                completedAt: $0.endedAt ?? $0.startedAt.addingTimeInterval(TimeInterval(max(0, $0.elapsedSeconds))),
                isComplete: $0.finished && $0.establishedAt != nil
            )
        }
        self.init(createdAt: profile.createdAt, sessions: indoor + outdoor, now: now, calendar: calendar)
    }
}

struct ProfileVerificationView: View {
    @EnvironmentObject private var profileStore: LocalProfileStore
    @EnvironmentObject private var workoutStore: WorkoutStore
    @EnvironmentObject private var outdoorStore: OutdoorActivityStore
    @Environment(\.dismiss) private var dismiss
    @State private var selectedTier: LocalBadgeTier = .blue
    @State private var showsPreview = false
    @State private var errorMessage: String?

    private func progress(at date: Date = Date()) -> LocalVerificationProgress {
        LocalVerificationProgress(profile: profileStore.profile, history: workoutStore.historyEntries, activities: outdoorStore.activities, now: date)
    }

    var body: some View {
        NavigationStack {
            TimelineView(.periodic(from: .now, by: 60)) { timeline in
                ProfileSettingsPage(title: "Verification") {
                    introduction
                    qualification(progress(at: timeline.date))
                    tierSelection
                }
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }.frame(minWidth: 44, minHeight: 44)
                }
            }
            .sheet(isPresented: $showsPreview) {
                NavigationStack {
                    ProfileSettingsPage(title: "Badge preview") {
                        tierPreview
                        Text("This preview shows your actual local profile. It is not a network account, trusted identity, subscription, or verified status.")
                            .font(TimeMasterFont.secondary()).foregroundStyle(ProfileStyle.secondary)
                        applyButton
                    }
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Done") { showsPreview = false }.frame(minWidth: 44, minHeight: 44)
                        }
                    }
                    .profileErrorAlert($errorMessage)
                }
                .tint(.white)
                .preferredColorScheme(.dark)
            }
            .profileErrorAlert($errorMessage)
            .onAppear { selectedTier = profileStore.snapshot.badgePreview ?? .blue }
        }
        .tint(.white)
        .preferredColorScheme(.dark)
    }

    private var introduction: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("SHOW UP.\nMAKE IT COUNT.").font(TimeMasterFont.title())
            Text("A local consistency milestone")
                .font(TimeMasterFont.heading()).foregroundStyle(.orange)
            Text("Earn a milestone from your real TimeMaster training history. This is an on-device record, not trusted network verification or proof of identity.")
                .font(TimeMasterFont.secondary()).foregroundStyle(ProfileStyle.secondary)
        }
    }

    private func qualification(_ progress: LocalVerificationProgress) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Earned through consistency").font(TimeMasterFont.heading())
            VStack(spacing: 20) {
                progressRow(title: "Local profile age", symbol: "hourglass", value: progress.accountDays, goal: LocalVerificationProgress.requiredAccountDays, unit: "days", explanation: "At least 180 days since this local profile was created.")
                progressRow(title: "Completed sessions", symbol: "figure.strengthtraining.traditional", value: progress.completedSessions, goal: LocalVerificationProgress.requiredSessions, unit: "sessions", explanation: "100 unique completed indoor or saved, finished outdoor sessions in the trailing 180 days.")
                progressRow(title: "Distinct active days", symbol: "calendar", value: progress.activeDays, goal: LocalVerificationProgress.requiredActiveDays, unit: "days", explanation: "Training on at least 75 different calendar days in the same trailing 180-day window.")
            }
            .padding(ProfileStyle.inset)
            .modifier(TimeMasterCardSurface(flat: true))
            Text("Private training counts locally. Partial workouts, unfinished outdoor recordings, future sessions, and duplicate session IDs do not. Route coordinates and private history are never published by this feature.")
                .font(TimeMasterFont.caption()).foregroundStyle(ProfileStyle.secondary)
            if profileStore.snapshot.earnedMilestoneClaimed {
                Label("Consistency milestone claimed locally", systemImage: "medal")
                    .font(TimeMasterFont.rowTitle()).foregroundStyle(.orange)
                Text("Saved on this device. This does not grant an identity checkmark or a badge tier. Current qualification is shown above and can change as the 180-day window moves.")
                    .font(TimeMasterFont.secondary()).foregroundStyle(ProfileStyle.secondary)
            } else {
                Button("Claim local consistency milestone") {
                    do { try profileStore.claimMilestone(progress: self.progress()) }
                    catch { errorMessage = error.localizedDescription }
                }
                .buttonStyle(ProfilePrimaryButtonStyle())
                .disabled(!progress.isEligible || profileStore.isReadOnly)
                if !progress.isEligible {
                    Text("All three goals are required. Keep training; your real local history updates these totals.")
                        .font(TimeMasterFont.caption()).foregroundStyle(ProfileStyle.secondary)
                }
            }
        }
    }

    private func progressRow(title: String, symbol: String, value: Int, goal: Int, unit: String, explanation: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: symbol).frame(width: 24).accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 4) {
                    Text(title).font(TimeMasterFont.rowTitle())
                    Text("\(value.formatted()) / \(goal.formatted()) \(unit)")
                        .font(TimeMasterFont.secondary()).foregroundStyle(ProfileStyle.secondary)
                }
                Spacer(minLength: 0)
                if value >= goal {
                    Image(systemName: "checkmark.circle.fill").foregroundStyle(.orange)
                        .accessibilityLabel("Goal met")
                }
            }
            ProgressView(value: min(1, max(0, Double(value) / Double(goal))))
                .tint(.orange)
                .accessibilityLabel(title)
                .accessibilityValue("\(value) of \(goal) \(unit)")
            Text(explanation).font(TimeMasterFont.caption()).foregroundStyle(ProfileStyle.secondary)
        }
        .accessibilityElement(children: .combine)
    }

    private var tierSelection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Paid-tier designs · Preview only").font(TimeMasterFont.heading())
            Text("Explore Blue, Silver, and Gold styling without buying anything. No charge, subscription, payment flow, identity verification, or additional privileges. Applying only saves a labeled local preview.")
                .font(TimeMasterFont.secondary()).foregroundStyle(ProfileStyle.secondary)
            ForEach(LocalBadgeTier.allCases) { tier in
                Button { selectedTier = tier } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "shield.lefthalf.filled")
                            .font(.title2).foregroundStyle(tierColor(tier))
                            .frame(width: 44, height: 44)
                            .accessibilityHidden(true)
                        VStack(alignment: .leading, spacing: 4) {
                            Text("\(tier.title) · Preview").font(TimeMasterFont.rowTitle()).foregroundStyle(.white)
                            Text("Design only · No subscription").font(TimeMasterFont.caption()).foregroundStyle(ProfileStyle.secondary)
                        }
                        Spacer(minLength: 0)
                        Image(systemName: selectedTier == tier ? "largecircle.fill.circle" : "circle")
                            .foregroundStyle(selectedTier == tier ? .white : ProfileStyle.secondary)
                            .accessibilityHidden(true)
                    }
                    .padding(12)
                    .frame(maxWidth: .infinity, minHeight: 68, alignment: .leading)
                    .modifier(TimeMasterCardSurface(flat: true))
                    .overlay {
                        RoundedRectangle(cornerRadius: ProfileStyle.corner)
                            .strokeBorder(selectedTier == tier ? Color.white.opacity(0.65) : .clear, lineWidth: 1)
                    }
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(selectedTier == tier ? .isSelected : [])
            }
            Button { showsPreview = true } label: {
                ProfilePillLabel(title: "Preview on your profile", symbol: "eye", isSelected: false)
            }
            .buttonStyle(.plain)
            applyButton
            if let applied = profileStore.snapshot.badgePreview {
                Text("\(applied.title) Preview is saved locally. Your profile always labels it Preview; it is not verified status.")
                    .font(TimeMasterFont.secondary()).foregroundStyle(.orange)
                Button("Clear local badge preview") {
                    do { try profileStore.setBadgePreview(nil) }
                    catch { errorMessage = error.localizedDescription }
                }
                .frame(minHeight: 44)
                .disabled(profileStore.isReadOnly)
            }
        }
    }

    private var applyButton: some View {
        Button(profileStore.snapshot.badgePreview == selectedTier ? "\(selectedTier.title) Preview applied locally" : "Apply \(selectedTier.title) local preview") {
            do { try profileStore.setBadgePreview(selectedTier) }
            catch { errorMessage = error.localizedDescription }
        }
        .buttonStyle(ProfilePrimaryButtonStyle())
        .disabled(profileStore.snapshot.badgePreview == selectedTier || profileStore.isReadOnly)
    }

    private var tierPreview: some View {
        VStack(alignment: .leading, spacing: 16) {
            ProfileStyledAvatar(profile: profileStore.profile, size: 96)
            ProfileStyledName(text: profileStore.profile.displayName)
            Text("@\(profileStore.profile.handle)").font(TimeMasterFont.secondary()).foregroundStyle(ProfileStyle.secondary)
            Label("\(selectedTier.title) · Preview", systemImage: "shield.lefthalf.filled")
                .font(TimeMasterFont.rowTitle()).foregroundStyle(tierColor(selectedTier))
                .padding(12).background(Theme.surface2, in: Capsule())
            Text("Preview only · No verified status").font(TimeMasterFont.caption()).foregroundStyle(.orange)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(ProfileStyle.inset)
        .modifier(TimeMasterCardSurface(flat: true))
    }

    private func tierColor(_ tier: LocalBadgeTier) -> Color {
        switch tier {
        case .blue: return .blue
        case .silver: return Color(white: 0.8)
        case .gold: return .orange
        }
    }
}
