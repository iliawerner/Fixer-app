import AppKit
import Combine
import SwiftUI
import UniformTypeIdentifiers

struct HistoryAudioSection: View {
    @Environment(\.historyWindowLifecycle) private var windowLifecycle
    let url: URL
    let duration: TimeInterval?
    @StateObject private var playback = HistoryAudioPlayback()
    @State private var exportError: String?
    @State private var isExporting = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("Recording", systemImage: "waveform")
                    .font(.headline)
                    .accessibilityAddTraits(.isHeader)
                Spacer()
                if let duration {
                    Text(Duration.seconds(duration), format: .time(pattern: .minuteSecond))
                        .font(.callout.monospacedDigit())
                        .foregroundStyle(Fixer.muted)
                }
            }
            HStack(spacing: 12) {
                Button(playback.isPlaying ? "Stop" : "Play", systemImage: playback.isPlaying ? "stop.fill" : "play.fill") {
                    playback.toggle(url)
                }
                Button(isExporting ? "Exporting…" : "Export audio…", systemImage: "square.and.arrow.up", action: exportAudio)
                    .disabled(isExporting)
            }
            if let message = playback.errorMessage ?? exportError {
                Text(message)
                    .font(.callout)
                    .foregroundStyle(Fixer.safeText)
                    .textSelection(.enabled)
            }
        }
        .padding(16)
        .background(Fixer.panel)
        .onDisappear { playback.stop() }
        .onReceive(windowLifecycle?.willClose.eraseToAnyPublisher() ?? Empty<Void, Never>().eraseToAnyPublisher()) {
            playback.stop()
        }
        .onChange(of: url) { _ in playback.stop() }
    }

    private func exportAudio() {
        let panel = NSSavePanel()
        panel.title = "Export recording"
        panel.nameFieldStringValue = "Fixer recording.\(url.pathExtension)"
        if let type = UTType(filenameExtension: url.pathExtension) {
            panel.allowedContentTypes = [type]
        }
        panel.canCreateDirectories = true
        panel.begin { response in
            guard response == .OK, let destination = panel.url else { return }
            isExporting = true
            exportError = nil
            Task { @MainActor in
                do {
                    try await Task.detached(priority: .userInitiated) {
                        // The save panel already obtains overwrite consent. An
                        // atomic write preserves an existing export on I/O failure.
                        let data = try Data(contentsOf: url, options: .mappedIfSafe)
                        try data.write(to: destination, options: .atomic)
                    }.value
                } catch {
                    exportError = "The recording could not be exported: \(error.localizedDescription)"
                }
                isExporting = false
            }
        }
    }
}
