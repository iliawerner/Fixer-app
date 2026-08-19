import SwiftUI

/// Compact status surface for one Action run.
///
/// It deliberately avoids product marks and decorative metaphors. State is
/// communicated with a familiar system indicator and direct copy.
struct HUDStatusPanel: View {
    let presentation: RunFeedbackPresentation
    let revision: Int
    let reduceMotion: Bool

    private var isError: Bool { presentation.phase == .error }
    private var minimumSize: CGSize { HUDLayout.cardSize(for: presentation.phase) }

    var body: some View {
        HStack(alignment: .center, spacing: HUDLayout.indicatorToCopySpacing) {
            HUDStatusIndicator(
                phase: presentation.phase,
                revision: revision,
                reduceMotion: reduceMotion
            )
            .frame(width: 18, height: 18)

            HUDFeedbackCopy(
                presentation: presentation,
                revision: revision,
                reduceMotion: reduceMotion
            )
        }
        .padding(.leading, HUDLayout.contentLeadingInset)
        .padding(.trailing, HUDLayout.contentTrailingInset)
        .padding(.vertical, isError ? 11 : 9)
        .frame(width: minimumSize.width, alignment: .leading)
        .fixedSize(horizontal: false, vertical: true)
        .frame(minHeight: minimumSize.height, alignment: .leading)
        .background(Fixer.panel)
        .overlay {
            RoundedRectangle(cornerRadius: HUDLayout.cornerRadius)
                .stroke(Fixer.line2.opacity(0.7), lineWidth: 1)
        }
        .clipShape(.rect(cornerRadius: HUDLayout.cornerRadius))
        .shadow(
            color: .black.opacity(0.10),
            radius: HUDLayout.shadowRadius,
            x: 0,
            y: HUDLayout.shadowYOffset
        )
    }
}
