import ActivityKit
import AppIntents
import SwiftUI
import WidgetKit

enum TmaxLiveStyle {
    static let secondary = Color.white.opacity(0.66)
    static let track = Color.white.opacity(0.18)
    static let dimmed = 0.45
    static let background = Color(widgetHex: "0A0A0A")
    static let rest = Color(widgetHex: "3CC8E0")
    static let prepare = Color(widgetHex: "FFB020")
    static let warmUp = Color(widgetHex: "FF4D2E")
    static let completed = Color(widgetHex: "34C759")

    static func timerFont(size: CGFloat) -> Font {
        .system(size: size, weight: .bold, design: .rounded).monospacedDigit()
    }
}

extension WorkoutActivityAttributes.ContentState {
    func tone(workout: Color) -> Color {
        switch phase {
        case .active: workout
        case .setRest, .sectionRest: TmaxLiveStyle.rest
        case .prepare: TmaxLiveStyle.prepare
        case .warmUp: TmaxLiveStyle.warmUp
        case .completed: TmaxLiveStyle.completed
        }
    }

    var isRest: Bool {
        phase == .setRest || phase == .sectionRest
    }

    var showsArtwork: Bool {
        phase == .active || phase == .prepare || phase == .warmUp
    }

    var phaseSymbol: String {
        switch phase {
        case .warmUp: "flame.fill"
        case .prepare: "hourglass"
        case .active: "figure.strengthtraining.traditional"
        case .setRest, .sectionRest: "figure.cooldown"
        case .completed: "checkmark"
        }
    }

    var glyphSymbol: String {
        isPaused && phase != .completed ? "pause.fill" : phaseSymbol
    }

    var nextSymbol: String {
        switch nextKindValue {
        case .section?: "rectangle.stack.fill"
        case .finish?: "flag.checkered"
        default: "figure.strengthtraining.traditional"
        }
    }

    func countdownWidth(fontSize: CGFloat, showsHours: Bool) -> CGFloat {
        let emWidth: CGFloat
        if showsHours && progressLength >= 3600 {
            emWidth = 3.7
        } else if !showsHours && progressLength >= 6000 {
            emWidth = 3.5
        } else {
            emWidth = 2.8
        }
        return (fontSize * emWidth).rounded(.up)
    }
}

struct TmaxLiveCountdown: View {
    let state: WorkoutActivityAttributes.ContentState
    var showsHours = true

    var body: some View {
        if let endDate = state.phaseEndDate, !state.isPaused {
            let now = Date.now
            Text(timerInterval: now...max(now, endDate), countsDown: true, showsHours: showsHours)
        } else {
            Text(WorkoutActivityAttributes.ContentState.clock(seconds: state.remainingSeconds, showsHours: showsHours))
                .accessibilityLabel(WorkoutActivityAttributes.ContentState.spokenDuration(state.remainingSeconds))
        }
    }
}

struct TmaxLiveRing: View {
    let state: WorkoutActivityAttributes.ContentState
    let tint: Color

    var body: some View {
        Group {
            if state.phase == .completed {
                ProgressView(value: 1.0)
            } else if let interval = state.runningInterval {
                ProgressView(timerInterval: interval, countsDown: false) {
                    EmptyView()
                } currentValueLabel: {
                    EmptyView()
                }
            } else {
                ProgressView(value: state.elapsedFraction)
            }
        }
        .progressViewStyle(.circular)
        .tint(state.isPaused ? tint.opacity(0.6) : tint)
        .widgetAccentable()
        .accessibilityHidden(true)
    }
}

struct TmaxLivePhaseBar: View {
    let state: WorkoutActivityAttributes.ContentState
    let tint: Color

    var body: some View {
        Group {
            if let interval = state.runningInterval {
                ProgressView(timerInterval: interval, countsDown: false) {
                    EmptyView()
                } currentValueLabel: {
                    EmptyView()
                }
            } else {
                ProgressView(value: state.elapsedFraction)
            }
        }
        .progressViewStyle(.linear)
        .tint(state.isPaused ? tint.opacity(0.6) : tint)
        .widgetAccentable()
        .accessibilityHidden(true)
    }
}

