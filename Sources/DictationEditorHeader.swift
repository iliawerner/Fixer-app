import SwiftUI

/// Protected identity masthead for Fixer's permanent Dictation Action.
///
/// It shares the text Action's paper plane but intentionally has no editable
/// title or options menu: this entry point cannot be renamed or removed.
struct DictationEditorHeader: View {
    var body: some View {
        ZStack(alignment: .bottomLeading) {
            ActionEditorGridBackground()

            WorkspaceWindowDragRegion()
                .accessibilityHidden(true)

            HStack(spacing: 10) {
                Image(systemName: "mic.fill")
                    .font(.title2)
                    .accessibilityHidden(true)

                Text("Dictation")
                    .font(.title)
                    .bold()
            }
            .foregroundStyle(Fixer.mastheadText)
            .padding(.leading, ActionEditorMetrics.headerHorizontalInset)
            .padding(.bottom, 11)
        }
        .frame(height: WorkspaceChromeMetrics.editorMastheadHeight)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Fixer.masthead)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(Fixer.chromeLine)
                .frame(height: 1)
                .allowsHitTesting(false)
                .accessibilityHidden(true)
        }
    }
}
