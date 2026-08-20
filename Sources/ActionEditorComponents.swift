import SwiftUI

// MARK: - Layout

/// Shared Action editor geometry. Keeping these values together prevents each
/// extracted section from inventing its own spacing rhythm.
enum ActionEditorMetrics {
    static let contentInset: CGFloat = 22
    /// Keeps the Prompt aligned with the compact one-column settings stack.
    /// Together with the sidebar and insets this produces the natural 820 pt
    /// workspace width without stretching the primary input into empty space.
    static let contentMaximumWidth: CGFloat = 480
    static let sectionVerticalInset: CGFloat = 12
    static let settingSpacing: CGFloat = 20
    static let headerHorizontalInset: CGFloat = 18
    static let headerNameMaximumWidth: CGFloat = 420
    static let promptMinimumHeight: CGFloat = 160
    static let promptDefaultHeight: CGFloat = 170
    /// Default windows stay compact; tall user-resized windows hand their
    /// surplus height to the primary writing surface instead of empty canvas.
    static let promptMaximumHeight: CGFloat = 360
}

// MARK: - Section chrome

struct ActionEditorRule: View {
    var body: some View {
        Rectangle()
            .fill(Fixer.line)
            .frame(height: 1)
            .accessibilityHidden(true)
    }
}

struct ActionEditorSectionLabel: View {
    let text: String

    init(_ text: String) {
        self.text = text
    }

    var body: some View {
        Text(text)
            .font(.subheadline)
            .bold()
            .foregroundStyle(Fixer.text)
    }
}
