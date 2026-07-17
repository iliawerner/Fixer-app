import SwiftUI
import KeyboardShortcuts

// MARK: - Action editor ("edit frame")

struct ActionEditor: View {
    @ObservedObject private var settings = SettingsManager.shared
    let actionID: UUID
    let models: [GeminiModel]
    let onClose: () -> Void

    // Bumped whenever a shortcut is recorded, forcing the body (and the live
    // conflict check) to re-evaluate — the recorder writes to its own store, not
    // to `settings`, so nothing else would invalidate the view.
    @State private var shortcutRev = 0
    // Snapshot of model availability captured when the editor opens, so the model
    // control never swaps TextField↔Menu mid-edit if a fetch completes meanwhile.
    @State private var modelsSnapshot: [GeminiModel]?

    private var index: Int? { settings.actions.firstIndex { $0.id == actionID } }
    private var effectiveModels: [GeminiModel] { modelsSnapshot ?? models }

    var body: some View {
        Group {
            if let i = index {
                editor(for: $settings.actions[i])
            } else {
                // The action was deleted while its editor sheet was open — there's
                // nothing to edit, so dismiss the sheet as soon as it appears.
                Color.clear.onAppear(perform: onClose)
            }
        }
        .frame(width: 520)
        .background(Fixer.base)
        .onAppear { if modelsSnapshot == nil { modelsSnapshot = models } }
    }

    @ViewBuilder
    private func editor(for action: Binding<MacroAction>) -> some View {
        let a = action.wrappedValue

        VStack(alignment: .leading, spacing: 0) {
            // Head
            HStack {
                MonoLabel("Edit frame · \(a.name.isEmpty ? "untitled" : a.name)", size: 10, tracking: 2, color: Fixer.muted)
                Spacer()
                HStack(spacing: 10) {
                    MonoLabel(a.isEnabled ? "Armed" : "Off", size: 9, tracking: 1.5,
                              color: a.isEnabled ? Fixer.safeText : Fixer.muted, weight: .semibold)
                    FixerSwitch(isOn: action.isEnabled) { settings.setEnabled($0, id: a.id) }
                }
            }
            .padding(.bottom, 16)

            // Name
            fieldLabel("Name")
            FixerField {
                TextField("Action name", text: action.name)
                    .textFieldStyle(.plain)
                    .font(Fixer.sans(14, .semibold))
                    .foregroundStyle(Fixer.text)
            }

            // Shortcut + Model
            HStack(alignment: .top, spacing: 16) {
                VStack(alignment: .leading, spacing: 6) {
                    fieldLabel("Developer key")
                    KeyboardShortcuts.Recorder(for: a.shortcutName) { _ in shortcutRev += 1 }
                        .controlSize(.large)
                    // `shortcutRev >= 0` is always true; it exists only to make this
                    // view depend on shortcutRev so the conflict check re-runs after
                    // a shortcut is recorded (the recorder writes to its own store).
                    if shortcutRev >= 0, let conflict = conflictingName(for: a) {
                        HStack(spacing: 6) {
                            Image(systemName: "exclamationmark.triangle.fill").font(.system(size: 10)).foregroundStyle(Fixer.safeText)
                            Text("Also used by \u{201C}\(conflict)\u{201D}")
                                .font(Fixer.mono(9, .medium)).foregroundStyle(Fixer.safeText)
                        }
                    }
                }
                VStack(alignment: .leading, spacing: 6) {
                    fieldLabel("Model")
                    modelPicker(action)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.top, 14)

            // Shortcut guidance — explains the macOS constraints.
            Text("Use \u{2318} \u{2325} \u{2303} + a key. Bare keys, Tab, and the 🌐 / Spotlight key are reserved by macOS and can\u{2019}t be recorded.")
                .font(Fixer.sans(10.5))
                .foregroundStyle(Fixer.muted)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 8)

            // Output
            fieldLabel("Output").padding(.top, 16)
            HStack(spacing: 12) {
                OutputModeToggle(mode: action.outputMode)
                Text(a.outputMode == .append ? "Result is added after your selection." : "Result replaces your selection.")
                    .font(Fixer.sans(11.5)).foregroundStyle(Fixer.muted)
            }

            // Prompt
            HStack {
                fieldLabel("Prompt")
                Spacer()
                Button {
                    action.promptTemplate.wrappedValue += "{text}"
                } label: { Label("Insert {text}", systemImage: "plus") }
                    .buttonStyle(FixerSecondaryButton())
            }
            .padding(.top, 16)

            FixerField {
                TextEditor(text: action.promptTemplate)
                    .scrollContentBackground(.hidden)
                    .font(Fixer.sans(13.5))
                    .foregroundStyle(Fixer.textDim)
                    .frame(minHeight: 84)
            }
            HStack(spacing: 0) {
                Text("{text}").font(Fixer.mono(10.5, .semibold)).foregroundStyle(Fixer.amber)
                Text(" is the latent image — replaced by your selection at run time.").font(Fixer.sans(11)).foregroundStyle(Fixer.muted)
            }
            .padding(.top, 6)

            Rectangle().fill(Fixer.line).frame(height: 1).padding(.top, 18)

            // Footer
            HStack {
                HStack(spacing: 8) {
                    Button { settings.duplicate(id: a.id); onClose() } label: { Text("Duplicate") }
                        .buttonStyle(FixerSecondaryButton())
                    Button { settings.deleteAction(id: a.id); onClose() } label: { Text("Delete") }
                        .buttonStyle(FixerSecondaryButton(tint: Fixer.safeText))
                }
                Spacer()
                Button(action: onClose) { Text("Done") }
                    .buttonStyle(FixerPrimaryButton())
                    .keyboardShortcut(.defaultAction)
            }
            .padding(.top, 16)
        }
        .padding(24)
    }

