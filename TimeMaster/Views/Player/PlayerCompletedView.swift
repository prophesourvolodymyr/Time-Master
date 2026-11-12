import SwiftUI

struct PlayerCompletedView: View {
    let workoutName: String
    let elapsedSeconds: Int
    let exerciseCount: Int
    let sectionCount: Int
    let onDone: () -> Void

    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                Spacer()

                VStack(spacing: 16) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 80))
                        .foregroundColor(.white)
                        .accessibilityHidden(true)

                    Text("Workout Complete")
                        .font(TimeMasterFont.black(34, relativeTo: .largeTitle))
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.horizontal, ProfileStyle.inset)

                    Text("Great job finishing \(workoutName).")
                        .font(TimeMasterFont.body(17))
                        .foregroundColor(.white.opacity(0.6))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 48)

                    HStack(spacing: 12) {
                        statChip(symbol: "timer", value: PlayerTime.clock(elapsedSeconds), spoken: PlayerTime.spoken(elapsedSeconds))
                        statChip(symbol: "figure.strengthtraining.traditional", value: "\(exerciseCount)", spoken: "\(exerciseCount) exercises")
                        if sectionCount > 1 {
                            statChip(symbol: "square.stack.3d.up.fill", value: "\(sectionCount)", spoken: "\(sectionCount) sections")
                        }
                    }
                    .padding(.top, 4)
                }
                .frame(maxWidth: .infinity)

                Spacer()

                Button(action: onDone) {
                    Text("Done")
                        .font(TimeMasterFont.black(17, relativeTo: .headline))
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(TimeMasterActionButtonStyle(prominent: true, minimumSize: 60))
                .padding(.horizontal, 24)
                .padding(.bottom, 32)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            PlayerConfettiView()
        }
    }

    private func statChip(symbol: String, value: String, spoken: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: symbol).font(.system(size: 14, weight: .bold))
            Text(value).font(TimeMasterFont.black(16, relativeTo: .body).monospacedDigit())
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 14)
        .frame(height: 40)
        .background(.white.opacity(0.14), in: Capsule())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(spoken)
    }
}
