import SwiftUI

/// Literal microphone-level feedback for the listening phase.
///
/// The bars reflect measured RMS rather than looping decorative motion. Reduce
/// Motion freezes their geometry while the adjacent copy still communicates the
/// recording state.
struct HUDVoiceLevelIndicator: View {
    let level: Float
    let reduceMotion: Bool

    var body: some View {
        HStack(alignment: .center, spacing: 2) {
            ForEach(0..<3, id: \.self) { index in
                Capsule()
                    .fill(Fixer.yellowDark)
                    .frame(width: 3, height: height(for: index))
            }
        }
        .frame(width: 18, height: 18)
        .animation(
            reduceMotion ? nil : .easeOut(duration: 0.08),
            value: quantizedLevel
        )
        .accessibilityHidden(true)
    }

    private var quantizedLevel: Float {
        guard !reduceMotion else { return 0.28 }
        return (max(0, min(1, level)) * 12).rounded() / 12
    }

    private func height(for index: Int) -> CGFloat {
        let base: [CGFloat] = [6, 9, 6]
        guard !reduceMotion else { return base[index] }
        let multipliers: [CGFloat] = [8, 11, 7]
        return base[index] + CGFloat(quantizedLevel) * multipliers[index]
    }
}
