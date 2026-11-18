import Testing

@testable import FarsangCore

struct HeartRateZonesTests {
    @Test func estimatesMaxHeartRateFromAge() {
        #expect(HeartRateZones(age: 30).maxHeartRate == 190)
        #expect(HeartRateZones.estimatedMaxHeartRate(forAge: 45) == 175)
    }

    @Test(arguments: [
        (99.0, nil), (100.0, HeartRateZone.one), (119.9, .one), (120.0, .two), (139.0, .two),
        (140.0, .three), (160.0, .four), (179.9, .four), (180.0, .five), (200.0, .five), (230.0, .five)
    ])
    func assignsZonesForMax200(bpm: Double, expected: HeartRateZone?) {
        #expect(HeartRateZones(maxHeartRate: 200).zone(for: bpm) == expected)
    }

    @Test func zoneBoundariesFollowTheMaxHeartRate() {
        #expect(HeartRateZones(maxHeartRate: 200).zone(for: 150) == .three)
        #expect(HeartRateZones(maxHeartRate: 160).zone(for: 150) == .five)
    }

    @Test func exposesLowerBounds() {
        let zones = HeartRateZones(maxHeartRate: 190)
        #expect(zones.lowerBound(of: .one) == 95)
        #expect(zones.lowerBound(of: .five) == 171)
    }

    @Test func invalidMaxHeartRateHasNoZones() {
        #expect(HeartRateZones(age: 230).zone(for: 150) == nil)
        #expect(HeartRateZones(maxHeartRate: 0).zone(for: 150) == nil)
        #expect(HeartRateZones(maxHeartRate: .nan).zone(for: 150) == nil)
    }

    @Test func zonesAreOrdered() {
        #expect(HeartRateZone.two < HeartRateZone.four)
        #expect(HeartRateZone.allCases.count == 5)
    }

    @Test func extremeAgesDoNotTrap() {
        #expect(HeartRateZones.estimatedMaxHeartRate(forAge: .min) > 0)
        #expect(HeartRateZones.estimatedMaxHeartRate(forAge: .max) < 0)
        #expect(HeartRateZones(age: .max).zone(for: 150) == nil)
    }

    @Test(arguments: [191.0, 187.0, 173.0, 199.0, 203.5, 211.0, 157.0])
    func classifiesTheBoundsItPublishes(maxHeartRate: Double) {
        let zones = HeartRateZones(maxHeartRate: maxHeartRate)
        for zone in HeartRateZone.allCases {
            let lower = zones.lowerBound(of: zone)
            #expect(zones.zone(for: lower) == zone)
            #expect(zones.zone(for: lower.nextDown) != zone)
        }
    }
}
