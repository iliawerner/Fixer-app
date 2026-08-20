import Foundation

enum AudioLevelMeter {
    /// Converts PCM samples to a stable 0...1 HUD level. The logarithmic mapping
    /// avoids a nearly motionless meter during ordinary speech while still
    /// preserving headroom for loud input.
    static func normalizedRMS<S: Collection>(samples: S) -> Float where S.Element == Float {
        guard !samples.isEmpty else { return 0 }

        let sumOfSquares = samples.reduce(0.0) { partial, sample in
            let bounded = Double(max(-1, min(1, sample)))
            return partial + bounded * bounded
        }
        return normalizedRMS(sumOfSquares: sumOfSquares, sampleCount: samples.count)
    }

    /// Render-thread-friendly form that avoids allocating a temporary sample
    /// array solely to update the level meter.
    static func normalizedRMS(sumOfSquares: Double, sampleCount: Int) -> Float {
        guard sampleCount > 0, sumOfSquares > 0 else { return 0 }
        let rms = sqrt(sumOfSquares / Double(sampleCount))
        guard rms > 0 else { return 0 }

        let decibels = 20 * log10(rms)
        let floorDecibels = -60.0
        return Float(max(0, min(1, (decibels - floorDecibels) / -floorDecibels)))
    }
}
