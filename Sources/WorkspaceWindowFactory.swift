import SwiftUI

/// Builds the Actions workspace as a standard AppKit window.
///
/// The window deliberately remains `.titled` instead of drawing a custom
/// rounded container. AppKit can therefore supply the current system window
/// shape (including the larger macOS 26 corner radius), shadow, resize affordance,
/// and traffic-light controls without Fixer having to imitate them.
@MainActor
enum WorkspaceWindowFactory {
    /// Creates the long-lived workspace window around the supplied SwiftUI view.
    ///
    /// - Parameter frameAutosaveName: Pass `nil` in isolated tests that must not
    ///   read or write the user's restored workspace frame.
    static func make<Content: View>(
        rootView: Content,
        frameAutosaveName: String? = WorkspaceWindowMetrics.autosaveName
    ) -> NSWindow {
        let window = NSWindow(
            contentRect: NSRect(origin: .zero, size: WorkspaceWindowMetrics.defaultSize),
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )

        // Keep a useful accessibility/Window-menu name without painting the app
        // name into its own interface. The visible titlebar belongs to the content.
        window.title = "Actions"
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.titlebarSeparatorStyle = .none

        // A real compact unified toolbar makes AppKit place the traffic lights
        // on the same 40 pt axis as our full-size content chrome. It remains
        // intentionally itemless: Fixer's SwiftUI controls stay interactive in
        // the titlebar plane while AppKit owns system geometry and hit testing.
        let toolbar = NSToolbar(identifier: "FixerWorkspaceToolbar")
        toolbar.allowsUserCustomization = false
        toolbar.autosavesConfiguration = false
        window.toolbar = toolbar
        window.toolbarStyle = .unifiedCompact

        // The signal-paper interface stays light in either system appearance so
        // controls and the transparent titlebar resolve against one palette.
        window.appearance = NSAppearance(named: .aqua)
        window.backgroundColor = Fixer.baseNS
        window.isMovableByWindowBackground = true
        window.minSize = WorkspaceWindowMetrics.minimumSize
        window.contentView = NSHostingView(rootView: rootView)

        // Center first so a new install has a deliberate position. Registering
        // autosave afterwards lets AppKit replace it with a valid restored frame.
        window.center()
        if let frameAutosaveName {
            window.setFrameAutosaveName(frameAutosaveName)
        }

        // AppDelegate caches and reuses this instance after the user closes it.
        window.isReleasedWhenClosed = false
        return window
    }

    /// Shows the workspace without letting AppKit choose the first editable
    /// control as an initial first responder. Users should enter title editing
    /// deliberately instead of seeing a caret immediately after launch.
    static func present(_ window: NSWindow) {
        window.makeKeyAndOrderFront(nil)
        window.makeFirstResponder(nil)
    }
}
