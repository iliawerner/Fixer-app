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
}
