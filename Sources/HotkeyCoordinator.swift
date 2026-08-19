import Foundation
import KeyboardShortcuts

/// Owns the lifetime of global-shortcut handlers. Invariants a change here must
/// preserve:
///
/// - Startup binds saved actions independently of whether the workspace opens.
/// - `KeyboardShortcuts.onKeyUp` appends handlers rather than replacing them, so
///   `bind(...)` must remain idempotent for each shortcut name.
/// - The package has no handler-removal API. Shortcut names are single-use and a
///   newly created or duplicated action must receive a fresh UUID-based name.
/// - A handler resolves the *current* action by id at fire time rather than a
///   captured copy, so edits to the prompt/model/mode take effect without
///   re-binding.
/// - KeyboardShortcuts registers physical combinations globally, not per Name.
///   Reconciliation therefore clears all saved Names before restoring the
///   unique enabled set; changing one duplicate must not strand another action.
@MainActor
final class HotkeyCoordinator {
    // MARK: - Shared coordinator and handler lifetime

    static let shared = HotkeyCoordinator()

    // One entry per shortcut Name we've registered a handler for. It only ever
    // grows: KeyboardShortcuts has no "remove handler" API, so a Name is single-
    // use — a fresh UUID is minted per action and must never be reused.
    private var registered = Set<String>()

    private init() {}

    /// Registers handlers for the actions loaded at process startup.
    ///
    /// Reconciliation is deliberately part of startup: `onKeyUp` registers a
    /// saved combination as a side effect, including combinations belonging to
    /// disabled actions.
    func bindAll() {
        reconcile(actions: SettingsManager.shared.actions)
    }

    /// Registers one permanent callback for a never-reused shortcut name.
    private func bind(name: KeyboardShortcuts.Name, actionID: UUID) {
        let key = name.rawValue
        guard !registered.contains(key) else { return }
        registered.insert(key)

        KeyboardShortcuts.onKeyUp(for: name) {
            // KeyboardShortcuts invokes this on the main thread; hop onto the
            // main actor explicitly to satisfy isolation and resolve live state.
            Task { @MainActor in
                guard let current = HotkeyRunPolicy.runnableAction(
                    actionID: actionID,
                    actions: SettingsManager.shared.actions,
                    shortcutFor: KeyboardShortcuts.getShortcut
                ) else { return }
                ActionRunner.shared.run(action: current)
            }
        }
    }

    /// Restores package registration from the complete current Action snapshot.
    ///
    /// KeyboardShortcuts tracks one Carbon registration per physical shortcut.
    /// Its Recorder first unregisters a Name's old combination, which also
    /// removes that combination for any other Name sharing it. Disabling all
    /// saved Names before enabling only unique enabled combinations gives us a
    /// deterministic package state after recording, enabling, disabling, or
    /// deleting.
    func reconcile(actions: [MacroAction]) {
        for action in actions {
            bind(name: action.shortcutName, actionID: action.id)
        }

        KeyboardShortcuts.disable(actions.map(\.shortcutName))
        KeyboardShortcuts.enable(
            HotkeyRegistrationPolicy.namesToEnable(
                actions: actions,
                shortcutFor: KeyboardShortcuts.getShortcut
            )
        )
    }

    /// Disables and resets a deleted action's recorded key.
    ///
    /// The underlying callback remains registered in memory because the package
    /// cannot remove it; the shortcut name must never be assigned to another
    /// action in the same process.
    func unbind(name: KeyboardShortcuts.Name) {
        // `reset` erases the user's recorded key combo from UserDefaults. That is
        // correct on delete, but must never be called for a mere disable — that
        // would silently wipe the shortcut the user recorded.
        KeyboardShortcuts.disable(name)
        KeyboardShortcuts.reset(name)
    }
}

/// The subset of `HotkeyCoordinator` that `SettingsManager` drives. Extracted as a
/// protocol so tests can inject a no-op fake instead of registering real global
/// shortcuts (which need a login session).
@MainActor
protocol HotkeyBinding {
    func unbind(name: KeyboardShortcuts.Name)
    func reconcile(actions: [MacroAction])
}

extension HotkeyCoordinator: HotkeyBinding {}

/// One source of truth for whether a saved Action has a usable shortcut.
///
/// Views, setup readiness, Carbon registration, and the fire-time guard must all
/// agree that only *enabled* Actions participate in an internal conflict.
enum ActionShortcutPolicy {
    static func conflictingAction(
        for action: MacroAction,
        actions: [MacroAction],
        shortcutFor: (KeyboardShortcuts.Name) -> KeyboardShortcuts.Shortcut?
    ) -> MacroAction? {
        guard action.isEnabled,
              let shortcut = shortcutFor(action.shortcutName) else { return nil }

        return actions.first { candidate in
            candidate.id != action.id
                && candidate.isEnabled
                && shortcutFor(candidate.shortcutName) == shortcut
        }
    }

    static func isRunnable(
        _ action: MacroAction,
        actions: [MacroAction],
        shortcutFor: (KeyboardShortcuts.Name) -> KeyboardShortcuts.Shortcut?
    ) -> Bool {
        action.isEnabled
            && shortcutFor(action.shortcutName) != nil
            && conflictingAction(
                for: action,
                actions: actions,
                shortcutFor: shortcutFor
            ) == nil
    }

    static func hasRunnableAction(
        actions: [MacroAction],
        shortcutFor: (KeyboardShortcuts.Name) -> KeyboardShortcuts.Shortcut?
    ) -> Bool {
        actions.contains { action in
            isRunnable(action, actions: actions, shortcutFor: shortcutFor)
        }
    }
}

/// Selects only physically unique, enabled combinations for Carbon registration.
/// Conflicting Actions remain saved and visible in the editor, but the package
/// receives no live registration until the user resolves the conflict.
enum HotkeyRegistrationPolicy {
    static func namesToEnable(
        actions: [MacroAction],
        shortcutFor: (KeyboardShortcuts.Name) -> KeyboardShortcuts.Shortcut?
    ) -> [KeyboardShortcuts.Name] {
        actions.compactMap { action in
            ActionShortcutPolicy.isRunnable(
                action,
                actions: actions,
                shortcutFor: shortcutFor
            ) ? action.shortcutName : nil
        }
    }
}

/// Pure fire-time eligibility policy, kept separate from Carbon registration so
/// duplicate and nil-shortcut behavior can be unit-tested without installing a
/// real global shortcut.
enum HotkeyRunPolicy {
    static func runnableAction(
        actionID: UUID,
        actions: [MacroAction],
        shortcutFor: (KeyboardShortcuts.Name) -> KeyboardShortcuts.Shortcut?
    ) -> MacroAction? {
        guard let action = actions.first(where: { $0.id == actionID }),
              ActionShortcutPolicy.isRunnable(
                action,
                actions: actions,
                shortcutFor: shortcutFor
              ) else { return nil }
        return action
    }
}
