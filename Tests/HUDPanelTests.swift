import AppKit
import Testing
@testable import fixer

@MainActor
struct HUDPanelTests {
    @Test func factoryBuildsAPassiveTransparentPanel() {
        let panel = HUDPanelFactory.make(size: HUDLayout.panelSize)

        #expect(panel.styleMask.contains(.borderless))
        #expect(panel.styleMask.contains(.nonactivatingPanel))
        #expect(!panel.canBecomeKey)
        #expect(!panel.canBecomeMain)
        #expect(panel.ignoresMouseEvents)
        #expect(!panel.isOpaque)
        #expect(!panel.hasShadow)
        #expect(panel.backgroundColor.alphaComponent == 0)
        #expect(panel.level == .statusBar)
    }
}
