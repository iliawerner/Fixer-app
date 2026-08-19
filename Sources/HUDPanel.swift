import AppKit

/// Builds the passive AppKit shell independently from its SwiftUI content.
/// Keeping construction deterministic makes the focus contract testable without
/// presenting a window or triggering an Action run.
@MainActor
enum HUDPanelFactory {
    static func make(size: NSSize) -> NonActivatingHUDPanel {
        let panel = NonActivatingHUDPanel(
            contentRect: NSRect(origin: .zero, size: size),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.isFloatingPanel = true
        panel.level = .statusBar
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = false
        panel.ignoresMouseEvents = true
        panel.hidesOnDeactivate = false
        panel.animationBehavior = .none
        panel.collectionBehavior = [
            .canJoinAllSpaces,
            .fullScreenAuxiliary,
            .stationary,
            .ignoresCycle
        ]
        return panel
    }
}

/// Defensive AppKit enforcement of the focus contract. The style mask already
/// requests a non-activating panel; these overrides make the intent explicit.
final class NonActivatingHUDPanel: NSPanel {
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}
