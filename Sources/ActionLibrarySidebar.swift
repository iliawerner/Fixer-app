import SwiftUI

/// Compact navigation rail for saved actions and workspace-level destinations.
///
/// The sidebar receives saved actions and derived shortcut state so it never
/// owns persistence or duplicates `SettingsManager` business logic.
struct ActionLibrarySidebar: View {
    let actions: [MacroAction]
    let selectedActionID: UUID?
    let setupIssueCount: Int
    let selectionNamespace: Namespace.ID
    let reduceMotion: Bool
    let shortcutText: (MacroAction) -> String?
    let hasShortcutConflict: (MacroAction) -> Bool
    let onSelect: (UUID) -> Void
    let onAdd: () -> Void
    let onOpenLibrary: () -> Void
    let onOpenSetup: () -> Void

    private var visibleActionIDs: [UUID] {
        actions.map(\.id)
    }

    var body: some View {
        VStack(spacing: 0) {
            ActionLibraryTitlebarRow(
                setupIssueCount: setupIssueCount,
                onAdd: onAdd,
                onOpenLibrary: onOpenLibrary,
                onOpenSetup: onOpenSetup
            )

            Group {
                if actions.isEmpty {
                    ActionLibraryEmptyState(
                        onCreate: onAdd
                    )
                    .transition(FixerMotion.detailTransition(reduceMotion: reduceMotion))
                } else {
                    ScrollView {
                        LazyVStack(spacing: 3) {
                            ForEach(actions) { action in
                                ActionLibraryRow(
                                    action: action,
                                    shortcut: shortcutText(action),
                                    hasConflict: hasShortcutConflict(action),
                                    isSelected: selectedActionID == action.id,
                                    selectionNamespace: selectionNamespace,
                                    reduceMotion: reduceMotion,
                                    onSelect: { onSelect(action.id) }
                                )
                                .transition(
                                    FixerMotion.detailTransition(reduceMotion: reduceMotion)
                                )
                            }
                        }
                        .padding(8)
                    }
                    .transition(FixerMotion.detailTransition(reduceMotion: reduceMotion))
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .animation(
                FixerMotion.structural(reduceMotion: reduceMotion),
                value: visibleActionIDs
            )
        }
        .background(Fixer.base)
    }
}
