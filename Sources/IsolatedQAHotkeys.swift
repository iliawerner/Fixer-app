import KeyboardShortcuts

/// An explicit FIXER_DATA_DIR launch must never register global shortcuts.
@MainActor
final class IsolatedQAHotkeys: HotkeyBinding {
    func unbind(name: KeyboardShortcuts.Name) {}
    func reconcile(actions: [MacroAction]) {}
}
