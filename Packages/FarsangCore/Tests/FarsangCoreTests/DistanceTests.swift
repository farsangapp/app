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
