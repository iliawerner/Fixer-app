import AppKit
import Combine

/// Applies the preference once at launch and immediately after each change.
/// Windows and sheets inherit the application appearance instead of keeping
/// separate overrides that could disagree or stop following macOS.
@MainActor
final class AppearanceController {
    private let preferences: AppearancePreferences
    private let applyAppearance: @MainActor (NSAppearance?) -> Void
    private var subscription: AnyCancellable?

    init(
        preferences: AppearancePreferences,
        applyAppearance: (@MainActor (NSAppearance?) -> Void)? = nil
    ) {
        self.preferences = preferences
        self.applyAppearance = applyAppearance ?? { NSApplication.shared.appearance = $0 }
    }

    func start() {
        guard subscription == nil else { return }
        subscription = preferences.$appearance
            .removeDuplicates()
            .sink { [weak self] appearance in
                self?.applyAppearance(appearance.appKitAppearance)
            }
    }
}
