import Foundation

/// Live UI QA gets the real windows and stores with inert system/provider edges.
/// Nothing here reads Keychain, sends a request, registers a shortcut or pastes.
@MainActor
final class IsolatedQAContext {
    let settings: SettingsManager
    let provider: ProviderSetupController
    let retry: HistoryRetryController

    init(history: HistoryStore, state: AppState) {
        settings = SettingsManager(
            defaults: PersistenceEnvironment.sharedDefaults,
            hotkeys: IsolatedQAHotkeys()
        )
        provider = ProviderSetupController(
            keyStore: IsolatedQAKeyStore(),
            modelLoader: { [GeminiModel(name: defaultModelName, displayName: "Preview model")] }
        )
        retry = HistoryRetryController(
            history: history,
            state: state,
            transcribe: { _ in "This is an isolated audio recovery preview." },
            generate: { _, _ in "This is an isolated result preview. No provider request was sent." },
            deliver: { _ in .historyOnly }
        )
    }
}