struct TmaxLiveFillBar: View {
    let fraction: Double
    let tint: Color
    var height: CGFloat = 3

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule().fill(TmaxLiveStyle.track)
                Capsule()
                    .fill(tint)
                    .frame(width: max(height, proxy.size.width * min(1, max(0, fraction))))
            }
        }
        .frame(height: height)
        .widgetAccentable()
        .accessibilityHidden(true)
    }
}

struct TmaxLiveArtworkImage: View {
    let name: String?
    var dimmed = false

    var body: some View {
        if let name, let image = WorkoutLiveActivityArtwork.image(named: name) {
            Image(uiImage: image)
                .resizable()
                .fullColorArtwork()
                .scaledToFill()
                .opacity(dimmed ? TmaxLiveStyle.dimmed : 1)
        }
    }

    static func isAvailable(_ name: String?) -> Bool {
        guard let name else { return false }
        return WorkoutLiveActivityArtwork.image(named: name) != nil
    }
}

private extension Image {
    @ViewBuilder
    func fullColorArtwork() -> some View {
        if #available(iOS 18.0, *) {
            widgetAccentedRenderingMode(.fullColor)
        } else {
            self
        }
    }
}

struct TmaxLiveTile: View {
    let state: WorkoutActivityAttributes.ContentState
    let tone: Color
    let size: CGFloat
    var showsRing = true

    var body: some View {
        let ringSize = size * 1.32
        let hasArtwork = state.showsArtwork && TmaxLiveArtworkImage.isAvailable(state.artworkName)
        ZStack {
            if showsRing {
                TmaxLiveRing(state: state, tint: tone)
                    .frame(width: ringSize, height: ringSize)
            }
            ZStack {
                if hasArtwork {
                    Color.black
                    TmaxLiveArtworkImage(name: state.artworkName, dimmed: state.isPaused)
                        .frame(width: size, height: size)
                        .clipped()
                    badge(hasArtwork: true)
                } else {
                    tone.opacity(0.22)
                    Image(systemName: state.glyphSymbol)
                        .font(.system(size: size * 0.42, weight: .bold))
                        .foregroundStyle(tone)
                        .widgetAccentable()
                }
            }
            .frame(width: size, height: size)
            .clipShape(RoundedRectangle(cornerRadius: size * 0.3, style: .continuous))
        }
        .frame(width: ringSize, height: ringSize)
        .accessibilityHidden(true)
    }

    @ViewBuilder
    private func badge(hasArtwork: Bool) -> some View {
        if state.isPaused {
            Image(systemName: "pause.fill")
                .font(.system(size: size * 0.34, weight: .bold))
                .foregroundStyle(.white)
        } else if state.phase != .active {
            Image(systemName: state.phaseSymbol)
                .font(.system(size: size * 0.2, weight: .bold))
                .foregroundStyle(.black)
                .frame(width: size * 0.34, height: size * 0.34)
                .background(tone, in: Circle())
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                .padding(size * 0.05)
        }
    }
}

struct TmaxLiveBadge: View {
    let state: WorkoutActivityAttributes.ContentState
    let tone: Color
    let size: CGFloat
    var isCircle = false

    var body: some View {
        Group {
            if state.showsArtwork && TmaxLiveArtworkImage.isAvailable(state.artworkName) {
                TmaxLiveArtworkImage(name: state.artworkName, dimmed: state.isPaused)
                    .frame(width: size, height: size)
                    .clipShape(RoundedRectangle(cornerRadius: isCircle ? size / 2 : size * 0.28, style: .continuous))
            } else {
                Image(systemName: state.glyphSymbol)
                    .font(.system(size: size * 0.7, weight: .bold))
                    .foregroundStyle(tone)
                    .widgetAccentable()
                    .frame(width: size, height: size)
            }
        }
        .accessibilityHidden(true)
    }
}

struct TmaxLivePositionView: View {
    let position: WorkoutLivePosition
    let isBundle: Bool
    let tint: Color
    var dot: CGFloat = 7

    var body: some View {
        HStack(spacing: dot) {
            Image(systemName: isBundle ? "list.number" : "repeat")
                .font(.system(size: dot * 1.6, weight: .bold))
                .foregroundStyle(TmaxLiveStyle.secondary)
            switch position.style {
            case .dots:
                HStack(spacing: dot * 0.6) {
                    ForEach(0..<position.count, id: \.self) { index in
                        Capsule()
                            .fill(color(for: index))
                            .frame(width: index == position.current ? dot * 2.3 : dot, height: dot)
                    }
                }
                .widgetAccentable()
            case .bar:
                TmaxLiveFillBar(fraction: position.fraction, tint: tint, height: dot)
                    .frame(maxWidth: dot * 18)
            }
        }
        .accessibilityHidden(true)
    }

