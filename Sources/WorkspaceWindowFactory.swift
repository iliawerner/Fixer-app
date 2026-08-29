import AppKit
import SwiftUI

/// Builds the Actions workspace as a standard AppKit window.
///
/// The window deliberately remains `.titled` instead of drawing a custom
/// rounded container. AppKit can therefore supply the current system window
/// shape (including the larger macOS 26 corner radius), shadow, resize affordance,
/// and traffic-light controls without Fixer having to imitate them.
@MainActor
enum WorkspaceWindowFactory {
    enum TitlebarCommand: Equatable {
        case addAction
        case openLibrary
        case openSetup
    }

    static let titlebarCommandNotification = Notification.Name(
        "FixerWorkspaceTitlebarCommand"
    )

    /// Transparent native hit targets placed above the system titlebar.
    ///
    /// SwiftUI continues to draw the approved controls beneath this view. The
    /// AppKit buttons own physical mouse routing, while returning `nil` outside
    /// their frames preserves traffic lights and native titlebar dragging.
    private final class TitlebarControlOverlay: NSView {
        private let addButton = NSButton(frame: .zero)
        private let setupButton = NSButton(frame: .zero)

        private var addButtonWindowX: CGFloat {
            WorkspaceChromeMetrics.trafficLightClearance
        }

        private var setupButtonWindowX: CGFloat {
            WorkspaceChromeMetrics.sidebarWidth
                - WorkspaceChromeMetrics.titlebarControlSize - 10
        }

        override init(frame frameRect: NSRect) {
            super.init(frame: frameRect)
            configure(
                addButton,
                frame: NSRect(
                    x: addButtonWindowX,
                    y: 6,
                    width: WorkspaceChromeMetrics.titlebarControlSize,
                    height: WorkspaceChromeMetrics.titlebarControlSize
                ),
                toolTip: "Create a text action",
                action: #selector(showAddMenu(_:))
            )
            configure(
                setupButton,
                frame: NSRect(
                    x: setupButtonWindowX,
                    y: 6,
                    width: WorkspaceChromeMetrics.titlebarControlSize,
                    height: WorkspaceChromeMetrics.titlebarControlSize
                ),
                toolTip: "Open setup",
                action: #selector(openSetup(_:))
            )
        }

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            needsLayout = true
        }

        override func layout() {
            super.layout()
            alignHitTargetsToWindow()
        }

        @available(*, unavailable)
        required init?(coder: NSCoder) {
            fatalError("init(coder:) is unavailable")
        }

        override func hitTest(_ point: NSPoint) -> NSView? {
            guard addButton.frame.contains(point) || setupButton.frame.contains(point) else {
                return nil
            }
            return super.hitTest(point)
        }

        /// `.left` titlebar accessories begin after AppKit's traffic-light
        /// cluster, so their local x-origin is not the window's x-origin. Keep
        /// these transparent controls aligned with the SwiftUI artwork using
        /// window coordinates instead of assuming both coordinate spaces match.
        private func alignHitTargetsToWindow() {
            guard window != nil else { return }

            let accessoryWindowX = convert(bounds, to: nil).minX
            addButton.frame.origin.x = addButtonWindowX - accessoryWindowX
            setupButton.frame.origin.x = setupButtonWindowX - accessoryWindowX
        }

        private func configure(
            _ button: NSButton,
            frame: NSRect,
            toolTip: String,
            action: Selector
        ) {
            button.frame = frame
            button.title = ""
            button.isBordered = false
            button.focusRingType = .none
            button.toolTip = toolTip
            button.target = self
            button.action = action
            button.setAccessibilityElement(false)
            button.setAccessibilityHidden(true)
            addSubview(button)
        }

        @objc private func showAddMenu(_ sender: NSButton) {
            let menu = NSMenu()
            let blankAction = NSMenuItem(
                title: "Blank Action",
                action: #selector(addBlankAction(_:)),
                keyEquivalent: ""
            )
            blankAction.image = NSImage(
                systemSymbolName: "doc.badge.plus",
                accessibilityDescription: nil
            )
            blankAction.target = self
            menu.addItem(blankAction)

            let starterLibrary = NSMenuItem(
                title: "From Starter Library",
                action: #selector(openStarterLibrary(_:)),
                keyEquivalent: ""
            )
            starterLibrary.image = NSImage(
                systemSymbolName: "books.vertical",
                accessibilityDescription: nil
            )
            starterLibrary.target = self
            menu.addItem(starterLibrary)
            menu.popUp(
                positioning: nil,
                at: NSPoint(x: 0, y: sender.bounds.minY),
                in: sender
            )
        }

        @objc private func addBlankAction(_ sender: NSMenuItem) {
            post(.addAction)
        }

        @objc private func openStarterLibrary(_ sender: NSMenuItem) {
            post(.openLibrary)
        }

        @objc private func openSetup(_ sender: NSButton) {
            post(.openSetup)
        }

        private func post(_ command: TitlebarCommand) {
            NotificationCenter.default.post(
                name: WorkspaceWindowFactory.titlebarCommandNotification,
                object: command
            )
        }
    }

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
        // Full-window background dragging steals ordinary mouse-down events
        // from SwiftUI controls that share the transparent titlebar plane.
        // Only explicit `WorkspaceWindowDragRegion` views may start a drag.
        window.isMovableByWindowBackground = false
        window.minSize = WorkspaceWindowMetrics.minimumSize
        window.contentView = NSHostingView(rootView: rootView)

        // Physical pointer events in this plane belong to AppKit, not to the
        // full-size SwiftUI content underneath the transparent titlebar.
        let titlebarOverlay = TitlebarControlOverlay(frame: NSRect(
            x: 0,
            y: 0,
            width: WorkspaceChromeMetrics.sidebarWidth,
            height: WorkspaceChromeMetrics.headerHeight
        ))
        let titlebarAccessory = NSTitlebarAccessoryViewController()
        titlebarAccessory.layoutAttribute = .left
        titlebarAccessory.view = titlebarOverlay
        window.addTitlebarAccessoryViewController(titlebarAccessory)

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
