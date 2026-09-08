import Foundation

/// Keeps hosted tests and explicitly isolated live QA away from the user's data.
enum PersistenceEnvironment {
    static var isTesting: Bool {
        NSClassFromString("XCTestCase") != nil
            || ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
            || ProcessInfo.processInfo.environment["XCTestBundlePath"] != nil
    }

    static var qaDirectory: URL? {
        guard let path = ProcessInfo.processInfo.environment["FIXER_DATA_DIR"],
              !path.isEmpty else { return nil }
        return URL(fileURLWithPath: path, isDirectory: true)
    }

    static let sharedDefaults: UserDefaults = {
        if let directory = qaDirectory {
            let identifier = Data(directory.path.utf8).base64EncodedString()
                .replacingOccurrences(of: "/", with: "_")
            return isolatedDefaults(named: "fixer.qa.\(identifier)")
        }
        if isTesting {
            return isolatedDefaults(named: "fixer.tests.\(UUID().uuidString)")
        }
        return .standard
    }()

    private static func isolatedDefaults(named suite: String) -> UserDefaults {
        guard let defaults = UserDefaults(suiteName: suite) else {
            preconditionFailure("An isolated preferences store is required for tests and live QA.")
        }
        return defaults
    }

    static func historyDirectory() -> URL {
        if let directory = qaDirectory {
            return directory.appendingPathComponent("History", isDirectory: true)
        }
        if isTesting {
            return FileManager.default.temporaryDirectory
                .appendingPathComponent("fixer-history-tests-\(UUID().uuidString)", isDirectory: true)
        }
        return FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("com.geminimacros.GeminiMacros", isDirectory: true)
            .appendingPathComponent("History", isDirectory: true)
    }
}
