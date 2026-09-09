import Foundation
import SwiftUI
import KeyboardShortcuts

/// Main-actor store for the user's actions and their shortcut lifecycle.
///
/// The action array is persisted as one JSON value in UserDefaults after every
/// mutation. Creation, duplication, deletion, Recorder changes, and enabled-state
/// changes are also reconciled through `HotkeyBinding`, keeping persistence and
/// global-shortcut state in one ownership boundary.
@MainActor
final class SettingsManager: ObservableObject {
    // MARK: - Shared store

    static let shared = SettingsManager(defaults: PersistenceEnvironment.sharedDefaults)

    /// The source of truth for saved actions. Mutations, including edits through
    /// a binding to an array element, trigger immediate JSON persistence.
    @Published var actions: [MacroAction] = [] {
        didSet { if !isLoading { saveActions() } }
    }

    /// Recovery stays visible across launches until the user dismisses it. Raw
    /// damaged snapshots remain available even after subsequent library edits.
    @Published private(set) var recoveryMessage: String?

    // MARK: - Dependencies and persistence identity

    private let defaults: UserDefaults
    /// Compatibility key inside the app's pinned UserDefaults domain.
    private let actionsKey = "savedActions"
    private let backupKey = "savedActions.lastGoodBackup"
    private let corruptBackupsKey = "savedActions.corruptBackups"
    private let recoveryMessageKey = "savedActions.recoveryMessage"
    private let hotkeys: HotkeyBinding
    private var isLoading = true

    /// Creates an action store and immediately loads its persisted snapshot.
    ///
    /// - Parameters:
    ///   - defaults: persistence store (inject `UserDefaults(suiteName:)` in tests).
    ///   - hotkeys: the shortcut binder (inject a fake in tests so no real global
    ///     shortcuts are registered).
    init(defaults: UserDefaults = .standard, hotkeys: HotkeyBinding? = nil) {
        self.defaults = defaults
        self.hotkeys = hotkeys ?? HotkeyCoordinator.shared
        loadActions()
    }

    // MARK: - Mutations

    /// Adds a blank action, reconciles its fresh shortcut identity, and returns
    /// the action id so the workspace can select it.
    @discardableResult
    func addAction() -> UUID {
        // Each action gets a brand-new random shortcut Name. These are single-use
        // (see HotkeyCoordinator): a Name is never reused, so a fresh UUID here — in
        // addStarter and duplicate too — avoids colliding with a retired handler.
        let newName = KeyboardShortcuts.Name(UUID().uuidString)
        let action = MacroAction(name: "New action", shortcutName: newName)
        actions.append(action)
        hotkeys.reconcile(actions: actions)
        return action.id
    }

    /// Copies a curated starter into the user's persistent action collection.
    @discardableResult
    func addStarter(_ starter: StarterAction) -> UUID {
        let newName = KeyboardShortcuts.Name(UUID().uuidString)
        let action = MacroAction(name: starter.name,
                                 shortcutName: newName,
                                 promptTemplate: starter.prompt,
                                 modelName: defaultModelName,
                                 outputMode: starter.mode)
        actions.append(action)
        hotkeys.reconcile(actions: actions)
        return action.id
    }

    /// Duplicates an action's editable fields while assigning new action and
    /// shortcut identities.
    @discardableResult
    func duplicate(id: UUID) -> UUID? {
        guard let source = actions.first(where: { $0.id == id }),
              source.kind == .text else { return nil }
        let newName = KeyboardShortcuts.Name(UUID().uuidString)
        let copy = MacroAction(name: source.name + " copy",
                               shortcutName: newName,
                               promptTemplate: source.promptTemplate,
                               modelName: source.modelName,
                               outputMode: source.outputMode,
                               isEnabled: source.isEnabled)
        actions.append(copy)
        hotkeys.reconcile(actions: actions)
        return copy.id
    }

    /// Deletes an action and retires its shortcut identity before removing the
    /// persisted value.
    func deleteAction(id: UUID) {
        guard let index = actions.firstIndex(where: { $0.id == id }),
              actions[index].kind == .text else { return }
        hotkeys.unbind(name: actions[index].shortcutName)
        actions.remove(at: index)
        // `reset` unregisters the physical combination even when another saved
        // Name shares it, so restore the surviving Actions immediately.
        hotkeys.reconcile(actions: actions)
    }

