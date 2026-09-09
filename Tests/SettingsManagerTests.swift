import Testing
import Foundation
import KeyboardShortcuts
@testable import fixer

/// A no-op stand-in for HotkeyCoordinator so tests never register real global
/// shortcuts (which need a login session).
@MainActor
final class FakeHotkeyBinding: HotkeyBinding {
    private(set) var unbound: [String] = []
    private(set) var reconciledActions: [[MacroAction]] = []

    func unbind(name: KeyboardShortcuts.Name) {
        unbound.append(name.rawValue)
    }

    func reconcile(actions: [MacroAction]) {
        reconciledActions.append(actions)
    }
}

@MainActor
struct SettingsManagerTests {

    /// A private, empty UserDefaults suite so tests don't touch real preferences.
    private func freshDefaults() -> UserDefaults {
        let suite = "fixer-test-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        return defaults
    }

    @Test func seedsDefaultActionOnFirstLaunch() {
        let mgr = SettingsManager(defaults: freshDefaults(), hotkeys: FakeHotkeyBinding())
        #expect(mgr.actions.count == 2)
        #expect(mgr.actions[0].kind == .dictation)
        #expect(mgr.actions[0].id == MacroAction.dictationID)
        #expect(mgr.actions[1].name == "Fix grammar")
    }

    @Test func persistsAcrossInstances() {
        let defaults = freshDefaults()
        let mgr = SettingsManager(defaults: defaults, hotkeys: FakeHotkeyBinding())
        mgr.addAction()
        #expect(mgr.actions.count == 3)

        let reloaded = SettingsManager(defaults: defaults, hotkeys: FakeHotkeyBinding())
        #expect(reloaded.actions.count == 3)
        #expect(reloaded.actions.first?.kind == .dictation)
    }

    @Test func duplicateGetsNewIDNameAndShortcut() {
        let mgr = SettingsManager(defaults: freshDefaults(), hotkeys: FakeHotkeyBinding())
        let srcID = mgr.actions[1].id

        let newID = mgr.duplicate(id: srcID)

        #expect(newID != nil)
        #expect(newID != srcID)
        #expect(mgr.actions.count == 3)
        #expect(mgr.actions[2].name == "Fix grammar copy")
        #expect(mgr.actions[2].shortcutName.rawValue != mgr.actions[1].shortcutName.rawValue)
    }

    @Test func deletingEveryTextActionKeepsPermanentDictationOnReload() {
        let defaults = freshDefaults()
        let mgr = SettingsManager(defaults: defaults, hotkeys: FakeHotkeyBinding())
        for action in mgr.actions { mgr.deleteAction(id: action.id) }
        #expect(mgr.actions.map(\.kind) == [.dictation])

        let reloaded = SettingsManager(defaults: defaults, hotkeys: FakeHotkeyBinding())
        #expect(reloaded.actions.count == 1)
        #expect(reloaded.actions[0].kind == .dictation)
    }

    @Test func addingAnActionReconcilesTheCompleteSnapshot() throws {
        let fake = FakeHotkeyBinding()
        let mgr = SettingsManager(defaults: freshDefaults(), hotkeys: fake)
        let newID = mgr.addAction()

        let snapshot = try #require(fake.reconciledActions.last)
        #expect(snapshot.count == 3)
        #expect(snapshot.contains { $0.id == newID })
    }

    @Test func recorderChangeReconcilesWithoutUsingTheGlobalCoordinator() throws {
        let fake = FakeHotkeyBinding()
        let mgr = SettingsManager(defaults: freshDefaults(), hotkeys: fake)

        mgr.reconcileShortcuts()

        let snapshot = try #require(fake.reconciledActions.last)
        #expect(snapshot.map(\.id) == mgr.actions.map(\.id))
    }

