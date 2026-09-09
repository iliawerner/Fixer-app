import SwiftUI

/// Workspace tools placed inside the full-size titlebar plane.
///
/// The leading clearance belongs exclusively to the system traffic lights.
/// Creation is one native menu because blank Actions and the starter catalog are
/// two ways into the same flow. Setup stays separate at the trailing edge because
/// it describes application readiness, not Action creation.
struct ActionLibraryTitlebarRow: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isAddMenuHovered = false

    let setupIssueCount: Int
    let onAdd: () -> Void
    let onOpenLibrary: () -> Void
    let onOpenSetup: () -> Void
    let onOpenHistory: () -> Void

    var body: some View {
        let setupButton = Button("Setup", systemImage: "gearshape", action: onOpenSetup)
            .labelStyle(.iconOnly)
            .font(.body)
            .buttonStyle(FixerHoverButtonStyle(.toolbar))
            .help(setupIssueCount == 0 ? "Open setup" : "Finish setup")
            .overlay(alignment: .topTrailing) {
                if setupIssueCount > 0 {
                    Image(systemName: "exclamationmark.circle.fill")
                        .font(.caption)
                        .symbolRenderingMode(.palette)
                        .foregroundStyle(Fixer.text, Fixer.yellow)
                        .background(Circle().fill(Fixer.base))
                        .offset(x: 4, y: -4)
                        .accessibilityHidden(true)
                }
            }

        HStack(spacing: 8) {
            Menu {
                Button("Blank Action", systemImage: "doc.badge.plus", action: onAdd)
                Button(
                    "From Starter Library",
                    systemImage: "books.vertical",
                    action: onOpenLibrary
                )
            } label: {
                Label("New Action", systemImage: "plus")
                    .labelStyle(.iconOnly)
                    .font(.body)
                    .foregroundStyle(isAddMenuHovered ? Fixer.text : Fixer.textDim)
                    .frame(
                        width: WorkspaceChromeMetrics.titlebarControlSize,
                        height: WorkspaceChromeMetrics.titlebarControlSize
                    )
                    .background {
                        RoundedRectangle(cornerRadius: 7)
                            .fill(Fixer.text.opacity(isAddMenuHovered ? 0.08 : 0))
                    }
                    .overlay {
                        RoundedRectangle(cornerRadius: 7)
                            .stroke(
                                Fixer.text.opacity(isAddMenuHovered ? 0.22 : 0),
                                lineWidth: 1
                            )
                    }
                    .contentShape(.rect(cornerRadius: 7))
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .fixedSize()
            .onHover { isAddMenuHovered = $0 }
            .animation(FixerMotion.hover(reduceMotion: reduceMotion), value: isAddMenuHovered)
            .help("Create a text action")

            // Dragging belongs only to this empty gap. Declaring the whole
            // window background draggable makes AppKit consume clicks meant
            // for the adjacent SwiftUI Menu and Setup button.
            WorkspaceWindowDragRegion()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .accessibilityHidden(true)

            Button("History", systemImage: "clock.arrow.circlepath", action: onOpenHistory)
                .labelStyle(.iconOnly)
                .font(.body)
                .buttonStyle(FixerHoverButtonStyle(.toolbar))
                .help("Open history")

            if setupIssueCount > 0 {
                setupButton.accessibilityValue(
                    "\(setupIssueCount) setup steps remaining"
                )
            } else {
                setupButton
            }
        }
        .padding(.leading, WorkspaceChromeMetrics.trafficLightClearance)
        .padding(.trailing, WorkspaceChromeMetrics.titlebarTrailingPadding)
        .frame(height: WorkspaceChromeMetrics.headerHeight)
        .background(Fixer.film.opacity(0.28))
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(Fixer.line2)
                .frame(height: 1)
                .allowsHitTesting(false)
                .accessibilityHidden(true)
        }
    }
}
