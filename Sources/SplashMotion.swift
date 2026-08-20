import CoreGraphics
import Foundation

/// Selects either the real first-run entrance or a deterministic final frame.
/// The settled mode exists for previews and render tests; it never starts tasks.
enum SplashPresentation: Equatable {
    case animated
    case settled
}

/// Pointer displacement normalized to the closed range `-1 ... 1` on each axis.
/// Keeping this value dimensionless prevents view size from changing motion feel.
struct SplashTilt: Equatable, Sendable {
    let x: CGFloat
    let y: CGFloat

    static let zero = SplashTilt(x: 0, y: 0)
    static let entrance = SplashTilt(x: -0.68, y: 0.42)

    init(x: CGFloat, y: CGFloat) {
        self.x = min(1, max(-1, x))
        self.y = min(1, max(-1, y))
    }

    init(pointerLocation location: CGPoint, in size: CGSize) {
        guard size.width > 0, size.height > 0 else {
            self = .zero
            return
        }

        self.init(
            x: (location.x / size.width - 0.5) * 2,
            y: (location.y / size.height - 0.5) * 2
        )
    }

    func parallaxOffset(depth: CGFloat) -> CGSize {
        CGSize(width: x * depth, height: y * depth)
    }
}

/// A single axis-angle rotation keeps diagonal pointer movement physically
/// coherent. Chaining X and Y rotations makes the result depend on modifier order.
struct SplashRotation: Equatable, Sendable {
    let angle: Double
    let axisX: CGFloat
    let axisY: CGFloat
}

/// Motion and geometry invariants shared by the live window and unit tests.
enum SplashMotionMetrics {
    static let artworkAspectRatio: CGFloat = 4 / 3
    /// Sixty points contain the 30 pt blur plus the maximum 24 pt downward
    /// shadow offset, leaving a small safety margin at full tilt.
    static let clearOverscan: CGFloat = 60
    static let maximumShadowExtent: CGFloat = 54
    static let maxRotationDegrees: CGFloat = 6
    static let perspective: CGFloat = 0.42
    static let cornerRadius: CGFloat = 18

    static let maximumWindowSize = CGSize(width: 860, height: 680)
    static let screenInset: CGFloat = 48

    static func preferredWindowSize(in visibleFrame: CGRect) -> CGSize {
        CGSize(
            width: min(maximumWindowSize.width, max(320, visibleFrame.width - screenInset)),
            height: min(maximumWindowSize.height, max(280, visibleFrame.height - screenInset))
        )
    }

    /// Fits the strict 4:3 identity inside transparent space reserved for tilt and
    /// the custom shadow. The overscan must remain larger than the maximum shadow.
    static func cardSize(in stage: CGSize) -> CGSize {
        let availableWidth = max(1, stage.width - clearOverscan * 2)
        let availableHeight = max(1, stage.height - clearOverscan * 2)
        let width = min(availableWidth, availableHeight * artworkAspectRatio)
        return CGSize(width: width, height: width / artworkAspectRatio)
    }

    static func resolvedTilt(_ tilt: SplashTilt, reduceMotion: Bool) -> SplashTilt {
        reduceMotion ? .zero : tilt
    }

    static func allowsEntranceAnimation(
        presentation: SplashPresentation,
        reduceMotion: Bool
    ) -> Bool {
        presentation == .animated && !reduceMotion
    }

    static func allowsPointerMotion(
        presentation: SplashPresentation,
        introComplete: Bool,
        reduceMotion: Bool
    ) -> Bool {
        presentation == .animated && introComplete && !reduceMotion
    }

    static func rotation(for tilt: SplashTilt) -> SplashRotation {
        let rawMagnitude = sqrt(tilt.x * tilt.x + tilt.y * tilt.y)
        guard rawMagnitude > 0.000_1 else {
            return SplashRotation(angle: 0, axisX: 1, axisY: 0)
        }

        let clampedMagnitude = min(1, rawMagnitude)
        return SplashRotation(
            angle: Double(clampedMagnitude * maxRotationDegrees),
            axisX: -tilt.y / rawMagnitude,
            axisY: tilt.x / rawMagnitude
        )
    }
}