    @Test func enabledStateReconcilesTheUpdatedAction() throws {
        let fake = FakeHotkeyBinding()
        let mgr = SettingsManager(defaults: freshDefaults(), hotkeys: fake)
        let id = try #require(mgr.actions.first(where: { $0.kind == .text })?.id)

        mgr.setEnabled(false, id: id)

        let snapshot = try #require(fake.reconciledActions.last)
        #expect(snapshot.first(where: { $0.id == id })?.isEnabled == false)
    }

    @Test func deletingReconcilesSurvivorsAfterRetiringTheName() throws {
        let fake = FakeHotkeyBinding()
        let mgr = SettingsManager(defaults: freshDefaults(), hotkeys: fake)
        let deletedAction = try #require(mgr.actions.first(where: { $0.kind == .text }))
        let deletedName = deletedAction.shortcutName.rawValue
        let survivorID = mgr.addAction()

        mgr.deleteAction(id: deletedAction.id)

        #expect(fake.unbound.contains(deletedName))
        let snapshot = try #require(fake.reconciledActions.last)
        #expect(snapshot.map(\.id) == [MacroAction.dictationID, survivorID])
    }

    @Test func legacySnapshotMigratesDictationExactlyOnceAndPinsItFirst() throws {
        let defaults = freshDefaults()
        let legacy = MacroAction(
            name: "Legacy",
            shortcutName: KeyboardShortcuts.Name("legacy")
        )
        defaults.set(try JSONEncoder().encode([legacy]), forKey: "savedActions")

        let manager = SettingsManager(defaults: defaults, hotkeys: FakeHotkeyBinding())

        #expect(manager.actions.map(\.kind) == [.dictation, .text])
        #expect(manager.actions[1].id == legacy.id)
        let reloaded = SettingsManager(defaults: defaults, hotkeys: FakeHotkeyBinding())
        #expect(reloaded.actions.filter { $0.kind == .dictation }.count == 1)
    }

    @Test func legacyEmptySnapshotAddsOnlyDictationWithoutReseedingTextActions() throws {
        let defaults = freshDefaults()
        defaults.set(try JSONEncoder().encode([MacroAction]()), forKey: "savedActions")

        let manager = SettingsManager(defaults: defaults, hotkeys: FakeHotkeyBinding())

        #expect(manager.actions.map(\.kind) == [.dictation])
    }

    @Test func permanentDictationCannotBeDeletedOrDuplicated() {
        let manager = SettingsManager(defaults: freshDefaults(), hotkeys: FakeHotkeyBinding())

        #expect(manager.duplicate(id: MacroAction.dictationID) == nil)
        manager.deleteAction(id: MacroAction.dictationID)

        #expect(manager.actions.first?.id == MacroAction.dictationID)
        #expect(manager.actions.count == 2)
    }

    @Test func dictationGesturePersistsAndAppliesAsGlobalVoiceSetting() {
        let defaults = freshDefaults()
        let manager = SettingsManager(defaults: defaults, hotkeys: FakeHotkeyBinding())

        manager.setVoiceActivationMode(.hold)

        #expect(manager.voiceActivationMode == .hold)
        let reloaded = SettingsManager(defaults: defaults, hotkeys: FakeHotkeyBinding())
        #expect(reloaded.voiceActivationMode == .hold)
    }

    @Test func corruptArrayMemberDoesNotDiscardValidActionsAndPreservesOriginal() throws {
        let defaults = freshDefaults()
        let action = MacroAction(name: "Preserve this", shortcutName: .init("keep-me"))
        let validObject = try JSONSerialization.jsonObject(with: JSONEncoder().encode(action))
        let damaged = try JSONSerialization.data(withJSONObject: [validObject, NSNull(), 42])
        defaults.set(damaged, forKey: "savedActions")

        let manager = SettingsManager(defaults: defaults, hotkeys: FakeHotkeyBinding())
        #expect(manager.actions.map(\.id) == [MacroAction.dictationID, action.id])
        #expect(manager.recoveryMessage?.contains("2 unreadable") == true)
        #expect((defaults.array(forKey: "savedActions.corruptBackups") as? [Data]) == [damaged])
        manager.addAction()
        #expect((defaults.array(forKey: "savedActions.corruptBackups") as? [Data]) == [damaged])
        #expect(SettingsManager(defaults: defaults, hotkeys: FakeHotkeyBinding()).actions.count == 3)
    }

