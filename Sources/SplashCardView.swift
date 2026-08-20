import SwiftUI

/// Complete floating card: artwork, lighting, border, close control and shadow all
/// share one 3D transform so no flat frame is left behind when the card tilts.
struct SplashCardView: View {
    let isRevealed: Bool
    let tilt: SplashTilt
    let reduceMotion: Bool
    let acceptsPointerMotion: Bool
    let onPointerTilt: (SplashTilt) -> Void
    let onPointerExit: () -> Void
    let onDismiss: () -> Void

    var body: some View {
        GeometryReader { geometry in
            let size = geometry.size
            let rotation = SplashMotionMetrics.rotation(for: tilt)

            ZStack(alignment: .topTrailing) {
                SplashPosterView(
                    isRevealed: isRevealed,
                    tilt: tilt,
                    reduceMotion: reduceMotion
                )
                .frame(width: size.width, height: size.height)
                .clipShape(cardShape)
                .overlay {
                    SplashSpecularHighlight(tilt: tilt, isVisible: isRevealed)
                        .clipShape(cardShape)
                }
                .overlay {
                    SplashDirectionalEdgeLight(tilt: tilt)
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(
                    "Fixer. A figure in yellow walks toward a mountain and a yellow sun."
                )

                Button("Close splash", systemImage: "xmark", action: onDismiss)
                    .labelStyle(.iconOnly)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Color.white.opacity(0.9))
                    .frame(width: 32, height: 32)
                    .background(Color.black.opacity(0.68), in: Circle())
                    .overlay(Circle().stroke(Color.white.opacity(0.26), lineWidth: 1))
                    .contentShape(Circle())
                    .buttonStyle(.plain)
                    .padding(12)
                    .help("Close splash")
            }
            .frame(width: size.width, height: size.height)
            .contentShape(cardShape)
            .rotation3DEffect(
                .degrees(rotation.angle),
                axis: (x: rotation.axisX, y: rotation.axisY, z: 0),
                anchor: .center,
                perspective: SplashMotionMetrics.perspective
            )
            .shadow(
                color: .black.opacity(0.18),
                radius: 8,
                x: -tilt.x * 3,
                y: 5
            )
            .shadow(
                color: .black.opacity(0.34),
                radius: 30,
                x: -tilt.x * 10,
                y: 18 + tilt.y * 6
            )
            .onContinuousHover { phase in
                switch phase {
                case .active(let location):
                    guard acceptsPointerMotion else { return }
                    onPointerTilt(SplashTilt(pointerLocation: location, in: size))
                case .ended:
                    onPointerExit()
                }
            }
        }
    }

    private var cardShape: RoundedRectangle {
        RoundedRectangle(cornerRadius: SplashMotionMetrics.cornerRadius)
    }
}

/// Reassembles the five approved identity assets. Layer offsets are deliberately
/// bounded so paper overscan always covers the card at maximum pointer tilt.
private struct SplashPosterView: View {
    let isRevealed: Bool
    let tilt: SplashTilt
    let reduceMotion: Bool

