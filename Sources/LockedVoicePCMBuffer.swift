import AVFoundation
import Foundation

/// Native-rate, mono PCM storage shared by AVAudioEngine's real-time callback
/// and the main-actor capture coordinator.
///
/// AVAudioEngine does not call taps on a Swift actor. A short lock is therefore
/// the appropriate boundary here: only the tap appends, while stop/cancel first
/// removes the tap and then takes or discards the buffer. `@unchecked Sendable`
/// is sound because every mutable property is protected by `lock`.
final class LockedVoicePCMBuffer: @unchecked Sendable {
    private let lock = NSLock()
    private let maximumFrameCount: Int
    private var samples: [Float] = []
    private var latestLevel: Float = 0

    let sampleRate: Double

    init(sampleRate: Double, maximumDuration: TimeInterval) {
        self.sampleRate = sampleRate
        maximumFrameCount = max(1, Int((sampleRate * maximumDuration).rounded(.down)))
        // Reserve before the engine starts. The render callback therefore never
        // grows the array's storage, and memory remains strictly bounded by the
        // five-minute capture policy.
        samples.reserveCapacity(maximumFrameCount)
    }

    /// Downmixes one non-interleaved Float32 buffer to mono. This render-thread
    /// method performs no asynchronous hop and does not grow backing storage.
    func append(_ buffer: AVAudioPCMBuffer) {
        guard let channels = buffer.floatChannelData else { return }

        lock.lock()
        defer { lock.unlock() }

        let availableFrames = Int(buffer.frameLength)
        let acceptedFrames = min(availableFrames, maximumFrameCount - samples.count)
        guard acceptedFrames > 0 else { return }

        let channelCount = max(1, Int(buffer.format.channelCount))
        var sumOfSquares = 0.0

        for frame in 0..<acceptedFrames {
            var mono: Float = 0
            for channel in 0..<channelCount {
                mono += channels[channel][frame]
            }
            mono /= Float(channelCount)
            let bounded = max(-1, min(1, mono))
            samples.append(bounded)
            sumOfSquares += Double(bounded * bounded)
        }

        latestLevel = AudioLevelMeter.normalizedRMS(
            sumOfSquares: sumOfSquares,
            sampleCount: acceptedFrames
        )
    }

    /// The UI polls this inexpensive snapshot at 30 Hz. Keeping the polling out
    /// of the audio tap avoids allocating a Task on the render thread.
    func level() -> Float {
        lock.lock()
        defer { lock.unlock() }
        return latestLevel
    }

    /// Transfers ownership of captured samples and clears the internal storage.
    func takeSamples() -> [Float] {
        lock.lock()
        defer { lock.unlock() }

        let result = samples
        samples.removeAll(keepingCapacity: false)
        return result
    }

    /// Erases microphone bytes on cancellation or startup failure.
    func discard() {
        lock.lock()
        samples.removeAll(keepingCapacity: false)
        latestLevel = 0
        lock.unlock()
    }
}
