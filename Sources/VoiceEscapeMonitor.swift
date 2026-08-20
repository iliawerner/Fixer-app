import AppKit

/// Observes Escape while a voice recording is cancellable without activating
/// Fixer or consuming the event from the user's current application.
@MainActor
final class VoiceEscapeMonitor {
    private var globalMonitor: Any?
    private var localMonitor: Any?

    func start(onEscape: @escaping @MainActor () -> Void) {
        stop()

        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { event in
            guard event.keyCode == 53, !event.isARepeat else { return }
            Task { @MainActor in onEscape() }
        }
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            if event.keyCode == 53, !event.isARepeat {
                Task { @MainActor in onEscape() }
            }
            // Monitoring must not change the active app's own Escape behavior.
            return event
        }
    }

    func stop() {
        if let globalMonitor {
            NSEvent.removeMonitor(globalMonitor)
            self.globalMonitor = nil
        }
        if let localMonitor {
            NSEvent.removeMonitor(localMonitor)
            self.localMonitor = nil
        }
    }

    // VoiceActionRunner is process-scoped and calls `stop()` on every terminal
    // path. Avoid touching main-actor monitor state from a nonisolated deinit;
    // AppKit also removes any remaining process monitors when Fixer exits.
}