    /// Enables or disables delivery without erasing the user's recorded key.
    func setEnabled(_ enabled: Bool, id: UUID) {
        guard let index = actions.firstIndex(where: { $0.id == id }) else { return }
        actions[index].isEnabled = enabled
        hotkeys.reconcile(actions: actions)
    }

    /// Updates the one process-wide voice gesture stored by the built-in
    /// Dictation Action. Voice-enabled text Actions read this setting at fire
    /// time, so no shortcut handler needs to be rebound when it changes.
    func setVoiceActivationMode(_ mode: VoiceActivationMode) {
        guard let index = actions.firstIndex(where: { $0.kind == .dictation }) else {
            return
        }
        actions[index].voiceActivationMode = mode
    }

    var voiceActivationMode: VoiceActivationMode {
        actions.first(where: { $0.kind == .dictation })?.voiceActivationMode ?? .toggle
    }

    /// Reconciles the complete shortcut set after KeyboardShortcuts.Recorder has
    /// already persisted its change in the package's UserDefaults namespace.
    /// The UI calls this ownership boundary instead of reaching for the global
    /// coordinator directly.
    func reconcileShortcuts() {
        hotkeys.reconcile(actions: actions)
    }

    // MARK: - Persistence

    private func saveActions() {
        do {
            let encoded = try JSONEncoder().encode(actions)
            defaults.set(encoded, forKey: actionsKey)
            // A separate, validated snapshot survives a malformed primary value.
            defaults.set(encoded, forKey: backupKey)
        } catch {
            setRecoveryMessage("Fixer could not save Actions. The previous saved library was preserved. \(error.localizedDescription)")
        }
    }

    private func loadActions() {
        recoveryMessage = defaults.string(forKey: recoveryMessageKey)
        defer { isLoading = false }
        // Older builds have no Dictation entry. Normalize every decoded snapshot
        // through one migration seam so the permanent Action appears exactly once
        // and always remains pinned first without touching the user's text Actions.
        guard let stored = defaults.object(forKey: actionsKey) else {
            actions = Self.initialActions()
            saveActions()
            return
        }

        if let data = stored as? Data {
            if let decoded = try? JSONDecoder().decode([MacroAction].self, from: data) {
                restoreActions(decoded, originalData: data)
                return
            }
            preserveCorruptSnapshot(data)
            // Decode array members separately. One scalar or truncated action
            // must not discard unrelated, valid Actions from the same snapshot.
            if let objects = try? JSONSerialization.jsonObject(with: data) as? [Any] {
                let recovered = objects.compactMap { object -> MacroAction? in
                    guard JSONSerialization.isValidJSONObject(object),
                          let fragment = try? JSONSerialization.data(withJSONObject: object) else { return nil }
                    return try? JSONDecoder().decode(MacroAction.self, from: fragment)
                }
                if !recovered.isEmpty {
                    restoreActions(recovered, originalData: data,
                                   recoveryNote: "Recovered \(recovered.count) Actions from a damaged library. \(objects.count - recovered.count) unreadable item(s) were skipped. The original data was backed up.")
                    return
                }
            }
        } else {
            // UserDefaults can contain a value of the wrong type. Keep that
            // property-list payload too, rather than overwriting the only copy.
            if let data = try? PropertyListSerialization.data(fromPropertyList: stored,
                                                              format: .binary, options: 0) {
                preserveCorruptSnapshot(data)
            }
        }

        if let backup = defaults.data(forKey: backupKey),
           let recovered = try? JSONDecoder().decode([MacroAction].self, from: backup) {
            restoreActions(recovered, originalData: backup,
                           recoveryNote: "The Actions library was damaged. Fixer restored the last good backup and preserved the damaged original.")
        } else {
            actions = [MacroAction.dictation()]
            setRecoveryMessage("The Actions library could not be read. Its original data was preserved for recovery. Your saved library has not been replaced with starter Actions.")
            // Do not replace an unreadable primary with starter Actions. A later
            // explicit user edit may save a new library; the raw backup survives.
        }
    }

    func dismissRecoveryMessage() {
        recoveryMessage = nil
        defaults.removeObject(forKey: recoveryMessageKey)
    }

    private func setRecoveryMessage(_ message: String) {
        recoveryMessage = message
        defaults.set(message, forKey: recoveryMessageKey)
    }

