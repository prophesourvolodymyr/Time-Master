import SwiftUI

// MARK: - Guide persistence

/// Persistence helpers for the first-run Music guide.
///
/// The guide itself deliberately does not decide when Music was entered. The
/// Music screen can call `scheduleFirstRunIfNeeded` when its view becomes
/// active, then bind the returned presentation state to `MusicGuideOverlay`.
public enum MusicGuidePersistence {
    public static let completionKey = "musicGuideCompletedV1"

    public static func hasCompleted(in defaults: UserDefaults = .standard) -> Bool {
        defaults.bool(forKey: completionKey)
    }

    public static func markCompleted(in defaults: UserDefaults = .standard) {
        defaults.set(true, forKey: completionKey)
    }

    public static func reset(in defaults: UserDefaults = .standard) {
        defaults.removeObject(forKey: completionKey)
    }

    /// Schedules a first-run presentation while leaving the normal Music UI
    /// visible during the delay. The caller owns cancellation if its screen
    /// disappears before the delay elapses.
    @MainActor
    @discardableResult
    public static func scheduleFirstRunIfNeeded(
        after delay: TimeInterval = 2,
        defaults: UserDefaults = .standard,
        present: @escaping @MainActor () -> Void
    ) -> Task<Void, Never>? {
        guard !hasCompleted(in: defaults) else { return nil }

        let nanoseconds = UInt64(max(0, delay) * 1_000_000_000)
        return Task { @MainActor in
            do {
                try await Task.sleep(nanoseconds: nanoseconds)
            } catch {
                return
            }

            guard !Task.isCancelled, !hasCompleted(in: defaults) else { return }
            present()
        }
    }
}

// MARK: - Guide public API

public enum MusicGuideStep: Int, CaseIterable, Identifiable, Hashable, Sendable {
    case step1 = 1
    case step2 = 2
    case step3 = 3

    public var id: Int { rawValue }

    // Semantic aliases make target dictionaries self-documenting while the
    // numeric cases keep the public API aligned with the guide specification.
    public static let sources = MusicGuideStep.step1
    public static let providerAccounts = MusicGuideStep.step2
    public static let organization = MusicGuideStep.step3
}

public enum MusicGuideFinishReason: Hashable, Sendable {
    case skipped
    case completed
    case dismissed
}

/// A contained, full-screen conversation guide for the Music screen.
///
/// `targetRects` are expressed in this overlay's local coordinate space. A
/// parent can obtain them from its real controls with a GeometryReader and
/// update the dictionary as those controls move. The guide never renders an
/// underlying screen of its own; the spotlight only highlights those caller
/// supplied rectangles.
public struct MusicGuideOverlay: View {
    @Binding private var isPresented: Bool

    private let targetRects: [MusicGuideStep: CGRect]
    private let onStep1: (() -> Void)?
    private let onStep2: (() -> Void)?
    private let onStep3: (() -> Void)?
    private let onDemonstrate: ((MusicGuideStep) -> Void)?
    private let onFinished: ((MusicGuideFinishReason) -> Void)?
    private let defaults: UserDefaults
    private let initialStep: MusicGuideStep

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var showOverlayContent = false
    @State private var presentationOpacity = 0.0
    @State private var presentationScale = 0.985
    @State private var sessionGeneration = 0
    @State private var containerSize: CGSize = .zero
    @State private var currentStep: MusicGuideStep = .step1
    @State private var messages: [GuideMessage] = []
    @State private var moreUsed = Set<MusicGuideStep>()
    @State private var isTyping = false
    @State private var isFinished = false
    @State private var spotlightRect: CGRect?
    @State private var replayTimestamps: [MusicGuideStep: Date] = [:]

    private let chatHeight: CGFloat = 224
    private let orange = Color(red: 1.0, green: 0.478, blue: 0.0)

    public init(
        isPresented: Binding<Bool>,
        targetRects: [MusicGuideStep: CGRect] = [:],
        initialStep: MusicGuideStep = .step1,
        defaults: UserDefaults = .standard,
        onStep1: (() -> Void)? = nil,
        onStep2: (() -> Void)? = nil,
        onStep3: (() -> Void)? = nil,
        onDemonstrate: ((MusicGuideStep) -> Void)? = nil,
        onFinished: ((MusicGuideFinishReason) -> Void)? = nil
    ) {
        _isPresented = isPresented
        self.targetRects = targetRects
        self.initialStep = initialStep
        self.defaults = defaults
        self.onStep1 = onStep1
        self.onStep2 = onStep2
        self.onStep3 = onStep3
        self.onDemonstrate = onDemonstrate
        self.onFinished = onFinished
    }

