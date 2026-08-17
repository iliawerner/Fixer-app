import SwiftUI

/// App-wide observable state. Main-actor isolated so it is safely `Sendable`
/// and can be referenced from the async macro pipeline without data races.
@MainActor
final class AppState: ObservableObject {
    static let shared = AppState()

    @Published var isProcessing: Bool = false
    @Published var processingActionName: String?
    @Published var accessibilityGranted: Bool = false
    @Published var lastError: String?

    /// Internal so previews and tests can use isolated, non-global state.
    init() {}

    func refreshAccessibility() {
        accessibilityGranted = PermissionsManager.isAccessibilityGranted
    }
}
