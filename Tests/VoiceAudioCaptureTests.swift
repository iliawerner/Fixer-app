import Foundation
import Testing
@testable import fixer

@Suite(.serialized)
@MainActor
struct VoiceAudioCaptureTests {
    @Test func permissionCancellationCannotTearDownAnImmediateRestart() async throws {
        let authorizer = ControlledMicrophoneAuthorizer(
            statuses: [.notDetermined, .authorized]
        )
        let restartedSession = TestVoiceAudioCaptureSession(
            samples: [0.25],
            sampleRate: 16_000
        )
        let factory = TestVoiceAudioCaptureSessionFactory(sessions: [restartedSession])
        let encoder = ControlledVoiceAudioEncoder()
        let sleeper = ControlledLimitSleeper()
        let capture = makeCapture(
            authorizer: authorizer,
            factory: factory,
            encoder: encoder,
            sleeper: sleeper
        )

        let firstStart = Task { @MainActor in
            try await capture.start()
        }
        await authorizer.waitForRequest()
        #expect(capture.state == .requestingPermission)

        capture.cancel()
        #expect(capture.state == .idle)

        try await capture.start()
        #expect(capture.state == .recording)
        #expect(restartedSession.startCount == 1)

        // A stale denial from generation A must be cancellation, and its catch
        // must not tear down the already-recording generation B.
        authorizer.resolveRequest(granted: false)
        do {
            try await firstStart.value
            Issue.record("Cancelled permission start unexpectedly succeeded")
        } catch is CancellationError {
            // Expected.
        } catch {
            Issue.record("Expected CancellationError, got \(error)")
        }

        #expect(capture.state == .recording)
        #expect(restartedSession.stopCount == 0)
        #expect(restartedSession.discardCount == 0)

        capture.cancel()
        #expect(restartedSession.stopCount == 1)
        #expect(restartedSession.discardCount == 1)
    }

    @Test func manualStopFreezesTheSessionBeforeEncodingAndReturnsThePayload() async throws {
        let authorizer = ControlledMicrophoneAuthorizer(statuses: [.authorized])
        let session = TestVoiceAudioCaptureSession(
            samples: [0.25, -0.5, 0.75, 1],
            sampleRate: 8
        )
        let factory = TestVoiceAudioCaptureSessionFactory(sessions: [session])
        let encoder = ControlledVoiceAudioEncoder()
        let sleeper = ControlledLimitSleeper()
        let capture = makeCapture(
            authorizer: authorizer,
            factory: factory,
            encoder: encoder,
            sleeper: sleeper
        )

        try await capture.start()
        #expect(capture.state == .recording)

        let stopTask = Task { @MainActor in
            try await capture.stop()
        }
        let invocation = await encoder.invocation(at: 0)

        #expect(capture.state == .encoding)
        #expect(session.stopCount == 1)
        #expect(session.takeSamplesCount == 1)
        #expect(session.discardCount == 0)
        #expect(invocation.samples == [0.25, -0.5, 0.75, 1])
        #expect(invocation.sampleRate == 8)

        let encoded = Data([0x52, 0x49, 0x46, 0x46])
        await encoder.succeed(encoded, at: 0)
        let captured = try await stopTask.value

        #expect(captured.data == encoded)
        #expect(captured.mimeType == VoiceCapturePolicy.mimeType)
        #expect(captured.duration == 0.5)
        #expect(capture.state == .idle)
    }

