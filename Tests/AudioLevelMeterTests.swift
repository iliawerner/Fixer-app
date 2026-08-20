import Foundation
import Testing
@testable import fixer

struct AudioLevelMeterTests {
    @Test func silenceStaysAtRest() {
        #expect(AudioLevelMeter.normalizedRMS(samples: [0, 0, 0]) == 0)
        #expect(AudioLevelMeter.normalizedRMS(samples: [Float]()) == 0)
    }

    @Test func logarithmicScaleMakesOrdinarySpeechVisible() {
        // 0.03162 amplitude is approximately -30 dB, halfway through the
        // meter's -60...0 dB visual range.
        let level = AudioLevelMeter.normalizedRMS(
            samples: Array(repeating: Float(0.031_622_78), count: 16)
        )
        #expect(abs(level - 0.5) < 0.01)
    }

    @Test func levelIsClampedToUnitRange() {
        #expect(AudioLevelMeter.normalizedRMS(samples: [2, -2]) == 1)
        #expect(AudioLevelMeter.normalizedRMS(sumOfSquares: 0, sampleCount: 20) == 0)
    }
}