    @Test func unreadableLibraryWithoutBackupIsNotOverwrittenOnLaunch() {
        let defaults = freshDefaults()
        let damaged = Data("truncated [{".utf8)
        defaults.set(damaged, forKey: "savedActions")

        let manager = SettingsManager(defaults: defaults, hotkeys: FakeHotkeyBinding())
        #expect(manager.actions.map(\.kind) == [.dictation])
        #expect(manager.recoveryMessage != nil)
        #expect(defaults.data(forKey: "savedActions") == damaged)
        #expect((defaults.array(forKey: "savedActions.corruptBackups") as? [Data]) == [damaged])

        _ = SettingsManager(defaults: defaults, hotkeys: FakeHotkeyBinding())
        #expect(defaults.data(forKey: "savedActions") == damaged)
        #expect((defaults.array(forKey: "savedActions.corruptBackups") as? [Data])?.count == 1)
    }

    @Test func restoresLastGoodBackupWhenPrimaryCannotBeParsed() throws {
        let defaults = freshDefaults()
        let original = SettingsManager(defaults: defaults, hotkeys: FakeHotkeyBinding())
        let newID = original.addAction()
        let index = try #require(original.actions.firstIndex { $0.id == newID })
        original.actions[index].name = "My custom action"
        original.actions[index].promptTemplate = "Do something specific with {text}"
        let damaged = Data("broken".utf8)
        defaults.set(damaged, forKey: "savedActions")

        let restored = SettingsManager(defaults: defaults, hotkeys: FakeHotkeyBinding())
        #expect(restored.actions == original.actions)
        #expect(restored.recoveryMessage?.contains("last good backup") == true)
        #expect((defaults.array(forKey: "savedActions.corruptBackups") as? [Data]) == [damaged])
        #expect(try JSONDecoder().decode([MacroAction].self, from: #require(defaults.data(forKey: "savedActions"))) == original.actions)
    }

    @Test func partialRecoveryArchivesLastGoodBackupBeforeReplacingIt() throws {
        let defaults = freshDefaults()
        let original = SettingsManager(defaults: defaults, hotkeys: FakeHotkeyBinding())
        let unreadableID = original.addAction()
        let backup = try #require(defaults.data(forKey: "savedActions.lastGoodBackup"))
        let object = try JSONSerialization.jsonObject(with: JSONEncoder().encode(original.actions[1]))
        let damaged = try JSONSerialization.data(withJSONObject: [object, NSNull()])
        defaults.set(damaged, forKey: "savedActions")

        let restored = SettingsManager(defaults: defaults, hotkeys: FakeHotkeyBinding())

        let archives = try #require(defaults.array(forKey: "savedActions.corruptBackups") as? [Data])
        #expect(archives.contains(damaged))
        #expect(archives.contains(backup))
        let preservedBackup = try JSONDecoder().decode([MacroAction].self, from: backup)
        #expect(preservedBackup.contains { $0.id == unreadableID })
        restored.addAction()
        #expect((defaults.array(forKey: "savedActions.corruptBackups") as? [Data])?.contains(backup) == true)
    }

    @Test func wrongTypeLibraryIsPreservedAndRecoveryNoticePersistsUntilDismissed() {
        let defaults = freshDefaults()
        defaults.set("unexpected string", forKey: "savedActions")
        let manager = SettingsManager(defaults: defaults, hotkeys: FakeHotkeyBinding())
        #expect(defaults.string(forKey: "savedActions") == "unexpected string")
        #expect((defaults.array(forKey: "savedActions.corruptBackups") as? [Data])?.isEmpty == false)
        manager.addAction()
        let reloaded = SettingsManager(defaults: defaults, hotkeys: FakeHotkeyBinding())
        #expect(reloaded.recoveryMessage != nil)
        reloaded.dismissRecoveryMessage()
        #expect(SettingsManager(defaults: defaults, hotkeys: FakeHotkeyBinding()).recoveryMessage == nil)
    }

