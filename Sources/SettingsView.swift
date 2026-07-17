import SwiftUI
import KeyboardShortcuts

struct SettingsView: View {
    @ObservedObject private var settings = SettingsManager.shared
    @ObservedObject private var appState = AppState.shared

    @State private var apiKey: String = ""
    @State private var availableModels: [GeminiModel] = []
    @State private var isLoadingModels = false
    @State private var modelError: String?
    @State private var keyValidated = false

    @State private var editingActionID: UUID?
    @State private var showLibrary = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                masthead
                if !appState.accessibilityGranted { permissionBanner }
                providerCard
                actionsSection
                statusFooter
            }
            .padding(.horizontal, 30)
            .padding(.top, 26)
            .padding(.bottom, 26)
        }
        .background(Fixer.base)
        .frame(minWidth: 480, minHeight: 560) // keep in sync with AppDelegate.openSettings() window.minSize
        .sheet(item: editorBinding) { ref in
            ActionEditor(actionID: ref.id, models: availableModels) { editingActionID = nil }
        }
        .sheet(isPresented: $showLibrary) {
            StarterLibrarySheet { showLibrary = false }
        }
        .onAppear {
            apiKey = KeychainManager.shared.getAPIKey() ?? ""
            appState.refreshAccessibility()
            if !apiKey.isEmpty { Task { await fetchModels() } }
        }
    }

    // MARK: Masthead

    private var masthead: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 8) {
                    MonoLabel("Darkroom", size: 10, tracking: 2.6, color: Fixer.muted, weight: .medium)
                    StatusDot(color: appState.isProcessing ? Fixer.safelight : Fixer.muted2, glow: appState.isProcessing)
                }
                HStack(alignment: .firstTextBaseline, spacing: 10) {
                    Text("FIXER")
                        .font(Fixer.display(48, .bold))
                        .tracking(-0.5)
                        .foregroundStyle(Fixer.text)
                    MonoLabel("latent → developer → fixed", size: 9, tracking: 1.4, color: Fixer.muted)
                        .padding(.bottom, 6)
                }
            }
            Spacer()
            HStack(spacing: 8) {
                Button { showLibrary = true } label: { Label("Library", systemImage: "film.stack") }
                    .buttonStyle(FixerSecondaryButton())
                Button {
                    let id = settings.addAction()
                    editingActionID = id
                } label: { Label("New", systemImage: "plus") }
                    .buttonStyle(FixerPrimaryButton())
            }
        }
    }

    // MARK: Permission banner (safelight)

    private var permissionBanner: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack(spacing: 9) {
                Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(Fixer.safelight)
                MonoLabel("Safelight — accessibility required", size: 10, tracking: 1.6, color: Fixer.safeText, weight: .semibold)
            }
            Text("fixer needs permission to read your selection and paste the developed result back into the app you're using.")
                .font(Fixer.sans(12.5))
                .foregroundStyle(Fixer.textDim)
                .fixedSize(horizontal: false, vertical: true)
            Button {
                PermissionsManager.promptForAccessibility()
                PermissionsManager.openAccessibilitySettings()
            } label: { Label("Open System Settings", systemImage: "arrow.up.right") }
                .buttonStyle(FixerPrimaryButton())
                .padding(.top, 2)
        }
        .padding(15)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Fixer.safelight.opacity(0.08))
        .overlay(alignment: .leading) { Rectangle().fill(Fixer.safelight).frame(width: 3) }
        .overlay(RoundedRectangle(cornerRadius: 4).stroke(Fixer.safelight.opacity(0.6), lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 4))
    }

    // MARK: Provider / key card

    private var providerCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                MonoLabel("Chemistry · Provider", size: 10, tracking: 2, color: Fixer.muted)
                Spacer()
                MonoLabel("Gemini", size: 10, tracking: 1.4, color: Fixer.text, weight: .semibold)
                    .padding(.horizontal, 9).padding(.vertical, 4)
                    .background(Fixer.film)
                    .overlay(RoundedRectangle(cornerRadius: 3).stroke(Fixer.line2))
            }

            MonoLabel("API key", size: 9, tracking: 1.8, color: Fixer.muted).padding(.top, 4)

            FixerField(borderColor: keyValidated ? Fixer.amber : Fixer.line2) {
                HStack(spacing: 8) {
                    SecureField("Paste your key from aistudio.google.com", text: $apiKey)
                        .textFieldStyle(.plain)
                        .font(Fixer.mono(12.5))
                        .foregroundStyle(Fixer.text)
                        .onChange(of: apiKey) { newValue in
                            try? KeychainManager.shared.saveAPIKey(newValue)
                            keyValidated = false
                        }
                    if keyValidated {
                        Image(systemName: "checkmark").font(.system(size: 12, weight: .bold)).foregroundStyle(Fixer.amber)
                    }
                }
            }

            HStack(spacing: 10) {
                Button { Task { await fetchModels() } } label: {
                    Label(isLoadingModels ? "Loading…" : "Fetch models", systemImage: "arrow.clockwise")
                }
                .buttonStyle(FixerSecondaryButton())
                .disabled(apiKey.isEmpty || isLoadingModels)

                if let modelError {
                    HStack(spacing: 6) {
                        Image(systemName: "exclamationmark.triangle.fill").font(.system(size: 10)).foregroundStyle(Fixer.safeText)
                        Text(modelError).font(Fixer.sans(11)).foregroundStyle(Fixer.safeText).lineLimit(1)
                    }
                } else if keyValidated {
                    HStack(spacing: 6) {
                        StatusDot(color: Fixer.amber)
                        MonoLabel("Key valid · \(availableModels.count) models loaded", size: 8.5, tracking: 1.2, color: Fixer.amber, weight: .semibold)
                    }
                }
            }

            HStack(alignment: .top, spacing: 7) {
                Image(systemName: "lock.fill").font(.system(size: 10)).foregroundStyle(Fixer.muted).padding(.top, 1)
                Text("Stored in the macOS Keychain. Your text goes only to Google Gemini.")
                    .font(Fixer.sans(11)).foregroundStyle(Fixer.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.top, 2)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Fixer.panel)
        .overlay(RoundedRectangle(cornerRadius: 6).stroke(Fixer.line2, lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }

    // MARK: Actions — film strip

    private var actionsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                MonoLabel("Exposures", size: 11, tracking: 2, color: Fixer.text, weight: .semibold)
                Spacer()
                MonoLabel("\(settings.actions.count) frames", size: 10, tracking: 1.2, color: Fixer.muted)
            }

            if settings.actions.isEmpty {
                emptyState
            } else {
                FilmFrame(edgeCode: "FIXER 400 · SAFELIGHT", edgeTrailing: "→ \(settings.actions.count)") {
                    VStack(spacing: 0) {
                        ForEach(Array(settings.actions.enumerated()), id: \.element.id) { pair in
                            let (i, action) = pair
                            ActionLedgerRow(
                                index: i + 1,
                                action: action,
                                onToggle: { settings.setEnabled($0, id: action.id) },
                                onEdit: { editingActionID = action.id },
                                onDelete: { settings.deleteAction(id: action.id) }
                            )
                            if i < settings.actions.count - 1 {
                                Rectangle().fill(Fixer.line).frame(height: 1)
                            }
                        }
                    }
                }
            }
        }
    }

    private var emptyState: some View {
        FilmFrame(edgeCode: "FIXER 400 · UNEXPOSED", edgeTrailing: "→ 0") {
            VStack(spacing: 14) {
                Image(systemName: "film").font(.system(size: 30, weight: .light)).foregroundStyle(Fixer.muted)
                Text("No exposures yet")
                    .font(Fixer.display(24, .bold)).tracking(-0.3).foregroundStyle(Fixer.text)
                Text("Create one from scratch, or load a ready-made from the library.")
                    .font(Fixer.sans(12.5)).foregroundStyle(Fixer.muted)
                    .multilineTextAlignment(.center).frame(maxWidth: 320)
                HStack(spacing: 8) {
                    Button { let id = settings.addAction(); editingActionID = id } label: { Label("New action", systemImage: "plus") }
                        .buttonStyle(FixerPrimaryButton())
                    Button { showLibrary = true } label: { Text("Browse library") }
                        .buttonStyle(FixerSecondaryButton())
                }
                .padding(.top, 4)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 26)
        }
    }

    // MARK: Footer

    private var statusFooter: some View {
        HStack {
            HStack(spacing: 7) {
                StatusDot(color: keyValidated ? Fixer.amber : Fixer.muted2)
                MonoLabel(keyValidated ? "Gemini · Key OK" : "Gemini · No key", size: 9, tracking: 1.5, color: Fixer.muted)
            }
            Spacer()
            HStack(spacing: 7) {
                MonoLabel(appState.accessibilityGranted ? "Accessibility · Granted" : "Accessibility · Blocked",
                          size: 9, tracking: 1.5,
                          color: appState.accessibilityGranted ? Fixer.muted : Fixer.safeText,
                          weight: appState.accessibilityGranted ? .regular : .semibold)
                StatusDot(color: appState.accessibilityGranted ? Fixer.amber : Fixer.safelight,
                          glow: !appState.accessibilityGranted)
            }
        }
        .padding(.top, 2)
    }

    // MARK: Model fetching

    private var editorBinding: Binding<IDRef?> {
        Binding(
            get: { editingActionID.map(IDRef.init) },
            set: { editingActionID = $0?.id }
        )
    }

    private func fetchModels() async {
        isLoadingModels = true
        modelError = nil
        do {
            let models = try await GeminiAPI.shared.fetchModels()
            availableModels = models.sorted { $0.displayName < $1.displayName }
            keyValidated = true
            isLoadingModels = false
        } catch {
            modelError = error.localizedDescription
            keyValidated = false
            isLoadingModels = false
        }
    }
}