    @Test func hardLimitPublishesTerminalStateBeforeConcurrentStopAndFinalCallback() async throws {
        let authorizer = ControlledMicrophoneAuthorizer(statuses: [.authorized])
        let session = TestVoiceAudioCaptureSession(
            samples: [0.1, 0.2],
            sampleRate: 2
        )
        let factory = TestVoiceAudioCaptureSessionFactory(sessions: [session])
        let encoder = ControlledVoiceAudioEncoder()
        let sleeper = ControlledLimitSleeper()
        let capture = makeCapture(
            authorizer: authorizer,
            factory: factory,
            encoder: encoder,
            sleeper: sleeper
        )
        let callbacks = HardLimitCallbackProbe()

        capture.onAutomaticLimitReached = { [weak capture, weak callbacks] in
            guard let capture, let callbacks else { return }
            callbacks.recordLimit(for: capture)
        }
        capture.onAutomaticStop = { [weak callbacks] result in
            callbacks?.recordAutomaticStop(result)
        }

        try await capture.start()
        _ = await sleeper.scheduledDuration(at: 0)
        await sleeper.fire(at: 0)

        let invocation = await encoder.invocation(at: 0)
        #expect(invocation.samples == [0.1, 0.2])
        #expect(callbacks.stateAtLimit == .encoding)
        #expect(capture.state == .encoding)
        #expect(session.stopCount == 1)

        guard let concurrentStopTask = callbacks.concurrentStopTask else {
            Issue.record("Hard-limit callback did not attempt the concurrent stop")
            return
        }
        let concurrentStop = await concurrentStopTask.value
        #expect(concurrentStop == .failure(.notRecording))
        #expect(callbacks.events == [.limitReached, .concurrentStopFinished])

        let encoded = Data([0x57, 0x41, 0x56])
        await encoder.succeed(encoded, at: 0)
        let automaticStop = await callbacks.waitForAutomaticStop()

        #expect(callbacks.events == [
            .limitReached,
            .concurrentStopFinished,
            .automaticStopFinished,
        ])
        #expect(automaticStop == .success(CapturedVoiceAudio(
            data: encoded,
            mimeType: VoiceCapturePolicy.mimeType,
            duration: 1
        )))
        #expect(capture.state == .idle)
    }

    @Test func cancelDuringEncodingAllowsImmediateRestartWithoutOldCompletionWinning() async throws {
        let authorizer = ControlledMicrophoneAuthorizer(
            statuses: [.authorized, .authorized]
        )
        let firstSession = TestVoiceAudioCaptureSession(
            samples: [0.3, 0.4],
            sampleRate: 2
        )
        let restartedSession = TestVoiceAudioCaptureSession(
            samples: [0.8],
            sampleRate: 2
        )
        let factory = TestVoiceAudioCaptureSessionFactory(
            sessions: [firstSession, restartedSession]
        )
        let encoder = ControlledVoiceAudioEncoder()
        let sleeper = ControlledLimitSleeper()
        let capture = makeCapture(
            authorizer: authorizer,
            factory: factory,
            encoder: encoder,
            sleeper: sleeper
        )

        try await capture.start()
        let firstStop = Task { @MainActor in
            try await capture.stop()
        }
        _ = await encoder.invocation(at: 0)
        #expect(capture.state == .encoding)

        capture.cancel()
        #expect(capture.state == .idle)

        try await capture.start()
        #expect(capture.state == .recording)
        #expect(restartedSession.startCount == 1)

        // Even an encoder that ignores cancellation and returns late cannot
        // publish generation A's payload or clear generation B's recording.
        await encoder.succeed(Data([0xAA]), at: 0)
        do {
            _ = try await firstStop.value
            Issue.record("Cancelled encoding unexpectedly produced audio")
        } catch is CancellationError {
            // Expected.
        } catch {
            Issue.record("Expected CancellationError, got \(error)")
        }

        #expect(capture.state == .recording)
        #expect(restartedSession.stopCount == 0)
        #expect(restartedSession.discardCount == 0)

        capture.cancel()
        #expect(restartedSession.stopCount == 1)
        #expect(restartedSession.discardCount == 1)
    }
}

