import Testing
@testable import FarsangCore

struct PaceFormatterTests {
    @Test func formatsMinutesAndSeconds() {
        #expect(PaceFormatter.string(fromSecondsPerUnit: 312) == "5:12")
    }

    @Test func formatsMetricPaceFromSpeed() {
        #expect(PaceFormatter.string(fromSpeed: 5, unitSystem: .metric) == "3:20")
    }

    @Test func formatsImperialPaceFromSpeed() {
        #expect(PaceFormatter.string(fromSpeed: 5, unitSystem: .imperial) == "5:22")
    }

    @Test func zeroSpeedIsDash() {
        #expect(PaceFormatter.string(fromSpeed: 0, unitSystem: .metric) == "--:--")
        #expect(PaceFormatter.string(fromSpeed: 0, unitSystem: .imperial) == "--:--")
    }

    @Test func paceOverSixtyMinutesIsDash() {
        #expect(PaceFormatter.string(fromSecondsPerUnit: 3_600) == "--:--")
        #expect(PaceFormatter.string(fromSecondsPerUnit: 4_000) == "--:--")
    }

    @Test func justUnderSixtyMinutesFormats() {
        #expect(PaceFormatter.string(fromSecondsPerUnit: 3_599) == "59:59")
    }

    @Test func roundsSecondsToNearest() {
        #expect(PaceFormatter.string(fromSecondsPerUnit: 312.4) == "5:12")
        #expect(PaceFormatter.string(fromSecondsPerUnit: 312.6) == "5:13")
    }

    @Test func roundsToWholeSecondBeforeBoundary() {
        #expect(PaceFormatter.string(fromSecondsPerUnit: 3_599.49) == "59:59")
        #expect(PaceFormatter.string(fromSecondsPerUnit: 3_599.5) == "--:--")
    }
}
