import Foundation

/// Owns the versioned first-run flag independently from splash rendering.
/// Replaying the splash from the menu must never change this value.
enum SplashPolicy {
    private static let seenKey = "fixer.v2.splash.seen.1"

    static func shouldShowFirstLaunch(defaults: UserDefaults = .standard) -> Bool {
        !defaults.bool(forKey: seenKey)
    }

    static func markSeen(defaults: UserDefaults = .standard) {
        defaults.set(true, forKey: seenKey)
    }
}
