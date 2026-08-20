import Foundation
import Testing
@testable import fixer

struct WAVAudioEncoderTests {
    @Test func writesCanonicalMonoPCM16HeaderAndSamples() throws {
        let wav = try WAVAudioEncoder.encodeMonoPCM16(
            samples: [-1, 0, 1],
            sourceSampleRate: 16_000
        )

        #expect(String(data: wav[0..<4], encoding: .ascii) == "RIFF")
        #expect(String(data: wav[8..<12], encoding: .ascii) == "WAVE")
        #expect(String(data: wav[12..<16], encoding: .ascii) == "fmt ")
        #expect(String(data: wav[36..<40], encoding: .ascii) == "data")
        #expect(wav.count == 44 + 3 * 2)
        #expect(wav.uint16(at: 20) == 1)      // linear PCM
        #expect(wav.uint16(at: 22) == 1)      // mono
        #expect(wav.uint32(at: 24) == 16_000)
        #expect(wav.uint16(at: 34) == 16)     // bits per sample
        #expect(Int16(bitPattern: wav.uint16(at: 44)) == .min)
        #expect(Int16(bitPattern: wav.uint16(at: 46)) == 0)
        #expect(Int16(bitPattern: wav.uint16(at: 48)) == .max)
    }

    @Test func downsamplingPreservesSpeechDuration() throws {
        let source = (0..<48_000).map { index in
            sin(Float(index) * 0.01)
        }
        let wav = try WAVAudioEncoder.encodeMonoPCM16(
            samples: source,
            sourceSampleRate: 48_000,
            outputSampleRate: 16_000
        )

        #expect(wav.uint32(at: 24) == 16_000)
        #expect(wav.uint32(at: 40) == 16_000 * 2)
        #expect(wav.count == 44 + 16_000 * 2)
    }

    @Test func invalidInputDoesNotCreateAHeaderOnlyRecording() {
        #expect(throws: VoiceCaptureError.couldNotEncode) {
            try WAVAudioEncoder.encodeMonoPCM16(samples: [], sourceSampleRate: 48_000)
        }
        #expect(throws: VoiceCaptureError.couldNotEncode) {
            try WAVAudioEncoder.encodeMonoPCM16(samples: [0], sourceSampleRate: 0)
        }
    }

    @Test func fiveMinutePolicyFitsInlineAudioBudget() {
        let pcmByteCount = Int(VoiceCapturePolicy.maximumDuration)
            * VoiceCapturePolicy.outputSampleRate * 2
        #expect(VoiceCapturePolicy.maximumDuration == 300)
        #expect(44 + pcmByteCount < 20 * 1_024 * 1_024)
    }

    @Test func encodingReleasesCancelledRecordingsInsteadOfFinishingInBackground() async {
        let samples = Array(repeating: Float(0.25), count: 250_000)
        let task = Task.detached {
            try WAVAudioEncoder.encodeMonoPCM16(
                samples: samples,
                sourceSampleRate: 48_000
            )
        }
        task.cancel()

        do {
            _ = try await task.value
            Issue.record("Cancelled encoding unexpectedly produced a WAV")
        } catch is CancellationError {
            // Expected: the task checks cancellation during resample/encoding.
        } catch {
            Issue.record("Expected CancellationError, got \(error)")
        }
    }
}

private extension Data {
    func uint16(at offset: Int) -> UInt16 {
        UInt16(self[offset]) | UInt16(self[offset + 1]) << 8
    }

    func uint32(at offset: Int) -> UInt32 {
        UInt32(self[offset])
            | UInt32(self[offset + 1]) << 8
            | UInt32(self[offset + 2]) << 16
            | UInt32(self[offset + 3]) << 24
    }
}
