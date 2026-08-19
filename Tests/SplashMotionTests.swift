import CoreGraphics
import Testing
@testable import fixer

struct SplashMotionTests {
    @Test func pointerCoordinatesNormalizeAndClamp() {
        let size = CGSize(width: 400, height: 300)

        #expect(SplashTilt(pointerLocation: CGPoint(x: 200, y: 150), in: size) == .zero)
        #expect(
            SplashTilt(pointerLocation: CGPoint(x: -200, y: 600), in: size)
                == SplashTilt(x: -1, y: 1)
        )
        #expect(SplashTilt(pointerLocation: .zero, in: .zero) == .zero)
    }

    @Test func diagonalRotationUsesOneNormalizedAxisAndNeverExceedsCap() {
        let rotation = SplashMotionMetrics.rotation(for: SplashTilt(x: 1, y: 1))
        let axisMagnitude = sqrt(rotation.axisX * rotation.axisX + rotation.axisY * rotation.axisY)

        #expect(abs(rotation.angle - Double(SplashMotionMetrics.maxRotationDegrees)) < 0.000_1)
        #expect(abs(axisMagnitude - 1) < 0.000_1)
    }

    @Test func cardKeepsClearSpaceForShadowAndTilt() {
        let stage = CGSize(width: 860, height: 680)
        let card = SplashMotionMetrics.cardSize(in: stage)

        #expect(card.width == 740)
        #expect(card.height == 555)
        #expect((stage.width - card.width) / 2 >= SplashMotionMetrics.clearOverscan)
        #expect((stage.height - card.height) / 2 >= SplashMotionMetrics.clearOverscan)
        #expect(SplashMotionMetrics.clearOverscan > SplashMotionMetrics.maximumShadowExtent)
    }

    @Test func reduceMotionDisablesEveryMotionEntryPoint() {
        let pointerTilt = SplashTilt(x: 0.8, y: -0.6)

        #expect(SplashMotionMetrics.resolvedTilt(pointerTilt, reduceMotion: true) == .zero)
        #expect(
            !SplashMotionMetrics.allowsEntranceAnimation(
                presentation: .animated,
                reduceMotion: true
            )
        )
        #expect(
            !SplashMotionMetrics.allowsPointerMotion(
                presentation: .animated,
                introComplete: true,
                reduceMotion: true
            )
        )
    }

    @Test func pointerMotionStartsOnlyAfterTheEntranceSettles() {
        #expect(
            !SplashMotionMetrics.allowsPointerMotion(
                presentation: .animated,
                introComplete: false,
                reduceMotion: false
            )
        )
        #expect(
            SplashMotionMetrics.allowsPointerMotion(
                presentation: .animated,
                introComplete: true,
                reduceMotion: false
            )
        )
        #expect(
            !SplashMotionMetrics.allowsPointerMotion(
                presentation: .settled,
                introComplete: true,
                reduceMotion: false
            )
        )
    }
}
