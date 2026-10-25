import SwiftUI

struct TmaxLoadingState: View {
    let title: String
    var detail: String? = nil
    var showsQuote = false
    var isFinishing = false
    var departureProgress: CGFloat = 0
    var logs: [String] = []
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    @ScaledMetric(relativeTo: .body) private var spacing = 24
    @ScaledMetric(relativeTo: .title3) private var quoteHeight = 144
    @State private var quote: TmaxQuote?
    @State private var isVisible = false

    var body: some View {
        GeometryReader { geometry in
            let contentPadding: CGFloat = showsQuote ? 32 : 20
            let logoWidth = min(geometry.size.width * 0.44, geometry.size.height * 0.24)
            ScrollView {
                VStack(spacing: spacing) {
                    if showsQuote {
                        Spacer(minLength: spacing)
                        TmaxAnimatedLogo(isComplete: isFinishing)
                            .frame(width: logoWidth)
                            .anchorPreference(key: TmaxStartupLogoFrameKey.self, value: .bounds) { $0 }
                            .opacity(isFinishing ? 0 : 1)
                            .zIndex(1)
                            .padding(.bottom, spacing / 2)
                    }

                    if showsQuote {
                        ZStack {
                            if let quote {
                                Text("“\(quote.text)”")
                                    .font(TimeMasterFont.blackItalic(20, relativeTo: .title3))
                                    .foregroundStyle(Theme.textPrimary)
                                    .fixedSize(horizontal: false, vertical: true)
                                    .id(quote.id)
                                    .transition(reduceMotion ? .opacity : .asymmetric(
                                        insertion: .offset(y: 16).combined(with: .opacity),
                                        removal: .offset(y: -16).combined(with: .opacity)
                                    ))
                            }
                        }
                        .frame(maxWidth: 320, minHeight: quoteHeight)
                        .clipped()
                        .opacity(isFinishing ? 0 : 1)
                        .animation(.easeOut(duration: 0.12), value: isFinishing)
                        .accessibilityHidden(isFinishing)
                        Spacer(minLength: spacing)
                    }
                    VStack(spacing: showsQuote ? 6 : 14) {
                        TmaxCircularLoader(rotationDuration: showsQuote ? 1.3 : 0.95)
                            .frame(width: showsQuote ? 24 : 26, height: showsQuote ? 24 : 26)
                        if showsQuote {
                            TmaxStartupLogWheel(history: logs, current: title, isActive: !isFinishing)
                        } else {
                            Text(title)
                                .font(TimeMasterFont.caption())
                                .foregroundStyle(Theme.textSecondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        if let detail {
                            Text(detail)
                                .font(TimeMasterFont.caption())
                                .foregroundStyle(Theme.textSecondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    .opacity(isFinishing ? 0 : 1)
                    .animation(.easeOut(duration: 0.12), value: isFinishing)
                    .accessibilityHidden(isFinishing)
                }
                .multilineTextAlignment(.center)
                .frame(minHeight: max(0, geometry.size.height - contentPadding * 2))
                .padding(contentPadding)
                .frame(maxWidth: .infinity)
            }
            #if os(macOS)
            .scrollIndicators(.hidden)
            .scrollBounceBehavior(.basedOnSize)
            #endif
        }
        .overlayPreferenceValue(TmaxStartupLogoFrameKey.self) { anchor in
            GeometryReader { proxy in
                if let anchor {
                    TmaxStartupDeparture(logoFrame: proxy[anchor], progress: departureProgress)
                        .opacity(isFinishing ? 1 : 0)
                }
            }
            .ignoresSafeArea()
            .allowsHitTesting(false)
            .accessibilityHidden(true)
        }
        .opacity(showsQuote || isVisible ? 1 : 0)
        .animation(reduceMotion ? nil : .easeOut(duration: 0.15), value: isVisible)
        .task {
            guard !showsQuote else { return }
            do {
                try await Task.sleep(nanoseconds: 120_000_000)
                isVisible = true
            } catch {}
        }
        .accessibilityIdentifier(showsQuote ? "tmax-startup-loading" : "tmax-page-loading")
        .task(id: showsQuote && scenePhase == .active && !isFinishing) {
            guard showsQuote, scenePhase == .active, !isFinishing else { return }
            if quote == nil {
                withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.65)) {
                    quote = TmaxQuotes.next()
                }
            }
            do {
                while !Task.isCancelled {
                    try await Task.sleep(nanoseconds: 7_000_000_000)
                    withAnimation(reduceMotion ? .easeInOut(duration: 0.2) : .easeInOut(duration: 0.65)) {
                        quote = TmaxQuotes.next(after: quote?.id)
                    }
                }
            } catch {}
        }
    }
}

private struct TmaxStartupLogWheel: View {
    let history: [String]
    let current: String
    let isActive: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    @ScaledMetric(relativeTo: .caption) private var rowHeight: CGFloat = 22
    @State private var displayedIndex = 0
    @State private var nextFeedbackIndex = 0
    @State private var nextStepAt: ContinuousClock.Instant?

    private struct FeedbackContext: Equatable {
        let index: Int
        let current: String
        let active: Bool
    }

    private var currentIndex: Int {
        history.last == current ? max(0, history.count - 1) : history.count
    }

    var body: some View {
        let latest = currentIndex
        let selected = min(displayedIndex, latest)
        ZStack {
            ForEach(0...latest, id: \.self) { index in
                TmaxStartupLogRowMotion(
                    distance: CGFloat(index - selected),
                    rowHeight: rowHeight,
                    reduceMotion: reduceMotion
                ) {
                    HStack(spacing: 6) {
                        Image(systemName: index < latest ? "checkmark.circle.fill" : "arrow.triangle.2.circlepath")
                            .font(.caption.weight(.black))
                            .accessibilityHidden(true)
                        Text("\(index + 1)")
                            .monospacedDigit()
                        Text(index < history.count ? history[index] : current)
                            .lineLimit(1)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .font(TimeMasterFont.blackItalic(12, relativeTo: .caption))
                    .foregroundStyle(Theme.textPrimary)
                    .frame(maxWidth: .infinity)
                    .frame(height: rowHeight)
                }
                .transition(reduceMotion ? .identity : .opacity)
            }
        }
        .frame(height: rowHeight * 7)
        .mask {
            LinearGradient(stops: [
                .init(color: .clear, location: 0),
                .init(color: .white, location: 0.22),
                .init(color: .white, location: 0.78),
                .init(color: .clear, location: 1)
            ], startPoint: .top, endPoint: .bottom)
        }
        .clipped()
        .animation(reduceMotion ? nil : .spring(response: 0.6, dampingFraction: 1, blendDuration: 0.12), value: selected)
        .task(id: FeedbackContext(index: latest, current: current, active: isActive && scenePhase == .active)) {
            guard isActive, scenePhase == .active else { return }
            AppInteractionHaptics.shared.prepareSelection()
            do {
                while nextFeedbackIndex <= latest {
                    if let nextStepAt {
                        try await Task.sleep(until: nextStepAt, clock: .continuous)
                    }
                    try Task.checkCancellation()
                    displayedIndex = nextFeedbackIndex
                    nextFeedbackIndex += 1
                    nextStepAt = .now.advanced(by: .milliseconds(450))
                    AppInteractionHaptics.shared.selectionChanged()
                }
            } catch {}
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Startup progress")
        .accessibilityValue("\(selected + 1). \(selected < history.count ? history[selected] : current)")
    }
}

private struct TmaxStartupLogoFrameKey: PreferenceKey {
    static var defaultValue: Anchor<CGRect>?

    static func reduce(value: inout Anchor<CGRect>?, nextValue: () -> Anchor<CGRect>?) {
        value = nextValue() ?? value
    }
}

private struct TmaxStartupLogRowMotion<Content: View>: View, Animatable {
    var distance: CGFloat
    let rowHeight: CGFloat
    let reduceMotion: Bool
    @ViewBuilder let content: Content

    var animatableData: CGFloat {
        get { distance }
        set { distance = newValue }
    }

    var body: some View {
        content
            .scaleEffect(reduceMotion ? 1 : max(0.82, 1 - abs(distance) * 0.05))
            .rotation3DEffect(
                .degrees(reduceMotion ? 0 : Double(distance) * -18),
                axis: (x: 1, y: 0, z: 0)
            )
            .opacity(max(0, 1 - abs(distance) * 0.25))
            .offset(y: distance * rowHeight)
    }
}
