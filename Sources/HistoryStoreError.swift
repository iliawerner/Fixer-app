import Foundation

enum HistoryStoreError: LocalizedError {
    case missingEntry
    case activeEntry
    case changedIdentity
    case invalidAudio
    case invalidRecord

    var errorDescription: String? {
        switch self {
        case .missingEntry: "This History entry is no longer available."
        case .activeEntry: "An operation in progress cannot be deleted."
        case .changedIdentity: "The identity of a History entry cannot be changed."
        case .invalidAudio: "The audio could not be saved as a valid WAV recording."
        case .invalidRecord: "A History record could not be read. The original file was preserved."
        }
    }
}
