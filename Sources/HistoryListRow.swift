import SwiftUI

struct HistoryListRow: View {
    @Environment(\.colorScheme) private var colorScheme

    let entry: HistoryEntry
    let isSelected: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                selectedStyle(
                    Text(entry.action.name)
                        .font(.headline)
                        .lineLimit(1),
                    unselected: Fixer.text
                )
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

    /// Light selection keeps the native foreground for its blue and gray states.
    /// In dark appearance, native inactive rows can dim their text into the gray
    /// selection surface. Warm light ink stays readable in both selection states.
    @ViewBuilder
    private func selectedStyle<Content: View>(_ content: Content, unselected color: Color) -> some View {
        if isSelected {
            if colorScheme == .dark {
                content.foregroundStyle(Fixer.text)
            } else {
                content
            }
        } else {
            content.foregroundStyle(color)
        }
    }
}
