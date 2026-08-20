import SwiftUI

/// A deliberate window-drag surface for otherwise empty workspace chrome.
///
/// The workspace draws controls inside a transparent full-size titlebar. AppKit's
/// global `isMovableByWindowBackground` behavior treats those controls as window
/// background on some macOS versions, so dragging is opt-in through this view.
struct WorkspaceWindowDragRegion: NSViewRepresentable {
    func makeNSView(context: Context) -> WorkspaceWindowDragView {
        WorkspaceWindowDragView()
    }

    func updateNSView(_ nsView: WorkspaceWindowDragView, context: Context) {}
}