    private func color(for index: Int) -> Color {
        if index == position.current { return tint }
        return index < position.current ? tint.opacity(0.55) : TmaxLiveStyle.track
    }
}

struct TmaxLiveNextCard: View {
    let state: WorkoutActivityAttributes.ContentState
    let accent: Color
    let size: CGFloat
    var maxNameWidth: CGFloat = 96

    @Environment(\.dynamicTypeSize) private var typeSize

    private var showsName: Bool {
        typeSize <= .large && (state.isRest || !TmaxLiveArtworkImage.isAvailable(state.nextArtworkName))
    }

    var body: some View {
        let emphasized = state.isRest
        let outline = emphasized ? state.tone(workout: accent) : Color.white.opacity(0.12)
        HStack(spacing: size * 0.2) {
            thumbnail
            if let title = state.nextTitle, !title.isEmpty, showsName {
                Text(title)
                    .font(.system(size: size * (emphasized ? 0.36 : 0.32), weight: .semibold))
                    .foregroundStyle(emphasized ? .white : TmaxLiveStyle.secondary)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .frame(maxWidth: maxNameWidth, alignment: .leading)
            }
            Image(systemName: "forward.fill")
                .font(.system(size: size * 0.26, weight: .bold))
                .foregroundStyle(emphasized ? state.tone(workout: accent) : TmaxLiveStyle.secondary)
                .widgetAccentable()
        }
        .padding(size * 0.14)
        .background(Color.white.opacity(emphasized ? 0.12 : 0.07), in: RoundedRectangle(cornerRadius: size * 0.42, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: size * 0.42, style: .continuous).stroke(outline, lineWidth: emphasized ? 1.5 : 1))
        .accessibilityHidden(true)
    }

    private var thumbnail: some View {
        ZStack {
            if TmaxLiveArtworkImage.isAvailable(state.nextArtworkName) {
                TmaxLiveArtworkImage(name: state.nextArtworkName)
                    .frame(width: size, height: size)
                    .clipped()
            } else {
                Color.white.opacity(0.1)
                Image(systemName: state.nextSymbol)
                    .font(.system(size: size * 0.44, weight: .bold))
                    .foregroundStyle(.white.opacity(0.85))
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: size * 0.3, style: .continuous))
    }
}

struct TmaxLiveIntentButton<Intent: AppIntent>: View {
    let intent: Intent
    let symbol: String
    let label: String
    let diameter: CGFloat
    let foreground: Color
    let fill: Color

    var body: some View {
        Button(intent: intent) {
            Image(systemName: symbol)
                .font(.system(size: diameter * 0.4, weight: .bold))
                .foregroundStyle(foreground)
                .frame(width: diameter, height: diameter)
                .background(fill, in: Circle())
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .widgetAccentable()
        .accessibilityLabel(label)
    }
}

struct TmaxLiveControls: View {
    let state: WorkoutActivityAttributes.ContentState
    let tone: Color
    let diameter: CGFloat

    var body: some View {
        HStack(spacing: diameter * 0.24) {
            TmaxLiveIntentButton(
                intent: TogglePauseWorkoutIntent(),
                symbol: state.isPaused ? "play.fill" : "pause.fill",
                label: state.isPaused ? "Resume workout" : "Pause workout",
                diameter: diameter,
                foreground: .black,
                fill: tone
            )
            TmaxLiveIntentButton(
                intent: SkipWorkoutPhaseIntent(),
                symbol: "forward.end.fill",
                label: "Skip to next",
                diameter: diameter,
                foreground: .white,
                fill: Color.white.opacity(0.16)
            )
        }
    }
}

struct TmaxLiveStaleMark: View {
    var body: some View {
        Label("Open Tmax to sync", systemImage: "arrow.triangle.2.circlepath")
            .font(.system(size: 12, weight: .medium))
            .foregroundStyle(TmaxLiveStyle.secondary)
            .lineLimit(1)
    }
}
