import SwiftUI
import KeyboardShortcuts

struct SettingsView: View {
    @ObservedObject private var settings: SettingsManager
    @ObservedObject private var appState: AppState
    @StateObject private var provider: ProviderSetupController

    private let refreshAccessibilityOnAppear: Bool

    @State private var selectedActionID: UUID?
    @State private var searchQuery = ""
    @State private var showLibrary = false
    @State private var showSetup = false
    @State private var shortcutRevision = 0

    @MainActor
    init(
        settings: SettingsManager = .shared,
        appState: AppState = .shared,
        provider: ProviderSetupController? = nil,
        refreshAccessibilityOnAppear: Bool = true
    ) {
        _settings = ObservedObject(wrappedValue: settings)
        _appState = ObservedObject(wrappedValue: appState)
        _provider = StateObject(wrappedValue: provider ?? ProviderSetupController())
        self.refreshAccessibilityOnAppear = refreshAccessibilityOnAppear
    }

    private var filteredActions: [MacroAction] {
        settings.actions.filter { ActionListFilter.matches($0, query: searchQuery) }
    }

    private var actionIDs: [UUID] {
        settings.actions.map(\.id)
    }

    private var setupIssueCount: Int {
        SetupReadiness.issueCount(
            accessibilityGranted: appState.accessibilityGranted,
            hasStoredKey: provider.hasStoredKey,
            hasRunnableAction: settings.actions.contains(where: isRunnableAction)
        )
    }

    var body: some View {
        VStack(spacing: 0) {
            if setupIssueCount > 0 {
                setupStrip
            }

            HStack(spacing: 0) {
                actionLibrary
                    .frame(width: 306)

                Rectangle()
                    .fill(Fixer.line2)
                    .frame(width: 1)

                detailPane
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .background(Fixer.base)
        .frame(minWidth: 900, minHeight: 620)
        .sheet(isPresented: $showSetup) {
            ProviderSetupSheet(
                appState: appState,
                settings: settings,
                provider: provider,
                refreshAccessibilityOnAppear: refreshAccessibilityOnAppear,
                onClose: { showSetup = false }
            )
        }
        .sheet(isPresented: $showLibrary) {
            StarterLibrarySheet(
                settings: settings,
                onAdded: { id in selectedActionID = id },
                onClose: { showLibrary = false }
            )
        }
        .onAppear {
            if refreshAccessibilityOnAppear {
                appState.refreshAccessibility()
            }
            if selectedActionID == nil {
                selectedActionID = settings.actions.first?.id
            }
            if provider.hasStoredKey,
               provider.availableModels.isEmpty,
               !provider.isLoadingModels {
                provider.fetchModels()
            }
        }
        .onChange(of: actionIDs) { ids in
            guard let selectedActionID, ids.contains(selectedActionID) else {
                self.selectedActionID = ids.first
                return
            }
        }
    }

    // MARK: Setup strip

    private var setupStrip: some View {
        HStack(spacing: 12) {
            RepairMark()
                .frame(width: 34, height: 24)

            VStack(alignment: .leading, spacing: 2) {
                Text("Finish setup before actions can run")
                    .font(Fixer.sans(12.5, .semibold))
                    .foregroundStyle(Fixer.text)
                Text(setupSummary)
                    .font(Fixer.sans(11))
                    .foregroundStyle(Fixer.muted)
            }

            Spacer()

            Button("Open setup") { showSetup = true }
                .buttonStyle(FixerSecondaryButton(tint: Fixer.text))
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 9)
        .background(Fixer.yellowWash)
        .overlay(alignment: .bottom) {
            Rectangle().fill(Fixer.yellowDark.opacity(0.45)).frame(height: 1)
        }
    }

    private var setupSummary: String {
        let issue = setupIssueCount == 1 ? "step" : "steps"
        return "\(setupIssueCount) \(issue) left · permission, API key and a shortcut are required"
    }

    // MARK: Action library

    private var actionLibrary: some View {
        VStack(spacing: 0) {
            HStack(spacing: 11) {
                RepairMark()
                    .frame(width: 34, height: 28)

                VStack(alignment: .leading, spacing: 1) {
                    Text("FIXER")
                        .font(Fixer.sans(22, .bold))
                        .tracking(2.8)
                        .foregroundStyle(Fixer.text)
                    MonoLabel("Text actions", size: 8.5, tracking: 1.5, color: Fixer.muted)
                }

                Spacer()

                Button {
                    let id = settings.addAction()
                    selectedActionID = id
                    searchQuery = ""
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 13, weight: .bold))
                        .frame(width: 18, height: 18)
                }
                .buttonStyle(FixerPrimaryButton())
                .help("New action")
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 13)

            HStack {
                MonoLabel("Your actions", size: 9.5, tracking: 1.4, color: Fixer.text, weight: .semibold)
                Spacer()
                Text(String(format: "%02d", settings.actions.count))
                    .font(Fixer.mono(10, .medium))
                    .foregroundStyle(Fixer.muted)
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 9)

            searchField
                .padding(.horizontal, 12)
                .padding(.bottom, 11)

            Rectangle().fill(Fixer.line).frame(height: 1)

            if filteredActions.isEmpty {
                emptySearchState
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(filteredActions) { action in
                            ActionLibraryRow(
                                action: action,
                                shortcut: shortcut(for: action).map { "\($0)" },
                                hasConflict: hasShortcutConflict(action),
                                isSelected: selectedActionID == action.id,
                                onSelect: { selectedActionID = action.id }
                            )
                        }
                    }
                }
            }

