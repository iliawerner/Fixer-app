@preconcurrency import AVFoundation
import Foundation

/// Reads both completed WAVs and recoverable streaming CAFs without touching the
/// microphone. Decoding and conversion are bounded and run off the main actor.
enum HistoryAudioLoader {
    static func load(_ url: URL) async throws -> VoiceAudio {
        let task = Task.detached(priority: .userInitiated) {
            try Task.checkCancellation()
            let file = try AVAudioFile(forReading: url, commonFormat: .pcmFormatFloat32, interleaved: false)
            let format = file.processingFormat
            guard format.sampleRate.isFinite, format.sampleRate > 0,
                  format.sampleRate <= 384_000,
                  format.channelCount > 0, format.channelCount <= 32,
                  file.length > 0,
                  Double(file.length) / format.sampleRate <= VoiceCapturePolicy.maximumDuration + 0.01 else {
                throw VoiceCaptureError.invalidInputFormat
            }
            var samples: [Float] = []
            samples.reserveCapacity(Int(file.length))
            guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 4_096) else {
                throw VoiceCaptureError.couldNotEncode
            }
            while file.framePosition < file.length {
                try Task.checkCancellation()
                try file.read(into: buffer, frameCount: 4_096)
                guard buffer.frameLength > 0, let channels = buffer.floatChannelData else {
                    throw VoiceCaptureError.couldNotEncode
                }
                for frame in 0..<Int(buffer.frameLength) {
                    var value: Float = 0
                    for channel in 0..<Int(format.channelCount) { value += channels[channel][frame] }
                    value /= Float(format.channelCount)
                    samples.append(value.isFinite ? max(-1, min(1, value)) : 0)
                }
            }
            let data = try WAVAudioEncoder.encodeMonoPCM16(samples: samples, sourceSampleRate: format.sampleRate)
            return VoiceAudio(data: data, mimeType: VoiceCapturePolicy.mimeType,
                              duration: Double(samples.count) / format.sampleRate)
        }
        return try await withTaskCancellationHandler {
            try await task.value
        } onCancel: {
            task.cancel()
        }
    }
}