    @Test func duplicateUUIDWithDifferentPromptsKeepsBothWithIndependentIdentities() throws {
        let defaults = freshDefaults()
        let first = MacroAction(name: "First", shortcutName: .init("first-identity"), promptTemplate: "First {text}")
        var variant = first
        variant.name = "Recovered variant"
        variant.promptTemplate = "Different {text}"
        let originalData = try JSONEncoder().encode([first, variant])
        defaults.set(originalData, forKey: "savedActions")

        let manager = SettingsManager(defaults: defaults, hotkeys: FakeHotkeyBinding())

        #expect(manager.actions.count == 3)
        #expect(manager.actions[1] == first)
        #expect(manager.actions[2].id != first.id)
        #expect(manager.actions[2].shortcutName.rawValue != first.shortcutName.rawValue)
        #expect(manager.actions[2].promptTemplate == variant.promptTemplate)
        #expect(manager.recoveryMessage?.contains("identities were repaired") == true)
        #expect((defaults.array(forKey: "savedActions.corruptBackups") as? [Data]) == [originalData])
        #expect(SettingsManager(defaults: defaults, hotkeys: FakeHotkeyBinding()).actions == manager.actions)
    }

    @Test func exactDuplicateOfSameIdentityIsRemovedWithoutLosingDifferentVariant() throws {
        let defaults = freshDefaults()
        let action = MacroAction(name: "Keep once", shortcutName: .init("same-identity"))
        var variant = action
        variant.promptTemplate = "A different prompt"
        defaults.set(try JSONEncoder().encode([action, action, variant, variant]), forKey: "savedActions")

        let manager = SettingsManager(defaults: defaults, hotkeys: FakeHotkeyBinding())

        #expect(manager.actions.count == 3)
        #expect(manager.actions[1] == action)
        #expect(manager.actions[2].promptTemplate == variant.promptTemplate)
        #expect(Set(manager.actions.map(\.id)).count == 3)
    }

    @Test func duplicateShortcutNamesAndReservedDictationNameAreRepaired() throws {
        let defaults = freshDefaults()
        let first = MacroAction(name: "First", shortcutName: .init("shared-name"))
        let second = MacroAction(name: "Second", shortcutName: .init("shared-name"))
        let reserved = MacroAction(name: "Reserved conflict", shortcutName: MacroAction.dictationShortcutName)
        defaults.set(try JSONEncoder().encode([first, second, reserved]), forKey: "savedActions")

        let manager = SettingsManager(defaults: defaults, hotkeys: FakeHotkeyBinding())

        #expect(manager.actions.count == 4)
        #expect(manager.actions[0].shortcutName == MacroAction.dictationShortcutName)
        #expect(manager.actions[1].shortcutName == first.shortcutName)
        #expect(manager.actions[2].id == second.id)
        #expect(manager.actions[3].id == reserved.id)
        #expect(Set(manager.actions.map { $0.shortcutName.rawValue }).count == 4)
        #expect(manager.recoveryMessage?.contains("shortcuts set again") == true)
    }

    @Test func independentIdentitiesWithIdenticalContentRemainSeparate() throws {
        let defaults = freshDefaults()
        let first = MacroAction(name: "Same content", shortcutName: .init("independent-one"))
        let second = MacroAction(name: "Same content", shortcutName: .init("independent-two"))
        defaults.set(try JSONEncoder().encode([first, second]), forKey: "savedActions")

        let manager = SettingsManager(defaults: defaults, hotkeys: FakeHotkeyBinding())

        #expect(manager.actions.map(\.id) == [MacroAction.dictationID, first.id, second.id])
        #expect(manager.recoveryMessage == nil)
        #expect(defaults.array(forKey: "savedActions.corruptBackups") == nil)
    }
}
