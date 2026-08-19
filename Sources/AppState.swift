import SwiftUI

/// Process-scoped state shared by the menu, workspace, window lifecycle, and
/// action pipeline.
///
/// This state is intentionally ephemeral; saved actions and credentials belong
/// to `SettingsManager` and `KeychainManager`. Main-actor isolation makes the
/// single-flight processing latch atomic across shortcut events and safe to read
/// from UI code.
@MainActor
final class AppState: ObservableObject {
    static let shared = AppState()

    /// The single-flight latch set by `ActionRunner` for the complete
    /// copy-request-paste operation.
    @Published var isProcessing: Bool = false

    /// The action associated with the active run, used by menu and HUD feedback.
    @Published var processingActionName: String?

    /// A periodically refreshed snapshot of macOS Accessibility trust.
    @Published var accessibilityGranted: Bool = false

    /// The most recent user-visible run error retained for the menu-bar menu.
    @Published var lastError: String?

    /// Internal so previews and tests can use isolated, non-global state.
    init() {}

    /// Refreshes the cached permission snapshot from Application Services.
    func refreshAccessibility() {
        accessibilityGranted = PermissionsManager.isAccessibilityGranted
    }
}
