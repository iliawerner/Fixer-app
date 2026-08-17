import SwiftUI
import AppKit

// MARK: - First-run policy

enum SplashPolicy {
    private static let seenKey = "fixer.v2.splash.seen.1"

    static func shouldShowFirstLaunch(defaults: UserDefaults = .standard) -> Bool {
        !defaults.bool(forKey: seenKey)
    }

    static func markSeen(defaults: UserDefaults = .standard) {
        defaults.set(true, forKey: seenKey)
    }
}

// MARK: - Splash stage

struct SplashView: View {
    let autoDismiss: Bool
    let onDismiss: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var paperVisible = false
    @State private var sunVisible = false
    @State private var landscapeVisible = false
    @State private var characterVisible = false
    @State private var overlayVisible = false
    @State private var introComplete = false
    @State private var introMotion = CGSize(width: -0.48, height: 0.24)
    @State private var pointerMotion = CGSize.zero

    var body: some View {
        GeometryReader { geometry in
            let card = fittedCardSize(in: geometry.size)

            ZStack {
                Color(hex: 0x10100F)
                    .ignoresSafeArea()

                ParallaxPoster(
                    paperVisible: paperVisible,
                    sunVisible: sunVisible,
                    landscapeVisible: landscapeVisible,
                    characterVisible: characterVisible,
                    overlayVisible: overlayVisible,
                    motion: activeMotion,
                    reduceMotion: reduceMotion,
                    introComplete: introComplete,
                    onPointerMotion: updatePointerMotion
                )
                .frame(width: card.width, height: card.height)
                .shadow(color: .black.opacity(0.58), radius: 38, x: 0, y: 22)
                .overlay(
                    Rectangle()
                        .stroke(Color.white.opacity(0.1), lineWidth: 1)
                )
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(
                    "Fixer. A figure in yellow walks toward a mountain and a yellow sun."
                )

                VStack {
                    HStack {
                        Spacer()
                        Button(action: onDismiss) {
                            Image(systemName: "xmark")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(Color.white.opacity(0.78))
                                .frame(width: 28, height: 28)
                                .background(Color.black.opacity(0.42), in: Circle())
                                .overlay(Circle().stroke(Color.white.opacity(0.16), lineWidth: 1))
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Close splash")
                        .help("Close splash")
                    }
                    Spacer()
                }
                .padding(16)
            }
        }
        .onExitCommand(perform: onDismiss)
        .task { await runIntro() }
    }

    private var activeMotion: CGSize {
        reduceMotion
            ? .zero
            : CGSize(
                width: introMotion.width + pointerMotion.width,
                height: introMotion.height + pointerMotion.height
            )
    }

    private func fittedCardSize(in stage: CGSize) -> CGSize {
        let inset: CGFloat = 64
        let availableWidth = max(320, stage.width - inset)
        let availableHeight = max(240, stage.height - inset)
        let width = min(availableWidth, availableHeight * 4 / 3)
        return CGSize(width: width, height: width * 3 / 4)
    }

    private func updatePointerMotion(_ value: CGSize) {
        guard introComplete, !reduceMotion else { return }
        withAnimation(.easeOut(duration: 0.16)) {
            pointerMotion = value
        }
    }

    @MainActor
    private func runIntro() async {
        if reduceMotion {
            withAnimation(.easeOut(duration: 0.08)) {
                paperVisible = true
                sunVisible = true
                landscapeVisible = true
                characterVisible = true
                overlayVisible = true
                introMotion = .zero
                introComplete = true
            }
            await autoDismissIfNeeded(after: 3.2)
            return
        }

        withAnimation(.easeOut(duration: 0.22)) {
            paperVisible = true
        }
        guard await pause(110) else { return }

        withAnimation(.timingCurve(0.2, 0.72, 0.2, 1, duration: 0.8)) {
            sunVisible = true
            introMotion = CGSize(width: 0.3, height: -0.14)
        }
        guard await pause(180) else { return }

        withAnimation(.timingCurve(0.2, 0.72, 0.2, 1, duration: 0.85)) {
            landscapeVisible = true
        }
        guard await pause(210) else { return }

        withAnimation(.spring(response: 0.85, dampingFraction: 0.82)) {
            characterVisible = true
        }
        guard await pause(430) else { return }

        withAnimation(.timingCurve(0.2, 0.72, 0.2, 1, duration: 0.78)) {
            overlayVisible = true
            introMotion = .zero
        }
        guard await pause(780) else { return }

        introComplete = true
        await autoDismissIfNeeded(after: 2.0)
    }

    @MainActor
    private func autoDismissIfNeeded(after delay: TimeInterval) async {
        guard autoDismiss else { return }
        try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
        guard !Task.isCancelled else { return }
        onDismiss()
    }

    private func pause(_ milliseconds: UInt64) async -> Bool {
        do {
            try await Task.sleep(nanoseconds: milliseconds * 1_000_000)
            return !Task.isCancelled
        } catch {
            return false
        }
    }
}

// MARK: - Layered poster

private struct ParallaxPoster: View {
    let paperVisible: Bool
    let sunVisible: Bool
    let landscapeVisible: Bool
    let characterVisible: Bool
    let overlayVisible: Bool
    let motion: CGSize
    let reduceMotion: Bool
    let introComplete: Bool
    let onPointerMotion: (CGSize) -> Void

