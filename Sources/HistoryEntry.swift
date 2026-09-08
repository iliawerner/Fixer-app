import Foundation

/// A durable snapshot of one operation. It retains the action as it was run,
/// even if the user edits or removes that action from the library later.
struct HistoryEntry: Identifiable, Codable, Equatable {
    var id: UUID = UUID()
    var createdAt: Date = .now
    var updatedAt: Date = .now
    var action: MacroAction
    var sourceAppName: String?
    var sourceText: String = ""
    var transcript: String?
    /// Speech recognition may use a different model from the saved text Action.
    var transcriptionModelName: String? = nil
    var prompt: String?
    var result: String?
    var audioFileName: String?
    var audioDuration: TimeInterval?
    var errorMessage: String?
    var status: HistoryStatus = .running
    var stage: HistoryStage = .capture
    var delivery: HistoryDelivery?

    var isActive: Bool { status == .running }
}
