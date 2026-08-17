import CoreGraphics
import Testing
@testable import fixer

struct HUDLayoutTests {
    @Test func centersPanelAndKeepsTheRailAboveTheVisibleFrameBottom() {
        let visibleFrame = CGRect(x: 0, y: 24, width: 1440, height: 876)
        let origin = HUDLayout.panelOrigin(
            panelSize: CGSize(width: 368, height: 88),
            visibleFrame: visibleFrame
        )

        #expect(origin.x == 536)
        #expect(origin.y == 80)
    }

    @Test func supportsDisplaysWithNegativeCoordinates() {
        let visibleFrame = CGRect(x: -1600, y: -77, width: 1600, height: 900)
        let origin = HUDLayout.panelOrigin(
            panelSize: CGSize(width: 368, height: 124),
            visibleFrame: visibleFrame
        )

        #expect(origin.x == -984)
        #expect(origin.y == -21)
    }
}