    var body: some View {
        GeometryReader { geometry in
            let size = geometry.size
            let paperOffset = tilt.parallaxOffset(depth: -2)
            let sunOffset = tilt.parallaxOffset(depth: -4)
            let landscapeOffset = tilt.parallaxOffset(depth: -8)
            let characterOffset = tilt.parallaxOffset(depth: -14)

            ZStack(alignment: .topLeading) {
                Image("SplashPaper")
                    .resizable()
                    .interpolation(.high)
                    .scaledToFill()
                    .frame(width: size.width * 1.06, height: size.height * 1.06)
                    .offset(
                        x: -size.width * 0.03 + paperOffset.width,
                        y: -size.height * 0.03 + paperOffset.height
                    )
                    .opacity(isRevealed ? 1 : 0)
                    .animation(layerAnimation(.easeOut(duration: 0.18)), value: isRevealed)
                    .accessibilityHidden(true)

                Image("SplashSun")
                    .resizable()
                    .interpolation(.high)
                    .scaledToFit()
                    .frame(width: size.width * 0.347)
                    .scaleEffect(isRevealed ? 1.025 : 0.88)
                    .offset(
                        x: size.width * 0.327 + sunOffset.width,
                        y: size.height * 0.238 + sunOffset.height + (isRevealed ? 0 : 14)
                    )
                    .opacity(isRevealed ? 1 : 0)
                    .animation(
                        layerAnimation(.timingCurve(0.2, 0.72, 0.2, 1, duration: 0.58).delay(0.14)),
                        value: isRevealed
                    )
                    .accessibilityHidden(true)

                Image("SplashLandscape")
                    .resizable()
                    .interpolation(.high)
                    .scaledToFit()
                    .frame(width: size.width * 0.936)
                    .scaleEffect(isRevealed ? 1.035 : 0.985)
                    .offset(
                        x: size.width * 0.032 + landscapeOffset.width,
                        y: size.height * 0.284 + landscapeOffset.height + (isRevealed ? 0 : 14)
                    )
                    .opacity(isRevealed ? 1 : 0)
                    .animation(
                        layerAnimation(.timingCurve(0.2, 0.72, 0.2, 1, duration: 0.62).delay(0.22)),
                        value: isRevealed
                    )
                    .accessibilityHidden(true)

                Image("SplashCharacter")
                    .resizable()
                    .interpolation(.high)
                    .scaledToFit()
                    .frame(width: size.width * 0.164)
                    .scaleEffect(isRevealed ? 1.025 : 0.92, anchor: .bottom)
                    .offset(
                        x: size.width * 0.418 + characterOffset.width,
                        y: size.height * 0.382 + characterOffset.height + (isRevealed ? 0 : 32)
                    )
                    .opacity(isRevealed ? 1 : 0)
                    .shadow(color: .black.opacity(0.12), radius: 7, x: 0, y: 10)
                    .animation(
                        layerAnimation(.spring(response: 0.72, dampingFraction: 0.78).delay(0.34)),
                        value: isRevealed
                    )
                    .accessibilityHidden(true)

                Image("SplashOverlay")
                    .resizable()
                    .interpolation(.high)
                    .frame(width: size.width, height: size.height)
                    .mask(
                        Rectangle()
                            .scaleEffect(x: isRevealed ? 1 : 0, y: 1, anchor: .leading)
                    )
                    .opacity(isRevealed ? 1 : 0)
                    .animation(
                        layerAnimation(.timingCurve(0.2, 0.72, 0.2, 1, duration: 0.42).delay(0.10)),
                        value: isRevealed
                    )
                    .accessibilityHidden(true)
            }
            .frame(width: size.width, height: size.height)
        }
    }

    private func layerAnimation(_ animation: Animation) -> Animation? {
        reduceMotion ? nil : animation
    }
}

/// Broad paper-like reflection driven only by pointer tilt. It has no repeating
/// timeline, so the settled card stays calm and consumes no animation work.
private struct SplashSpecularHighlight: View {
    let tilt: SplashTilt
    let isVisible: Bool

    var body: some View {
        GeometryReader { geometry in
            let size = geometry.size
            let x = size.width / 2 + tilt.x * size.width * 0.34 - tilt.y * size.width * 0.08
            let y = size.height / 2 + tilt.y * size.height * 0.18

            Rectangle()
                .fill(
                    LinearGradient(
                        stops: [
                            .init(color: .clear, location: 0),
                            .init(color: Color.white.opacity(0.03), location: 0.28),
                            .init(color: Color(red: 1, green: 0.96, blue: 0.82).opacity(0.22), location: 0.5),
                            .init(color: Color.white.opacity(0.025), location: 0.68),
                            .init(color: .clear, location: 1)
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .frame(width: size.width * 0.48, height: size.height * 1.55)
                .rotationEffect(.degrees(-24 + Double(tilt.y * 5)))
                .position(x: x, y: y)
                .blur(radius: 5)
                .blendMode(.screen)
                .opacity(isVisible ? 0.72 : 0)
                .allowsHitTesting(false)
        }
    }
}

/// Directional rim light moves opposite the card normal, reinforcing depth even
/// where the poster itself is visually quiet.
private struct SplashDirectionalEdgeLight: View {
    let tilt: SplashTilt

    var body: some View {
        RoundedRectangle(cornerRadius: SplashMotionMetrics.cornerRadius)
            .stroke(
                LinearGradient(
                    stops: [
                        .init(color: Color.white.opacity(0.68), location: 0),
                        .init(color: Color.white.opacity(0.14), location: 0.36),
                        .init(color: Color.black.opacity(0.20), location: 1)
                    ],
                    startPoint: UnitPoint(
                        x: 0.08 - tilt.x * 0.12,
                        y: 0.04 - tilt.y * 0.10
                    ),
                    endPoint: UnitPoint(
                        x: 0.92 - tilt.x * 0.12,
                        y: 0.96 - tilt.y * 0.10
                    )
                ),
                lineWidth: 1
            )
            .allowsHitTesting(false)
    }
}
