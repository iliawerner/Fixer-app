import AVFoundation
import Foundation
import Testing
@testable import fixer

struct HistoryAudioLoaderTests {
    @Test func unfinishedCAFIsRecoverableBeforeRecordingIsClosed() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("unfinished.caf")
        let writer = try RecoverableVoiceRecording(url: url, sampleRate: 16_000, maximumDuration: 300)
        writer.append(try buffer(frames: 16_000))
        try writer.checkpoint()
        // No stop/finalization: this is what the next launch sees after a crash.
        let recovered = try await HistoryAudioLoader.load(url)
        #expect(recovered.duration == 1)
        #expect(recovered.mimeType == "audio/wav")
        #expect(recovered.data.count == 32_044)
        try writer.finish()
        let finished = try await HistoryAudioLoader.load(url)
        #expect(recovered == finished)
    }

    @Test func completedWAVCanBeRetriedWithoutTheMicrophone() async throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("\(UUID().uuidString).wav")
        defer { try? FileManager.default.removeItem(at: url) }
        let encoded = try WAVAudioEncoder.encodeMonoPCM16(samples: [Float](repeating: 0.2, count: 16_000), sourceSampleRate: 16_000)
        try encoded.write(to: url)
        let result = try await HistoryAudioLoader.load(url)
        #expect(result.duration == 1)
        #expect(result.data.count == encoded.count)
    }

    @Test func writerOverflowIsReportedAndPreviouslyWrittenAudioSurvives() async throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("\(UUID().uuidString).caf")
        defer { try? FileManager.default.removeItem(at: url) }
        let writer = try RecoverableVoiceRecording(url: url, sampleRate: 16_000, maximumDuration: 300)
        writer.append(try buffer(frames: 1_600))
        try writer.checkpoint()
        writer.append(try buffer(frames: 80_000)) // exceeds the bounded four-second ring
        #expect(writer.error != nil)
        #expect(throws: (any Error).self) { try writer.finish() }
        let recovered = try await HistoryAudioLoader.load(url)
        #expect(recovered.duration == 0.1)
    }

    @Test func emptyRecordingAndMalformedFilesNeverBecomeUploadPayloads() async throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("\(UUID().uuidString).caf")
        defer { try? FileManager.default.removeItem(at: url) }
        let writer = try RecoverableVoiceRecording(url: url, sampleRate: 16_000, maximumDuration: 300)
        try writer.finish()
        await #expect(throws: (any Error).self) { try await HistoryAudioLoader.load(url) }
        try Data("not audio".utf8).write(to: url)
        await #expect(throws: (any Error).self) { try await HistoryAudioLoader.load(url) }
    }

    private func buffer(frames: UInt32) throws -> AVAudioPCMBuffer {
        let format = try #require(AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: 16_000, channels: 1, interleaved: false))
        let buffer = try #require(AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frames))
        buffer.frameLength = frames
        let channel = try #require(buffer.floatChannelData?[0])
        for frame in 0..<Int(frames) { channel[frame] = 0.2 }
        return buffer
    }
}
