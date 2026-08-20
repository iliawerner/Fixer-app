import SwiftUI

/// Transparent stage for the first-run identity card.
/// The stage itself never draws a backdrop; clear space is reserved for rotation
/// and shadow so the artwork appears to float above the desktop.
struct SplashView: View {
    let autoDismiss: Bool
    let presentation: SplashPresentation
    let onDismiss: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var introStarted: Bool
    @State private var introComplete: Bool
    @State private var tilt: SplashTilt

    init(
        autoDismiss: Bool,
        presentation: SplashPresentation = .animated,
        onDismiss: @escaping () -> Void
    ) {
        self.autoDismiss = autoDismiss
        self.presentation = presentation
        self.onDismiss = onDismiss

        let isSettled = presentation == .settled
        _introStarted = State(initialValue: isSettled)
        _introComplete = State(initialValue: isSettled)
        _tilt = State(initialValue: isSettled ? .zero : .entrance)
    }

    var body: some View {
        GeometryReader { geometry in
            let cardSize = SplashMotionMetrics.cardSize(in: geometry.size)

            SplashCardView(
                isRevealed: resolvedIntroStarted,
                tilt: resolvedTilt,
                reduceMotion: reduceMotion,
                acceptsPointerMotion: acceptsPointerMotion,
                onPointerTilt: updatePointerTilt,
                onPointerExit: settlePointerTilt,
                onDismiss: onDismiss
            )
            .frame(width: cardSize.width, height: cardSize.height)
            .opacity(resolvedIntroStarted ? 1 : 0)
            .scaleEffect(reduceMotion ? 1 : (introStarted ? 1 : 0.94))
            .offset(y: reduceMotion ? 0 : (introStarted ? 0 : 24))
            .animation(cardEntranceAnimation, value: resolvedIntroStarted)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(Color.clear)
        .onExitCommand(perform: onDismiss)
        .task(id: reduceMotion) {
            await runPresentation()
        }
    }

    private var resolvedIntroStarted: Bool {
        presentation == .settled || reduceMotion || introStarted
    }

    private var resolvedTilt: SplashTilt {
        SplashMotionMetrics.resolvedTilt(tilt, reduceMotion: reduceMotion)
    }

    private var acceptsPointerMotion: Bool {
        SplashMotionMetrics.allowsPointerMotion(
            presentation: presentation,
            introComplete: introComplete,
            reduceMotion: reduceMotion
        )
    }

    private var cardEntranceAnimation: Animation? {
        guard SplashMotionMetrics.allowsEntranceAnimation(
            presentation: presentation,
            reduceMotion: reduceMotion
        ) else { return nil }
        return .spring(response: 0.72, dampingFraction: 0.78, blendDuration: 0.14)
    }

    private func updatePointerTilt(_ newTilt: SplashTilt) {
        guard acceptsPointerMotion else { return }
        // Re-targeting the same interactive spring preserves velocity between
        // pointer samples and creates inertia without a timer or manual physics loop.
        withAnimation(.interactiveSpring(response: 0.28, dampingFraction: 0.74, blendDuration: 0.16)) {
            tilt = newTilt
        }
    }

    private func settlePointerTilt() {
        guard presentation == .animated, !reduceMotion else { return }
        withAnimation(.spring(response: 0.62, dampingFraction: 0.70, blendDuration: 0.16)) {
            tilt = .zero
        }
    }

    @MainActor
    private func runPresentation() async {
        guard presentation == .animated else { return }

        if reduceMotion {
            introStarted = true
            introComplete = true
            tilt = .zero
            await autoDismissIfNeeded(after: 3.2)
            return
        }

        // Yield one frame so the entrance values are committed before the spring
        // is targeted at its resting state.
        await Task.yield()
        introStarted = true
        withAnimation(.spring(response: 0.78, dampingFraction: 0.76, blendDuration: 0.14)) {
            tilt = .zero
        }

        guard await pause(seconds: 1.1) else { return }
        introComplete = true
        await autoDismissIfNeeded(after: 2.2)
    }

    @MainActor
    private func autoDismissIfNeeded(after delay: TimeInterval) async {
        guard autoDismiss else { return }
        guard await pause(seconds: delay) else { return }
        onDismiss()
    }

    private func pause(seconds: TimeInterval) async -> Bool {
        do {
            try await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
            return !Task.isCancelled
        } catch {
            return false
        }
    }
}
