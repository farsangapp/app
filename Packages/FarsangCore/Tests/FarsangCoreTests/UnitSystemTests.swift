import Testing
@testable import FarsangCore

struct UnitSystemTests {
    @Test func convertsMetersToKilometers() {
        #expect(UnitSystem.metric.value(fromMeters: 1_500) == 1.5)
    }

    @Test func convertsMetersToMiles() {
        #expect(abs(UnitSystem.imperial.value(fromMeters: 1_609.344) - 1) < 1e-9)
    }

    @Test func zeroMetersIsZeroInBothSystems() {
        #expect(UnitSystem.metric.value(fromMeters: 0) == 0)
        #expect(UnitSystem.imperial.value(fromMeters: 0) == 0)
    }

    @Test func exposesSymbolsAndNames() {
        #expect(UnitSystem.metric.unitSymbol == "km")
        #expect(UnitSystem.imperial.unitSymbol == "mi")
        #expect(UnitSystem.metric.unitName == "kilometer")
        #expect(UnitSystem.imperial.unitName == "mile")
    }

    @Test func exposesMetersPerUnit() {
        #expect(UnitSystem.metric.metersPerUnit == 1_000)
        #expect(UnitSystem.imperial.metersPerUnit == 1_609.344)
    }
}
