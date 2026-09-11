import SwiftUI

/// Hosts exactly one editor with a brief dissolve over stationary surfaces.
///
/// The selected id may change immediately in the sidebar, but this shell first
/// hides the outgoing editor, swaps the stable-id binding only while invisible,
/// and then reveals the latest requested Action. Rapid requests cancel the
/// pending swap, so an outgoing TextEditor never coexists with the new one.
struct ActionDetailMotionShell: View {
    @ObservedObject var settings: SettingsManager

    let actionID: UUID
    let models: [GeminiModel]
    @Binding var shortcutRevision: Int
    let onSelectAction: (UUID) -> Void
    let onShortcutChanged: () -> Void
    let animatesAppearance: Bool
    let reduceMotion: Bool

    @State private var replacement: ActionReplacementState
    @State private var replacementTask: Task<Void, Never>?
    @State private var deletionTask: Task<Void, Never>?
    @State private var deletingActionID: UUID?

    init(
        settings: SettingsManager,
        actionID: UUID,
        models: [GeminiModel],
        shortcutRevision: Binding<Int>,
        onSelectAction: @escaping (UUID) -> Void,
        onShortcutChanged: @escaping () -> Void,
        animatesAppearance: Bool,
        reduceMotion: Bool
    ) {
        self.settings = settings
        self.actionID = actionID
        self.models = models
        _shortcutRevision = shortcutRevision
        self.onSelectAction = onSelectAction
        self.onShortcutChanged = onShortcutChanged
        self.animatesAppearance = animatesAppearance
        self.reduceMotion = reduceMotion
        _replacement = State(
            initialValue: ActionReplacementState(
                actionID: actionID,
                animatesAppearance: animatesAppearance
            )
        )
    }

    var body: some View {
        ActionDetailPane(
            settings: settings,
            actionID: replacement.displayedActionID,
            models: models,
            shortcutRevision: $shortcutRevision,
            onSelectAction: onSelectAction,
            onShortcutChanged: onShortcutChanged,
            onDeleteAction: deleteAction
        )
        // Fade the editor as one layer so its panel cannot blend through its
        // masthead and tint the stationary surface underneath.
        .compositingGroup()
        .opacity(replacement.phase.opacity)
        // Keep both surface colors in place even at the invisible identity
        // swap. Fading the masthead into the panel would itself look like a flash.
        .background(alignment: .top) {
            Fixer.panel
                .overlay(alignment: .top) {
                    ActionEditorMastheadBackground()
                        .frame(height: WorkspaceChromeMetrics.editorMastheadHeight)
                }
                .allowsHitTesting(false)
                .accessibilityHidden(true)
        }
        .disabled(replacement.phase == .exiting)
        .allowsHitTesting(replacement.phase != .exiting)
        .accessibilityHidden(replacement.phase == .exiting)
        .onAppear {
            guard replacement.phase == .entering else { return }
            withAnimation(FixerMotion.replacementEntrance(reduceMotion: reduceMotion)) {
                replacement.settle()
            }
        }
        .onChange(of: actionID, perform: replaceAction)
        .onDisappear {
            replacementTask?.cancel()
            replacementTask = nil
            deletionTask?.cancel()
            deletionTask = nil
            deletingActionID = nil
        }
    }

