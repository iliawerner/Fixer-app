@preconcurrency import AVFoundation
import Foundation

/// Writes a streaming CAF before transcription. The audio callback only copies
/// into a preallocated ring; an ordered background writer owns all file I/O.
/// CAF's unknown data length keeps already-written frames readable after a crash.
final class RecoverableVoiceRecording: @unchecked Sendable {
    private let lock = NSLock()
    private let queue = DispatchQueue(label: "com.fixer.voice-recovery", qos: .utility)
    private let file: FileHandle
    private var timer: DispatchSourceTimer?
    private var ring: [Float]
    private var readIndex = 0
    private var count = 0
    private var totalFrames = 0
    private let maximumFrames: Int
    private var overflowed = false
    private var failure: Error?
    private var closed = false

    init(url: URL, sampleRate: Double, maximumDuration: TimeInterval) throws {
        guard sampleRate.isFinite, sampleRate > 0, sampleRate <= 384_000,
              maximumDuration > 0 else { throw VoiceCaptureError.invalidInputFormat }
        ring = .init(repeating: 0, count: max(1, Int(sampleRate * 4)))
        maximumFrames = Int(sampleRate * maximumDuration)
        var header = Data("caff".utf8)
        header.appendBE(UInt16(1))
        header.appendBE(UInt16(0))
        header.append(contentsOf: "desc".utf8)
        header.appendBE(UInt64(32))
        header.appendBE(sampleRate.bitPattern)
        header.append(contentsOf: "lpcm".utf8)
        header.appendBE(UInt32(3)) // CAF Float32, little endian
        header.appendBE(UInt32(4)) // bytes per packet
        header.appendBE(UInt32(1)) // frames per packet
        header.appendBE(UInt32(1)) // channels
        header.appendBE(UInt32(32))
        header.append(contentsOf: "data".utf8)
        header.appendBE(UInt64.max) // streaming data extends to EOF
        header.appendBE(UInt32(0)) // edit count
        try header.write(to: url, options: [.atomic])
        try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: url.path)
        file = try FileHandle(forWritingTo: url)
        try file.seekToEnd()
        try file.synchronize()
        let timer = DispatchSource.makeTimerSource(queue: queue)
        timer.schedule(deadline: .now() + .milliseconds(100), repeating: .milliseconds(100))
        timer.setEventHandler { [weak self] in self?.drain() }
        self.timer = timer
        timer.resume()
    }

    func append(_ buffer: AVAudioPCMBuffer) {
        guard let channels = buffer.floatChannelData else { return }
        lock.lock()
        defer { lock.unlock() }
        guard !closed, failure == nil, !overflowed else { return }
        let accepted = min(Int(buffer.frameLength), maximumFrames - totalFrames)
        guard accepted > 0 else { return }
        guard accepted <= ring.count - count else {
            overflowed = true
            return
        }
        let channelCount = max(1, Int(buffer.format.channelCount))
        for frame in 0..<accepted {
            var value: Float = 0
            for channel in 0..<channelCount { value += channels[channel][frame] }
            value /= Float(channelCount)
            ring[(readIndex + count) % ring.count] = value.isFinite ? max(-1, min(1, value)) : 0
            count += 1
        }
        totalFrames += accepted
    }

    var error: Error? {
        lock.lock()
        defer { lock.unlock() }
        if let failure { return failure }
        if overflowed {
            return VoiceCaptureError.couldNotStart("Audio recovery could not keep up with recording. The saved audio may be incomplete.")
        }
        return nil
    }

    /// Flushes the currently captured prefix without ending the recording.
    func checkpoint() throws {
        queue.sync { drain() }
        if let error { throw error }
    }

    /// Called after removing the microphone tap. Previously saved audio is kept,
    /// including on cancellation and writer failure.
    func finish() throws {
        timer?.cancel()
        timer = nil
        queue.sync {
            lock.lock()
            let wasClosed = closed
            closed = true
            lock.unlock()
            guard !wasClosed else { return }
            drain()
            do {
                try file.synchronize()
                try file.close()
            } catch {
                record(error)
            }
        }
        if let error { throw error }
    }

    private func drain() {
        while true {
            lock.lock()
            let frameCount = min(count, 4_096)
            guard frameCount > 0, failure == nil else {
                lock.unlock()
                break
            }
            var chunk = [Float]()
            chunk.reserveCapacity(frameCount)
            for _ in 0..<frameCount {
                chunk.append(ring[readIndex])
                readIndex = (readIndex + 1) % ring.count
            }
            count -= frameCount
            lock.unlock()
            do {
                let data = chunk.withUnsafeBytes { Data($0) }
                try file.write(contentsOf: data)
            } catch {
                record(error)
                break
            }
        }
        do { try file.synchronize() } catch { record(error) }
    }

    private func record(_ error: Error) {
        lock.lock()
        if failure == nil { failure = error }
        lock.unlock()
    }

    deinit {
        timer?.cancel()
        try? file.close()
    }
}

private extension Data {
    mutating func appendBE<T: FixedWidthInteger>(_ value: T) {
        var encoded = value.bigEndian
        Swift.withUnsafeBytes(of: &encoded) { append(contentsOf: $0) }
    }
}
