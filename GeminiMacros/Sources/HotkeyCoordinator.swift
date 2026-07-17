import Foundation
import KeyboardShortcuts

/// Owns the lifetime of global-shortcut handlers.
///
/// Two bugs this design fixes:
///  1. Handlers used to be registered only when the Settings window opened, so
///     hotkeys were dead after every launch. `bindAll()` is now called once at
///     app startup from the AppDelegate, independent of any window.
///  2. `KeyboardShortcuts.onKeyUp` *appends* handlers, so re-registering stacked
///     duplicates that each fired the action again. We register exactly one
///     handler per shortcut Name for the app's lifetime (tracked in `registered`)
///     and resolve the *current* action by id at fire time, so edits to the
///     prompt/model/mode always take effect without re-binding.
@MainActor
final class HotkeyCoordinator {
    static let shared = HotkeyCoordinator()

    private var registered = Set<String>()

    private init() {}

    func bindAll() {
        for action in SettingsManager.shared.actions {
            bind(name: action.shortcutName, actionID: action.id)
        }
    }

    func bind(name: KeyboardShortcuts.Name, actionID: UUID) {
        let key = name.rawValue
        guard !registered.contains(key) else { return }
        registered.insert(key)

        KeyboardShortcuts.onKeyUp(for: name) {
            // KeyboardShortcuts invokes this on the main thread; hop onto the
            // main actor explicitly to satisfy isolation and resolve live state.
            Task { @MainActor in
                guard let current = SettingsManager.shared.actions.first(where: { $0.id == actionID }),
                      current.isEnabled else { return }
                ActionRunner.shared.run(action: current)
            }
        }
    }

    func setEnabled(_ enabled: Bool, name: KeyboardShortcuts.Name) {
        if enabled {
            KeyboardShortcuts.enable(name)
        } else {
            KeyboardShortcuts.disable(name)
        }
    }

    func unbind(name: KeyboardShortcuts.Name) {
        KeyboardShortcuts.disable(name)
        KeyboardShortcuts.reset(name)
    }
}