    var body: some View {
        GeometryReader { geometry in
            let size = geometry.size

            ZStack(alignment: .topLeading) {
                Image("SplashPaper")
                    .resizable()
                    .scaledToFill()
                    .frame(width: size.width * 1.04, height: size.height * 1.04)
                    .scaleEffect(1.02)
                    .offset(
                        x: -size.width * 0.02 + motion.width * -2,
                        y: -size.height * 0.02 + motion.height * -2
                    )
                    .opacity(paperVisible ? 1 : 0)
                    .accessibilityHidden(true)

                Image("SplashSun")
                    .resizable()
                    .scaledToFit()
                    .frame(width: size.width * 0.347)
                    .scaleEffect(sunVisible ? 1.025 : 0.8)
                    .offset(
                        x: size.width * 0.327 + motion.width * -4,
                        y: size.height * 0.238 + motion.height * -4 + (sunVisible ? 0 : 20)
                    )
                    .opacity(sunVisible ? 1 : 0)
                    .accessibilityHidden(true)

                Image("SplashLandscape")
                    .resizable()
                    .scaledToFit()
                    .frame(width: size.width * 0.936)
                    .scaleEffect(landscapeVisible ? 1.035 : 0.98)
                    .offset(
                        x: size.width * 0.032 + motion.width * -10,
                        y: size.height * 0.284 + motion.height * -8 + (landscapeVisible ? 0 : 18)
                    )
                    .opacity(landscapeVisible ? 1 : 0)
                    .accessibilityHidden(true)

                Image("SplashCharacter")
                    .resizable()
                    .scaledToFit()
                    .frame(width: size.width * 0.164)
                    .scaleEffect(characterVisible ? 1.025 : 0.9, anchor: .bottom)
                    .offset(
                        x: size.width * 0.418 + motion.width * -22,
                        y: size.height * 0.382 + motion.height * -17 + (characterVisible ? 0 : 42)
                    )
                    .opacity(characterVisible ? 1 : 0)
                    .shadow(color: .black.opacity(0.12), radius: 7, x: 0, y: 10)
                    .accessibilityHidden(true)

                Image("SplashOverlay")
                    .resizable()
                    .frame(width: size.width, height: size.height)
                    .mask(
                        Rectangle()
                            .scaleEffect(x: overlayVisible ? 1 : 0, y: 1, anchor: .leading)
                    )
                    .opacity(overlayVisible ? 1 : 0)
                    .accessibilityHidden(true)
            }
            .frame(width: size.width, height: size.height)
            .clipped()
            .contentShape(Rectangle())
            .rotation3DEffect(
                .degrees(reduceMotion ? 0 : Double(motion.height * -4.2)),
                axis: (x: 1, y: 0, z: 0),
                perspective: 0.55
            )
            .rotation3DEffect(
                .degrees(reduceMotion ? 0 : Double(motion.width * 5.4)),
                axis: (x: 0, y: 1, z: 0),
                perspective: 0.55
            )
            .onContinuousHover { phase in
                guard introComplete, !reduceMotion else { return }
                switch phase {
                case .active(let location):
                    let x = max(-1, min(1, (location.x / max(size.width, 1) - 0.5) * 2))
                    let y = max(-1, min(1, (location.y / max(size.height, 1) - 0.5) * 2))
                    onPointerMotion(CGSize(width: x, height: y))
                case .ended:
                    onPointerMotion(.zero)
                }
            }
        }
    }
}
