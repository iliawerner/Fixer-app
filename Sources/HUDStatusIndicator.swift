import SwiftUI

/// Familiar, literal status feedback for an Action run.
///
/// Working uses the native indeterminate indicator. Success and error use the
/// standard macOS confirmation symbols. Reduce Motion replaces indeterminate
/// animation with a static clock while the adjacent text still says "Working…".
struct HUDStatusIndicator: View {
    let phase: RunFeedbackPresentation.Phase
    let revision: Int
    let reduceMotion: Bool
    let activityLevel: Float

    var body: some View {
        Group {
            switch phase {
            case .listening:
                HUDVoiceLevelIndicator(
                    level: activityLevel,
                    reduceMotion: reduceMotion
                )
            case .working, .busy:
                if HUDMotion.shouldAnimateProgress(
                    phase: phase,
                    reduceMotion: reduceMotion
                ) {
                    ProgressView()
                        .controlSize(.small)
                        .tint(Fixer.textDim)
                } else {
                    Image(systemName: "clock")
                        .font(.title3)
                        .foregroundStyle(Fixer.textDim)
                }
            case .success:
                Image(systemName: "checkmark.circle.fill")
                    .font(.title3)
                    .foregroundStyle(Fixer.fixed)
            case .notice:
                Image(systemName: "doc.on.clipboard")
                    .font(.title3)
                    .foregroundStyle(Fixer.textDim)
            case .cancelled:
                Image(systemName: "xmark.circle")
                    .font(.title3)
                    .foregroundStyle(Fixer.textDim)
            case .error:
                Image(systemName: "exclamationmark.circle.fill")
                    .font(.title3)
                    .foregroundStyle(Fixer.safeText)
            }
        }
        .id("\(revision)-\(phase)")
        .transition(.opacity)
        .animation(HUDMotion.phaseChange(reduceMotion: reduceMotion), value: revision)
        .accessibilityHidden(true)
    }
}
