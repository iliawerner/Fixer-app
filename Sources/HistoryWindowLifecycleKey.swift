import SwiftUI

struct HistoryWindowLifecycleKey: EnvironmentKey {
    static let defaultValue: HistoryWindowLifecycle? = nil
}

extension EnvironmentValues {
    var historyWindowLifecycle: HistoryWindowLifecycle? {
        get { self[HistoryWindowLifecycleKey.self] }
        set { self[HistoryWindowLifecycleKey.self] = newValue }
    }
}