            Rectangle().fill(Fixer.line).frame(height: 1)

            HStack(spacing: 14) {
                Button("Browse starters") { showLibrary = true }
                    .buttonStyle(.plain)
                    .font(Fixer.sans(11.5, .medium))
                    .foregroundStyle(Fixer.textDim)

                Spacer()

                Button {
                    showSetup = true
                } label: {
                    HStack(spacing: 6) {
                        StatusDot(color: setupIssueCount == 0 ? Fixer.fixed : Fixer.yellowDark)
                        Text("Setup")
                    }
                }
                .buttonStyle(.plain)
                .font(Fixer.sans(11.5, .medium))
                .foregroundStyle(Fixer.textDim)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 13)
        }
        .background(Fixer.base)
    }

    private var searchField: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(Fixer.muted)
            TextField("Search actions", text: $searchQuery)
                .textFieldStyle(.plain)
                .font(Fixer.sans(12.5))
                .foregroundStyle(Fixer.text)
            if !searchQuery.isEmpty {
                Button {
                    searchQuery = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 11))
                        .foregroundStyle(Fixer.muted2)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(Fixer.panel)
        .overlay(RoundedRectangle(cornerRadius: 6).stroke(Fixer.line, lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }

    private var emptySearchState: some View {
        VStack(spacing: 9) {
            Spacer()
            Image(systemName: settings.actions.isEmpty ? "text.badge.plus" : "magnifyingglass")
                .font(.system(size: 24, weight: .light))
                .foregroundStyle(Fixer.muted2)
            Text(settings.actions.isEmpty ? "No actions yet" : "No matching actions")
                .font(Fixer.sans(13, .semibold))
                .foregroundStyle(Fixer.text)
            if settings.actions.isEmpty {
                Button("Create an action") {
                    selectedActionID = settings.addAction()
                }
                .buttonStyle(FixerPrimaryButton())
            } else {
                Button("Clear search") { searchQuery = "" }
                    .buttonStyle(FixerSecondaryButton())
            }
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(24)
    }

    // MARK: Detail

    @ViewBuilder
    private var detailPane: some View {
        if let id = selectedActionID, settings.actions.contains(where: { $0.id == id }) {
            ActionDetailPane(
                settings: settings,
                actionID: id,
                models: provider.availableModels,
                shortcutRevision: $shortcutRevision,
                onSelectAction: { selectedActionID = $0 }
            )
            .id(id)
        } else {
            VStack(spacing: 15) {
                RepairMark(crossed: true)
                    .frame(width: 54, height: 44)
                Text("Choose an action")
                    .font(Fixer.display(28, .bold))
                    .foregroundStyle(Fixer.text)
                Text("Select one from the list, or create a new action.")
                    .font(Fixer.sans(12.5))
                    .foregroundStyle(Fixer.muted)
                Button("New action") {
                    selectedActionID = settings.addAction()
                }
                .buttonStyle(FixerPrimaryButton())
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Fixer.panel)
        }
    }

    // MARK: Shortcut state

    private func shortcut(for action: MacroAction) -> KeyboardShortcuts.Shortcut? {
        _ = shortcutRevision
        return KeyboardShortcuts.getShortcut(for: action.shortcutName)
    }

    private func hasShortcutConflict(_ action: MacroAction) -> Bool {
        guard let value = shortcut(for: action) else { return false }
        return settings.actions.contains { other in
            other.id != action.id && shortcut(for: other) == value
        }
    }

    private func isRunnableAction(_ action: MacroAction) -> Bool {
        action.isEnabled && shortcut(for: action) != nil && !hasShortcutConflict(action)
    }

}

// MARK: - Sidebar row

private struct ActionLibraryRow: View {
    let action: MacroAction
    let shortcut: String?
    let hasConflict: Bool
    let isSelected: Bool
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 10) {
                VStack(alignment: .leading, spacing: 0) {
                    HStack(spacing: 6) {
                        Text(action.name.isEmpty ? "Untitled action" : action.name)
                            .font(Fixer.sans(13.5, .semibold))
                            .foregroundStyle(isSelected ? Fixer.base : Fixer.text)
                            .lineLimit(1)

                        if hasConflict {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.system(size: 9))
                                .foregroundStyle(Fixer.yellow)
                                .accessibilityLabel("Shortcut conflict")
                        }
                    }
                }

                Spacer(minLength: 5)

                if let shortcut {
                    Keycap(text: shortcut, inverse: isSelected)
                } else {
                    SetKeyChip()
                }

                StatusDot(
                    color: action.isEnabled ? Fixer.yellow : (isSelected ? Fixer.base.opacity(0.32) : Fixer.muted2)
                )
            }
            .padding(.horizontal, 13)
            .padding(.vertical, 11)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(isSelected ? Fixer.text : Color.clear)
            .overlay(alignment: .leading) {
                Rectangle()
                    .fill(isSelected ? Fixer.yellow : Color.clear)
                    .frame(width: 3)
            }
            .contentShape(Rectangle())
            .opacity(action.isEnabled || isSelected ? 1 : 0.5)
        }
        .buttonStyle(.plain)
        .overlay(alignment: .bottom) {
            Rectangle().fill(Fixer.line).frame(height: 1)
        }
    }
}

