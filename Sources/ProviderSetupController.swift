import Foundation
import SwiftUI

/// Owns provider setup state independently from the Settings view. Validation is
/// tied to the exact key revision that started it, so an old network response can
/// never validate a changed or removed credential.
@MainActor
final class ProviderSetupController: ObservableObject {
    @Published private(set) var apiKey: String
    @Published private(set) var availableModels: [GeminiModel] = []
    @Published private(set) var isLoadingModels = false
    @Published private(set) var modelError: String?
    @Published private(set) var keyValidated = false
    @Published private(set) var hasStoredKey: Bool

    private let keyStore: any APIKeyStoring
    private let modelLoader: () async throws -> [GeminiModel]
    private var validationTask: Task<Void, Never>?
    private var keyRevision = 0

    init(
        keyStore: any APIKeyStoring = KeychainManager.shared,
        modelLoader: @escaping () async throws -> [GeminiModel] = {
            try await GeminiAPI.shared.fetchModels()
        }
    ) {
        self.keyStore = keyStore
        self.modelLoader = modelLoader
        let storedKey = keyStore.getAPIKey() ?? ""
        self.apiKey = storedKey
        self.hasStoredKey = !storedKey.isEmpty
    }

    func updateAPIKey(_ newValue: String) {
        guard newValue != apiKey else { return }

        invalidateValidation(clearError: false)
        let previousValue = apiKey
        let previousStoredState = hasStoredKey

        do {
            if newValue.isEmpty {
                try keyStore.deleteAPIKey()
            } else {
                try keyStore.saveAPIKey(newValue)
            }
            apiKey = newValue
            hasStoredKey = !newValue.isEmpty
            modelError = nil
        } catch {
            apiKey = previousValue
            hasStoredKey = previousStoredState
            let operation = newValue.isEmpty ? "remove" : "save"
            modelError = "Could not \(operation) key: \(error.localizedDescription)"
        }
    }

    func removeKey() {
        invalidateValidation(clearError: false)

        do {
            try keyStore.deleteAPIKey()
            apiKey = ""
            hasStoredKey = false
            modelError = nil
        } catch {
            modelError = "Could not remove key: \(error.localizedDescription)"
        }
    }

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
