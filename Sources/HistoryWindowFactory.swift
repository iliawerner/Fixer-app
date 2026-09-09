import AppKit
import SwiftUI

@MainActor
enum HistoryWindowFactory {
    static func make<Content: View>(rootView: Content, frameAutosaveName: String? = "FixerHistory") -> NSWindow {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 920, height: 680),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "History"
        window.backgroundColor = Fixer.baseNS
        window.minSize = NSSize(width: 680, height: 480)
        let lifecycle = HistoryWindowLifecycle()
        window.delegate = lifecycle
        window.contentView = NSHostingView(
            rootView: rootView.environment(\.historyWindowLifecycle, lifecycle)
        )
        window.isReleasedWhenClosed = false
        window.center()
        if let frameAutosaveName { window.setFrameAutosaveName(frameAutosaveName) }
        return window
    }
}