    public var body: some View {
        Group {
            if showOverlayContent {
                overlayContent
                    .opacity(presentationOpacity)
                    .scaleEffect(presentationScale)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .allowsHitTesting(showOverlayContent && presentationOpacity > 0.01)
        .accessibilityHidden(!showOverlayContent)
        .onAppear {
            if isPresented {
                presentSession()
            }
        }
        .onChange(of: isPresented) { presented in
            if presented {
                presentSession()
            } else {
                dismissSession(reason: .dismissed, notify: false)
            }
        }
        .onChange(of: targetRects) { _ in
            updateSpotlight(in: containerSize, animated: true)
        }
    }

    // MARK: Overlay composition

    private var overlayContent: some View {
        GeometryReader { geometry in
            ZStack(alignment: .topLeading) {
                // This is intentionally contained by the host view. No
                // ignoresSafeArea call lets guide effects escape a phone/card
                // clipping boundary supplied by the Music screen.
                Color.black.opacity(0.56)
                    .contentShape(Rectangle())
                    .onTapGesture { }

                spotlightView
                    .allowsHitTesting(false)

                skipButton(in: geometry.size)

                chatSurface(in: geometry.size)
            }
            .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
            .onAppear {
                containerSize = geometry.size
                updateSpotlight(in: geometry.size, animated: false)
            }
            .onChange(of: geometry.size) { size in
                containerSize = size
                updateSpotlight(in: size, animated: false)
            }
        }
        .accessibilityAddTraits(.isModal)
        .transition(.opacity)
    }

    private var spotlightView: some View {
        Group {
            if let rect = spotlightRect {
                RoundedRectangle(cornerRadius: spotlightCornerRadius(for: rect), style: .continuous)
                    .fill(orange.opacity(0.14))
                    .overlay {
                        RoundedRectangle(cornerRadius: spotlightCornerRadius(for: rect), style: .continuous)
                            .stroke(orange.opacity(0.95), lineWidth: 1.5)
                    }
                    .shadow(color: orange.opacity(0.24), radius: 24)
                    .overlay {
                        RoundedRectangle(cornerRadius: spotlightCornerRadius(for: rect), style: .continuous)
                            .stroke(orange.opacity(0.10), lineWidth: 8)
                            .blur(radius: 3)
                    }
                    .frame(width: rect.width, height: rect.height)
                    .position(x: rect.midX, y: rect.midY)
                    .transition(.opacity)
            }
        }
        .animation(motionAnimation(response: 0.46), value: spotlightRect)
    }

    private func skipButton(in size: CGSize) -> some View {
        Button("Skip") {
            finish(.skipped)
        }
        .font(.system(size: 11, weight: .semibold))
        .foregroundStyle(Color.white.opacity(0.86))
        .padding(.horizontal, 12)
        .frame(height: 32)
        .background {
            Capsule(style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay {
                    Capsule(style: .continuous)
                        .fill(Color.black.opacity(0.36))
                }
                .overlay {
                    Capsule(style: .continuous)
                        .stroke(Color.white.opacity(0.14), lineWidth: 1)
                }
        }
        .contentShape(Capsule(style: .continuous))
        .accessibilityHint("Closes the Music guide")
        .padding(.top, 50)
        .padding(.trailing, 14)
        .frame(width: size.width, alignment: .trailing)
    }

    private func chatSurface(in size: CGSize) -> some View {
        let height = min(chatHeight, max(190, size.height * 0.42))
        let top = currentStep == .step1
            ? max(12, size.height - height - 28)
            : min(max(72, size.height * 0.11), max(72, size.height - height - 12))

        return VStack(spacing: 0) {
            messageList
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            composeBar
        }
        .padding(.top, 9)
        .padding(.horizontal, 10)
        .padding(.bottom, 10)
        .frame(width: max(0, size.width - 76), height: height)
        .background {
            // iOS 16–25 use a native Material underlay plus an opaque black
            // tint. It preserves the floating hierarchy without pretending to
            // be the newer Liquid Glass API.
            Rectangle()
                .fill(.ultraThinMaterial)
                .overlay(Color.black.opacity(0.90))
        }
        .overlay {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(Color.white.opacity(0.075), lineWidth: 1)
        }
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .shadow(color: Color.black.opacity(0.44), radius: 18, y: 10)
        .overlay(alignment: .top) {
            LinearGradient(
                colors: [Color.black.opacity(0.84), Color.black.opacity(0.16), .clear],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 28)
            .allowsHitTesting(false)
        }
        .position(x: size.width / 2, y: top + height / 2)
        .animation(motionAnimation(response: 0.58), value: currentStep)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Music guide conversation")
    }

    private var composeBar: some View {
        HStack(spacing: 7) {
            HStack(spacing: 7) {
                Circle()
                    .fill(Color.white.opacity(0.28))
                    .frame(width: 6, height: 6)
                Circle()
                    .fill(Color.white.opacity(0.28))
                    .frame(width: 6, height: 6)
                Circle()
                    .fill(Color.white.opacity(0.28))
                    .frame(width: 6, height: 6)
            }
            .padding(.horizontal, 10)
            .frame(height: 34, alignment: .leading)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background {
                Capsule(style: .continuous)
                    .fill(Color.white.opacity(0.065))
                    .overlay {
                        Capsule(style: .continuous)
                            .stroke(Color.white.opacity(0.10), lineWidth: 1)
                    }
            }
            .overlay(alignment: .leading) {
                Text("iMessage reply")
                    .font(.system(size: 10, weight: .regular))
                    .foregroundStyle(Color.white.opacity(0.40))
                    .padding(.leading, 33)
                    .accessibilityHidden(true)
            }
            .accessibilityLabel("Guide reply field")
            .accessibilityValue("Disabled")

            if !isFinished {
                guideButton("Okay", primary: true, isEnabled: !isTyping) {
                    respond(.okay)
                }

                if !moreUsed.contains(currentStep) {
                    guideButton("More", primary: false, isEnabled: !isTyping) {
                        respond(.more)
                    }
                }
            } else {
                guideButton("Done", primary: true, isEnabled: true) {
                    finish(.completed)
                }
            }
        }
        .padding(.top, 6)
    }

    private func guideButton(
        _ title: String,
        primary: Bool,
        isEnabled: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 11, weight: .semibold))
                .lineLimit(1)
                .frame(minWidth: title == "More" ? 66 : 62)
                .frame(height: 32)
                .padding(.horizontal, 4)
        }
        .buttonStyle(.plain)
        .foregroundStyle(primary ? Color.black : Color.white.opacity(0.94))
        .background {
            Capsule(style: .continuous)
                .fill(primary ? orange : Color.white.opacity(0.12))
                .overlay {
                    Capsule(style: .continuous)
                        .stroke(primary ? orange : Color.white.opacity(0.14), lineWidth: 1)
                }
        }
        .opacity(isEnabled ? 1 : 0.32)
        .disabled(!isEnabled)
        .accessibilityHint(isEnabled ? "Advances the guide" : "Guide is preparing the next message")
    }

