import SwiftUI

struct HistoryListRow: View {
    let entry: HistoryEntry
    let isSelected: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(entry.action.name)
                    .font(.headline)
                    .lineLimit(1)
                Spacer(minLength: 4)
                selectedStyle(
                    Image(systemName: HistoryEntryPresentation.symbol(entry))
                        .accessibilityHidden(true),
                    unselected: entry.status == .failed ? Fixer.safeText : Fixer.textDim
                )
            }
            selectedStyle(
                Text(HistoryEntryPresentation.preview(entry))
                    .font(.callout)
                    .lineLimit(2),
                unselected: Fixer.textDim
            )
            selectedStyle(
                Text(HistoryEntryPresentation.status(entry)).font(.caption),
                unselected: Fixer.muted
            )
            selectedStyle(
                Text(entry.createdAt, format: .dateTime.month(.abbreviated).day().hour().minute())
                    .font(.caption),
                unselected: Fixer.muted
            )
        }
        .padding(.vertical, 7)
        .accessibilityElement(children: .combine)
    }

    /// Native List switches selected text between white (focused blue) and dark
    /// (inactive gray). Any explicit foreground style would override that state.
    @ViewBuilder
    private func selectedStyle<Content: View>(_ content: Content, unselected color: Color) -> some View {
        if isSelected {
            content
        } else {
            content.foregroundStyle(color)
        }
    }
}
