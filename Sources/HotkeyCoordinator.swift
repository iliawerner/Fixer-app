import Foundation
import KeyboardShortcuts

/// Owns the lifetime of global-shortcut handlers. Invariants a change here must
/// preserve:
///  * `bindAll()` MUST be called exactly once at app startup (from the
///    AppDelegate), so shortcuts are live on every cold start — independent of the
///    Settings window ever being opened.
///  * `KeyboardShortcuts.onKeyUp` *appends* handlers (it never replaces), so
///    `bind(...)` must stay idempotent per shortcut Name — hence the `registered`
///    set. Registering the same Name twice makes the action fire twice.
///  * The handler resolves the *current* action by id at fire time (never a
///    captured copy), so edits to the prompt/model/mode take effect without
///    re-binding.
@MainActor
final class HotkeyCoordinator {
    static let shared = HotkeyCoordinator()

    // One entry per shortcut Name we've registered a handler for. It only ever
    // grows: KeyboardShortcuts has no "remove handler" API, so a Name is single-
    // use — a fresh UUID is minted per action and must never be reused.
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
        // `reset` erases the user's recorded key combo from UserDefaults. That is
        // correct on delete, but must never be called for a mere disable (see
        // `setEnabled`) — that would silently wipe the shortcut the user recorded.
        KeyboardShortcuts.disable(name)
        KeyboardShortcuts.reset(name)
    }
}

/// The subset of `HotkeyCoordinator` that `SettingsManager` drives. Extracted as a
/// protocol so tests can inject a no-op fake instead of registering real global
/// shortcuts (which need a login session).
@MainActor
protocol HotkeyBinding {
    func bind(name: KeyboardShortcuts.Name, actionID: UUID)
    func unbind(name: KeyboardShortcuts.Name)
    func setEnabled(_ enabled: Bool, name: KeyboardShortcuts.Name)
}

extension HotkeyCoordinator: HotkeyBinding {}
