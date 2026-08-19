import AppKit
import SwiftUI
import Testing
@testable import fixer

struct WorkspaceWindowFactoryTests {
    @Test @MainActor
    func workspaceUsesSystemManagedWindowChrome() {
        let window = WorkspaceWindowFactory.make(
            rootView: Color.clear,
            frameAutosaveName: nil
        )
        defer { window.close() }

        #expect(window.styleMask.contains(.titled))
        #expect(window.styleMask.contains(.closable))
        #expect(window.styleMask.contains(.miniaturizable))
        #expect(window.styleMask.contains(.resizable))
        #expect(window.styleMask.contains(.fullSizeContentView))

        // A standard titled window leaves the corner shape and traffic lights to
        // the running macOS release instead of baking in a soon-stale imitation.
        let closeButton = window.standardWindowButton(.closeButton)
        #expect(closeButton?.isHidden == false)
        #expect(window.standardWindowButton(.miniaturizeButton)?.isHidden == false)
        #expect(window.standardWindowButton(.zoomButton)?.isHidden == false)
        #expect(closeButton?.window === window)
        #expect(window.toolbar != nil)
        #expect(window.toolbarStyle == .unifiedCompact)
        if let titlebarHeight = closeButton?.superview?.bounds.height {
            #expect(abs(titlebarHeight - WorkspaceChromeMetrics.headerHeight) <= 0.5)
        }
        if let contentView = window.contentView {
            #expect(closeButton?.isDescendant(of: contentView) == false)
        }
    }

    @Test @MainActor
    func workspaceTitlebarIsTransparentAndOwnedByContent() {
        let window = WorkspaceWindowFactory.make(
            rootView: Color.clear,
            frameAutosaveName: nil
        )
        defer { window.close() }

        #expect(window.title == "Actions")
        #expect(window.titleVisibility == .hidden)
        #expect(window.titlebarAppearsTransparent)
        #expect(window.titlebarSeparatorStyle == .none)
        #expect(window.toolbar?.allowsUserCustomization == false)
        #expect(window.toolbar?.autosavesConfiguration == false)
        #expect(window.isMovableByWindowBackground)
    }

    @Test @MainActor
    func workspaceLifecycleAndGeometryRemainRestorable() {
        let window = WorkspaceWindowFactory.make(
            rootView: Color.clear,
            frameAutosaveName: nil
        )
        defer { window.close() }

        #expect(window.contentRect(forFrameRect: window.frame).size == WorkspaceWindowMetrics.defaultSize)
        // AppKit includes the compact unified titlebar's frame decoration in
        // `minSize`, while the SwiftUI workspace owns the requested content
        // minimum. Width remains exact; height may grow by a few system points.
        #expect(window.minSize.width == WorkspaceWindowMetrics.minimumSize.width)
        #expect(window.minSize.height >= WorkspaceWindowMetrics.minimumSize.height)
        #expect(
            window.minSize.height
                <= WorkspaceWindowMetrics.minimumSize.height + WorkspaceChromeMetrics.headerHeight
        )
        #expect(!window.isReleasedWhenClosed)
        #expect(window.contentView is NSHostingView<Color>)
    }

    @Test @MainActor
    func presentationDoesNotAutoFocusAnEditor() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 480, height: 320),
            styleMask: [.titled],
            backing: .buffered,
            defer: false
        )
        defer { window.close() }

        let field = NSTextField(string: "Action name")
        window.contentView?.addSubview(field)
        #expect(window.makeFirstResponder(field))
        #expect(window.firstResponder is NSTextView)

        WorkspaceWindowFactory.present(window)

        #expect(window.firstResponder === window)
    }
}
