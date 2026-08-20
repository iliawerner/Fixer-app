import SwiftUI

/// Browses reusable starter Actions. It lives separately from the inline editor
/// because the sheet has its own navigation and selection lifecycle.
struct StarterLibrarySheet: View {
    @ObservedObject var settings: SettingsManager

    let onAdded: (UUID) -> Void
    let onClose: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top, spacing: 12) {
                RepairMark()
                    .frame(width: 36, height: 28)
                VStack(alignment: .leading, spacing: 3) {
                    Text("Starter actions")
                        .font(Fixer.display(28, .bold))
                        .foregroundStyle(Fixer.text)
                    Text("Add one, then give it a shortcut.")
                        .font(Fixer.sans(12))
                        .foregroundStyle(Fixer.muted)
                }
                Spacer()
                Text(StarterLibrary.all.count, format: .number.precision(.integerLength(2)))
                    .font(Fixer.mono(10, .medium))
                    .foregroundStyle(Fixer.muted)
            }
            .padding(.bottom, 16)

            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(StarterLibrary.all) { item in
                        HStack(spacing: 14) {
                            VStack(alignment: .leading, spacing: 3) {
                                Text(item.name)
                                    .font(Fixer.sans(13.5, .semibold))
                                    .foregroundStyle(Fixer.text)
                                Text(item.subtitle)
                                    .font(Fixer.sans(11))
                                    .foregroundStyle(Fixer.muted)
                            }

                            Spacer()

                            if isAdded(item) {
                                Label("Added", systemImage: "checkmark")
                                    .font(Fixer.sans(10.5, .semibold))
                                    .foregroundStyle(Fixer.fixed)
                            } else {
                                Button("Add") {
                                    add(item)
                                }
                                .buttonStyle(FixerSecondaryButton())
                            }
                        }
                        .padding(.vertical, 12)
                        .overlay(alignment: .bottom) {
                            Rectangle().fill(Fixer.line).frame(height: 1)
                        }
                    }
                }
            }
            .frame(height: 380)

            HStack {
                Spacer()
                Button("Done", action: onClose)
                    .buttonStyle(FixerPrimaryButton())
                    .keyboardShortcut(.defaultAction)
            }
            .padding(.top, 16)
        }
        .padding(24)
        .frame(width: 480)
        .background(Fixer.base)
    }

    private func isAdded(_ item: StarterAction) -> Bool {
        settings.actions.contains { $0.name == item.name }
    }

    private func add(_ item: StarterAction) {
        onAdded(settings.addStarter(item))
    }
}