    private func restoreActions(_ decoded: [MacroAction], originalData: Data, recoveryNote: String? = nil) {
        let normalized = Self.normalize(decoded)
        if recoveryNote != nil || normalized.repairedIdentities,
           let previousBackup = defaults.data(forKey: backupKey), previousBackup != originalData,
           (try? JSONDecoder().decode([MacroAction].self, from: previousBackup)) != nil {
            // A partial recovery may omit an unreadable member that still exists
            // in the prior backup. Archive that backup before saveActions replaces
            // it; do not silently discard it or resurrect deleted Actions.
            preserveCorruptSnapshot(previousBackup)
        }
        actions = normalized.actions
        var notices = recoveryNote.map { [$0] } ?? []
        if normalized.repairedIdentities {
            preserveCorruptSnapshot(originalData)
            notices.append("Duplicate Action identities were repaired. Exact duplicates were removed; differing Actions were kept. Recovered Actions with new shortcut identities need their shortcuts set again. The original library was backed up.")
        }
        if !notices.isEmpty { setRecoveryMessage(notices.joined(separator: " ")) }
        saveActions()
    }

    private func preserveCorruptSnapshot(_ data: Data) {
        var snapshots = defaults.array(forKey: corruptBackupsKey) as? [Data] ?? []
        guard !snapshots.contains(data) else { return }
        snapshots.append(data)
        defaults.set(snapshots, forKey: corruptBackupsKey)
    }

    private static func initialActions() -> [MacroAction] {
        let action = MacroAction(name: "Fix grammar",
                                 shortcutName: KeyboardShortcuts.Name("defaultAction"),
                                 promptTemplate: "Fix grammar and make it sound simple and natural: {text}. Return only the corrected text.",
                                 modelName: defaultModelName,
                                 outputMode: .replace)
        return [MacroAction.dictation(), action]
    }

    nonisolated static func normalizedActions(_ decoded: [MacroAction]) -> [MacroAction] {
        normalize(decoded).actions
    }

    /// Repair identity conflicts without conflating independently created Actions
    /// that happen to have the same text. New identities are deliberately unbound
    /// so a recovered variant cannot silently inherit another Action's hotkey.
    nonisolated private static func normalize(_ decoded: [MacroAction]) -> (actions: [MacroAction], repairedIdentities: Bool) {
        let persistedDictation = decoded.first {
            $0.kind == .dictation || $0.id == MacroAction.dictationID
        }
        let dictation = MacroAction.dictation(
            isEnabled: persistedDictation?.isEnabled ?? true,
            activationMode: persistedDictation?.voiceActivationMode ?? .toggle
        )
        let textCandidates = decoded.filter {
            $0.kind == .text && $0.id != MacroAction.dictationID
        }
        var repairedIdentities = decoded.count - textCandidates.count > 1
        var result = [dictation]
        var originalVariants: [UUID: [MacroAction]] = [:]
        var usedIDs: Set<UUID> = [dictation.id]
        var usedNames: Set<String> = [dictation.shortcutName.rawValue]
        var reservedIDs = Set(decoded.map(\.id))
        reservedIDs.insert(dictation.id)
        var reservedNames = Set(decoded.map { $0.shortcutName.rawValue })
        reservedNames.insert(dictation.shortcutName.rawValue)

        func freshID() -> UUID {
            var id = UUID()
            while reservedIDs.contains(id) { id = UUID() }
            reservedIDs.insert(id)
            return id
        }
        func freshShortcutName() -> KeyboardShortcuts.Name {
            var name = UUID().uuidString
            while reservedNames.contains(name) { name = UUID().uuidString }
            reservedNames.insert(name)
            return KeyboardShortcuts.Name(name)
        }

        for original in textCandidates {
            if originalVariants[original.id]?.contains(original) == true {
                repairedIdentities = true
                continue
            }
            originalVariants[original.id, default: []].append(original)
            var action = original
            if usedIDs.contains(action.id) {
                action.id = freshID()
                action.shortcutName = freshShortcutName()
                repairedIdentities = true
            } else if usedNames.contains(action.shortcutName.rawValue) {
                action.shortcutName = freshShortcutName()
                repairedIdentities = true
            }
            usedIDs.insert(action.id)
            usedNames.insert(action.shortcutName.rawValue)
            result.append(action)
        }
        return (result, repairedIdentities)
    }
}