@MainActor
private func makeCapture(
    authorizer: ControlledMicrophoneAuthorizer,
    factory: TestVoiceAudioCaptureSessionFactory,
    encoder: ControlledVoiceAudioEncoder,
    sleeper: ControlledLimitSleeper
) -> VoiceAudioCapture {
    VoiceAudioCapture(
        authorizer: authorizer,
        maximumDuration: 1,
        sessionFactory: { duration in
            try factory.make(maximumDuration: duration)
        },
        encoder: { samples, sampleRate in
            try await encoder.encode(samples: samples, sampleRate: sampleRate)
        },
        limitSleeper: { duration in
            try await sleeper.sleep(for: duration)
        }
    )
}

private final class ControlledMicrophoneAuthorizer: MicrophoneAuthorizing, @unchecked Sendable {
    private let lock = NSLock()
    private var statuses: [MicrophoneAuthorizationStatus]
    private var requestContinuation: CheckedContinuation<Bool, Never>?
    private var requestWaiter: CheckedContinuation<Void, Never>?

    init(statuses: [MicrophoneAuthorizationStatus]) {
        self.statuses = statuses
    }

    func authorizationStatus() -> MicrophoneAuthorizationStatus {
        lock.lock()
        defer { lock.unlock() }

        guard !statuses.isEmpty else { return .authorized }
        if statuses.count == 1 { return statuses[0] }
        return statuses.removeFirst()
    }

    func requestAuthorization() async -> Bool {
        await withCheckedContinuation { continuation in
            lock.lock()
            requestContinuation = continuation
            let waiter = requestWaiter
            requestWaiter = nil
            lock.unlock()
            waiter?.resume()
        }
    }

    func waitForRequest() async {
        await withCheckedContinuation { continuation in
            lock.lock()
            if requestContinuation != nil {
                lock.unlock()
                continuation.resume()
            } else {
                requestWaiter = continuation
                lock.unlock()
            }
        }
    }

    func resolveRequest(granted: Bool) {
        lock.lock()
        let continuation = requestContinuation
        requestContinuation = nil
        lock.unlock()
        continuation?.resume(returning: granted)
    }
}

private final class TestVoiceAudioCaptureSession: VoiceAudioCaptureSession {
    let sampleRate: Double
    private var samples: [Float]

    private(set) var startCount = 0
    private(set) var stopCount = 0
    private(set) var takeSamplesCount = 0
    private(set) var discardCount = 0

    init(samples: [Float], sampleRate: Double) {
        self.samples = samples
        self.sampleRate = sampleRate
    }

    func start() throws {
        startCount += 1
    }

    func stop() {
        stopCount += 1
    }

    func takeSamples() -> [Float] {
        takeSamplesCount += 1
        let result = samples
        samples.removeAll(keepingCapacity: false)
        return result
    }

    func discard() {
        discardCount += 1
        samples.removeAll(keepingCapacity: false)
    }

    func level() -> Float { 0.5 }
}

@MainActor
private final class TestVoiceAudioCaptureSessionFactory {
    private var sessions: [TestVoiceAudioCaptureSession]
    private(set) var requestedMaximumDurations: [TimeInterval] = []

    init(sessions: [TestVoiceAudioCaptureSession]) {
        self.sessions = sessions
    }

    func make(maximumDuration: TimeInterval) throws -> any VoiceAudioCaptureSession {
        requestedMaximumDurations.append(maximumDuration)
        guard !sessions.isEmpty else {
            throw VoiceCaptureError.couldNotStart("Test session queue is empty")
        }
        return sessions.removeFirst()
    }
}

private actor ControlledVoiceAudioEncoder {
    struct Invocation: Sendable, Equatable {
        let samples: [Float]
        let sampleRate: Double
    }

    private var invocations: [Invocation] = []
    private var completions: [Int: CheckedContinuation<Data, Error>] = [:]
    private var invocationWaiters: [Int: [CheckedContinuation<Invocation, Never>]] = [:]

    func encode(samples: [Float], sampleRate: Double) async throws -> Data {
        let index = invocations.count
        let invocation = Invocation(samples: samples, sampleRate: sampleRate)
        invocations.append(invocation)

        let waiters = invocationWaiters.removeValue(forKey: index) ?? []
        for waiter in waiters {
            waiter.resume(returning: invocation)
        }

        return try await withCheckedThrowingContinuation { continuation in
            completions[index] = continuation
        }
    }

    func invocation(at index: Int) async -> Invocation {
        if invocations.indices.contains(index) {
            return invocations[index]
        }
        return await withCheckedContinuation { continuation in
            invocationWaiters[index, default: []].append(continuation)
        }
    }

    func succeed(_ data: Data, at index: Int) {
        completions.removeValue(forKey: index)?.resume(returning: data)
    }
}

