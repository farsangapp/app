import Testing
@testable import FarsangCore

struct DistanceTests {
    @Test func convertsMetersToKilometers() {
        #expect(Distance(meters: 1_500).kilometers == 1.5)
    }

    @Test func convertsMetersToMiles() {
        let miles = Distance(meters: 1_609.344).miles
        #expect(abs(miles - 1) < 1e-9)
    }

    @Test func zeroIsZeroInEveryUnit() {
        #expect(Distance.zero.kilometers == 0)
        #expect(Distance.zero.miles == 0)
    }
}

struct CoordinateRoundingTests {
    @Test func nearAntipodalPointsStayFinite() {
        let meters = Coordinate(latitude: 0, longitude: 0).distance(to: Coordinate(latitude: 0, longitude: 180)).meters
        #expect(meters.isFinite)
        #expect(abs(meters - 6_371_000 * .pi) < 1)
        let north = Coordinate(latitude: 90, longitude: 0).distance(to: Coordinate(latitude: -90, longitude: 0)).meters
        #expect(north.isFinite)
        // Exact antipodes whose unclamped half-chord term rounds to 1 + 2.2e-16, so only the clamp keeps this finite.
        let overshoot = Coordinate(latitude: -63, longitude: 0).distance(to: Coordinate(latitude: 63, longitude: -180))
        #expect(overshoot.meters.isFinite)
        #expect(abs(overshoot.meters - 6_371_000 * .pi) < 1)
    }
}
