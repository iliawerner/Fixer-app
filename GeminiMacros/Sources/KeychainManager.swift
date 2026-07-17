import Foundation
import KeychainAccess

class KeychainManager {
    static let shared = KeychainManager()
    
    private let keychain = Keychain(service: "com.geminimacros.apikey")
    
    func saveAPIKey(_ key: String) throws {
        try keychain.set(key, key: "apiKey")
    }
    
    func getAPIKey() -> String? {
        return try? keychain.get("apiKey")
    }
    
    func deleteAPIKey() throws {
        try keychain.remove("apiKey")
    }
}