private actor ControlledLimitSleeper {
    private struct ScheduledSleep {
        let id: UUID
        let duration: TimeInterval
    }

    private var scheduled: [ScheduledSleep] = []
    private var completions: [UUID: CheckedContinuation<Void, Error>] = [:]
    private var scheduleWaiters: [Int: [CheckedContinuation<TimeInterval, Never>]] = [:]

    func sleep(for duration: TimeInterval) async throws {
        let id = UUID()
        let index = scheduled.count
        scheduled.append(ScheduledSleep(id: id, duration: duration))

        let waiters = scheduleWaiters.removeValue(forKey: index) ?? []
        for waiter in waiters {
            waiter.resume(returning: duration)
        }

        try await withTaskCancellationHandler {
            try Task.checkCancellation()
            try await withCheckedThrowingContinuation { continuation in
                completions[id] = continuation
            }
        } onCancel: {
            Task { await self.cancelSleep(id: id) }
        }
    }

    func scheduledDuration(at index: Int) async -> TimeInterval {
        if scheduled.indices.contains(index) {
            return scheduled[index].duration
        }
        return await withCheckedContinuation { continuation in
            scheduleWaiters[index, default: []].append(continuation)
        }
    }

    func fire(at index: Int) {
        guard scheduled.indices.contains(index) else { return }
        let id = scheduled[index].id
        completions.removeValue(forKey: id)?.resume()
    }

    private func cancelSleep(id: UUID) {
        completions.removeValue(forKey: id)?.resume(throwing: CancellationError())
    }
}

@MainActor
private final class HardLimitCallbackProbe {
    enum Event: Equatable {
        case limitReached
        case concurrentStopFinished
        case automaticStopFinished
    }

    private(set) var events: [Event] = []
    private(set) var stateAtLimit: VoiceAudioCaptureState?
    private(set) var concurrentStopTask: Task<
        Result<CapturedVoiceAudio, VoiceCaptureError>,
        Never
    >?

    private var automaticStopResult: Result<CapturedVoiceAudio, VoiceCaptureError>?
    private var automaticStopWaiter: CheckedContinuation<
        Result<CapturedVoiceAudio, VoiceCaptureError>,
        Never
    >?

    func recordLimit(for capture: VoiceAudioCapture) {
        stateAtLimit = capture.state
        events.append(.limitReached)
        concurrentStopTask = Task { @MainActor [weak self, weak capture] in
            guard let capture else { return .failure(.notRecording) }
            let result: Result<CapturedVoiceAudio, VoiceCaptureError>
            do {
                result = .success(try await capture.stop())
            } catch let error as VoiceCaptureError {
                result = .failure(error)
            } catch {
                result = .failure(.couldNotStart(error.localizedDescription))
            }
            self?.events.append(.concurrentStopFinished)
            return result
        }
    }

    func recordAutomaticStop(_ result: Result<CapturedVoiceAudio, VoiceCaptureError>) {
        automaticStopResult = result
        events.append(.automaticStopFinished)
        automaticStopWaiter?.resume(returning: result)
        automaticStopWaiter = nil
    }

    func waitForAutomaticStop() async -> Result<CapturedVoiceAudio, VoiceCaptureError> {
        if let automaticStopResult { return automaticStopResult }
        return await withCheckedContinuation { continuation in
            automaticStopWaiter = continuation
        }
    }
}
