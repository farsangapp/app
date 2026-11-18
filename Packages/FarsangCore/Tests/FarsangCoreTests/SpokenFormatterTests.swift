import Testing
@testable import FarsangCore

struct SpokenFormatterTests {
    @Test func speaksPacePerKilometer() {
        #expect(SpokenFormatter.pace(fromSecondsPerUnit: 310, unitSystem: .metric) == "five ten per kilometer")
    }

    @Test func speaksPacePerMile() {
        #expect(SpokenFormatter.pace(fromSecondsPerUnit: 310, unitSystem: .imperial) == "five ten per mile")
    }

    @Test func speaksSingleDigitSeconds() {
        #expect(SpokenFormatter.pace(fromSecondsPerUnit: 307, unitSystem: .metric) == "five seven per kilometer")
    }

    @Test func speaksCompoundSeconds() {
        #expect(SpokenFormatter.pace(fromSecondsPerUnit: 335, unitSystem: .metric) == "five thirty-five per kilometer")
    }

    @Test func invalidPaceIsEmpty() {
        #expect(SpokenFormatter.pace(fromSecondsPerUnit: 0, unitSystem: .metric) == "")
        #expect(SpokenFormatter.pace(fromSecondsPerUnit: 3_600, unitSystem: .metric) == "")
    }

    @Test func speaksKilometerMarker() {
        #expect(SpokenFormatter.distanceMarker(fromMeters: 6_000, unitSystem: .metric) == "kilometer 6")
    }

    @Test func speaksMileMarker() {
        #expect(SpokenFormatter.distanceMarker(fromMeters: 1_609.344, unitSystem: .imperial) == "mile 1")
    }

    @Test func zeroDistanceMarker() {
        #expect(SpokenFormatter.distanceMarker(fromMeters: 0, unitSystem: .metric) == "kilometer 0")
    }
}
