import Testing
@testable import FarsangCore

struct DistanceFormatterTests {
    @Test func formatsKilometers() {
        #expect(DistanceFormatter.string(fromMeters: 6_210, unitSystem: .metric) == "6.21 km")
    }

    @Test func formatsMiles() {
        #expect(DistanceFormatter.string(fromMeters: 6_210, unitSystem: .imperial) == "3.86 mi")
    }

    @Test func roundsDownToTwoDecimals() {
        #expect(DistanceFormatter.string(fromMeters: 6_214, unitSystem: .metric) == "6.21 km")
    }

    @Test func roundsUpToTwoDecimals() {
        #expect(DistanceFormatter.string(fromMeters: 6_216, unitSystem: .metric) == "6.22 km")
    }

    @Test func zeroDistanceFormatsAsZero() {
        #expect(DistanceFormatter.string(fromMeters: 0, unitSystem: .metric) == "0.00 km")
        #expect(DistanceFormatter.string(fromMeters: 0, unitSystem: .imperial) == "0.00 mi")
    }

    @Test func wholeKilometersKeepTwoDecimals() {
        #expect(DistanceFormatter.string(fromMeters: 5_000, unitSystem: .metric) == "5.00 km")
    }
}
