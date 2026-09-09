/// Ephemeral setup state used only by an explicit isolated QA launch.
final class IsolatedQAKeyStore: APIKeyStoring {
    private var value: String?
    func saveAPIKey(_ key: String) throws { value = key }
    func getAPIKey() throws -> String? { value }
    func deleteAPIKey() throws { value = nil }
}
