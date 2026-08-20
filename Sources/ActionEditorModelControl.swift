import SwiftUI

/// Presents human-readable provider names first. The exact API resource ID is
/// available as an advanced control for models that are not in the loaded list.
struct ActionEditorModelControl: View {
    @Binding var action: MacroAction
    let models: [GeminiModel]

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var revealsCustomModelID = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ActionEditorSectionLabel("Model")

            if models.isEmpty {
                Label("No loaded models", systemImage: "arrow.triangle.2.circlepath")
                    .font(.caption)
                    .foregroundStyle(Fixer.muted)
            } else {
                Picker("Model", selection: $action.modelName) {
                    if !isCurrentModelLoaded {
                        Text(shortModelID(action.modelName))
                            .tag(action.modelName)
                    }

                    ForEach(models) { model in
                        Text(pickerLabel(for: model))
                            .tag(model.name)
                    }
                }
                .labelsHidden()
                .pickerStyle(.menu)
                .controlSize(.regular)
                .frame(maxWidth: 420, alignment: .leading)
            }

            if showsModelIDField {
                FixerField {
                    TextField("models/gemini-3.6-flash", text: $action.modelName)
                        .textFieldStyle(.plain)
                        .font(.callout.monospaced())
                        .foregroundStyle(Fixer.text)
                        .accessibilityLabel("Custom model identifier")
                }
                .frame(maxWidth: 420, alignment: .leading)
                .transition(modelIDTransition)
            }

            if canToggleModelIDField {
                Button(action: toggleModelIDField) {
                    HStack(spacing: 5) {
                        Image(systemName: "chevron.right")
                            .font(.caption.bold())
                            .rotationEffect(
                                .degrees(reduceMotion ? 0 : (revealsCustomModelID ? 90 : 0))
                            )
                        Text(revealsCustomModelID ? "Hide model ID" : "Custom model ID")
                    }
                    .font(.caption)
                    .foregroundStyle(Fixer.textDim)
                }
                .buttonStyle(FixerHoverButtonStyle(.inline))
                .accessibilityHint("Show or hide the exact Gemini API model identifier")
            } else if models.isEmpty {
                Text("Load models in Setup, or enter an exact model ID.")
                    .font(.caption)
                    .foregroundStyle(Fixer.muted)
                    .fixedSize(horizontal: false, vertical: true)
            } else if !isCurrentModelLoaded {
                Text("This action uses a custom model ID.")
                    .font(.caption)
                    .foregroundStyle(Fixer.muted)
            }
        }
        .animation(FixerMotion.structural(reduceMotion: reduceMotion), value: revealsCustomModelID)
        .animation(FixerMotion.structural(reduceMotion: reduceMotion), value: isCurrentModelLoaded)
    }

    private var isCurrentModelLoaded: Bool {
        models.contains { $0.name == action.modelName }
    }

    private var showsModelIDField: Bool {
        models.isEmpty || !isCurrentModelLoaded || revealsCustomModelID
    }

    private var canToggleModelIDField: Bool {
        !models.isEmpty && isCurrentModelLoaded
    }

    private var modelIDTransition: AnyTransition {
        reduceMotion
            ? .opacity
            : .opacity.combined(with: .move(edge: .top))
    }

    private func toggleModelIDField() {
        withAnimation(FixerMotion.structural(reduceMotion: reduceMotion)) {
            revealsCustomModelID.toggle()
        }
    }

    private func pickerLabel(for model: GeminiModel) -> String {
        let hasDuplicateDisplayName = models.contains { candidate in
            candidate.id != model.id && candidate.displayName == model.displayName
        }
        return hasDuplicateDisplayName ? Self.modelMenuLabel(for: model) : model.displayName
    }

    private func shortModelID(_ resourceName: String) -> String {
        let prefix = "models/"
        return resourceName.hasPrefix(prefix)
            ? String(resourceName.dropFirst(prefix.count))
            : resourceName
    }

    /// Provider display names are not guaranteed to be unique. Pairing duplicate
    /// names with their shortened resource ID keeps menu choices deterministic.
    static func modelMenuLabel(for model: GeminiModel) -> String {
        let prefix = "models/"
        let shortID = model.name.hasPrefix(prefix)
            ? String(model.name.dropFirst(prefix.count))
            : model.name
        return "\(model.displayName) — \(shortID)"
    }
}
