import AppKit

/// AppKit endpoint that starts a native window drag only from its own bounds.
final class WorkspaceWindowDragView: NSView {
    override var mouseDownCanMoveWindow: Bool { true }

    override func mouseDown(with event: NSEvent) {
        window?.performDrag(with: event)
    }
}
