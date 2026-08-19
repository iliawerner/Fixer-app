import SwiftUI

/// Keeps copy swaps local to the text while the status panel retains its identity.
struct HUDTransitioningText: View {
    let value: String
    let font: Font
    let color: Color
    let revision: Int
    let reduceMotion: Bool

    var body: some View {
        Text(value)
            .font(font)
            .foregroundStyle(color)
            .fixedSize(horizontal: false, vertical: true)
            .id("\(revision)-\(value)")
            .transition(.opacity)
            .animation(HUDMotion.phaseChange(reduceMotion: reduceMotion), value: revision)
    }
}