/// Wraps a UUID so it can drive `.sheet(item:)`.
struct IDRef: Identifiable { let id: UUID }

// MARK: - Film-strip row

struct ActionLedgerRow: View {
    let index: Int
    let action: MacroAction
    let onToggle: (Bool) -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void

    @State private var hovering = false

    private var shortcutString: String? {
        KeyboardShortcuts.getShortcut(for: action.shortcutName).map { "\($0)" }
    }

    var body: some View {
        HStack(spacing: 14) {
            VStack(spacing: 5) {
                MonoLabel(String(format: "%02d", index), size: 9, tracking: 1, color: Fixer.kodak, weight: .semibold)
                Group {
                    if let s = shortcutString { Keycap(text: s) } else { SetKeyChip() }
                }
            }
            .frame(minWidth: 46)

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text(action.name)
                        .font(Fixer.sans(15, .semibold))
                        .foregroundStyle(Fixer.text)
                    if shortcutString == nil {
                        MonoLabel("Menu only", size: 8, tracking: 1.2, color: Fixer.amber, weight: .semibold)
                    }
                }
                PromptPreview(prompt: action.promptTemplate)
                    .lineLimit(2)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
            .onTapGesture(perform: onEdit)

            HStack(spacing: 12) {
                if hovering {
                    Button(action: onEdit) { Image(systemName: "pencil") }
                        .buttonStyle(.plain).foregroundStyle(Fixer.textDim)
                    Button(action: onDelete) { Image(systemName: "trash") }
                        .buttonStyle(.plain).foregroundStyle(Fixer.safeText)
                }
                // Not a real two-way binding: the row is display-only and routes
                // toggles through `onChange` → SettingsManager, which owns the state.
                FixerSwitch(isOn: .constant(action.isEnabled), onChange: onToggle)
            }
        }
        .padding(.vertical, 14)
        .opacity(action.isEnabled ? 1 : 0.6)
        .contentShape(Rectangle())
        .onHover { hovering = $0 }
    }
}

// MARK: - Output mode segmented control

struct OutputModeToggle: View {
    @Binding var mode: ActionOutputMode

    var body: some View {
        HStack(spacing: 0) {
            ForEach(ActionOutputMode.allCases) { m in
                let selected = mode == m
                Button { mode = m } label: {
                    Text(m.rawValue)
                        .font(Fixer.mono(10, .medium)).tracking(1.4).textCase(.uppercase)
                        .foregroundStyle(selected ? Fixer.base : Fixer.textDim)
                        .padding(.horizontal, 18).padding(.vertical, 7)
                        .background(selected ? Fixer.text : Color.clear)
                }
                .buttonStyle(.plain)
            }
        }
        .overlay(RoundedRectangle(cornerRadius: 3).stroke(Fixer.line2, lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 3))
    }
}