    // MARK: Conversation

    private var messageList: some View {
        GeometryReader { viewport in
            ScrollViewReader { proxy in
                ScrollView(.vertical, showsIndicators: false) {
                    LazyVStack(spacing: 0) {
                        ForEach(messages) { message in
                            if let step = message.replayStep {
                                MusicGuideReplaySentinel(
                                    step: step,
                                    viewportHeight: viewport.size.height,
                                    onVisible: replayStepIfNeeded
                                )
                            }

                            messageRow(message)
                                .id(message.id)
                        }

                        if isTyping {
                            HStack {
                                MusicGuideTypingDots(reduceMotion: reduceMotion)
                                    .padding(.horizontal, 11)
                                    .frame(minWidth: 54, minHeight: 34)
                                    .background {
                                        RoundedRectangle(cornerRadius: 17, style: .continuous)
                                            .fill(Color(red: 0.165, green: 0.165, blue: 0.18))
                                            .overlay {
                                                RoundedRectangle(cornerRadius: 17, style: .continuous)
                                                    .stroke(Color.white.opacity(0.075), lineWidth: 1)
                                            }
                                    }
                                Spacer(minLength: 0)
                            }
                            .padding(.vertical, 4)
                            .transition(.opacity.combined(with: .scale(scale: 0.96, anchor: .bottomLeading)))
                            .id("typing")
                        }

                        Color.clear
                            .frame(height: 1)
                            .id("guide-bottom")
                    }
                    .padding(.top, 14)
                    .padding(.horizontal, 2)
                    .padding(.bottom, 6)
                    .animation(sendAnimation, value: messages.count)
                    .animation(sendAnimation, value: isTyping)
                }
                .coordinateSpace(name: "MusicGuideMessages")
                .onChange(of: messages.count) { _ in
                    scrollToLatest(using: proxy, animated: true)
                }
                .onChange(of: isTyping) { _ in
                    scrollToLatest(using: proxy, animated: true)
                }
                .onAppear {
                    scrollToLatest(using: proxy, animated: false)
                }
            }
        }
    }

