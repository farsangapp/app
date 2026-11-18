import Testing
@testable import FarsangCore

struct ElapsedTimeFormatterTests {
    @Test func formatsMinutesAndSeconds() {
        #expect(ElapsedTimeFormatter.string(fromSeconds: 1_938) == "32:18")
    }

    @Test func formatsHoursMinutesAndSeconds() {
        #expect(ElapsedTimeFormatter.string(fromSeconds: 3_909) == "1:05:09")
    }

    @Test func zeroIsZero() {
        #expect(ElapsedTimeFormatter.string(fromSeconds: 0) == "0:00")
    }

    @Test func negativeClampsToZero() {
        #expect(ElapsedTimeFormatter.string(fromSeconds: -5) == "0:00")
    }

    @Test func roundsSecondsToNearest() {
        #expect(ElapsedTimeFormatter.string(fromSeconds: 1_938.4) == "32:18")
        #expect(ElapsedTimeFormatter.string(fromSeconds: 1_938.6) == "32:19")
    }

    @Test func exactlyOneHour() {
        #expect(ElapsedTimeFormatter.string(fromSeconds: 3_600) == "1:00:00")
    }

    @Test func roundsHalfUpToNextUnit() {
        #expect(ElapsedTimeFormatter.string(fromSeconds: 3_599.5) == "1:00:00")
    }

    @Test func rejectsSecondsThatDoNotFitInInt() {
        #expect(ElapsedTimeFormatter.string(fromSeconds: Double(Int.max)) == "0:00")
    }

    @Test func padsSingleDigitSeconds() {
        #expect(ElapsedTimeFormatter.string(fromSeconds: 61) == "1:01")
        #expect(ElapsedTimeFormatter.string(fromSeconds: 600) == "10:00")
    }
}
