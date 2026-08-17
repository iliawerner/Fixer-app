import SwiftUI
import KeyboardShortcuts

// MARK: - Inline action editor

struct ActionDetailPane: View {
    @ObservedObject private var settings = SettingsManager.shared

    let actionID: UUID
    let models: [GeminiModel]
    @Binding var shortcutRevision: Int
    let onSelectAction: (UUID) -> Void

    @State private var showDeleteConfirmation = false

    private var index: Int? {
        settings.actions.firstIndex { $0.id == actionID }
    }

    var body: some View {
        Group {
            if let index {
                editor(for: $settings.actions[index], index: index)
            } else {
                Color.clear
            }
        }
        .background(Fixer.panel)
    }

    @ViewBuilder
    private func editor(for action: Binding<MacroAction>, index: Int) -> some View {
        let value = action.wrappedValue

        VStack(spacing: 0) {
            actionHeader(action: action, index: index)

            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    HStack(alignment: .top, spacing: 24) {
                        runtimeState(action)
                            .frame(maxWidth: .infinity, alignment: .topLeading)
                        shortcutEditor(value)
                            .frame(maxWidth: .infinity, alignment: .topLeading)
                    }
                    .padding(.horizontal, 28)
                    .padding(.vertical, 22)

                    rule

                    promptEditor(action)
                        .padding(.horizontal, 28)
                        .padding(.vertical, 22)

                    rule

                    HStack(alignment: .top, spacing: 24) {
                        modelEditor(action)
                            .frame(maxWidth: .infinity, alignment: .topLeading)
                        outputEditor(action)
                            .frame(maxWidth: .infinity, alignment: .topLeading)
                    }
                    .padding(.horizontal, 28)
                    .padding(.vertical, 22)

                    rule

                    footer(value)
                        .padding(.horizontal, 28)
                        .padding(.vertical, 18)
                }
            }
        }
        .alert("Delete “\(displayName(value))”?", isPresented: $showDeleteConfirmation) {
            Button("Delete", role: .destructive) {
                settings.deleteAction(id: value.id)
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This removes the prompt and its shortcut. This cannot be undone.")
        }
    }

    // MARK: Header

    private func actionHeader(action: Binding<MacroAction>, index: Int) -> some View {
        ZStack {
            Fixer.yellow

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    MonoLabel(
                        "Action \(String(format: "%02d", index + 1))",
                        size: 9,
                        tracking: 1.5,
                        color: Fixer.text.opacity(0.62),
                        weight: .semibold
                    )
                    Spacer()
                    RepairMark()
                        .frame(width: 38, height: 30)
                }

                TextField("Untitled action", text: action.name)
                    .textFieldStyle(.plain)
                    .font(Fixer.display(32, .bold))
                    .tracking(-0.4)
                    .foregroundStyle(Fixer.text)
                    .lineLimit(1)

                HStack(spacing: 9) {
                    if let shortcut = currentShortcut(action.wrappedValue) {
                        Keycap(text: "\(shortcut)")
                    } else {
                        Text("No shortcut assigned")
                            .font(Fixer.sans(11.5, .medium))
                            .foregroundStyle(Fixer.text.opacity(0.58))
                    }

                    Text("Changes save automatically")
                        .font(Fixer.sans(10.5))
                        .foregroundStyle(Fixer.text.opacity(0.52))
                }
            }
            .padding(.horizontal, 28)
            .padding(.vertical, 15)
        }
        .frame(minHeight: 108)
        .overlay(alignment: .bottom) {
            Rectangle().fill(Fixer.yellowDark.opacity(0.45)).frame(height: 1)
        }
    }

    // MARK: Runtime state

    private func runtimeState(_ action: Binding<MacroAction>) -> some View {
        VStack(alignment: .leading, spacing: 9) {
            sectionLabel("Status")

            HStack(spacing: 10) {
                FixerSwitch(isOn: action.isEnabled) { enabled in
                    settings.setEnabled(enabled, id: action.wrappedValue.id)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(action.wrappedValue.isEnabled ? "Enabled" : "Disabled")
                        .font(Fixer.sans(13, .semibold))
                        .foregroundStyle(Fixer.text)
                    Text(action.wrappedValue.isEnabled ? "The shortcut can fire." : "The action stays saved but never runs.")
                        .font(Fixer.sans(11))
                        .foregroundStyle(Fixer.muted)
                }
            }
        }
    }

    private func shortcutEditor(_ action: MacroAction) -> some View {
        VStack(alignment: .leading, spacing: 9) {
            sectionLabel("Global shortcut")

            KeyboardShortcuts.Recorder(for: action.shortcutName) { _ in
                shortcutRevision += 1
            }
            .controlSize(.large)

            if let conflict = conflictingName(for: action) {
                HStack(alignment: .top, spacing: 6) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 10))
                        .foregroundStyle(Fixer.yellowDark)
                        .padding(.top, 1)
                    Text("Also used by “\(conflict)”. Reassign one before using either action.")
                        .font(Fixer.sans(10.5, .medium))
                        .foregroundStyle(Fixer.yellowDark)
                        .fixedSize(horizontal: false, vertical: true)
                }
            } else {
                Text("Use ⌘, ⌥ or ⌃ plus a key. Conflicts with other apps can’t be detected.")
                    .font(Fixer.sans(10.5))
                    .foregroundStyle(Fixer.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    // MARK: Prompt

    private func promptEditor(_ action: Binding<MacroAction>) -> some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack {
                sectionLabel("Prompt template")
                Spacer()
                Button("Insert {text}") {
                    action.promptTemplate.wrappedValue += "{text}"
                }
                .buttonStyle(FixerSecondaryButton())
            }

            FixerField {
                TextEditor(text: action.promptTemplate)
                    .scrollContentBackground(.hidden)
                    .font(Fixer.mono(12.5))
                    .foregroundStyle(Fixer.text)
                    .frame(minHeight: 138)
            }

            HStack(alignment: .top, spacing: 4) {
                Text("{text}")
                    .font(Fixer.mono(10.5, .semibold))
                    .foregroundStyle(Fixer.yellowDark)
                Text("marks where the current selection will be inserted. Without it, the selection is appended to the prompt.")
                    .font(Fixer.sans(10.5))
                    .foregroundStyle(Fixer.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    // MARK: Model and output

    private func modelEditor(_ action: Binding<MacroAction>) -> some View {
        VStack(alignment: .leading, spacing: 9) {
            sectionLabel("Model")

            FixerField {
                HStack(spacing: 8) {
                    TextField("models/gemini-2.5-flash", text: action.modelName)
                        .textFieldStyle(.plain)
                        .font(Fixer.mono(11.5))
                        .foregroundStyle(Fixer.text)

                    if !models.isEmpty {
                        Menu {
                            ForEach(models) { model in
                                Button(model.displayName) {
                                    action.modelName.wrappedValue = model.name
                                }
                            }
                        } label: {
                            Image(systemName: "chevron.down")
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundStyle(Fixer.muted)
                                .frame(width: 20, height: 20)
                        }
                        .menuStyle(.borderlessButton)
                        .menuIndicator(.hidden)
                        .fixedSize()
                        .help("Choose a loaded model")
                    }
                }
            }

            Text(
                models.isEmpty
                    ? "Load available models in Setup, or enter an exact model ID."
                    : "\(currentModelLabel(action.wrappedValue.modelName)) · edit the ID or choose a loaded model."
            )
            .font(Fixer.sans(10.5))
            .foregroundStyle(Fixer.muted)
            .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func outputEditor(_ action: Binding<MacroAction>) -> some View {
        VStack(alignment: .leading, spacing: 9) {
            sectionLabel("Output mode")
            OutputModeToggle(mode: action.outputMode)
            Text(
                action.wrappedValue.outputMode == .replace
                    ? "Replaces the selected text. Try ⌘Z in the active app to undo."
                    : "Keeps the original and adds the result on a new line."
            )
            .font(Fixer.sans(10.5))
            .foregroundStyle(Fixer.muted)
            .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: Footer

    private func footer(_ action: MacroAction) -> some View {
        HStack(spacing: 10) {
            HStack(spacing: 7) {
                StatusDot(color: Fixer.fixed)
                Text("Saved locally")
                    .font(Fixer.sans(10.5, .medium))
                    .foregroundStyle(Fixer.muted)
            }

            Spacer()

            Button("Duplicate") {
                if let id = settings.duplicate(id: action.id) {
                    onSelectAction(id)
                }
            }
            .buttonStyle(FixerSecondaryButton())

            Button("Delete") {
                showDeleteConfirmation = true
            }
            .buttonStyle(FixerSecondaryButton(tint: Fixer.safeText))
        }
    }

    private var rule: some View {
        Rectangle()
            .fill(Fixer.line)
            .frame(height: 1)
            .padding(.horizontal, 28)
    }

    private func sectionLabel(_ text: String) -> some View {
        MonoLabel(text, size: 9.5, tracking: 1.4, color: Fixer.muted, weight: .semibold)
    }

    private func displayName(_ action: MacroAction) -> String {
        action.name.isEmpty ? "this action" : action.name
    }

    private func currentShortcut(_ action: MacroAction) -> KeyboardShortcuts.Shortcut? {
        _ = shortcutRevision
        return KeyboardShortcuts.getShortcut(for: action.shortcutName)
    }

    private func conflictingName(for action: MacroAction) -> String? {
        guard let mine = currentShortcut(action) else { return nil }
        for other in settings.actions where other.id != action.id {
            if KeyboardShortcuts.getShortcut(for: other.shortcutName) == mine {
                return other.name
            }
        }
        return nil
    }

    private func currentModelLabel(_ id: String) -> String {
        models.first(where: { $0.name == id })?.displayName
            ?? id.replacingOccurrences(of: "models/", with: "")
    }
}

// MARK: - Output mode

struct OutputModeToggle: View {
    @Binding var mode: ActionOutputMode

    var body: some View {
        HStack(spacing: 0) {
            ForEach(ActionOutputMode.allCases) { option in
                let selected = option == mode
                Button {
                    mode = option
                } label: {
                    Text(option.rawValue)
                        .font(Fixer.sans(12, selected ? .semibold : .medium))
                        .foregroundStyle(selected ? Fixer.base : Fixer.textDim)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(selected ? Fixer.text : Fixer.film)
                }
                .buttonStyle(.plain)
            }
        }
        .overlay(RoundedRectangle(cornerRadius: 6).stroke(Fixer.line2, lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }
}

// MARK: - Starter library

struct StarterLibrarySheet: View {
    @ObservedObject private var settings = SettingsManager.shared

    let onAdded: (UUID) -> Void
    let onClose: () -> Void

    private func isAdded(_ item: StarterAction) -> Bool {
        settings.actions.contains { $0.name == item.name }
    }

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
                Text(String(format: "%02d", StarterLibrary.all.count))
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
                                HStack(spacing: 5) {
                                    Image(systemName: "checkmark")
                                        .font(.system(size: 9, weight: .bold))
                                    Text("Added")
                                        .font(Fixer.sans(10.5, .semibold))
                                }
                                .foregroundStyle(Fixer.fixed)
                            } else {
                                Button("Add") {
                                    let id = settings.addStarter(item)
                                    onAdded(id)
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
                Button("Done") { onClose() }
                    .buttonStyle(FixerPrimaryButton())
                    .keyboardShortcut(.defaultAction)
            }
            .padding(.top, 16)
        }
        .padding(24)
        .frame(width: 480)
        .background(Fixer.base)
    }
}
