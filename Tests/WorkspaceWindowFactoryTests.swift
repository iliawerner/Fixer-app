import AppKit
import Combine
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
            if ProcessInfo.processInfo.operatingSystemVersion.majorVersion >= 26 {
                // macOS 26 owns the 40 pt compact titlebar geometry that the
                // current visual contract targets.
                #expect(abs(titlebarHeight - WorkspaceChromeMetrics.headerHeight) <= 0.5)
            } else {
                // Earlier supported releases render unifiedCompact between 36
                // and 42 pt. That variation belongs to AppKit, not Fixer.
                #expect((36.0 ... 42.0).contains(titlebarHeight))
            }
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
        // The full background must not steal clicks from SwiftUI controls in
        // the transparent titlebar. Dedicated drag-region views own movement.
        #expect(!window.isMovableByWindowBackground)
    }

    @Test @MainActor
    func workspaceControlsLiveInTheSystemTitlebarLayer() throws {
        let window = WorkspaceWindowFactory.make(
            rootView: Color.clear,
            frameAutosaveName: nil
        )
        defer { window.close() }

        let accessory = try #require(window.titlebarAccessoryViewControllers.first)
        #expect(accessory.layoutAttribute == .left)
        #expect(accessory.view.isDescendant(of: window.contentView!) == false)

        let buttons = accessory.view.subviews.compactMap { $0 as? NSButton }
        #expect(buttons.count == 3)

        let addButton = try #require(
            buttons.first { $0.toolTip == "Create a text action" }
        )
        let setupButton = try #require(
            buttons.first { $0.toolTip == "Open setup" }
        )
        let historyButton = try #require(buttons.first { $0.toolTip == "Open history" })
        window.contentView?.superview?.layoutSubtreeIfNeeded()
        accessory.view.layoutSubtreeIfNeeded()

        let addFrameInWindow = accessory.view.convert(addButton.frame, to: nil)
        let setupFrameInWindow = accessory.view.convert(setupButton.frame, to: nil)
        let closeButton = try #require(window.standardWindowButton(.closeButton))
        let closeButtonSuperview = try #require(closeButton.superview)
        let closeFrameInWindow = closeButtonSuperview.convert(closeButton.frame, to: nil)
        let expectedAddCenterX = WorkspaceChromeMetrics.trafficLightClearance
            + WorkspaceChromeMetrics.titlebarControlSize / 2
        let expectedSetupCenterX = WorkspaceChromeMetrics.sidebarWidth
            - WorkspaceChromeMetrics.titlebarTrailingPadding
            - WorkspaceChromeMetrics.titlebarControlSize / 2

        #expect(
            abs(addFrameInWindow.midX - expectedAddCenterX) <= 0.5,
            "Add hit target is at x=\(addFrameInWindow.midX), expected x=\(expectedAddCenterX)"
        )
        #expect(
            abs(setupFrameInWindow.midX - expectedSetupCenterX) <= 0.5,
            "Setup hit target is at x=\(setupFrameInWindow.midX), expected x=\(expectedSetupCenterX)"
        )
        #expect(abs(addFrameInWindow.midY - closeFrameInWindow.midY) <= 0.5)
        #expect(abs(setupFrameInWindow.midY - closeFrameInWindow.midY) <= 0.5)
        let historyFrameInWindow = accessory.view.convert(historyButton.frame, to: nil)
        #expect(abs(historyFrameInWindow.midX - (expectedSetupCenterX - 36)) <= 0.5)
        #expect(abs(historyFrameInWindow.midY - closeFrameInWindow.midY) <= 0.5)
        #expect(!historyButton.isAccessibilityElement())
        #expect(historyButton.refusesFirstResponder)
        #expect(accessory.view.hitTest(NSPoint(x: historyButton.frame.midX, y: historyButton.frame.midY)) === historyButton)
        #expect(!addButton.isAccessibilityElement())
        #expect(!setupButton.isAccessibilityElement())
        #expect(addButton.refusesFirstResponder)
        #expect(setupButton.refusesFirstResponder)
        let exposedAccessibilityChildren = NSAccessibility.unignoredChildren(
            from: accessory.view.accessibilityChildren() ?? []
        )
        #expect(
            exposedAccessibilityChildren.isEmpty,
            "Transparent titlebar hit targets must not add duplicate VoiceOver elements"
        )
        #expect(addButton.action != nil)
        #expect(setupButton.action != nil)
        #expect(
            accessory.view.hitTest(
                NSPoint(x: addButton.frame.midX, y: addButton.frame.midY)
            ) === addButton
        )
        #expect(
            accessory.view.hitTest(
                NSPoint(x: setupButton.frame.midX, y: setupButton.frame.midY)
            ) === setupButton
        )

        window.toolbar?.isVisible = false
        window.contentView?.superview?.layoutSubtreeIfNeeded()
        accessory.view.layoutSubtreeIfNeeded()

        let hiddenToolbarAddFrame = accessory.view.convert(addButton.frame, to: nil)
        let hiddenToolbarSetupFrame = accessory.view.convert(setupButton.frame, to: nil)
        let contentView = try #require(window.contentView)
        let contentTopY = contentView.convert(contentView.bounds, to: nil).maxY
        let expectedControlCenterY = contentTopY - WorkspaceChromeMetrics.headerHeight / 2
        #expect(abs(hiddenToolbarAddFrame.midY - expectedControlCenterY) <= 0.5)
        #expect(abs(hiddenToolbarSetupFrame.midY - expectedControlCenterY) <= 0.5)
        #expect(
            accessory.view.hitTest(
                NSPoint(x: addButton.frame.midX, y: addButton.frame.midY)
            ) === addButton
        )
        #expect(
            accessory.view.hitTest(
                NSPoint(x: setupButton.frame.midX, y: setupButton.frame.midY)
            ) === setupButton
        )
        // The rest of the titlebar still belongs to AppKit's traffic lights and
        // the explicit SwiftUI drag region underneath this transparent overlay.
        #expect(accessory.view.hitTest(NSPoint(x: 4, y: 4)) == nil)
    }

    @Test @MainActor
    func titlebarNotificationForwardsWorkspaceCommands() {
        var receivedCommands: [WorkspaceWindowFactory.TitlebarCommand] = []
        let commandSubscription = NotificationCenter.default.publisher(
            for: WorkspaceWindowFactory.titlebarCommandNotification
        )
        .compactMap { $0.object as? WorkspaceWindowFactory.TitlebarCommand }
        .sink { receivedCommands.append($0) }
        defer { commandSubscription.cancel() }

        for command in [
            WorkspaceWindowFactory.TitlebarCommand.addAction,
            .openLibrary,
            .openSetup,
            .openHistory,
        ] {
            NotificationCenter.default.post(
                name: WorkspaceWindowFactory.titlebarCommandNotification,
                object: command
            )
        }

        #expect(receivedCommands == [.addAction, .openLibrary, .openSetup, .openHistory])
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
    func everyWindowInheritsTheApplicationAppearance() {
        let windows: [NSWindow] = [
            WorkspaceWindowFactory.make(rootView: Color.clear, frameAutosaveName: nil),
            HistoryWindowFactory.make(rootView: Color.clear, frameAutosaveName: nil),
            SplashWindowController.makeWindow(contentRect: NSRect(x: 0, y: 0, width: 640, height: 480)),
            HUDPanelFactory.make(size: HUDLayout.panelSize),
        ]
        defer { windows.forEach { $0.close() } }

        let applicationAppearance = NSApplication.shared.effectiveAppearance
            .bestMatch(from: [.aqua, .darkAqua])
        for window in windows {
            #expect(window.appearance == nil)
            #expect(window.effectiveAppearance.bestMatch(from: [.aqua, .darkAqua]) == applicationAppearance)
        }
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
