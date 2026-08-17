import Foundation
import Testing
@testable import fixer

@Suite(.serialized)
@MainActor
struct ProviderSetupControllerTests {
    @Test func staleModelResponseCannotValidateAChangedKey() async {
        let store = TestAPIKeyStore(value: "key-a")
        let loader = ControlledModelLoader()
        let controller = ProviderSetupController(
            keyStore: store,
            modelLoader: { try await loader.load() }
        )

        controller.fetchModels()
        await Task.yield()
        #expect(loader.isWaiting)

        controller.updateAPIKey("key-b")
        loader.succeed([
            GeminiModel(name: "models/a", displayName: "Model A")
        ])
        await Task.yield()

        #expect(controller.apiKey == "key-b")
        #expect(!controller.keyValidated)
        #expect(controller.availableModels.isEmpty)
        #expect(!controller.isLoadingModels)
    }

    @Test func removingKeyWhileModelsLoadRejectsTheStaleResponse() async {
        let store = TestAPIKeyStore(value: "key-a")
        let loader = ControlledModelLoader()
        let controller = ProviderSetupController(
            keyStore: store,
            modelLoader: { try await loader.load() }
        )

        controller.fetchModels()
        await Task.yield()
        #expect(loader.isWaiting)

        controller.removeKey()
        loader.succeed([
            GeminiModel(name: "models/a", displayName: "Model A")
        ])
        await Task.yield()

        #expect(controller.apiKey.isEmpty)
        #expect(!controller.hasStoredKey)
        #expect(!controller.canRemoveKey)
        #expect(!controller.keyValidated)
        #expect(controller.availableModels.isEmpty)
        #expect(!controller.isLoadingModels)
    }

    @Test func staleModelFailureCannotOverwriteChangedKeyState() async {
        let store = TestAPIKeyStore(value: "key-a")
        let loader = ControlledModelLoader()
        let controller = ProviderSetupController(
            keyStore: store,
            modelLoader: { try await loader.load() }
        )

        controller.fetchModels()
        await Task.yield()
        #expect(loader.isWaiting)

        controller.updateAPIKey("key-b")
        loader.fail(TestKeyStoreError.denied)
        await Task.yield()

        #expect(controller.apiKey == "key-b")
        #expect(controller.hasStoredKey)
        #expect(controller.canRemoveKey)
        #expect(controller.modelError == nil)
        #expect(!controller.keyValidated)
        #expect(controller.availableModels.isEmpty)
        #expect(!controller.isLoadingModels)
    }

    @Test func failedDeletionKeepsCredentialVisibleAndReportsTheError() {
        let store = TestAPIKeyStore(value: "key-a")
        store.deleteError = TestKeyStoreError.denied
        let controller = ProviderSetupController(
            keyStore: store,
            modelLoader: { [] }
        )

        controller.removeKey()

        #expect(controller.apiKey == "key-a")
        #expect(controller.hasStoredKey)
        #expect(controller.modelError?.contains("Could not remove key") == true)
        #expect(store.value == "key-a")
    }

    @Test func failedSaveRestoresThePreviouslyStoredCredential() {
        let store = TestAPIKeyStore(value: "key-a")
        store.saveError = TestKeyStoreError.denied
        let controller = ProviderSetupController(
            keyStore: store,
            modelLoader: { [] }
        )

        controller.updateAPIKey("key-b")

        #expect(controller.apiKey == "key-a")
        #expect(controller.hasStoredKey)
        #expect(controller.modelError?.contains("Could not save key") == true)
        #expect(store.value == "key-a")
    }

    @Test func failedClearReportsRemovalAndKeepsTheStoredCredential() {
        let store = TestAPIKeyStore(value: "key-a")
        store.deleteError = TestKeyStoreError.denied
        let controller = ProviderSetupController(
            keyStore: store,
            modelLoader: { [] }
        )

        controller.updateAPIKey("")

        #expect(controller.apiKey == "key-a")
        #expect(controller.hasStoredKey)
        #expect(controller.modelError?.contains("Could not remove key") == true)
        #expect(store.value == "key-a")
    }

    @Test func failedReadIsSurfacedAndPossibleRetainedCredentialCanBeRemoved() {
        let store = TestAPIKeyStore(value: nil)
        store.readError = TestKeyStoreError.denied

        let controller = ProviderSetupController(
            keyStore: store,
            modelLoader: { [] }
        )

        #expect(controller.apiKey.isEmpty)
        #expect(!controller.hasStoredKey)
        #expect(controller.canRemoveKey)
        #expect(controller.modelError?.contains("Could not read key") == true)
    }

    @Test func successfulRemovalClearsAnUnreadableCredentialState() {
        let store = TestAPIKeyStore(value: nil)
        store.readError = TestKeyStoreError.denied
        let controller = ProviderSetupController(
            keyStore: store,
            modelLoader: { [] }
        )

        controller.removeKey()

        #expect(controller.apiKey.isEmpty)
        #expect(!controller.hasStoredKey)
        #expect(!controller.canRemoveKey)
        #expect(controller.modelError == nil)
    }

    @Test func savedKeyIsAReadinessRequirementEvenBeforeOptionalValidation() {
        let controller = ProviderSetupController(
            keyStore: TestAPIKeyStore(value: "saved-key"),
            modelLoader: { [] }
        )

        #expect(controller.hasStoredKey)
        #expect(!controller.keyValidated)
        #expect(
            SetupReadiness.issueCount(
                accessibilityGranted: true,
                hasStoredKey: controller.hasStoredKey,
                hasRunnableAction: true
            ) == 0
        )
    }
}

@MainActor
private final class ControlledModelLoader {
    private var continuation: CheckedContinuation<[GeminiModel], Error>?

    var isWaiting: Bool { continuation != nil }

    func load() async throws -> [GeminiModel] {
        try await withCheckedThrowingContinuation { continuation in
            self.continuation = continuation
        }
    }

    func succeed(_ models: [GeminiModel]) {
        continuation?.resume(returning: models)
        continuation = nil
    }

    func fail(_ error: Error) {
        continuation?.resume(throwing: error)
        continuation = nil
    }
}

private enum TestKeyStoreError: LocalizedError {
    case denied

    var errorDescription: String? { "Keychain access denied" }
}

private final class TestAPIKeyStore: APIKeyStoring {
    var value: String?
    var readError: Error?
    var saveError: Error?
    var deleteError: Error?

    init(value: String?) {
        self.value = value
    }

    func saveAPIKey(_ key: String) throws {
        if let saveError { throw saveError }
        value = key
    }

    func getAPIKey() throws -> String? {
        if let readError { throw readError }
        return value
    }

    func deleteAPIKey() throws {
        if let deleteError { throw deleteError }
        value = nil
    }
}
