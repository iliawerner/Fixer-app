import Foundation
import CoreGraphics

enum AppPresentationPolicy {
    static func mayActivateFixer(isProcessing: Bool) -> Bool {
        !isProcessing
    }
}

enum SetupReadiness {
    static func issueCount(
        accessibilityGranted: Bool,
        hasStoredKey: Bool,
        hasRunnableAction: Bool
    ) -> Int {
        [accessibilityGranted, hasStoredKey, hasRunnableAction]
            .filter { !$0 }
            .count
    }
}

/// Immutable copy and timing for one semantic state of the non-activating HUD.
///
/// `ActionRunner` chooses the state, `HUDManager` owns its lifetime, and the
/// SwiftUI view owns only the transition between values. Keeping those concerns
/// separate is what lets the HUD update without ever activating Fixer.
struct RunFeedbackPresentation: Equatable {
    enum Phase: Equatable {
        case working
        case busy
        case success
        case error
    }

    let phase: Phase
    let label: String
    let title: String
    let detail: String
    let dismissAfter: TimeInterval?
    /// Present only for successful output, so motion never needs to infer
    /// Replace versus Append by parsing localized user-facing copy.
    let outputMode: ActionOutputMode?

    var accessibilityAnnouncement: String {
        guard !detail.isEmpty else { return title }
        let separator = title.last.map { ".!?…".contains($0) } == true ? " " : ". "
        return "\(title)\(separator)\(detail)"
    }

    static func working(actionName: String) -> Self {
        Self(
            phase: .working,
            label: "Working",
            title: "Processing text…",
            detail: actionName,
            dismissAfter: nil,
            outputMode: nil
        )
    }

    static func busy(actionName: String) -> Self {
        Self(
            phase: .busy,
            label: "Working",
            title: "Already running",
            detail: actionName,
            dismissAfter: 1.4,
            outputMode: nil
        )
    }

    static func success(actionName _: String, mode: ActionOutputMode) -> Self {
        Self(
            phase: .success,
            label: "Complete",
            title: mode == .replace ? "Text replaced" : "Text appended",
            detail: "",
            dismissAfter: 1.6,
            outputMode: mode
        )
    }

    static func error(_ message: String) -> Self {
        let copy = HUDErrorCopy(message: message)
        return Self(
            phase: .error,
            label: "Error",
            title: copy.title,
            detail: copy.detail,
            dismissAfter: 5.5,
            outputMode: nil
        )
    }
}

/// Deterministic placement and sizing for the passive status panel.
enum HUDLayout {
    static let cornerRadius = 13.0
    static let shadowRadius = 8.0
    static let shadowYOffset = 4.0
    /// The status glyph needs a little more air against the rounded leading
    /// edge than the copy needs at the trailing edge.
    static let contentLeadingInset = 20.0
    static let contentTrailingInset = 14.0
    static let indicatorToCopySpacing = 12.0
    /// Keeps the visible status surface at the same screen height while the
    /// transparent panel grows enough to contain shadow and larger text.
    static let visibleCenterOffset = 107.0
    static let compactCardSize = CGSize(width: 304, height: 60)
    static let errorCardSize = CGSize(width: 344, height: 86)
    static let panelSize = CGSize(width: 420, height: 200)

    static func cardSize(for phase: RunFeedbackPresentation.Phase) -> CGSize {
        phase == .error ? errorCardSize : compactCardSize
    }

    static func panelSize(for _: RunFeedbackPresentation.Phase) -> CGSize {
        Self.panelSize
    }

    static func cardOrigin(for phase: RunFeedbackPresentation.Phase) -> CGPoint {
        let cardSize = cardSize(for: phase)
        return CGPoint(
            x: (panelSize.width - cardSize.width) / 2,
            y: (panelSize.height - cardSize.height) / 2
        )
    }

    static func panelOrigin(panelSize: CGSize, visibleFrame: CGRect) -> CGPoint {
        CGPoint(
            x: visibleFrame.midX - panelSize.width / 2,
            y: visibleFrame.minY + visibleCenterOffset - panelSize.height / 2
        )
    }
}
