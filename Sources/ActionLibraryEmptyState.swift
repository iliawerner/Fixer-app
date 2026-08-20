import SwiftUI

/// Small inline recovery state that avoids turning unused sidebar space into a
/// large decorative placeholder.
struct ActionLibraryEmptyState: View {
    let onCreate: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("No actions yet", systemImage: "text.badge.plus")
            .font(.callout)
            .foregroundStyle(Fixer.muted)

            Button("Create Action", action: onCreate)
                .buttonStyle(.bordered)
                .controlSize(.small)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
    }
}
