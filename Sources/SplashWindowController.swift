import AppKit
import SwiftUI

/// Owns the splash window separately from application lifecycle routing.
/// The window stays transparent; all visible shape and shadow belong to SwiftUI.
@MainActor
final class SplashWindowController {
    private let openSettingsAfter: Bool
    private let onDismiss: (Bool) -> Void

    private(set) var window: SplashWindow?
    private var didDismiss = false

    init(openSettingsAfter: Bool, onDismiss: @escaping (Bool) -> Void) {
        self.openSettingsAfter = openSettingsAfter
        self.onDismiss = onDismiss
    }

    var isVisible: Bool {
        window?.isVisible == true
    }

    func show() {
        if isVisible {
            bringToFront()
            return
        }

        let pointer = NSEvent.mouseLocation
        let screen = NSScreen.screens.first { $0.frame.contains(pointer) } ?? NSScreen.main
        let visibleFrame = screen?.visibleFrame ?? NSRect(x: 0, y: 0, width: 960, height: 720)
        let size = SplashMotionMetrics.preferredWindowSize(in: visibleFrame)
        let contentRect = NSRect(origin: .zero, size: size)

        let window = Self.makeWindow(contentRect: contentRect)
        window.setFrameOrigin(
            NSPoint(
                x: visibleFrame.midX - size.width / 2,
                y: visibleFrame.midY - size.height / 2
            )
        )

        let rootView = SplashView(autoDismiss: openSettingsAfter) { [weak self] in
            self?.dismiss()
        }
        window.contentView = Self.makeHostingView(rootView: rootView, size: size)

        self.window = window
        window.makeKeyAndOrderFront(nil)
    }

    func bringToFront() {
        window?.makeKeyAndOrderFront(nil)
    }

    func dismiss() {
        guard !didDismiss else { return }
        didDismiss = true

        let callback = onDismiss
        let shouldOpenSettings = openSettingsAfter
        if let window {
            self.window = nil
            window.contentView = nil
            window.close()
        }
        callback(shouldOpenSettings)
    }

    /// Internal factory keeps the transparency contract directly unit-testable.
    static func makeWindow(contentRect: NSRect) -> SplashWindow {
        let window = SplashWindow(
            contentRect: contentRect,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        window.title = "Fixer"
        window.appearance = NSAppearance(named: .aqua)
        window.backgroundColor = .clear
        window.isOpaque = false
        window.hasShadow = false
        window.level = .floating
        window.isMovableByWindowBackground = true
        window.acceptsMouseMovedEvents = true
        window.isReleasedWhenClosed = false
        window.animationBehavior = .none
        window.collectionBehavior = [.moveToActiveSpace, .fullScreenAuxiliary]
        return window
    }

    /// `NSHostingView` can otherwise contribute an opaque backing layer even when
    /// its SwiftUI root is clear, recreating a rectangular window behind the card.
    static func makeHostingView(rootView: SplashView, size: CGSize) -> NSHostingView<SplashView> {
        let hosting = NSHostingView(rootView: rootView)
        hosting.frame = NSRect(origin: .zero, size: size)
        hosting.wantsLayer = true
        hosting.layer?.backgroundColor = NSColor.clear.cgColor
        hosting.layer?.isOpaque = false
        hosting.layer?.masksToBounds = false
        return hosting
    }
}

/// Borderless windows do not become key by default. The splash needs key status
/// only for its close button and Escape handling; it is never used during a run.
final class SplashWindow: NSWindow {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}
