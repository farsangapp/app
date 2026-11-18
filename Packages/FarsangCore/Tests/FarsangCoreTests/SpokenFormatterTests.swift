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

    @Test func overflowingDistanceFallsBackToZeroMarker() {
        #expect(
            SpokenFormatter.distanceMarker(fromMeters: .greatestFiniteMagnitude, unitSystem: .metric)
                == "kilometer 0")
    }
}

struct SpokenDistanceTests {
    @Test func speaksShortMetricDistanceInMeters() {
        #expect(SpokenFormatter.distance(fromMeters: 150, unitSystem: .metric) == "150 meters")
        #expect(SpokenFormatter.distance(fromMeters: 148, unitSystem: .metric) == "150 meters")
    }

    @Test func neverSpeaksZeroMeters() {
        #expect(SpokenFormatter.distance(fromMeters: 2, unitSystem: .metric) == "10 meters")
    }

    @Test func speaksLongMetricDistanceInKilometers() {
        #expect(SpokenFormatter.distance(fromMeters: 1_240, unitSystem: .metric) == "1.2 kilometers")
        #expect(SpokenFormatter.distance(fromMeters: 1_000, unitSystem: .metric) == "1 kilometer")
        #expect(SpokenFormatter.distance(fromMeters: 2_000, unitSystem: .metric) == "2 kilometers")
    }

    @Test func speaksShortImperialDistanceInFeet() {
        #expect(SpokenFormatter.distance(fromMeters: 60, unitSystem: .imperial) == "200 feet")
        #expect(SpokenFormatter.distance(fromMeters: 1, unitSystem: .imperial) == "50 feet")
    }

    @Test func speaksLongImperialDistanceInMiles() {
        #expect(SpokenFormatter.distance(fromMeters: 482.8, unitSystem: .imperial) == "0.3 miles")
        #expect(SpokenFormatter.distance(fromMeters: 1_609.344, unitSystem: .imperial) == "1 mile")
    }

    @Test func invalidDistanceSpeaksZero() {
        #expect(SpokenFormatter.distance(fromMeters: -1, unitSystem: .metric) == "0 meters")
        #expect(SpokenFormatter.distance(fromMeters: .nan, unitSystem: .imperial) == "0 feet")
    }
}
