import Foundation
import SwiftUI

/// Main-actor model for credential editing and Gemini model discovery.
///
/// The Keychain remains the credential source of truth. Published values are the
/// workspace's presentation snapshot. Each validation request captures both the
/// key and a monotonically increasing revision, so an old response cannot
/// validate or overwrite state for a changed or removed credential.
@MainActor
final class ProviderSetupController: ObservableObject {
    // MARK: - Published setup state

    @Published private(set) var apiKey: String
    @Published private(set) var availableModels: [GeminiModel] = []
    @Published private(set) var isLoadingModels = false
    @Published private(set) var modelError: String?
    @Published private(set) var keyValidated = false
    @Published private(set) var hasStoredKey: Bool
    @Published private(set) var canRemoveKey: Bool

    // MARK: - Dependencies and request identity

    private let keyStore: any APIKeyStoring
    private let modelLoader: () async throws -> [GeminiModel]
    private var validationTask: Task<Void, Never>?
    private var keyRevision = 0

    /// Creates an isolated setup model from the current Keychain state.
    ///
    /// Inject both dependencies in tests to avoid the real Keychain and network.
    init(
        keyStore: any APIKeyStoring = KeychainManager.shared,
        modelLoader: @escaping () async throws -> [GeminiModel] = {
            try await GeminiAPI.shared.fetchModels()
        }
    ) {
        self.keyStore = keyStore
        self.modelLoader = modelLoader
        do {
            let storedKey = try keyStore.getAPIKey() ?? ""
            self.apiKey = storedKey
            self.hasStoredKey = !storedKey.isEmpty
            self.canRemoveKey = !storedKey.isEmpty
        } catch {
            self.apiKey = ""
            self.hasStoredKey = false
            self.canRemoveKey = true
            self.modelError = "Could not read key: \(error.localizedDescription). It may still be stored in Keychain."
        }
    }

    // MARK: - Credential mutations

    /// Persists a credential edit immediately and rolls the presentation state
    /// back if the Keychain operation fails.
    func updateAPIKey(_ newValue: String) {
        guard newValue != apiKey else { return }

        invalidateValidation(clearError: false)
        let previousValue = apiKey
        let previousStoredState = hasStoredKey
        let previousRemovalState = canRemoveKey

        do {
            if newValue.isEmpty {
                try keyStore.deleteAPIKey()
            } else {
                try keyStore.saveAPIKey(newValue)
            }
            apiKey = newValue
            hasStoredKey = !newValue.isEmpty
            canRemoveKey = !newValue.isEmpty
            modelError = nil
        } catch {
            apiKey = previousValue
            hasStoredKey = previousStoredState
            canRemoveKey = previousRemovalState
            let operation = newValue.isEmpty ? "remove" : "save"
            modelError = "Could not \(operation) key: \(error.localizedDescription)"
        }
    }

    /// Removes the credential even when a previous Keychain read failed and the
    /// UI cannot display the retained value.
    func removeKey() {
        invalidateValidation(clearError: false)

        do {
            try keyStore.deleteAPIKey()
            apiKey = ""
            hasStoredKey = false
            canRemoveKey = false
            modelError = nil
        } catch {
            modelError = "Could not remove key: \(error.localizedDescription)"
        }
    }

    // MARK: - Model validation

    /// Loads the provider catalog and marks the exact current credential revision
    /// as validated when the request succeeds.
    func fetchModels() {
        guard hasStoredKey, !apiKey.isEmpty else {
            modelError = "Enter and save an API key first."
            return
        }

        invalidateValidation(clearError: true)
        isLoadingModels = true

        let requestRevision = keyRevision
        let requestKey = apiKey
        let loader = modelLoader

        validationTask = Task { @MainActor [weak self] in
            do {
                let models = try await loader()
                guard let self,
                      !Task.isCancelled,
                      self.keyRevision == requestRevision,
                      self.apiKey == requestKey else { return }

                self.availableModels = models.sorted { $0.displayName < $1.displayName }
                self.keyValidated = true
                self.modelError = nil
                self.isLoadingModels = false
            } catch is CancellationError {
                guard let self,
                      self.keyRevision == requestRevision else { return }
                self.isLoadingModels = false
            } catch {
                guard let self,
                      !Task.isCancelled,
                      self.keyRevision == requestRevision,
                      self.apiKey == requestKey else { return }

                self.availableModels = []
                self.keyValidated = false
                self.modelError = error.localizedDescription
                self.isLoadingModels = false
            }
        }
    }

    /// Cancels the visible validation attempt and advances the identity used to
    /// reject late success or failure callbacks.
    private func invalidateValidation(clearError: Bool) {
        validationTask?.cancel()
        validationTask = nil
        keyRevision += 1
        availableModels = []
        keyValidated = false
        isLoadingModels = false
        if clearError {
            modelError = nil
        }
    }
}
