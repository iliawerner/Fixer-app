import SwiftUI

struct HistoryTextSection: View {
    let title: String
    let text: String
    let onCopy: (String) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(title)
                    .font(.headline)
                    .accessibilityAddTraits(.isHeader)
                Spacer()
                Button("Copy \(title.lowercased())", systemImage: "doc.on.doc") {
                    onCopy(text)
                }
                .labelStyle(.iconOnly)
                .buttonStyle(.borderless)
                .help("Copy \(title.lowercased())")
            }
            Text(text)
                .font(.body)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .background(Fixer.panel)
        .overlay(alignment: .bottom) {
            Rectangle().fill(Fixer.line).frame(height: 1)
        }
    }
}
