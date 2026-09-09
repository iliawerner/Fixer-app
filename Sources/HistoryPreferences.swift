import Foundation
import Combine

@MainActor
final class HistoryPreferences: ObservableObject {
    static let shared = HistoryPreferences(defaults: PersistenceEnvironment.sharedDefaults)

    @Published var copyResultWhenTargetChanges: Bool {
        didSet { defaults.set(copyResultWhenTargetChanges, forKey: Self.copyKey) }
    }

    /// Zero means forever. Failed and interrupted entries are never pruned.
    @Published var retentionDays: Int {
        didSet {
            if retentionDays < 0 { retentionDays = 0 }
            defaults.set(retentionDays, forKey: Self.retentionKey)
        }
    }

    private let defaults: UserDefaults
    private static let copyKey = "history.copyResultWhenTargetChanges"
    private static let retentionKey = "history.retentionDays"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        copyResultWhenTargetChanges = defaults.object(forKey: Self.copyKey) as? Bool ?? true
        retentionDays = max(0, defaults.object(forKey: Self.retentionKey) as? Int ?? 30)
    }
}
