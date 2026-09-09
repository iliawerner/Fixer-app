@preconcurrency import AVFoundation
import Foundation

/// One started-or-startable audio graph owned by `VoiceAudioCapture`.
///
/// Keeping the AVFoundation boundary behind this small interface lets lifecycle
/// behavior be exercised without opening the real microphone in unit tests.
/// Implementations own their final deinit cleanup: an actor-isolated capture can
/// be released from a nonisolated deinit context in future Swift language modes.
protocol VoiceAudioCaptureSession: AnyObject {
    var sampleRate: Double { get }

    func start() throws
    func stop()
    func takeSamples() -> [Float]
    func discard()
    func level() -> Float
    func prepareRecovery(at url: URL) throws
    func finishRecovery() throws
    var recoveryError: Error? { get }
}

extension VoiceAudioCaptureSession {
    func prepareRecovery(at url: URL) throws {}
    func finishRecovery() throws {}
    var recoveryError: Error? { nil }
}

private final class SystemVoiceAudioCaptureSession: VoiceAudioCaptureSession {
    private let engine: AVAudioEngine
    private let pcmBuffer: LockedVoicePCMBuffer
    private var tapIsInstalled = false
    private let maximumDuration: TimeInterval
    private let inputFormat: AVAudioFormat
    private var recovery: RecoverableVoiceRecording?

    var sampleRate: Double { pcmBuffer.sampleRate }

    init(maximumDuration: TimeInterval) throws {
        let engine = AVAudioEngine()
        let input = engine.inputNode
        let format = input.outputFormat(forBus: 0)
        guard format.sampleRate > 0, format.channelCount > 0 else {
            throw VoiceCaptureError.noInputDevice
        }
        guard format.commonFormat == .pcmFormatFloat32, !format.isInterleaved else {
            throw VoiceCaptureError.invalidInputFormat
        }

        let pcmBuffer = LockedVoicePCMBuffer(
            sampleRate: format.sampleRate,
            maximumDuration: maximumDuration
        )
        self.engine = engine
        self.pcmBuffer = pcmBuffer
        self.maximumDuration = maximumDuration
        self.inputFormat = format
    }

    func prepareRecovery(at url: URL) throws {
        recovery = try RecoverableVoiceRecording(url: url, sampleRate: sampleRate, maximumDuration: maximumDuration)
    }

    func finishRecovery() throws { try recovery?.finish() }
    var recoveryError: Error? { recovery?.error }

    func start() throws {
        engine.inputNode.installTap(onBus: 0, bufferSize: 1_024, format: inputFormat) { [pcmBuffer, recovery] buffer, _ in
            pcmBuffer.append(buffer)
            recovery?.append(buffer)
        }
        tapIsInstalled = true
        engine.prepare()
        do {
            try engine.start()
        } catch {
            throw VoiceCaptureError.couldNotStart(error.localizedDescription)
        }
    }

    func stop() {
        if tapIsInstalled {
            engine.inputNode.removeTap(onBus: 0)
            tapIsInstalled = false
        }
        engine.stop()
    }

    func takeSamples() -> [Float] {
        pcmBuffer.takeSamples()
    }

    func discard() {
        pcmBuffer.discard()
    }

    func level() -> Float {
        pcmBuffer.level()
    }

    deinit {
        if tapIsInstalled {
            engine.inputNode.removeTap(onBus: 0)
        }
        engine.stop()
        try? recovery?.finish()
        pcmBuffer.discard()
    }
}

/// Owns one recoverable microphone session and produces a 16 kHz mono WAV.
///
/// The class is main-actor isolated because AVAudioEngine lifecycle calls are UI
/// session state. The audio tap writes only into `LockedVoicePCMBuffer`; expensive
/// resampling/encoding happens off the main actor after the tap is removed.
@MainActor
final class VoiceAudioCapture {
    typealias LevelHandler = @MainActor @Sendable (Float) -> Void
    typealias AutomaticStopHandler = @MainActor @Sendable (
        Result<CapturedVoiceAudio, VoiceCaptureError>
    ) -> Void
    typealias AutomaticLimitHandler = @MainActor @Sendable () -> Void
    typealias SessionFactory = @MainActor (TimeInterval) throws -> any VoiceAudioCaptureSession
    typealias Encoder = @Sendable ([Float], Double) async throws -> Data
    typealias LimitSleeper = @Sendable (TimeInterval) async throws -> Void

    private struct RecordingSnapshot: Sendable {
        let generation: UUID
        let samples: [Float]
        let sampleRate: Double

        var duration: TimeInterval {
            Double(samples.count) / sampleRate
        }
    }

    private let authorizer: any MicrophoneAuthorizing
    private let maximumDuration: TimeInterval
    private let sessionFactory: SessionFactory
    private let encoder: Encoder
    private let limitSleeper: LimitSleeper
    private var session: (any VoiceAudioCaptureSession)?
    private var limitTask: Task<Void, Never>?
    private var levelTask: Task<Void, Never>?
    private var encodingTask: Task<Data, Error>?
    private var activeGeneration: UUID?
    private var encodingGeneration: UUID?

