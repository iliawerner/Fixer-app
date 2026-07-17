import SwiftUI
import AppKit

@main
struct FixerApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        MenuBarExtra {
            MenuContent()
        } label: {
            MenuBarLabel()
        }
    }
}

/// Menu-bar glyph. The safelight glows red while an action is developing.
///
/// In a `MenuBarExtra` label, a SwiftUI `Image(...).resizable()` loses its
/// intrinsic size, and the status item then measures to zero width and renders
/// nothing at all (no visible icon — the item is simply absent). The reliable
/// pattern is an `NSImage` with an explicit `.size` (which gives a real
/// intrinsic size, so no `.resizable()` is needed) and `.isTemplate` set per
/// state: idle is a template (auto-tinted for light/dark menu bars), the active
/// state keeps its real red so the safelight reads while an action develops.
struct MenuBarLabel: View {
    @ObservedObject private var appState = AppState.shared
    var body: some View {
        Image(nsImage: MenuBarLabel.glyph(active: appState.isProcessing))
    }

    private static func glyph(active: Bool) -> NSImage {
        let name = active ? "MenuIconActive" : "MenuIcon"
        guard let base = NSImage(named: name), let copy = base.copy() as? NSImage else {
            // Fallback so the item is never zero-size / invisible.
            let fallback = NSImage(systemSymbolName: "sparkles", accessibilityDescription: "fixer") ?? NSImage()
            fallback.isTemplate = true
            return fallback
        }
        copy.size = NSSize(width: 18, height: 18)
        copy.isTemplate = !active
        return copy
    }
}

struct MenuContent: View {
    @ObservedObject private var appState = AppState.shared

    var body: some View {
        if appState.isProcessing {
            Text("Developing…")
            Divider()
        }

        if !appState.accessibilityGranted {
            Button("⚠ Enable Accessibility Permission…") {
                PermissionsManager.promptForAccessibility()
                PermissionsManager.openAccessibilitySettings()
            }
            Divider()
        }

        if let error = appState.lastError, !appState.isProcessing {
            Text("Last error: \(error)")
                .font(.caption)
            Divider()
        }

        Button("Darkroom…") {
            AppDelegate.shared?.openSettings()
        }
        .keyboardShortcut(",", modifiers: .command)

        Divider()

        Button("Quit fixer") {
            NSApplication.shared.terminate(nil)
        }
        .keyboardShortcut("q", modifiers: .command)
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    static private(set) var shared: AppDelegate?

    private var settingsWindow: NSWindow?
    private var permissionTimer: Timer?

    func applicationDidFinishLaunching(_ notification: Notification) {
        AppDelegate.shared = self

        // Register the bundled Archivo Narrow display font before any UI renders.
        Fixer.registerFonts()

        // Register global hotkeys at launch — independent of the Settings window,
        // so shortcuts work immediately on every cold start.
        _ = SettingsManager.shared
        HotkeyCoordinator.shared.bindAll()

        // Accessibility permission gate.
        AppState.shared.refreshAccessibility()
        if !AppState.shared.accessibilityGranted {
            PermissionsManager.promptForAccessibility()
        }
        startPermissionMonitoring()

        // Always open the darkroom on launch. This is a menu-bar-only
        // (LSUIElement) app with no Dock icon, so a launch that doesn't show
        // anything reads as "nothing happened" — every double-click of the
        // .app should visibly do something.
        openSettings()
    }

    /// Called when the user double-clicks the .app (or clicks its Dock icon)
    /// while it's already running. Without this, reactivating an already-running
    /// LSUIElement app is a silent no-op — there's no window to bring forward and
    /// no Dock bounce, so nothing visible happens. Surface the darkroom instead.
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        openSettings()
        return true
    }

    private func startPermissionMonitoring() {
        // macOS sends no notification when the user grants Accessibility, so polling
        // is the only way to update the UI live. 2s feels responsive without waste.
        permissionTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { _ in
            Task { @MainActor in
                AppState.shared.refreshAccessibility()
            }
        }
    }

    @MainActor
    func openSettings() {
        NSApp.activate(ignoringOtherApps: true)

        if let window = settingsWindow {
            window.makeKeyAndOrderFront(nil)
            return
        }

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 560, height: 720),
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.title = "fixer"
        // Darkroom: near-black background, dark controls, transparent title bar
        // (real traffic lights kept).
        window.appearance = NSAppearance(named: .darkAqua)
        window.backgroundColor = Fixer.baseNS
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.isMovableByWindowBackground = true
        window.contentView = NSHostingView(rootView: SettingsView())
        window.center()
        window.setFrameAutosaveName("DarkroomWindow")
        // Keep the window object alive after it closes; reopening a released
        // NSWindow crashes (classic AppKit footgun with cached windows).
        window.isReleasedWhenClosed = false
        window.minSize = NSSize(width: 480, height: 560) // keep in sync with SettingsView's root .frame(minWidth:minHeight:)
        window.makeKeyAndOrderFront(nil)
        settingsWindow = window
    }
}