    private func messageRow(_ message: GuideMessage) -> some View {
        HStack {
            if message.author == .app {
                Text(message.text)
                    .guideBubbleStyle(author: .app)
                Spacer(minLength: 0)
            } else {
                Spacer(minLength: 0)
                Text(message.text)
                    .guideBubbleStyle(author: .user)
            }
        }
        .padding(.vertical, 4)
        .transition(.move(edge: .bottom).combined(with: .opacity).combined(with: .scale(scale: 0.97, anchor: .bottom)))
        .accessibilityElement(children: .combine)
        .accessibilityLabel(message.author == .app ? "Music guide" : "You")
        .accessibilityValue(message.text)
    }

    private func scrollToLatest(using proxy: ScrollViewProxy, animated: Bool) {
        DispatchQueue.main.async {
            let action = {
                proxy.scrollTo(isTyping ? "typing" : "guide-bottom", anchor: .bottom)
            }
            if animated && !reduceMotion {
                withAnimation(.easeOut(duration: 0.24), action)
            } else {
                action()
            }
        }
    }

    // MARK: Session state

    private func presentSession() {
        guard !showOverlayContent else { return }

        sessionGeneration += 1
        let token = sessionGeneration
        currentStep = initialStep
        messages = []
        moreUsed.removeAll()
        isTyping = false
        isFinished = false
        replayTimestamps.removeAll()
        spotlightRect = nil
        showOverlayContent = true
        presentationOpacity = 0
        presentationScale = reduceMotion ? 1 : 0.985

        DispatchQueue.main.async {
            guard isPresented, token == sessionGeneration else { return }
            withAnimation(entryAnimation) {
                presentationOpacity = 1
                presentationScale = 1
            }
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.22) {
            guard isPresented, token == sessionGeneration else { return }
            beginStep(initialStep, token: token)
        }
    }

    private func dismissSession(reason: MusicGuideFinishReason, notify: Bool) {
        guard showOverlayContent else { return }

        sessionGeneration += 1
        let token = sessionGeneration
        isTyping = false

        withAnimation(exitAnimation) {
            presentationOpacity = 0
            presentationScale = reduceMotion ? 1 : 0.985
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + (reduceMotion ? 0.18 : 0.42)) {
            guard token == sessionGeneration, !isPresented else { return }
            showOverlayContent = false
            messages = []
            spotlightRect = nil
            isFinished = false
        }

        if notify {
            onFinished?(reason)
        }
    }

    private func finish(_ reason: MusicGuideFinishReason) {
        guard showOverlayContent else { return }

        if reason == .skipped || reason == .completed {
            MusicGuidePersistence.markCompleted(in: defaults)
        }
        onFinished?(reason)
        isPresented = false
        dismissSession(reason: reason, notify: false)
    }

    private enum GuideResponse {
        case okay
        case more
    }

