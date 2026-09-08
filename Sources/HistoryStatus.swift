import Foundation

enum HistoryStatus: String, Codable {
    case running, succeeded, failed, interrupted, cancelled
}
