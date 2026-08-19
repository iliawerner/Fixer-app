import Foundation
import SwiftUI

/// Motion tokens for the passive run-status panel.
///
/// Entry is a 120 ms fade with a four-point rise. Phase changes are 140 ms
/// crossfades. Reduce Motion leaves opacity as the only animated property.
enum HUDMotion {
    static let acknowledgementDuration: TimeInterval = 0.12
    static let entranceDuration: TimeInterval = 0.12
    static let phaseDuration: TimeInterval = 0.14
    static let dismissalDuration: TimeInterval = 0.14

    static func acknowledgement(reduceMotion: Bool) -> Animation {
        .easeOut(duration: reduceMotion ? 0.06 : acknowledgementDuration)
    }

    static func entrance(reduceMotion: Bool) -> Animation {
        .easeOut(duration: reduceMotion ? 0.06 : entranceDuration)
    }

    static func phaseChange(reduceMotion: Bool) -> Animation {
        reduceMotion
            ? .easeOut(duration: 0.08)
            : .easeInOut(duration: phaseDuration)
    }

    static func panelOffset(isPresented: Bool, reduceMotion: Bool) -> Double {
        guard !reduceMotion else { return 0 }
        return isPresented ? 0 : 4
    }

    static func shouldAnimateProgress(
        phase: RunFeedbackPresentation.Phase,
        reduceMotion: Bool
    ) -> Bool {
        (phase == .working || phase == .busy) && !reduceMotion
    }
}
