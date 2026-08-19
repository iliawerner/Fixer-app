import CoreGraphics
import Testing
@testable import fixer

struct HUDLayoutTests {
    @Test func centersPanelAboveTheVisibleFrameBottom() {
        let visibleFrame = CGRect(x: 0, y: 24, width: 1440, height: 876)
        let origin = HUDLayout.panelOrigin(
            panelSize: HUDLayout.panelSize,
            visibleFrame: visibleFrame
        )

        #expect(origin.x == 510)
        #expect(origin.y == 31)
    }

    @Test func supportsDisplaysWithNegativeCoordinates() {
        let visibleFrame = CGRect(x: -1600, y: -77, width: 1600, height: 900)
        let origin = HUDLayout.panelOrigin(
            panelSize: HUDLayout.panelSize,
            visibleFrame: visibleFrame
        )

        #expect(origin.x == -1010)
        #expect(origin.y == -70)
    }

    @Test func errorExpandsOnlyTheVisibleSurfaceInsideAStablePanel() {
        #expect(HUDLayout.cardSize(for: .working) == HUDLayout.compactCardSize)
        #expect(HUDLayout.cardSize(for: .busy) == HUDLayout.compactCardSize)
        #expect(HUDLayout.cardSize(for: .success) == HUDLayout.compactCardSize)
        #expect(HUDLayout.cardSize(for: .error) == HUDLayout.errorCardSize)
        #expect(HUDLayout.panelSize(for: .working) == HUDLayout.panelSize)
        #expect(HUDLayout.panelSize(for: .busy) == HUDLayout.panelSize)
        #expect(HUDLayout.panelSize(for: .success) == HUDLayout.panelSize)
        #expect(HUDLayout.panelSize(for: .error) == HUDLayout.panelSize)
    }

    @Test func statusSurfacesKeepTransparentBreathingRoomInsideTheirPanels() {
        #expect(HUDLayout.panelSize.width - HUDLayout.compactCardSize.width == 116)
        #expect(HUDLayout.panelSize.height - HUDLayout.compactCardSize.height == 140)
        #expect(HUDLayout.panelSize.width - HUDLayout.errorCardSize.width == 76)
        #expect(HUDLayout.panelSize.height - HUDLayout.errorCardSize.height == 114)
        #expect(HUDLayout.cornerRadius == 13)
        #expect(HUDLayout.shadowRadius == 8)
        #expect(HUDLayout.shadowYOffset == 4)
        #expect(HUDLayout.contentLeadingInset == 20)
        #expect(HUDLayout.contentTrailingInset == 14)
        #expect(HUDLayout.indicatorToCopySpacing == 12)
        #expect(HUDLayout.contentLeadingInset > HUDLayout.contentTrailingInset)
        #expect(HUDLayout.cardOrigin(for: .working) == CGPoint(x: 58, y: 70))
        #expect(HUDLayout.cardOrigin(for: .success) == CGPoint(x: 58, y: 70))
        #expect(HUDLayout.cardOrigin(for: .error) == CGPoint(x: 38, y: 57))
    }

    @Test func everySurfaceHasEnoughOverscanForItsShadowOnEveryEdge() {
        let requiredOverscan = HUDLayout.shadowRadius * 2 + abs(HUDLayout.shadowYOffset)

        for phase in [
            RunFeedbackPresentation.Phase.working,
            .busy,
            .success,
            .error
        ] {
            let size = HUDLayout.cardSize(for: phase)
            let origin = HUDLayout.cardOrigin(for: phase)
            let trailing = HUDLayout.panelSize.width - origin.x - size.width
            let top = HUDLayout.panelSize.height - origin.y - size.height

            #expect(origin.x > requiredOverscan)
            #expect(trailing > requiredOverscan)
            #expect(origin.y > requiredOverscan)
            #expect(top > requiredOverscan)
        }
    }
}
