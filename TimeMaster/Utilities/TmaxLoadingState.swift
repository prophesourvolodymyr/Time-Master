import SwiftUI

struct TmaxLoadingState: View {
    let title: String
    var detail: String? = nil
    var showsQuote = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    @ScaledMetric(relativeTo: .body) private var spacing = 24
    @ScaledMetric(relativeTo: .title3) private var quoteHeight = 144
    @State private var quote: TmaxQuote?
    @State private var quoteIsVisible = false
    @State private var isVisible = false

    var body: some View {
        GeometryReader { geometry in
            ScrollView {
                VStack(spacing: spacing) {
                    if showsQuote {
                        TmaxAnimatedLogo()
                            .frame(width: min(geometry.size.width * 0.44, geometry.size.height * 0.24))
                            .padding(.bottom, spacing / 2)
                    }

                    VStack(spacing: 14) {
                        TmaxCircularLoader()
                            .frame(width: showsQuote ? 36 : 26, height: showsQuote ? 36 : 26)
                        Text(title)
                            .font(TimeMasterFont.caption())
                            .foregroundStyle(Theme.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                        if let detail {
                            Text(detail)
                                .font(TimeMasterFont.caption())
                                .foregroundStyle(Theme.textSecondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }

                    if showsQuote {
                        VStack(spacing: 12) {
                            Text(quote.map { "“\($0.text)”" } ?? " ")
                                .font(TimeMasterFont.heading())
                                .foregroundStyle(Theme.textPrimary)
                                .fixedSize(horizontal: false, vertical: true)
                            Text(quote.map { "— \($0.author)" } ?? " ")
                                .font(TimeMasterFont.caption())
                                .foregroundStyle(Theme.textSecondary)
                        }
                        .frame(maxWidth: 320, minHeight: quoteHeight)
                        .opacity(quoteIsVisible ? 1 : 0)
                        .accessibilityHidden(!quoteIsVisible)
                    }
                }
                .multilineTextAlignment(.center)
                .padding(showsQuote ? 32 : 20)
                .frame(maxWidth: .infinity)
                .frame(minHeight: geometry.size.height)
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
        .task(id: showsQuote && scenePhase == .active) {
            guard showsQuote, scenePhase == .active else { return }
            if quote == nil { quote = TmaxQuotes.next() }
            do {
                if !reduceMotion { try await Task.sleep(nanoseconds: 100_000_000) }
                withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.65)) {
                    quoteIsVisible = true
                }
                while !Task.isCancelled {
                    try await Task.sleep(nanoseconds: 8_000_000_000)
                    withAnimation(reduceMotion ? nil : .easeOut(duration: 0.2)) {
                        quoteIsVisible = false
                    }
                    if !reduceMotion { try await Task.sleep(nanoseconds: 200_000_000) }
                    quote = TmaxQuotes.next(after: quote?.id)
                    withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.65)) {
                        quoteIsVisible = true
                    }
                }
            } catch {}
        }
    }
}
