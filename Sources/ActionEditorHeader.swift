import SwiftUI

/// The selected Action's document-like identity masthead.
///
/// Its 100-point yellow plane deliberately contrasts the native 40-point rail.
/// A barely visible stationery grid gives it character without becoming a
/// ruler, progress indicator, or another piece of editor state.
struct ActionEditorHeader: View {
    @Binding var action: MacroAction

    let onDuplicate: () -> Void
    let onRequestDelete: () -> Void

    var body: some View {
        ZStack(alignment: .topTrailing) {
            ActionEditorMastheadBackground()

            // Empty masthead paper remains a window drag surface, while the
            // title field and options Menu layered above keep normal clicks.
            WorkspaceWindowDragRegion()
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 0) {
                Spacer(minLength: WorkspaceChromeMetrics.titlebarControlSize + 8)

                ActionEditorNameField(name: $action.name)
                    .frame(
                        minWidth: 180,
                        idealWidth: 320,
                        maxWidth: ActionEditorMetrics.headerNameMaximumWidth,
                        alignment: .leading
                    )
                    .padding(.leading, ActionEditorMetrics.headerHorizontalInset)
                    .padding(.trailing, 56)
                    .padding(.bottom, 10)
            }
            // The ZStack is top-trailing so the options Menu can use that
            // corner. Expand the title plane explicitly or that same alignment
            // also places this intrinsic-width VStack at the trailing edge.
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)

            Menu {
                Button("Duplicate Action", systemImage: "plus.square.on.square", action: onDuplicate)
                Divider()
                Button(
                    "Delete Action",
                    systemImage: "trash",
                    role: .destructive,
                    action: onRequestDelete
                )
            } label: {
                ActionOptionsMenuLabel()
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .fixedSize()
            .help("Duplicate or delete this action")
            .padding(.top, 7)
            .padding(.trailing, 10)
        }
        .frame(height: WorkspaceChromeMetrics.editorMastheadHeight)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    init(
        action: Binding<MacroAction>,
        onDuplicate: @escaping () -> Void,
        onRequestDelete: @escaping () -> Void
    ) {
        self._action = action
        self.onDuplicate = onDuplicate
        self.onRequestDelete = onRequestDelete
    }
}
