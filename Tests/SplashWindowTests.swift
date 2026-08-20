import AppKit
import Testing
@testable import fixer

@Suite(.serialized)
struct SplashWindowTests {
    @Test @MainActor func windowAndHostingSurfaceStayTransparent() {
        let size = CGSize(width: 860, height: 680)
        let window = SplashWindowController.makeWindow(
            contentRect: NSRect(origin: .zero, size: size)
        )
        defer { window.close() }

        #expect(window.styleMask == .borderless)
        #expect(!window.isOpaque)
        #expect(window.backgroundColor.alphaComponent < 0.001)
        #expect(!window.hasShadow)
        #expect(window.level == .floating)
        #expect(window.isMovableByWindowBackground)
        #expect(window.acceptsMouseMovedEvents)
        #expect(window.canBecomeKey)
        #expect(window.canBecomeMain)

        let rootView = SplashView(
            autoDismiss: false,
            presentation: .settled,
            onDismiss: {}
        )
        let hosting = SplashWindowController.makeHostingView(rootView: rootView, size: size)
        let layerColor = hosting.layer?.backgroundColor.flatMap { NSColor(cgColor: $0) }

        #expect(hosting.wantsLayer)
        #expect(hosting.layer?.isOpaque == false)
        #expect(hosting.layer?.masksToBounds == false)
        #expect((layerColor?.alphaComponent ?? 1) < 0.001)
    }

    @Test func preferredSizeStaysInsideTheVisibleScreenBudget() {
        let large = SplashMotionMetrics.preferredWindowSize(
            in: CGRect(x: 0, y: 0, width: 1728, height: 1080)
        )
        let compact = SplashMotionMetrics.preferredWindowSize(
            in: CGRect(x: 0, y: 0, width: 800, height: 600)
        )

        #expect(large == SplashMotionMetrics.maximumWindowSize)
        #expect(compact == CGSize(width: 752, height: 552))
    }
}
