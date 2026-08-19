import SwiftUI

/// Shared motion language for the workspace.
///
/// Steep timing curves preserve Fixer's tactile ease-in/ease-out character, but
/// short durations keep every response feeling immediate. Reduce Motion removes
/// spatial movement and uses only a brief opacity change.
enum FixerMotion {
    static let workspaceDuration: TimeInterval = 0.34
    static let controlDuration: TimeInterval = 0.18
    static let focusDuration: TimeInterval = 0.16
    static let hoverDuration: TimeInterval = 0.11
    static let pressDuration: TimeInterval = 0.09
    static let replacementExitDuration: TimeInterval = 0.12
    static let replacementEntranceDuration: TimeInterval = 0.24

    static func workspace(reduceMotion: Bool) -> Animation {
        reduceMotion
            ? .easeOut(duration: 0.07)
            : .timingCurve(0.82, 0.02, 0.18, 0.98, duration: workspaceDuration)
    }

    static func control(reduceMotion: Bool) -> Animation {
        reduceMotion
            ? .easeOut(duration: 0.05)
            : .timingCurve(0.78, 0.03, 0.22, 0.98, duration: controlDuration)
    }

    static func focus(reduceMotion: Bool) -> Animation {
        reduceMotion
            ? .easeOut(duration: 0.05)
            : .timingCurve(0.82, 0.02, 0.18, 0.98, duration: focusDuration)
    }

    /// Hover is a recognition cue, not a transition users should wait for.
    /// It therefore settles faster than control selection while keeping the
    /// same steep ease-in/ease-out character.
    static func hover(reduceMotion: Bool) -> Animation {
        reduceMotion
            ? .easeOut(duration: 0.04)
            : .timingCurve(0.72, 0.02, 0.28, 0.98, duration: hoverDuration)
    }

    static func press(reduceMotion: Bool) -> Animation {
        reduceMotion
            ? .easeOut(duration: 0.03)
            : .timingCurve(0.78, 0.02, 0.22, 0.98, duration: pressDuration)
    }

    /// Layout insertions and removals must not interpolate when Reduce Motion
    /// is enabled. Color/opacity-only callers may still use the short reduced
    /// variants above, but structural callers use this optional transaction.
    static func structural(reduceMotion: Bool) -> Animation? {
        reduceMotion ? nil : control(reduceMotion: false)
    }

    static func replacementExit(reduceMotion: Bool) -> Animation {
        reduceMotion
            ? .easeOut(duration: 0.04)
            : .timingCurve(0.78, 0.02, 0.22, 0.98, duration: replacementExitDuration)
    }

    static func replacementEntrance(reduceMotion: Bool) -> Animation {
        reduceMotion
            ? .easeOut(duration: 0.06)
            : .timingCurve(0.84, 0.01, 0.16, 0.99, duration: replacementEntranceDuration)
    }

    static func replacementSwapDelay(reduceMotion: Bool) -> TimeInterval {
        reduceMotion ? 0.04 : replacementExitDuration
    }

    static func detailTransition(reduceMotion: Bool) -> AnyTransition {
        guard !reduceMotion else { return .opacity }
        return .asymmetric(
            insertion: .opacity.combined(with: .offset(x: 8)),
            removal: .opacity.combined(with: .offset(x: -5))
        )
    }
}
