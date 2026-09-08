import Foundation

enum HistoryDelivery: String, Codable {
    /// The paste event was sent. This is not proof that another app accepted it.
    case pasteSent
    case copied
    case historyOnly
}
