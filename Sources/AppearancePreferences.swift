import Combine
import Foundation

@MainActor
final class AppearancePreferences: ObservableObject {
    static let shared = AppearancePreferences(defaults: PersistenceEnvironment.sharedDefaults)

    @Published var appearance: AppAppearance {
        didSet { defaults.set(appearance.rawValue, forKey: Self.storageKey) }
    }

    private let defaults: UserDefaults
    static let storageKey = "appearance.mode"

    init(defaults: UserDefaults) {
        self.defaults = defaults
        appearance = defaults.string(forKey: Self.storageKey)
            .flatMap(AppAppearance.init(rawValue:)) ?? .system
    }
}