    /// Retargets the still-visible outgoing editor. Only the latest request is
    /// swapped in after the exit delay, which makes rapid A→B→C selection end
    /// deterministically on C without creating ghost hit or VoiceOver targets.
    private func replaceAction(with requestedActionID: UUID) {
        // A confirmed deletion must keep moving toward its invisible boundary.
        // Clicking back to that row cannot resurrect the soon-to-be-removed
        // editor or cancel the destructive operation.
        if requestedActionID == deletingActionID { return }

        guard requestedActionID != replacement.displayedActionID
                || replacement.phase != .settled else { return }

        replacementTask?.cancel()
        if requestedActionID == replacement.displayedActionID {
            withAnimation(FixerMotion.replacementEntrance(reduceMotion: reduceMotion)) {
                replacement.request(requestedActionID)
            }
            replacementTask = nil
            return
        }

        withAnimation(FixerMotion.replacementExit(reduceMotion: reduceMotion)) {
            replacement.request(requestedActionID)
        }

        let delay = FixerMotion.replacementSwapDelay(reduceMotion: reduceMotion)
        replacementTask = Task { @MainActor in
            do {
                try await Task.sleep(for: .seconds(delay))
            } catch {
                return
            }
            guard !Task.isCancelled else { return }

            var transaction = Transaction()
            transaction.disablesAnimations = true
            withTransaction(transaction) {
                replacement.swapToLatestRequest()
            }

            withAnimation(FixerMotion.replacementEntrance(reduceMotion: reduceMotion)) {
                replacement.settle()
            }
            replacementTask = nil
        }
    }

    /// Deletes only after the outgoing editor reaches opacity zero. The next
    /// stable-id binding is installed in that same nonanimated boundary, so a
    /// model removal can never flash an empty editor between Actions.
    private func deleteAction(_ actionID: UUID) {
        guard actionID == replacement.displayedActionID else {
            settings.deleteAction(id: actionID)
            return
        }

        replacementTask?.cancel()
        replacementTask = nil
        deletionTask?.cancel()
        deletingActionID = actionID
        withAnimation(FixerMotion.replacementExit(reduceMotion: reduceMotion)) {
            replacement.beginExit()
        }

        let delay = FixerMotion.replacementSwapDelay(reduceMotion: reduceMotion)
        deletionTask = Task { @MainActor in
            do {
                try await Task.sleep(for: .seconds(delay))
            } catch {
                return
            }
            guard !Task.isCancelled else { return }

            let nextActionID = replacement.deletionSuccessor(
                deleting: actionID,
                availableActionIDs: settings.actions.map(\.id)
            )
            replacementTask?.cancel()
            replacementTask = nil
            settings.deleteAction(id: actionID)

            guard let nextActionID else {
                deletionTask = nil
                deletingActionID = nil
                return
            }

            var transaction = Transaction()
            transaction.disablesAnimations = true
            withTransaction(transaction) {
                replacement.swapImmediately(to: nextActionID)
                onSelectAction(nextActionID)
            }

            withAnimation(FixerMotion.replacementEntrance(reduceMotion: reduceMotion)) {
                replacement.settle()
            }
            deletionTask = nil
            deletingActionID = nil
        }
    }
}

enum ReplacementPhase: Equatable {
    case entering
    case settled
    case exiting

    var opacity: Double {
        switch self {
        case .entering:
            0
        case .settled:
            1
        case .exiting:
            0
        }
    }
}

/// Pure target/phase state for the one-editor replacement host. Keeping the
/// latest requested id separate from the displayed id makes cancellation and
/// rapid retargeting deterministic and directly testable without AppKit focus.
struct ActionReplacementState: Equatable {
    private(set) var displayedActionID: UUID
    private(set) var requestedActionID: UUID
    private(set) var phase: ReplacementPhase

    init(actionID: UUID, animatesAppearance: Bool = false) {
        displayedActionID = actionID
        requestedActionID = actionID
        phase = animatesAppearance ? .entering : .settled
    }

    mutating func request(_ actionID: UUID) {
        requestedActionID = actionID
        phase = actionID == displayedActionID ? .settled : .exiting
    }

    mutating func beginExit() {
        phase = .exiting
    }

    mutating func swapToLatestRequest() {
        displayedActionID = requestedActionID
        phase = .entering
    }

    mutating func swapImmediately(to actionID: UUID) {
        requestedActionID = actionID
        displayedActionID = actionID
        phase = .entering
    }

    mutating func settle() {
        phase = .settled
    }

    func deletionSuccessor(
        deleting actionID: UUID,
        availableActionIDs: [UUID]
    ) -> UUID? {
        if requestedActionID != actionID,
           availableActionIDs.contains(requestedActionID) {
            return requestedActionID
        }
        return availableActionIDs.first { $0 != actionID }
    }
}
