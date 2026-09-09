import AVFoundation
import Foundation

@MainActor
final class HistoryAudioPlayback: NSObject, ObservableObject, AVAudioPlayerDelegate {
    @Published private(set) var isPlaying = false
    @Published private(set) var errorMessage: String?
    private var player: AVAudioPlayer?

    func toggle(_ url: URL) {
        if isPlaying {
            stop()
            return
        }
        do {
            let player = try AVAudioPlayer(contentsOf: url)
            player.delegate = self
            guard player.prepareToPlay(), player.play() else {
                errorMessage = "This recording could not be played. Export it to open it in another audio app."
                return
            }
            self.player = player
            errorMessage = nil
            isPlaying = true
        } catch {
            errorMessage = "This recording could not be played: \(error.localizedDescription)"
        }
    }

    func stop() {
        player?.stop()
        player = nil
        isPlaying = false
    }

    nonisolated func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        let finishedPlayer = ObjectIdentifier(player)
        Task { @MainActor [weak self] in
            guard let self, let currentPlayer = self.player,
                  ObjectIdentifier(currentPlayer) == finishedPlayer else { return }
            self.isPlaying = false
            self.player = nil
            if !flag { self.errorMessage = "Playback stopped before the recording ended." }
        }
    }
}
