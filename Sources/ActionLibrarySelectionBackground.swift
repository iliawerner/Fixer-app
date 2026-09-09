import SwiftUI

/// Calm selection surface that smoothly travels between rows instead of stacking
/// a dark fill, accent rail, and status color on the same item.
struct ActionLibrarySelectionBackground: View {
    let isSelected: Bool
    let isHovered: Bool
    let namespace: Namespace.ID
    let reduceMotion: Bool

    var body: some View {
        if isSelected {
            if reduceMotion {
                selectionShape
            } else {
                selectionShape
                    .matchedGeometryEffect(id: "action-library-selection", in: namespace)
            }
        }
    }

    private var selectionShape: some View {
        RoundedRectangle(cornerRadius: 7)
            .fill(Fixer.selection.opacity(isHovered ? 0.98 : 0.93))
            .overlay {
                RoundedRectangle(cornerRadius: 7)
                    .stroke(Fixer.selectionBorder, lineWidth: 1)
            }
    }
}
