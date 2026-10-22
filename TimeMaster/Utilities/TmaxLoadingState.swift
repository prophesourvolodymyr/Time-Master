import SwiftUI

struct TmaxLoadingState: View {
    let title: String
    var detail: String? = nil
    var showsQuote = false
    var isFinishing = false
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
            let departureScale = max(geometry.size.width, geometry.size.height) / max(1, logoWidth) * 3
            ScrollView {
                VStack(spacing: spacing) {
                    if showsQuote {
                        Spacer(minLength: spacing)
                        TmaxAnimatedLogo(isComplete: isFinishing)
                            .frame(width: logoWidth)
                            .scaleEffect(isFinishing && !reduceMotion ? departureScale : 1)
                            .zIndex(1)
                            .padding(.bottom, spacing / 2)
                    }

                    if showsQuote {
                        ZStack {
                            if let quote {
                                Text("“\(quote.text)”")
                                    .font(TimeMasterFont.heading())
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
                        .accessibilityHidden(isFinishing)
                        Spacer(minLength: spacing)
                    }
                    VStack(spacing: showsQuote ? 6 : 14) {
                        TmaxCircularLoader(rotationDuration: showsQuote ? 1.3 : 0.95)
                            .frame(width: showsQuote ? 24 : 26, height: showsQuote ? 24 : 26)
                        if showsQuote {
                            TmaxStartupLogWheel(history: logs, current: title)
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
                    .accessibilityHidden(isFinishing)
                }
                .multilineTextAlignment(.center)
                .frame(minHeight: max(0, geometry.size.height - contentPadding * 2))
                .padding(contentPadding)
                .frame(maxWidth: .infinity)
            }
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
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @ScaledMetric(relativeTo: .caption) private var rowHeight: CGFloat = 28

    private var currentIndex: Int {
        history.last == current ? max(0, history.count - 1) : history.count
    }

    var body: some View {
        let selected = currentIndex
        ZStack {
            ForEach(0...selected, id: \.self) { index in
                let distance = index - selected
                HStack(spacing: 8) {
                    Text("\(index + 1)")
                        .monospacedDigit()
                    Text(index < history.count ? history[index] : current)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .font(TimeMasterFont.caption())
                .foregroundStyle(Theme.textSecondary)
                .frame(maxWidth: .infinity)
                .frame(height: rowHeight)
                .scaleEffect(reduceMotion || distance == 0 ? 1 : 0.92)
                .rotation3DEffect(
                    .degrees(reduceMotion ? 0 : Double(distance) * -18),
                    axis: (x: 1, y: 0, z: 0)
                )
                .opacity(distance == 0 ? 1 : abs(distance) == 1 ? 0.5 : 0)
                .offset(y: CGFloat(distance) * rowHeight)
                .transition(reduceMotion ? .identity : .offset(y: rowHeight).combined(with: .opacity))
            }
        }
        .frame(height: rowHeight * 3)
        .mask {
            LinearGradient(stops: [
                .init(color: .clear, location: 0),
                .init(color: .white, location: 0.35),
                .init(color: .white, location: 0.65),
                .init(color: .clear, location: 1)
            ], startPoint: .top, endPoint: .bottom)
        }
        .clipped()
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.85), value: selected)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Startup progress")
        .accessibilityValue("\(selected + 1). \(current)")
    }
}
