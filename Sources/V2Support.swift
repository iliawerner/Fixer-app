import Foundation
import CoreGraphics

/// Pure filtering used by the v2 action library. Keeping this outside the view
/// makes search behavior deterministic and cheap to test.
enum ActionListFilter {
    static func matches(_ action: MacroAction, query: String) -> Bool {
        let needle = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !needle.isEmpty else { return true }

        return [action.name, action.promptTemplate, action.modelName]
            .contains { $0.localizedCaseInsensitiveContains(needle) }
    }
}

/// Copy and timing for the non-activating HUD. The view owns only animation and
/// layout; ActionRunner decides which semantic state should be shown.
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

    static func working(actionName: String) -> Self {
        Self(
            phase: .working,
            label: "FIXING",
            title: actionName,
            detail: "Gemini is working · up to 30 sec",
            dismissAfter: nil
        )
    }

    static func busy(actionName: String) -> Self {
        Self(
            phase: .busy,
            label: "STILL FIXING",
            title: actionName,
            detail: "Already running · wait for the result",
            dismissAfter: 1.4
        )
    }

    static func success(actionName: String, mode: ActionOutputMode) -> Self {
        Self(
            phase: .success,
            label: "RESULT SENT",
            title: actionName,
            detail: "\(mode.rawValue) · try ⌘Z to undo",
            dismissAfter: 1.6
        )
    }

    static func error(_ message: String) -> Self {
        Self(
            phase: .error,
            label: "NEEDS ATTENTION",
            title: "Couldn’t finish",
            detail: message,
            dismissAfter: 5.5
        )
    }
}

/// Deterministic placement for the passive HUD. The rail itself has 8 pt of
/// stage padding below it, so a panel inset of 56 pt places the visible rail
/// exactly 64 pt above the screen's visible-frame edge.
enum HUDLayout {
    static func panelOrigin(panelSize: CGSize, visibleFrame: CGRect) -> CGPoint {
        CGPoint(
            x: visibleFrame.midX - panelSize.width / 2,
            y: visibleFrame.minY + 56
        )
    }
}
