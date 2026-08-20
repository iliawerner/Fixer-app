import Foundation
import KeychainAccess

/// Credential-storage boundary used by provider setup and injected test stores.
protocol APIKeyStoring {
    func saveAPIKey(_ key: String) throws
    func getAPIKey() throws -> String?
    func deleteAPIKey() throws
}

/// Stores the Gemini API key in the macOS Keychain under compatibility-pinned
/// service and item identifiers.
final class KeychainManager: APIKeyStoring {
    // MARK: - Shared store and persistence identity

    static let shared = KeychainManager()

    // DO NOT rename this service string. It is the storage location of every
    // existing user's saved API key; changing it (e.g. to match the "fixer"
    // product name) would orphan their key and silently sign everyone out. Like
    // the bundle id, it is deliberately decoupled from the product name.
    private let keychain = Keychain(service: "com.geminimacros.apikey")

    // MARK: - APIKeyStoring

    func saveAPIKey(_ key: String) throws {
        // `apiKey` is persisted identity too. Rename only with an explicit
        // migration that can read the old record before writing the new one.
        try keychain.set(key, key: "apiKey")
    }

    /// Returns the stored key, or nil if none is set. Read failures remain
    /// distinguishable from a genuinely missing credential.
    func getAPIKey() throws -> String? {
        try keychain.get("apiKey")
    }

    func deleteAPIKey() throws {
        try keychain.remove("apiKey")
    }
}
