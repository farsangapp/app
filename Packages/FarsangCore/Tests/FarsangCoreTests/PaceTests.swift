import Testing

@testable import FarsangCore

struct PaceTests {
    @Test func computesSecondsPerKilometer() throws {
        let pace = try #require(Pace(duration: 300, distance: Distance(meters: 1_000)))
        #expect(pace.secondsPerKilometer == 300)
    }

    @Test func convertsToSecondsPerMile() throws {
        let pace = try #require(Pace(duration: 300, distance: Distance(meters: 1_000)))
        #expect(abs(pace.secondsPerMile - 300 * 1.609344) < 1e-9)
    }

    @Test func isNilWithoutDistance() {
        #expect(Pace(duration: 60, distance: .zero) == nil)
    }

    @Test func isNilWithoutElapsedTime() {
        #expect(Pace(duration: 0, distance: Distance(meters: 5)) == nil)
    }

    @Test func fasterPaceIsSmaller() {
        #expect(Pace(secondsPerKilometer: 240) < Pace(secondsPerKilometer: 300))
    }
}

struct CoordinateTests {
    @Test func oneDegreeOfLatitudeIsAbout111Kilometers() {
        let start = Coordinate(latitude: 10, longitude: 20)
        let meters = start.distance(to: Coordinate(latitude: 11, longitude: 20)).meters
        #expect(abs(meters - 111_194.9) < 1)
    }

    @Test func distanceToSelfIsZero() {
        let point = Coordinate(latitude: 47, longitude: 8)
        #expect(point.distance(to: point).meters == 0)
    }

    @Test func longitudeShrinksWithLatitude() {
        let atEquator = Coordinate(latitude: 0, longitude: 0).distance(to: Coordinate(latitude: 0, longitude: 1))
        let at60 = Coordinate(latitude: 60, longitude: 0).distance(to: Coordinate(latitude: 60, longitude: 1))
        #expect(abs(at60.meters / atEquator.meters - 0.5) < 0.001)
    }

    @Test func isNilWhenTheQuotientIsNotUsable() {
        #expect(Pace(duration: 60, distance: Distance(meters: .leastNonzeroMagnitude)) == nil)
        #expect(Pace(duration: .infinity, distance: Distance(meters: 1_000)) == nil)
        #expect(Pace(duration: 60, distance: Distance(meters: .infinity)) == nil)
        #expect(Pace(duration: .nan, distance: Distance(meters: 1_000)) == nil)
    }
}
