import Foundation

/// A saved result is pasted only into a still-verifiable source. Fallback copy
/// is an explicit preference and never runs when clipboard preservation is on.
@MainActor
final class ResultDeliveryService {
    static let shared = ResultDeliveryService()

    typealias TargetCheck = @MainActor () -> Bool
    private let isCurrent: (VoiceInsertionTarget) -> Bool
    private let paste: (String, @escaping TargetCheck) async -> Bool
    private let copy: (String) async -> Bool
    private let shouldCopy: () -> Bool

    init(
        isCurrent: ((VoiceInsertionTarget) -> Bool)? = nil,
        paste: ((String, @escaping TargetCheck) async -> Bool)? = nil,
        copy: ((String) async -> Bool)? = nil,
        shouldCopy: (() -> Bool)? = nil
    ) {
        self.isCurrent = isCurrent ?? { SystemVoiceInsertionTarget().isCurrent($0) }
        self.paste = paste ?? { text, check in
            await ClipboardManager.shared.paste(text, ifTargetCurrent: check)
        }
        self.copy = copy ?? { await ClipboardManager.shared.copyText($0) }
        self.shouldCopy = shouldCopy ?? { HistoryPreferences.shared.copyResultWhenTargetChanges }
    }

    func deliver(_ result: String, to target: VoiceInsertionTarget?) async -> HistoryDelivery {
        guard !Task.isCancelled else { return .historyOnly }
        if let target, isCurrent(target) {
            let check = isCurrent
            if await paste(result, { check(target) }) { return .pasteSent }
        }
        if !Task.isCancelled, shouldCopy() {
            return await copy(result) ? .copied : .historyOnly
        }
        return .historyOnly
    }
}