    private(set) var state: VoiceAudioCaptureState = .idle
    private(set) var recoveryError: String?
    var onLevelChange: LevelHandler?
    /// Fires after the microphone tap is removed but before a hard-limit WAV is
    /// encoded, allowing the coordinator to reject a concurrent key-up cleanly.
    var onAutomaticLimitReached: AutomaticLimitHandler?
    var onAutomaticStop: AutomaticStopHandler?

    convenience init(
        authorizer: any MicrophoneAuthorizing = SystemMicrophoneAuthorizer(),
        maximumDuration: TimeInterval = VoiceCapturePolicy.maximumDuration
    ) {
        self.init(
            authorizer: authorizer,
            maximumDuration: maximumDuration,
            sessionFactory: { maximumDuration in
                try SystemVoiceAudioCaptureSession(maximumDuration: maximumDuration)
            },
            encoder: { samples, sampleRate in
                try WAVAudioEncoder.encodeMonoPCM16(
                    samples: samples,
                    sourceSampleRate: sampleRate
                )
            },
            limitSleeper: { duration in
                try await Task.sleep(for: .seconds(duration))
            }
        )
    }

    init(
        authorizer: any MicrophoneAuthorizing,
        maximumDuration: TimeInterval,
        sessionFactory: @escaping SessionFactory,
        encoder: @escaping Encoder,
        limitSleeper: @escaping LimitSleeper
    ) {
        self.authorizer = authorizer
        self.maximumDuration = max(0.1, min(VoiceCapturePolicy.maximumDuration, maximumDuration))
        self.sessionFactory = sessionFactory
        self.encoder = encoder
        self.limitSleeper = limitSleeper
    }

    var isRecording: Bool { state == .recording }

    /// Requests permission only when necessary, then starts an input-only engine.
    func start(recoveryURL: URL? = nil) async throws {
        guard state == .idle else { throw VoiceCaptureError.alreadyRecording }
        let generation = UUID()
        activeGeneration = generation
        recoveryError = nil
        state = .requestingPermission

        do {
            switch try MicrophoneAuthorizationPolicy.decision(for: authorizer.authorizationStatus()) {
            case .proceed:
                break
            case .requestPermission:
                let granted = await authorizer.requestAuthorization()
                guard !Task.isCancelled,
                      activeGeneration == generation,
                      state == .requestingPermission else {
                    throw CancellationError()
                }
                guard granted else {
                    throw VoiceCaptureError.microphonePermissionDenied
                }
            }

            // `start()` is actor-reentrant while macOS displays its permission
            // sheet. Respect a cancellation made during that await.
            guard !Task.isCancelled,
                  activeGeneration == generation,
                  state == .requestingPermission else {
                throw CancellationError()
            }
            try startEngine(recoveryURL: recoveryURL)
        } catch is CancellationError {
            if activeGeneration == generation {
                teardownAudioGraph(discardingAudio: true)
                activeGeneration = nil
                state = .idle
            }
            throw CancellationError()
        } catch {
            // A cancelled permission request may finish after a new generation
            // has already started. Never let its catch tear down the new engine.
            if activeGeneration == generation {
                teardownAudioGraph(discardingAudio: true)
                activeGeneration = nil
                state = .idle
            }
            throw map(error)
        }
    }

    /// Stops capture and transfers the only in-memory copy to the caller.
    func stop() async throws -> CapturedVoiceAudio {
        let snapshot = try freezeRecording(cancelLimitTask: true)
        return try await encode(snapshot)
    }

    /// Stops without producing an upload payload. Buffered samples are erased,
    /// while the source recording stays in local history for explicit recovery.
    @discardableResult
    func cancel() -> Task<Data, Error>? {
        guard state != .idle else { return nil }
        let generation = activeGeneration
        let cancelledEncoding = encodingGeneration == generation ? encodingTask : nil
        if encodingGeneration == generation {
            encodingTask?.cancel()
            encodingTask = nil
            encodingGeneration = nil
        }
        teardownAudioGraph(discardingAudio: true)
        activeGeneration = nil
        state = .idle
        onLevelChange?(0)
        return cancelledEncoding
    }

    private func startEngine(recoveryURL: URL?) throws {
        let session = try sessionFactory(maximumDuration)
        self.session = session
        if let recoveryURL { try session.prepareRecovery(at: recoveryURL) }
        try session.start()

        state = .recording
        scheduleHardLimit()
        scheduleLevelUpdates(for: session)
    }

    private func scheduleHardLimit() {
        let duration = maximumDuration
        let sleeper = limitSleeper
        limitTask = Task { @MainActor [weak self] in
            do {
                try await sleeper(duration)
            } catch {
                return
            }
            guard !Task.isCancelled else { return }
            await self?.finishAtHardLimit()
        }
    }

