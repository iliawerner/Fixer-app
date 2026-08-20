import Foundation

enum WAVAudioEncoder {
    static func encodeMonoPCM16(
        samples: [Float],
        sourceSampleRate: Double,
        outputSampleRate: Int = VoiceCapturePolicy.outputSampleRate
    ) throws -> Data {
        guard !samples.isEmpty,
              sourceSampleRate.isFinite,
              sourceSampleRate > 0,
              outputSampleRate > 0 else {
            throw VoiceCaptureError.couldNotEncode
        }

        let output = try resample(
            samples: samples,
            sourceSampleRate: sourceSampleRate,
            outputSampleRate: Double(outputSampleRate)
        )
        guard !output.isEmpty else { throw VoiceCaptureError.couldNotEncode }

        let bytesPerSample = 2
        let dataByteCount = output.count * bytesPerSample
        guard dataByteCount <= Int(UInt32.max) - 36 else {
            throw VoiceCaptureError.couldNotEncode
        }

        var wav = Data()
        wav.reserveCapacity(44 + dataByteCount)
        wav.append(contentsOf: "RIFF".utf8)
        wav.appendLittleEndian(UInt32(36 + dataByteCount))
        wav.append(contentsOf: "WAVE".utf8)
        wav.append(contentsOf: "fmt ".utf8)
        wav.appendLittleEndian(UInt32(16))          // PCM fmt chunk size
        wav.appendLittleEndian(UInt16(1))           // linear PCM
        wav.appendLittleEndian(UInt16(1))           // mono
        wav.appendLittleEndian(UInt32(outputSampleRate))
        wav.appendLittleEndian(UInt32(outputSampleRate * bytesPerSample))
        wav.appendLittleEndian(UInt16(bytesPerSample))
        wav.appendLittleEndian(UInt16(16))
        wav.append(contentsOf: "data".utf8)
        wav.appendLittleEndian(UInt32(dataByteCount))

        for (index, sample) in output.enumerated() {
            if index.isMultiple(of: 4_096) {
                try Task.checkCancellation()
            }
            let clamped = max(-1, min(1, sample))
            let scaled: Int16
            if clamped == -1 {
                scaled = .min
            } else {
                scaled = Int16((clamped * Float(Int16.max)).rounded())
            }
            wav.appendLittleEndian(UInt16(bitPattern: scaled))
        }

        return wav
    }

    /// A small box filter prevents obvious aliasing while downsampling common
    /// 44.1/48 kHz microphone input. Linear interpolation covers the uncommon
    /// upsampling case. Both run only after capture leaves the render thread.
    static func resample(
        samples: [Float],
        sourceSampleRate: Double,
        outputSampleRate: Double
    ) throws -> [Float] {
        guard !samples.isEmpty,
              sourceSampleRate.isFinite,
              outputSampleRate.isFinite,
              sourceSampleRate > 0,
              outputSampleRate > 0 else { return [] }
        guard sourceSampleRate != outputSampleRate else { return samples }

        let sourceStep = sourceSampleRate / outputSampleRate
        let outputCount = max(1, Int((Double(samples.count) / sourceStep).rounded()))

        if sourceStep > 1 {
            var result: [Float] = []
            result.reserveCapacity(outputCount)
            for outputIndex in 0..<outputCount {
                if outputIndex.isMultiple(of: 4_096) {
                    try Task.checkCancellation()
                }
                let start = Double(outputIndex) * sourceStep
                let end = min(Double(samples.count), Double(outputIndex + 1) * sourceStep)
                guard end > start else {
                    result.append(samples[min(samples.count - 1, Int(start))])
                    continue
                }

                let firstIndex = Int(start.rounded(.down))
                let lastIndex = min(samples.count - 1, Int(end.rounded(.up)) - 1)
                var weightedSum: Double = 0
                var totalWeight: Double = 0

                for sourceIndex in firstIndex...lastIndex {
                    let overlapStart = max(start, Double(sourceIndex))
                    let overlapEnd = min(end, Double(sourceIndex + 1))
                    let weight = max(0, overlapEnd - overlapStart)
                    weightedSum += Double(samples[sourceIndex]) * weight
                    totalWeight += weight
                }
                result.append(totalWeight > 0 ? Float(weightedSum / totalWeight) : 0)
            }
            return result
        }

        var result: [Float] = []
        result.reserveCapacity(outputCount)
        for outputIndex in 0..<outputCount {
            if outputIndex.isMultiple(of: 4_096) {
                try Task.checkCancellation()
            }
            let sourcePosition = min(Double(samples.count - 1), Double(outputIndex) * sourceStep)
            let lowerIndex = Int(sourcePosition)
            let upperIndex = min(samples.count - 1, lowerIndex + 1)
            let fraction = Float(sourcePosition - Double(lowerIndex))
            result.append(
                samples[lowerIndex] + (samples[upperIndex] - samples[lowerIndex]) * fraction
            )
        }
        return result
    }
}

private extension Data {
    mutating func appendLittleEndian<T: FixedWidthInteger>(_ value: T) {
        var littleEndian = value.littleEndian
        Swift.withUnsafeBytes(of: &littleEndian) { bytes in
            append(contentsOf: bytes)
        }
    }
}
