import AppKit
import Combine
import SwiftUI
import KeyboardShortcuts

/// Root workspace that coordinates action navigation, editing, and setup.
///
/// `SettingsView` owns selection and presentation state only. Persistence stays
/// in `SettingsManager`, provider validation stays in the single
/// `ProviderSetupController`, and action editing receives a live binding so
/// autosave is never disconnected by copying a model into local state.
struct SettingsView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @ObservedObject private var settings: SettingsManager
    @ObservedObject private var appState: AppState
    @StateObject private var provider: ProviderSetupController
    @ObservedObject private var historyPreferences: HistoryPreferences
    @ObservedObject private var appearancePreferences: AppearancePreferences

    private let refreshAccessibilityOnAppear: Bool
    private let allowsActionEditing: Bool

    @State private var selectedActionID: UUID?
    @State private var showLibrary = false
    @State private var showSetup = false
    /// The initial editor is rendered in place. Only later Action changes get
    /// the directional reveal, so launch never looks half-loaded.
    @State private var hasPresentedInitialSelection = false
    /// KeyboardShortcuts is not observable. Incrementing this bridge after a
    /// recorder change forces sidebar conflict/readiness derivations to refresh.
    @State private var shortcutRevision = 0
    @Namespace private var librarySelectionNamespace

    @MainActor
    init(
        settings: SettingsManager? = nil,
        appState: AppState? = nil,
        provider: ProviderSetupController? = nil,
        historyPreferences: HistoryPreferences? = nil,
        appearancePreferences: AppearancePreferences? = nil,
        initialSelectedActionID: UUID? = nil,
        refreshAccessibilityOnAppear: Bool = true,
        allowsActionEditing: Bool = true
    ) {
        let resolvedSettings = settings ?? SettingsManager.shared
        _settings = ObservedObject(wrappedValue: resolvedSettings)
        _appState = ObservedObject(wrappedValue: appState ?? AppState.shared)
        _provider = StateObject(wrappedValue: provider ?? ProviderSetupController())
        _historyPreferences = ObservedObject(wrappedValue: historyPreferences ?? HistoryPreferences.shared)
        _appearancePreferences = ObservedObject(wrappedValue: appearancePreferences ?? AppearancePreferences.shared)
        let initialActionID = initialSelectedActionID.flatMap { requestedID in
            resolvedSettings.actions.first { $0.id == requestedID }?.id
        }
        _selectedActionID = State(initialValue: initialActionID ?? resolvedSettings.actions.first?.id)
        self.refreshAccessibilityOnAppear = refreshAccessibilityOnAppear
        self.allowsActionEditing = allowsActionEditing
    }

    private var actionIDs: [UUID] {
        settings.actions.map(\.id)
    }

    private var setupIssueCount: Int {
        SetupReadiness.issueCount(
            accessibilityGranted: appState.accessibilityGranted,
            hasStoredKey: provider.hasStoredKey,
            hasRunnableAction: ActionShortcutPolicy.hasRunnableAction(
                actions: settings.actions,
                shortcutFor: { shortcut(named: $0) }
            )
        )
    }

    var body: some View {
        HStack(spacing: 0) {
            ActionLibrarySidebar(
                actions: settings.actions,
                selectedActionID: selectedActionID,
                setupIssueCount: setupIssueCount,
                selectionNamespace: librarySelectionNamespace,
                reduceMotion: reduceMotion,
                shortcutText: { shortcut(for: $0).map { String(describing: $0) } },
                hasShortcutConflict: hasShortcutConflict,
                onSelect: selectAction,
                onAdd: addAction,
                onOpenLibrary: openLibrary,
                onOpenSetup: openSetup,
                onOpenHistory: openHistory
            )
            .frame(width: WorkspaceChromeMetrics.sidebarWidth)

            Rectangle()
                .fill(Fixer.chromeLine)
                .frame(width: 1)

            detailPane
                .disabled(!allowsActionEditing)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .clipped()
        }
        .background(Fixer.base)
        .frame(
            minWidth: WorkspaceWindowMetrics.minimumSize.width,
            minHeight: WorkspaceWindowMetrics.minimumSize.height
        )
        // The AppKit window uses `fullSizeContentView`. Opting out of SwiftUI's
        // titlebar safe area lets the compact workspace chrome sit beside the
        // traffic lights instead of leaving an empty strip above the app.
        .ignoresSafeArea(.container, edges: .top)
        .sheet(isPresented: $showSetup) {
            ProviderSetupSheet(
                appState: appState,
                settings: settings,
                provider: provider,
                historyPreferences: historyPreferences,
                appearancePreferences: appearancePreferences,
                refreshAccessibilityOnAppear: refreshAccessibilityOnAppear,
                onClose: { showSetup = false }
            )
        }
        .sheet(isPresented: $showLibrary) {
            StarterLibrarySheet(
                settings: settings,
                onAdded: selectAction,
                onClose: { showLibrary = false }
            )
        }
        .onAppear {
            if refreshAccessibilityOnAppear {
                appState.refreshAccessibility()
            }
            if selectedActionID == nil {
                var transaction = Transaction()
                transaction.disablesAnimations = true
                withTransaction(transaction) {
                    selectedActionID = settings.actions.first?.id
                }
            }
            hasPresentedInitialSelection = true
            if provider.hasStoredKey,
               provider.availableModels.isEmpty,
               !provider.isLoadingModels {
                provider.fetchModels()
            }
        }
        .onReceive(
            NotificationCenter.default.publisher(
                for: WorkspaceWindowFactory.titlebarCommandNotification
            ),
            perform: handleTitlebarCommand
        )
        .onChange(of: actionIDs) { ids in
            guard let selectedActionID, ids.contains(selectedActionID) else {
                self.selectedActionID = ids.first
                return
            }
        }
    }

    // MARK: Detail

    @ViewBuilder
    private var detailPane: some View {
        if let id = selectedActionID {
            ActionDetailMotionShell(
                settings: settings,
                actionID: id,
                models: provider.availableModels,
                shortcutRevision: $shortcutRevision,
                onSelectAction: selectAction,
                onShortcutChanged: shortcutDidChange,
                animatesAppearance: hasPresentedInitialSelection,
                reduceMotion: reduceMotion
            )
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
                    addAction()
                }
                .buttonStyle(FixerPrimaryButton())
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Fixer.panel)
        }
    }

    // MARK: Shortcut state

    private func shortcut(for action: MacroAction) -> KeyboardShortcuts.Shortcut? {
        shortcut(named: action.shortcutName)
    }

    private func shortcut(named name: KeyboardShortcuts.Name) -> KeyboardShortcuts.Shortcut? {
        _ = shortcutRevision
        return KeyboardShortcuts.getShortcut(for: name)
    }

    private func hasShortcutConflict(_ action: MacroAction) -> Bool {
        ActionShortcutPolicy.conflictingAction(
            for: action,
            actions: settings.actions,
            shortcutFor: { shortcut(named: $0) }
        ) != nil
    }

    /// The Recorder owns persistence, while SettingsManager owns package
    /// registration. Keep those responsibilities joined by one explicit UI
    /// callback, then refresh the non-observable shortcut-derived labels.
    private func shortcutDidChange() {
        settings.reconcileShortcuts()
        shortcutRevision += 1
    }

    // MARK: - Workspace actions

    /// Selection changes are the workspace's principal spatial transition.
    /// They share one quick, strongly eased curve, while Reduce Motion turns
    /// the same state change into a short dissolve.
    private func selectAction(_ id: UUID) {
        guard selectedActionID != id else { return }
        // End editing before changing binding identity. This commits the title
        // draft and prevents the previous editor retaining first responder.
        NSApp.keyWindow?.makeFirstResponder(nil)
        selectedActionID = id
    }

    private func addAction() {
        let id = settings.addAction()
        NSApp.keyWindow?.makeFirstResponder(nil)
        selectedActionID = id
    }

    private func openLibrary() {
        showLibrary = true
    }

    private func openHistory() {
        AppDelegate.shared?.openHistory()
    }

    private func openSetup() {
        showSetup = true
    }

    private func handleTitlebarCommand(_ notification: Notification) {
        guard let command = notification.object as? WorkspaceWindowFactory.TitlebarCommand else {
            return
        }

        switch command {
        case .addAction:
            addAction()
        case .openLibrary:
            openLibrary()
        case .openSetup:
            openSetup()
        case .openHistory:
            openHistory()
        }
    }

}
