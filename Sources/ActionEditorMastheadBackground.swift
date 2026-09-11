import SwiftUI

/// Shared, stationary title surface for both editor kinds and their dissolve.
struct ActionEditorMastheadBackground: View {
    var body: some View {
        ActionEditorGridBackground()
            .background(Fixer.masthead)
            .overlay(alignment: .bottom) {
                Rectangle()
                    .fill(Fixer.chromeLine)
                    .frame(height: 1)
            }
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }
}
