import AppKit
import Foundation
import Testing
@testable import fixer

@Suite(.serialized)
struct SplashPolicyTests {
    @Test func firstLaunchShowsOncePerV2Install() {
        let suite = "SplashPolicyTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }

        #expect(SplashPolicy.shouldShowFirstLaunch(defaults: defaults))

        SplashPolicy.markSeen(defaults: defaults)

        #expect(!SplashPolicy.shouldShowFirstLaunch(defaults: defaults))
    }

    @Test @MainActor func approvedPosterLayersAreBundled() {
        let names = [
            "SplashPaper",
            "SplashSun",
            "SplashLandscape",
            "SplashCharacter",
            "SplashOverlay"
        ]

        for name in names {
            #expect(NSImage(named: name) != nil, "Missing splash asset: \(name)")
        }
    }
}
