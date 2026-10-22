import SwiftUI

struct WorkoutResumeView: View {
    let state: ResumeState
    let workout: Workout?
    let onResume: () -> Void
    let onDiscard: () -> Void
    let onClose: () -> Void

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var showDiscardConfirmation = false

    var body: some View {
        NavigationStack {
            ScrollView {
                summary
                    .padding(ProfileStyle.inset)
                    .frame(maxWidth: ProfileStyle.readableWidth, alignment: .leading)
                    .frame(maxWidth: .infinity)
            }
            .background(Theme.background)
            .safeAreaInset(edge: .bottom, spacing: 0) {
                actions
            }
            .timeMasterNavigationTitle("Resume workout")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                AppToolbar.iconItem(placement: .cancellationAction) {
                    Button("Not now", systemImage: "xmark", action: onClose)
                        .labelStyle(.iconOnly)
                        .keyboardShortcut(.cancelAction)
                        .accessibilityHint("Keeps this session saved for later.")
                        .accessibilityIdentifier("workout-resume-close")
                }
            }
        }
        .font(TimeMasterFont.body())
        .tint(Theme.toolbarOrange)
        .preferredColorScheme(.dark)
        #if os(iOS)
        .presentationDetents(dynamicTypeSize.isAccessibilitySize ? [.large] : [.medium, .large])
        .presentationDragIndicator(.visible)
        #else
        .frame(idealWidth: ProfileStyle.readableWidth)
        #endif
    }

    private var summary: some View {
        VStack(alignment: .leading, spacing: ProfileStyle.spacing) {
            TimeMasterPageTitle(state.workoutName, size: 31, relativeTo: .title2)
                .foregroundStyle(Theme.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)
                .accessibilityIdentifier("workout-resume-title")

            VStack(alignment: .leading, spacing: ProfileStyle.spacing) {
                Label("Saved progress", systemImage: "clock.arrow.circlepath")
                    .font(TimeMasterFont.caption())
                    .foregroundStyle(Theme.textSecondary)

                VStack(alignment: .leading, spacing: ProfileStyle.spacing / 2) {
                    Text(Duration.seconds(max(0, state.elapsedSeconds)), format: .units(
                        allowed: [.hours, .minutes, .seconds],
                        width: .abbreviated
                    ))
                    .font(TimeMasterFont.display())
                    .monospacedDigit()
                    .foregroundStyle(Theme.textPrimary)
                    .accessibilityHint("Elapsed time at the last checkpoint.")
                    .accessibilityIdentifier("workout-resume-elapsed")

                    Text(position)
                        .font(TimeMasterFont.rowTitle())
                        .foregroundStyle(Theme.textPrimary)
                        .accessibilityIdentifier("workout-resume-position")

                    Text(phaseDescription)
                        .font(TimeMasterFont.secondary())
                        .foregroundStyle(Theme.textSecondary)

                    if state.phase != .warmUp, let section {
                        Text(section.name)
                            .font(TimeMasterFont.secondary())
                            .foregroundStyle(Theme.textSecondary)
                    }
                }
                .fixedSize(horizontal: false, vertical: true)
            }
            .padding(ProfileStyle.inset)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.surface, in: RoundedRectangle(cornerRadius: ProfileStyle.corner, style: .continuous))

            Text("Saved \(state.savedAt.formatted(date: .abbreviated, time: .shortened))")
                .font(TimeMasterFont.caption())
                .foregroundStyle(Theme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)

            if workout == nil {
                Label("This workout is no longer in your library. Keep the saved session for later or discard it.", systemImage: "exclamationmark.triangle")
                    .font(TimeMasterFont.secondary())
                    .foregroundStyle(Theme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var actions: some View {
        VStack(spacing: ProfileStyle.spacing / 2) {
            Button(action: onResume) {
                Label("Resume workout", systemImage: "play.fill")
                    .font(TimeMasterFont.label())
                    .frame(maxWidth: .infinity, minHeight: ProfileStyle.touchTarget)
            }
            .buttonStyle(TimeMasterToolbarWideButtonStyle())
            .keyboardShortcut(.defaultAction)
            .disabled(workout == nil)
            .accessibilityIdentifier("workout-resume-continue")

            Button(role: .destructive) {
                showDiscardConfirmation = true
            } label: {
                Label("Discard session", systemImage: "trash")
                    .font(TimeMasterFont.label())
                    .frame(maxWidth: .infinity, minHeight: ProfileStyle.touchTarget)
            }
            .buttonStyle(TimeMasterToolbarWideButtonStyle())
            .accessibilityIdentifier("workout-resume-discard")
            .confirmationDialog("Discard this saved session?", isPresented: $showDiscardConfirmation, titleVisibility: .visible) {
                Button("Discard session", role: .destructive, action: onDiscard)
                Button("Keep workout", role: .cancel) { }
            } message: {
                Text(state.elapsedSeconds >= 180 && workout != nil
                     ? "It will be saved to history as a partial workout. Your resume checkpoint will be removed."
                     : "Your saved progress will be removed. This cannot be undone.")
            }
        }
        .padding(.horizontal, ProfileStyle.inset)
        .padding(.vertical, ProfileStyle.spacing)
        .frame(maxWidth: ProfileStyle.readableWidth)
        .frame(maxWidth: .infinity)
        .background(Theme.background)
    }

    private var section: Section? {
        guard let workout, workout.sections.indices.contains(state.currentSectionIndex) else { return nil }
        return workout.sections[state.currentSectionIndex]
    }

    private var position: String {
        if state.phase == .warmUp { return "Warm-up" }
        if let workout, section != nil {
            return "Section \(state.currentSectionIndex + 1) of \(workout.sections.count)"
        }
        return state.sectionName
    }

    private var phaseDescription: String {
        switch state.phase {
        case .warmUp: return state.isPaused ? "Warm-up paused" : "Warm-up in progress"
        case .prepare: return "Preparing set \(state.currentSetIndex + 1)"
        case .active: return "Set \(state.currentSetIndex + 1) · \(state.isPaused ? "Paused" : "In progress")"
        case .setRest: return "Rest after set \(state.currentSetIndex + 1)"
        case .sectionRest: return "Rest between sections"
        }
    }
}
