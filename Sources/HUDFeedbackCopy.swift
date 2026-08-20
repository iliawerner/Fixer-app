import SwiftUI

/// One visible hierarchy: the semantic run state first, then the Action name or
/// one useful error-recovery step in the quieter supporting position.
struct HUDFeedbackCopy: View {
    let presentation: RunFeedbackPresentation
    let revision: Int
    let reduceMotion: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            HUDTransitioningText(
                value: presentation.title,
                font: .headline,
                color: presentation.phase == .error ? Fixer.safeText : Fixer.text,
                revision: revision,
                reduceMotion: reduceMotion
            )

            if !presentation.detail.isEmpty {
                HUDTransitioningText(
                    value: presentation.detail,
                    font: .subheadline,
                    color: Fixer.textDim,
                    revision: revision,
                    reduceMotion: reduceMotion
                )
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