// MARK: - Setup sheet

private struct ProviderSetupSheet: View {
    @ObservedObject var appState: AppState
    @ObservedObject var settings: SettingsManager
    @ObservedObject var provider: ProviderSetupController

    let refreshAccessibilityOnAppear: Bool
    let onClose: () -> Void

    private var apiKeyBinding: Binding<String> {
        Binding(
            get: { provider.apiKey },
            set: { provider.updateAPIKey($0) }
        )
    }

    private var hasShortcut: Bool {
        settings.actions.contains { action in
            guard action.isEnabled,
                  let value = KeyboardShortcuts.getShortcut(for: action.shortcutName) else {
                return false
            }
            return !settings.actions.contains { other in
                other.id != action.id
                    && KeyboardShortcuts.getShortcut(for: other.shortcutName) == value
            }
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top, spacing: 12) {
                RepairMark()
                    .frame(width: 36, height: 28)
                VStack(alignment: .leading, spacing: 3) {
                    Text("Finish setup")
                        .font(Fixer.display(28, .bold))
                        .foregroundStyle(Fixer.text)
                    Text("Permission, provider and at least one shortcut make Fixer ready.")
                        .font(Fixer.sans(12))
                        .foregroundStyle(Fixer.muted)
                }
                Spacer()
            }
            .padding(.bottom, 20)

            setupSection(
                number: "01",
                title: "Accessibility",
                isComplete: appState.accessibilityGranted
            ) {
                Text("Allows Fixer to copy selected text and send the result back to the app you’re using.")
                    .font(Fixer.sans(12))
                    .foregroundStyle(Fixer.textDim)
                    .fixedSize(horizontal: false, vertical: true)

                if !appState.accessibilityGranted {
                    Button("Open System Settings") {
                        PermissionsManager.promptForAccessibility()
                        PermissionsManager.openAccessibilitySettings()
                    }
                    .buttonStyle(FixerPrimaryButton())
                    .padding(.top, 9)
                }
            }

            Rectangle().fill(Fixer.line).frame(height: 1).padding(.vertical, 18)

            setupSection(
                number: "02",
                title: "Gemini API key",
                isComplete: provider.hasStoredKey
            ) {
                FixerField(borderColor: provider.keyValidated ? Fixer.fixed : Fixer.line2) {
                    HStack(spacing: 8) {
                        SecureField("Paste your key", text: apiKeyBinding)
                            .textFieldStyle(.plain)
                            .font(Fixer.mono(12))
                            .foregroundStyle(Fixer.text)

                        if provider.keyValidated {
                            Image(systemName: "checkmark")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundStyle(Fixer.fixed)
                        }
                    }
                }

                HStack(spacing: 10) {
                    Button(provider.isLoadingModels ? "Checking…" : "Check key & load models") {
                        provider.fetchModels()
                    }
                    .buttonStyle(FixerPrimaryButton())
                    .disabled(!provider.hasStoredKey || provider.isLoadingModels)

                    Link("Get a key ↗", destination: URL(string: "https://aistudio.google.com/app/apikey")!)
                        .font(Fixer.sans(11.5, .medium))
                        .foregroundStyle(Fixer.textDim)
                }
                .padding(.top, 10)

                if let modelError = provider.modelError {
                    Text(modelError)
                        .font(Fixer.sans(11))
                        .foregroundStyle(Fixer.safeText)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.top, 8)
                } else if provider.keyValidated {
                    Text("Key works · \(provider.availableModels.count) text models loaded")
                        .font(Fixer.sans(11, .medium))
                        .foregroundStyle(Fixer.fixed)
                        .padding(.top, 8)
                }

                HStack(alignment: .top, spacing: 6) {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 9))
                        .padding(.top, 2)
                    Text("Stored in the macOS Keychain. Selected text goes only to Google Gemini.")
                        .font(Fixer.sans(10.5))
                }
                .foregroundStyle(Fixer.muted)
                .padding(.top, 10)

                if provider.hasStoredKey {
                    Button("Remove key") {
                        provider.removeKey()
                    }
                    .buttonStyle(.plain)
                    .font(Fixer.sans(11, .medium))
                    .foregroundStyle(Fixer.safeText)
                    .padding(.top, 9)
                }
            }

            Rectangle().fill(Fixer.line).frame(height: 1).padding(.vertical, 18)

            setupSection(number: "03", title: "Action shortcut", isComplete: hasShortcut) {
                Text("Close setup, choose an action and record a global shortcut. An action without one cannot run.")
                    .font(Fixer.sans(12))
                    .foregroundStyle(Fixer.textDim)
                    .fixedSize(horizontal: false, vertical: true)
            }

            HStack {
                Spacer()
                Button("Done") { onClose() }
                    .buttonStyle(FixerPrimaryButton())
                    .keyboardShortcut(.defaultAction)
            }
            .padding(.top, 22)
        }
        .padding(26)
        .frame(width: 520)
        .background(Fixer.base)
        .onAppear {
            if refreshAccessibilityOnAppear {
                appState.refreshAccessibility()
            }
        }
    }

    private func setupSection<Content: View>(
        number: String,
        title: String,
        isComplete: Bool,
        @ViewBuilder content: () -> Content
    ) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Text(number)
                .font(Fixer.mono(10, .semibold))
                .foregroundStyle(isComplete ? Fixer.fixed : Fixer.yellowDark)
                .frame(width: 25, alignment: .leading)

            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 7) {
                    Text(title)
                        .font(Fixer.sans(14, .semibold))
                        .foregroundStyle(Fixer.text)
                    if isComplete {
                        Image(systemName: "checkmark")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(Fixer.fixed)
                    }
                }
                content()
            }
        }
    }
}
