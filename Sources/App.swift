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

/// Menu-bar glyph. The repair mark turns signal yellow while an action runs.
///
/// In a `MenuBarExtra` label, a SwiftUI `Image(...).resizable()` loses its
/// intrinsic size, and the status item then measures to zero width and renders
/// nothing at all (no visible icon — the item is simply absent). The reliable
/// pattern is an `NSImage` with an explicit `.size` (which gives a real
/// intrinsic size, so no `.resizable()` is needed) and `.isTemplate` set per
/// state: idle is a template (auto-tinted for light/dark menu bars), the active
/// state keeps its signal color so progress remains visible without a toast.
struct MenuBarLabel: View {
    @ObservedObject private var appState = AppState.shared
    var body: some View {
        Image(nsImage: MenuBarLabel.glyph(active: appState.isProcessing))
            // The bundled NSImage is visual-only; expose both identity and live
            // status so VoiceOver users can find the menu-bar entry reliably.
            .accessibilityLabel(Text(verbatim: "Fixer"))
            .accessibilityValue(
                Text(verbatim: appState.isProcessing ? "Processing an action" : "Idle")
            )
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
            Text("Working\(appState.processingActionName.map { ": \($0)" } ?? "…")")
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

        Button("Open Fixer…") {
            AppDelegate.shared?.openSettings()
        }
        .keyboardShortcut(",", modifiers: .command)
        .disabled(appState.isProcessing)

        Button("History…") {
            AppDelegate.shared?.openHistory()
        }
        .keyboardShortcut("h", modifiers: [.command, .shift])

        Button("Show Splash…") {
            AppDelegate.shared?.showSplash()
        }
        .disabled(appState.isProcessing)

        Divider()

        // Termination is blocked while Fixer owns the pasteboard lifecycle; quitting
        // between synthetic copy and restore could strand temporary clipboard data.
        Button("Quit Fixer") {
            NSApplication.shared.terminate(nil)
        }
        .keyboardShortcut("q", modifiers: .command)
        .disabled(appState.isProcessing)
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    static private(set) var shared: AppDelegate?

    private var settingsWindow: NSWindow?
    private var historyWindow: NSWindow?
    private var splashController: SplashWindowController?
    private var permissionTimer: Timer?
    private var deferredFirstLaunchTask: Task<Void, Never>?
    private var isolatedQAContext: IsolatedQAContext?

    func applicationDidFinishLaunching(_ notification: Notification) {
        AppDelegate.shared = self

        // The unit tests are hosted in this app, which launches the whole thing.
        // Skip startup side effects (global hotkeys, permission prompt, opening the
        // window) so the test run doesn't register real shortcuts or nag the user.
        if PersistenceEnvironment.isTesting { return }

        do {
            try HistoryMaintenance.applyRetention(
                history: HistoryStore.shared,
                preferences: HistoryPreferences.shared
            )
        } catch {
            AppState.shared.lastError = "History cleanup could not finish: \(error.localizedDescription)"
        }

        // An explicit isolated data directory uses the real workspace with
        // in-memory credentials, inert shortcuts, and an offline retry handler.
        if PersistenceEnvironment.qaDirectory != nil {
            Fixer.registerFonts()
            AppState.shared.accessibilityGranted = true
            openSettings()
            return
        }

        // Register the bundled Archivo Narrow display font before any UI renders.
        Fixer.registerFonts()

        // Register global hotkeys at launch — independent of the Settings window,
        // so shortcuts work immediately on every cold start.
        _ = SettingsManager.shared
        HotkeyCoordinator.shared.bindAll()

        let shouldShowFirstLaunch = SplashPolicy.shouldShowFirstLaunch()

        // Accessibility permission gate. On a new v2 install, defer the system
        // prompt until after the identity animation so it cannot cover the splash.
        AppState.shared.refreshAccessibility()
        if !AppState.shared.accessibilityGranted && !shouldShowFirstLaunch {
            PermissionsManager.promptForAccessibility()
        }
        startPermissionMonitoring()

        // Always show something on launch. New v2 users see the identity motion
        // once; subsequent launches open the workspace directly.
        // (LSUIElement) app with no Dock icon, so a launch that doesn't show
        // anything reads as "nothing happened" — every double-click of the
        // .app should visibly do something.
        if shouldShowFirstLaunch {
            showSplash(openSettingsAfter: true)
        } else {
            openSettings()
        }
    }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        AppState.shared.isProcessing ? .terminateCancel : .terminateNow
    }