    private func scheduleLevelUpdates(for session: any VoiceAudioCaptureSession) {
        levelTask = Task { @MainActor [weak self] in
            while !Task.isCancelled {
                do {
                    try await Task.sleep(for: .milliseconds(33))
                } catch {
                    return
                }
                guard let self, self.state == .recording else { return }
                if let error = session.recoveryError {
                    self.recoveryError = error.localizedDescription
                    self.cancel()
                    self.onAutomaticStop?(.failure(self.map(error)))
                    return
                }
                self.onLevelChange?(session.level())
            }
        }
    }

    private func finishAtHardLimit() async {
        guard state == .recording, let generation = activeGeneration else { return }
        // Capture the callback with the generation. Replacing callbacks for a
        // subsequent run must never make it receive this run's completion.
        let completion = onAutomaticStop
        do {
            let snapshot = try freezeRecording(cancelLimitTask: false)
            // The session becomes Finishing synchronously with the tap removal.
            // A key-up arriving during encoding then observes a terminal local
            // capture state instead of attempting a second `stop()`.
            onAutomaticLimitReached?()
            let audio = try await encode(snapshot)
            completion?(.success(audio))
        } catch is CancellationError {
            // Explicit cancellation owns truthful UI and session cleanup.
        } catch let error as VoiceCaptureError {
            // A cancelled encoder can fail after a new recording has installed
            // new callbacks. Never forward that old failure into the new run.
            guard !Task.isCancelled,
                  activeGeneration == nil || activeGeneration == generation else { return }
            completion?(.failure(error))
        } catch {
            guard !Task.isCancelled,
                  activeGeneration == nil || activeGeneration == generation else { return }
            completion?(.failure(.couldNotEncode))
        }
    }

    private func stopSessionAndTimer(cancelLimitTask: Bool = true) {
        if cancelLimitTask {
            limitTask?.cancel()
        }
        limitTask = nil
        levelTask?.cancel()
        levelTask = nil

        session?.stop()
    }

    private func freezeRecording(cancelLimitTask: Bool) throws -> RecordingSnapshot {
        guard state == .recording,
              let generation = activeGeneration,
              let session else {
            throw VoiceCaptureError.notRecording
        }

        stopSessionAndTimer(cancelLimitTask: cancelLimitTask)
        self.session = nil
        state = .encoding
        onLevelChange?(0)

        do {
            try session.finishRecovery()
        } catch {
            recoveryError = error.localizedDescription
            activeGeneration = nil
            state = .idle
            throw map(error)
        }
        let samples = session.takeSamples()
        guard !samples.isEmpty else {
            activeGeneration = nil
            state = .idle
            throw VoiceCaptureError.noAudioCaptured
        }
        return RecordingSnapshot(
            generation: generation,
            samples: samples,
            sampleRate: session.sampleRate
        )
    }

    private func encode(_ snapshot: RecordingSnapshot) async throws -> CapturedVoiceAudio {
        let encoder = encoder
        let task = Task.detached(priority: .userInitiated) {
            try await encoder(snapshot.samples, snapshot.sampleRate)
        }
        encodingTask = task
        encodingGeneration = snapshot.generation

        do {
            let data = try await withTaskCancellationHandler {
                try await task.value
            } onCancel: {
                task.cancel()
            }
            guard activeGeneration == snapshot.generation,
                  encodingGeneration == snapshot.generation,
                  state == .encoding else { throw CancellationError() }
            encodingTask = nil
            encodingGeneration = nil
            activeGeneration = nil
            state = .idle
            return CapturedVoiceAudio(
                data: data,
                mimeType: VoiceCapturePolicy.mimeType,
                duration: snapshot.duration
            )
        } catch is CancellationError {
            task.cancel()
            if encodingGeneration == snapshot.generation {
                encodingTask = nil
                encodingGeneration = nil
            }
            if activeGeneration == snapshot.generation {
                activeGeneration = nil
                if state == .encoding { state = .idle }
            }
            throw CancellationError()
        } catch {
            let wasCurrent = activeGeneration == snapshot.generation
                && encodingGeneration == snapshot.generation
            if encodingGeneration == snapshot.generation {
                encodingTask = nil
                encodingGeneration = nil
            }
            if activeGeneration == snapshot.generation {
                activeGeneration = nil
                if state == .encoding { state = .idle }
            }
            guard wasCurrent, !Task.isCancelled else { throw CancellationError() }
            throw map(error)
        }
    }

    private func teardownAudioGraph(discardingAudio: Bool) {
        stopSessionAndTimer()
        do { try session?.finishRecovery() }
        catch { recoveryError = error.localizedDescription }
        if discardingAudio { session?.discard() }
        session = nil
    }

    private func map(_ error: Error) -> VoiceCaptureError {
        if let captureError = error as? VoiceCaptureError { return captureError }
        return .couldNotStart(error.localizedDescription)
    }

    deinit {
        limitTask?.cancel()
        levelTask?.cancel()
        encodingTask?.cancel()
        // Releasing `session` invokes the production adapter's own deinit, which
        // stops AVAudioEngine and erases its buffer without crossing actor
        // isolation from this nonisolated deinit context.
    }
}
