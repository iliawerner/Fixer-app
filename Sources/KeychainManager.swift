import Foundation
import KeychainAccess

/// Stores the Gemini API key in the macOS Keychain.
class KeychainManager {
    static let shared = KeychainManager()

    // DO NOT rename this service string. It is the storage location of every
    // existing user's saved API key; changing it (e.g. to match the "fixer"
    // product name) would orphan their key and silently sign everyone out. Like
    // the bundle id, it is deliberately decoupled from the product name.
    private let keychain = Keychain(service: "com.geminimacros.apikey")

    func saveAPIKey(_ key: String) throws {
        try keychain.set(key, key: "apiKey")
    }

    /// Returns the stored key, or nil if none is set. Errors (e.g. a locked
    /// keychain) are intentionally swallowed and read as "no key set".
    func getAPIKey() -> String? {
        return try? keychain.get("apiKey")
    }
    
    func deleteAPIKey() throws {
        try keychain.remove("apiKey")
    }
}