    /// Called when the user double-clicks the .app (or clicks its Dock icon)
    /// while it's already running. Without this, reactivating an already-running
    /// LSUIElement app is a silent no-op — there's no window to bring forward and
    /// no Dock bounce, so nothing visible happens. Surface the workspace instead.
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        guard AppPresentationPolicy.mayActivateFixer(
            isProcessing: AppState.shared.isProcessing
        ) else { return false }

        if let splashController, splashController.isVisible {
            NSApp.activate(ignoringOtherApps: true)
            splashController.bringToFront()
            return false
        }
        openSettings()
        return false
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
        guard AppPresentationPolicy.mayActivateFixer(
            isProcessing: AppState.shared.isProcessing
        ) else { return }

        NSApp.activate(ignoringOtherApps: true)

        if let window = settingsWindow {
            WorkspaceWindowFactory.present(window)
            return
        }

        let rootView: SettingsView
        let isIsolated = PersistenceEnvironment.qaDirectory != nil
        if isIsolated {
            let context = qaContext()
            rootView = SettingsView(
                settings: context.settings,
                provider: context.provider,
                historyPreferences: HistoryPreferences.shared,
                refreshAccessibilityOnAppear: false,
                allowsActionEditing: false
            )
        } else {
            rootView = SettingsView()
        }
        let window = WorkspaceWindowFactory.make(
            rootView: rootView,
            frameAutosaveName: isIsolated ? nil : WorkspaceWindowMetrics.autosaveName
        )
        settingsWindow = window
        WorkspaceWindowFactory.present(window)
    }

    /// Explicit access stays available while processing. The delivery service
    /// checks the original field before paste and preserves changed-target output.
    @MainActor
    func openHistory() {
        NSApp.activate(ignoringOtherApps: true)
        if let historyWindow {
            WorkspaceWindowFactory.present(historyWindow)
            return
        }
        let isIsolated = PersistenceEnvironment.qaDirectory != nil
        let window = HistoryWindowFactory.make(
            rootView: HistoryView(
                history: HistoryStore.shared,
                appState: AppState.shared,
                onRetry: { [weak self] entry in
                    if isIsolated {
                        self?.qaContext().retry.retry(entry)
                    } else {
                        HistoryRetryController.shared.retry(entry)
                    }
                }
            ),
            frameAutosaveName: isIsolated ? nil : "FixerHistory"
        )
        historyWindow = window
        WorkspaceWindowFactory.present(window)
    }

    @MainActor
    private func qaContext() -> IsolatedQAContext {
        if let isolatedQAContext { return isolatedQAContext }
        let context = IsolatedQAContext(history: HistoryStore.shared, state: AppState.shared)
        isolatedQAContext = context
        return context
    }

    /// Replays the approved layered identity. First launch auto-completes into
    /// the workspace; a manual replay stays open until the user closes it.
    @MainActor
    func showSplash(openSettingsAfter: Bool = false) {
        guard AppPresentationPolicy.mayActivateFixer(
            isProcessing: AppState.shared.isProcessing
        ) else { return }

        NSApp.activate(ignoringOtherApps: true)

        if let splashController, splashController.isVisible {
            splashController.bringToFront()
            return
        }

        let controller = SplashWindowController(
            openSettingsAfter: openSettingsAfter
        ) { [weak self] shouldOpenSettings in
            self?.splashDidDismiss(openSettingsAfter: shouldOpenSettings)
        }
        splashController = controller
        controller.show()
    }

    @MainActor
    private func splashDidDismiss(openSettingsAfter: Bool) {
        splashController = nil

        if openSettingsAfter {
            SplashPolicy.markSeen()
            finishFirstLaunchWhenIdle()
        }
    }

    @MainActor
    private func finishFirstLaunchWhenIdle() {
        deferredFirstLaunchTask?.cancel()

        guard !AppState.shared.isProcessing else {
            deferredFirstLaunchTask = Task { @MainActor [weak self] in
                while AppState.shared.isProcessing {
                    do {
                        try await Task.sleep(nanoseconds: 100_000_000)
                    } catch {
                        return
                    }
                }
                guard !Task.isCancelled else { return }
                guard let self else { return }
                self.deferredFirstLaunchTask = nil
                self.finishFirstLaunchWhenIdle()
            }
            return
        }

        deferredFirstLaunchTask = nil
        openSettings()
        if !AppState.shared.accessibilityGranted {
            PermissionsManager.promptForAccessibility()
        }
    }
}
