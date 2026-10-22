import SwiftUI

struct TmaxCircularLoader: View {
    var rotationDuration: TimeInterval = 0.95
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    @State private var startedAt = Date()

    var body: some View {
        GeometryReader { geometry in
            let lineWidth = max(3, geometry.size.width * 0.14)
            TimelineView(.animation(minimumInterval: 1.0 / 60, paused: reduceMotion || scenePhase != .active)) { context in
                let elapsed = max(0, context.date.timeIntervalSince(startedAt))
                ZStack {
                    Circle()
                        .stroke(.white.opacity(0.10), lineWidth: lineWidth)
                    Circle()
                        .trim(from: 0.04, to: 0.78)
                        .stroke(
                            AngularGradient(colors: [Theme.toolbarOrange.opacity(0.15), Theme.toolbarOrange], center: .center),
                            style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                        )
                        .rotationEffect(.degrees(reduceMotion || scenePhase != .active ? -90 : elapsed / rotationDuration * 360 - 90))
                }
                .padding(lineWidth / 2)
            }
        }
        .aspectRatio(1, contentMode: .fit)
        .accessibilityHidden(true)
        .onChange(of: scenePhase) { phase in
            if phase == .active { startedAt = .now }
        }
    }
}
