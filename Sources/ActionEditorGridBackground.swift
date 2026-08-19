import SwiftUI

/// Static, low-contrast square paper behind the selected Action title.
/// The grid is decorative only and deliberately too quiet to imply progress,
/// scale, selection, or another interactive mode.
struct ActionEditorGridBackground: View {
    private let cellSize: CGFloat = 18

    var body: some View {
        Canvas { context, size in
            var grid = Path()

            for x in stride(from: 0.5, through: size.width, by: cellSize) {
                grid.move(to: CGPoint(x: x, y: 0))
                grid.addLine(to: CGPoint(x: x, y: size.height))
            }

            for y in stride(from: 0.5, through: size.height, by: cellSize) {
                grid.move(to: CGPoint(x: 0, y: y))
                grid.addLine(to: CGPoint(x: size.width, y: y))
            }

            context.stroke(
                grid,
                with: .color(Fixer.text.opacity(0.035)),
                lineWidth: 0.5
            )
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}