    private func respond(_ response: GuideResponse) {
        guard showOverlayContent, !isTyping, !isFinished else { return }

        switch response {
        case .more:
            guard !moreUsed.contains(currentStep) else { return }
            moreUsed.insert(currentStep)
            appendUserMessage("More")
            sendAppMessage(copy(for: currentStep).more, step: nil, final: false, token: sessionGeneration)

        case .okay:
            appendUserMessage("Okay")
            let token = sessionGeneration
            isTyping = true

            if currentStep == .step3 {
                sendFinalMessage(token: token)
            } else {
                let next = currentStep == .step1 ? MusicGuideStep.step2 : MusicGuideStep.step3
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.32) {
                    guard isPresented, token == sessionGeneration else { return }
                    beginStep(next, token: token)
                }
            }
        }
    }

    private func beginStep(_ step: MusicGuideStep, token: Int) {
        guard isPresented, token == sessionGeneration else { return }

        currentStep = step
        isFinished = false
        spotlightRect = nil
        sendAppMessage(copy(for: step).main, step: step, final: false, token: token)
    }

    private func sendAppMessage(
        _ text: String,
        step: MusicGuideStep?,
        final: Bool,
        token: Int
    ) {
        guard isPresented, token == sessionGeneration else { return }

        isTyping = true
        let delay = final ? 0.56 : 0.48
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            guard isPresented, token == sessionGeneration else { return }
            isTyping = false
            messages.append(GuideMessage(author: .app, text: text, replayStep: step))

            if let step {
                updateSpotlight(in: containerSize, animated: true)
                triggerDemonstration(for: step)
            }

            if final {
                isFinished = true
            }
        }
    }

    private func sendFinalMessage(token: Int) {
        sendAppMessage(
            "That’s it — your music can come from different places and still stay organized your way. Scroll up through this conversation to replay any demonstration. When you’re ready, tap Done.",
            step: nil,
            final: true,
            token: token
        )
    }

    private func appendUserMessage(_ text: String) {
        messages.append(GuideMessage(author: .user, text: text, replayStep: nil))
    }

    private func copy(for step: MusicGuideStep) -> (main: String, more: String) {
        switch step {
        case .step1:
            return (
                "This is where your music comes from. Import audio you already have, or connect Spotify, YouTube, and SoundCloud. Pick whichever source feels natural — everything stays organized in one place.",
                "General is your shared music shelf. New music goes there by default, but if you already opened a workout folder, the import can go straight into that folder instead."
            )
        case .step2:
            return (
                "When you choose a service, you’ll see the account you are signed into and the music that account can provide. Choose the playlist, album, library, or tracks you want — you never have to bring everything in.",
                "Spotify and SoundCloud stay connected to their supported players. YouTube can use its official player; if you already have an audio copy you are allowed to use, you can attach that local file instead."
            )
        case .step3:
            return (
                "You can organize music without importing it again. Hold a music card, drag it onto the workout folder you want, and that destination can open for you before you drop it.",
                "You can move music back to General or into another folder later. If a destination is closed, keep holding over it briefly and it can open while you are still dragging."
            )
        }
    }

    // MARK: Demonstrations and spotlight

    private func triggerDemonstration(for step: MusicGuideStep) {
        switch step {
        case .step1:
            onStep1?()
        case .step2:
            onStep2?()
        case .step3:
            onStep3?()
        }
        onDemonstrate?(step)
    }

    private func updateSpotlight(in size: CGSize, animated: Bool) {
        guard size.width > 0, size.height > 0, isPresented,
              let target = targetRects[currentStep], target.width > 0, target.height > 0
        else {
            if spotlightRect != nil {
                withAnimation(animated ? motionAnimation(response: 0.30) : nil) {
                    spotlightRect = nil
                }
            }
            return
        }

        let inset: CGFloat = 4
        let maxWidth = max(1, size.width - inset * 2)
        let maxHeight = max(1, size.height - inset * 2)
        let width = min(max(1, target.width + inset * 2), maxWidth)
        let height = min(max(1, target.height + inset * 2), maxHeight)
        let x = min(max(inset + width / 2, target.midX), size.width - inset - width / 2)
        let y = min(max(inset + height / 2, target.midY), size.height - inset - height / 2)
        let clamped = CGRect(x: x - width / 2, y: y - height / 2, width: width, height: height)

        if animated {
            withAnimation(motionAnimation(response: 0.46)) {
                spotlightRect = clamped
            }
        } else {
            spotlightRect = clamped
        }
    }

    private func replayStepIfNeeded(_ step: MusicGuideStep) {
        guard isFinished else { return }
        let now = Date()
        if let last = replayTimestamps[step], now.timeIntervalSince(last) < 0.9 {
            return
        }
        replayTimestamps[step] = now
        updateSpotlight(in: containerSize, animated: true)
        triggerDemonstration(for: step)
    }

    private func spotlightCornerRadius(for rect: CGRect) -> CGFloat {
        min(24, max(11, min(rect.width, rect.height) * 0.20))
    }

    // MARK: Motion

    private var entryAnimation: Animation {
        reduceMotion ? .easeOut(duration: 0.16) : .spring(response: 0.46, dampingFraction: 0.92)
    }

    private var exitAnimation: Animation {
        reduceMotion ? .easeIn(duration: 0.14) : .easeInOut(duration: 0.34)
    }

    private var sendAnimation: Animation {
        reduceMotion ? .easeOut(duration: 0.14) : .spring(response: 0.32, dampingFraction: 0.90)
    }

    private func motionAnimation(response: Double) -> Animation {
        reduceMotion ? .easeInOut(duration: 0.16) : .spring(response: response, dampingFraction: 0.88)
    }
}