    private func fieldLabel(_ text: String) -> some View {
        MonoLabel(text, size: 9, tracking: 1.8, color: Fixer.muted)
    }

    @ViewBuilder
    private func modelPicker(_ action: Binding<MacroAction>) -> some View {
        if effectiveModels.isEmpty {
            FixerField {
                TextField("models/gemini-2.5-flash", text: action.modelName)
                    .textFieldStyle(.plain).font(Fixer.mono(12)).foregroundStyle(Fixer.text)
            }
        } else {
            Menu {
                ForEach(effectiveModels) { m in
                    Button(m.displayName) { action.modelName.wrappedValue = m.name }
                }
            } label: {
                HStack {
                    Text(currentModelLabel(action.wrappedValue.modelName))
                        .font(Fixer.sans(13)).foregroundStyle(Fixer.text).lineLimit(1)
                    Spacer()
                    Image(systemName: "chevron.down").font(.system(size: 10, weight: .semibold)).foregroundStyle(Fixer.muted)
                }
                .padding(.horizontal, 11).padding(.vertical, 9)
                .background(Fixer.panel)
                .overlay(RoundedRectangle(cornerRadius: 3).stroke(Fixer.line2))
                .clipShape(RoundedRectangle(cornerRadius: 3))
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
        }
    }

    private func currentModelLabel(_ id: String) -> String {
        effectiveModels.first(where: { $0.name == id })?.displayName ?? id
    }

    /// Returns the name of another action that resolves to the same shortcut, if any.
    private func conflictingName(for a: MacroAction) -> String? {
        guard let mine = KeyboardShortcuts.getShortcut(for: a.shortcutName) else { return nil }
        for other in settings.actions where other.id != a.id {
            if KeyboardShortcuts.getShortcut(for: other.shortcutName) == mine {
                return other.name
            }
        }
        return nil
    }
}

// MARK: - Starter library

struct StarterLibrarySheet: View {
    @ObservedObject private var settings = SettingsManager.shared
    let onClose: () -> Void

    // "Added" is derived from the real action list (by name), so it survives
    // reopening the sheet and prevents silently creating duplicate actions.
    private func isAdded(_ item: StarterAction) -> Bool {
        settings.actions.contains { $0.name == item.name }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .firstTextBaseline) {
                MonoLabel("Library · ready-made frames", size: 11, tracking: 2, color: Fixer.text, weight: .semibold)
                Spacer()
                MonoLabel("\(StarterLibrary.all.count)", size: 10, tracking: 1, color: Fixer.muted)
            }
            .padding(.bottom, 6)

            Text("Load one, then set a developer key for it.")
                .font(Fixer.sans(12)).foregroundStyle(Fixer.muted)
                .padding(.bottom, 8)

            ScrollView {
                VStack(spacing: 0) {
                    ForEach(StarterLibrary.all) { item in
                        HStack(spacing: 12) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(item.name).font(Fixer.sans(13.5, .semibold)).foregroundStyle(Fixer.text)
                                Text(item.subtitle).font(Fixer.sans(11)).foregroundStyle(Fixer.muted)
                            }
                            Spacer()
                            if isAdded(item) {
                                HStack(spacing: 5) {
                                    Image(systemName: "checkmark").font(.system(size: 10, weight: .bold))
                                    MonoLabel("Loaded", size: 8.5, tracking: 1.2, color: Fixer.amber, weight: .semibold)
                                }
                                .foregroundStyle(Fixer.amber)
                            } else {
                                Button {
                                    settings.addStarter(item)
                                } label: { Label("Load", systemImage: "plus") }
                                    .buttonStyle(FixerSecondaryButton())
                            }
                        }
                        .padding(.vertical, 12)
                        Rectangle().fill(Fixer.line).frame(height: 1)
                    }
                }
            }
            .frame(height: 360)

            HStack {
                Spacer()
                Button(action: onClose) { Text("Done") }
                    .buttonStyle(FixerPrimaryButton())
                    .keyboardShortcut(.defaultAction)
            }
            .padding(.top, 14)
        }
        .padding(24)
        .frame(width: 460)
        .background(Fixer.base)
    }
}
