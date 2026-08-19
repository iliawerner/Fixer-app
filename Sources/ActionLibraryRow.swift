import SwiftUI

/// Compact navigation row for one saved action.
///
/// Shortcut conflict detection lives in `SettingsView`, where all actions and
/// the manual shortcut revision bridge are available; this view only renders
/// the already-derived state.
struct ActionLibraryRow: View {
    let action: MacroAction
    let shortcut: String?
    let hasConflict: Bool
    let isSelected: Bool
    let selectionNamespace: Namespace.ID
    let reduceMotion: Bool
    let onSelect: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 10) {
                HStack(spacing: 6) {
                    Text(action.name.isEmpty ? "Untitled action" : action.name)
                        .font(.callout)
                        .fontWeight(isSelected ? .semibold : .regular)
                        .foregroundStyle(isSelected ? Fixer.base : Fixer.text)
                        .lineLimit(1)

                    if hasConflict {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 9))
                            .foregroundStyle(isSelected ? Fixer.warningWash : Fixer.safeText)
                            .accessibilityLabel("Shortcut conflict")
                            .help("This shortcut is assigned to another action")
                    }
                }

                Spacer(minLength: 5)

                if let shortcut {
                    Keycap(text: shortcut, inverse: isSelected)
                } else {
                    Text("No shortcut")
                        .font(.caption)
                        .foregroundStyle(isSelected ? Fixer.base.opacity(0.74) : Fixer.muted)
                }
            }
            .padding(.horizontal, 11)
            .padding(.vertical, 9)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background {
                ZStack {
                    if isHovered, !isSelected {
                        RoundedRectangle(cornerRadius: 7)
                            .fill(Fixer.film.opacity(0.88))
                            .overlay {
                                RoundedRectangle(cornerRadius: 7)
                                    .stroke(Fixer.line2.opacity(0.72), lineWidth: 1)
                            }
                    }

                    ActionLibrarySelectionBackground(
                        isSelected: isSelected,
                        isHovered: isHovered,
                        namespace: selectionNamespace,
                        reduceMotion: reduceMotion
                    )
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(FixerHoverButtonStyle(.row))
        .onHover { isHovered = $0 }
        .animation(FixerMotion.control(reduceMotion: reduceMotion), value: isSelected)
        .animation(FixerMotion.hover(reduceMotion: reduceMotion), value: isHovered)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .accessibilityValue(isSelected ? "Selected" : "Not selected")
    }
}
