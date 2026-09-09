import AppKit
import SwiftUI

/// History remains available during an operation. Opening it deliberately
/// changes focus; the runner then saves its result instead of pasting here.
struct HistoryView: View {
    @ObservedObject var history: HistoryStore
    @ObservedObject var appState: AppState
    let onRetry: (HistoryEntry) -> Void
    @State private var selectedID: UUID?
    @State private var deleteCandidate: UUID?
    @State private var confirmsDelete = false
    @State private var confirmsClear = false
    @State private var actionMessage: String?

    init(history: HistoryStore, appState: AppState, onRetry: @escaping (HistoryEntry) -> Void) {
        self.history = history
        self.appState = appState
        self.onRetry = onRetry
        _selectedID = State(initialValue: history.entries.first?.id)
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Label("History", systemImage: "clock.arrow.circlepath")
                    .font(.title2.bold())
                    .accessibilityAddTraits(.isHeader)
                Spacer()
                Button("Clear history…", action: { confirmsClear = true })
                    .disabled(!history.hasClearableEntries)
            }
            .padding(18)
            .background(Fixer.panel)
            Divider()
            if let message = history.persistenceError ?? actionMessage {
                Label(message, systemImage: "info.circle")
                    .font(.callout)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(12)
                    .background(history.persistenceError == nil ? Fixer.film : Fixer.warningWash)
            }
            if history.entries.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "clock.arrow.circlepath")
                        .font(.largeTitle)
                        .accessibilityHidden(true)
                    Text(history.persistenceError == nil ? "Your runs will appear here" : "No readable runs")
                        .font(.title3.bold())
                    Text(history.persistenceError == nil
                         ? "Original text, recordings and results are saved on this Mac, including runs that fail."
                         : "Fixer could not load your saved history. Available files have been preserved.")
                        .font(.body)
                        .multilineTextAlignment(.center)
                        .foregroundStyle(Fixer.muted)
                        .frame(maxWidth: 360)
                }
                .padding(24)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                HSplitView {
                    List(selection: $selectedID) {
                        ForEach(history.entries) { entry in
                            HistoryListRow(entry: entry, isSelected: selectedID == entry.id)
                                .tag(entry.id)
                        }
                    }
                    .listStyle(.sidebar)
                    .scrollContentBackground(.hidden)
                    .background(Fixer.panel)
                    .frame(minWidth: 240, idealWidth: 280, maxWidth: 340)
                    .accessibilityLabel("Saved runs")
                    if let id = selectedID, let entry = history.entry(id: id) {
                        HistoryDetailView(
                            entry: entry,
                            audioURL: history.audioURL(for: entry),
                            isProcessing: appState.isProcessing,
                            onRetry: onRetry,
                            onCopy: copyText,
                            onDelete: {
                                deleteCandidate = entry.id
                                confirmsDelete = true
                            }
                        )
                        .frame(minWidth: 360, maxWidth: .infinity, maxHeight: .infinity)
                    } else {
                        Text("Select a run to view its saved input and result.")
                            .foregroundStyle(Fixer.muted)
                            .frame(minWidth: 360, maxWidth: .infinity, maxHeight: .infinity)
                    }
                }
            }
            Divider()
            Text("Stored locally · Retention and clipboard behavior are in Setup")
                .font(.caption)
                .foregroundStyle(Fixer.muted)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 18)
                .padding(.vertical, 10)
        }
        .background(Fixer.base)
        .frame(minWidth: 680, minHeight: 440)
        .alert("Delete this run?", isPresented: $confirmsDelete) {
            Button("Delete", role: .destructive, action: deleteRun)
            Button("Cancel", role: .cancel) { deleteCandidate = nil }
        } message: {
            Text("Its original text, result and recording will be permanently removed from this Mac.")
        }
        .alert("Clear history?", isPresented: $confirmsClear) {
            Button("Clear history", role: .destructive, action: clearHistory)
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("All finished runs, unreadable history records and their recordings will be permanently removed. Running actions are kept.")
        }
        .onChange(of: history.entries.map(\.id)) { ids in
            if let selectedID, ids.contains(selectedID) { return }
            selectedID = ids.first
        }
    }

    private func copyText(_ text: String) {
        Task { @MainActor in
            if await ClipboardManager.shared.copyText(text) {
                actionMessage = "Copied to clipboard."
            } else {
                actionMessage = "The clipboard could not be updated. Select the saved text and copy it manually."
            }
        }
    }

    private func deleteRun() {
        guard let id = deleteCandidate else { return }
        deleteCandidate = nil
        do {
            try history.delete(id)
            actionMessage = nil
        } catch {
            actionMessage = error.localizedDescription
        }
    }

    private func clearHistory() {
        do {
            try history.clear()
            actionMessage = nil
        } catch {
            actionMessage = error.localizedDescription
        }
    }
}