// MARK: - Private support views

private struct GuideMessage: Identifiable {
    enum Author {
        case app
        case user
    }

    let id = UUID()
    let author: Author
    let text: String
    let replayStep: MusicGuideStep?
}

private struct MusicGuideTypingDots: View {
    let reduceMotion: Bool

    var body: some View {
        if reduceMotion {
            dots(offsets: [0, 0, 0], opacities: [0.72, 0.72, 0.72])
        } else {
            TimelineView(.animation) { context in
                let time = context.date.timeIntervalSinceReferenceDate
                let offsets = (0..<3).map { index in
                    CGFloat(sin(time * 5.2 - Double(index) * 0.55)) * 3.0
                }
                let opacities = (0..<3).map { index in
                    0.56 + 0.35 * (0.5 + 0.5 * sin(time * 5.2 - Double(index) * 0.55))
                }
                dots(offsets: offsets, opacities: opacities)
            }
        }
    }

    private func dots(offsets: [CGFloat], opacities: [Double]) -> some View {
        HStack(spacing: 4) {
            ForEach(0..<3, id: \.self) { index in
                Circle()
                    .fill(Color.white.opacity(opacities[index]))
                    .frame(width: 6, height: 6)
                    .offset(y: offsets[index])
            }
        }
        .frame(height: 34)
        .accessibilityHidden(true)
    }
}

private struct MusicGuideReplaySentinel: View {
    let step: MusicGuideStep
    let viewportHeight: CGFloat
    let onVisible: (MusicGuideStep) -> Void

    var body: some View {
        GeometryReader { proxy in
            Color.clear
                .frame(height: 2)
                .onAppear {
                    checkVisibility(proxy.frame(in: .named("MusicGuideMessages")))
                }
                .onChange(of: proxy.frame(in: .named("MusicGuideMessages")).minY) { _ in
                    checkVisibility(proxy.frame(in: .named("MusicGuideMessages")))
                }
        }
        .frame(height: 2)
        .accessibilityHidden(true)
    }

    private func checkVisibility(_ frame: CGRect) {
        guard viewportHeight > 0 else { return }
        let visible = frame.maxY > 0 && frame.minY < viewportHeight
        if visible {
            onVisible(step)
        }
    }
}

private enum GuideBubbleAuthor {
    case app
    case user
}

private struct GuideBubbleModifier: ViewModifier {
    let author: GuideBubbleAuthor

    func body(content: Content) -> some View {
        content
            .font(.system(size: 10.5, weight: author == .app ? .regular : .semibold))
            .lineSpacing(1)
            .foregroundStyle(author == .app ? Color.white.opacity(0.93) : Color.black)
            .multilineTextAlignment(.leading)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.horizontal, 11)
            .padding(.vertical, 8)
            .frame(maxWidth: 300, alignment: .leading)
            .background {
                RoundedRectangle(cornerRadius: 17, style: .continuous)
                    .fill(author == .app ? Color(red: 0.165, green: 0.165, blue: 0.18) : Color(red: 1.0, green: 0.478, blue: 0.0))
                    .overlay {
                        RoundedRectangle(cornerRadius: 17, style: .continuous)
                            .stroke(author == .app ? Color.white.opacity(0.075) : Color.clear, lineWidth: 1)
                    }
            }
            .clipShape(RoundedRectangle(cornerRadius: 17, style: .continuous))
            .frame(maxWidth: .infinity, alignment: author == .app ? .leading : .trailing)
    }
}

private extension View {
    func guideBubbleStyle(author: GuideBubbleAuthor) -> some View {
        modifier(GuideBubbleModifier(author: author))
    }
}

#Preview {
    struct PreviewContainer: View {
        @State private var isPresented = true

        var body: some View {
            ZStack {
                Color(red: 0.035, green: 0.035, blue: 0.04)

                VStack(spacing: 18) {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(Color.white.opacity(0.08))
                        .frame(height: 82)
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(Color.white.opacity(0.08))
                        .frame(height: 116)
                }
                .padding(36)

                MusicGuideOverlay(
                    isPresented: $isPresented,
                    targetRects: [
                        .step1: CGRect(x: 36, y: 120, width: 318, height: 82),
                        .step2: CGRect(x: 36, y: 120, width: 318, height: 82),
                        .step3: CGRect(x: 36, y: 254, width: 318, height: 116)
                    ]
                )
            }
            .preferredColorScheme(.dark)
        }
    }

    return PreviewContainer()
}
