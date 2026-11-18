import Foundation
import Testing

@testable import FarsangCore

struct GPXTimeTests {
    @Test func ignoresAnUnparseableElevationOrTime() throws {
        let xml = """
            <gpx version="1.1" creator="x">
              <wpt lat="1" lon="2"><ele>high</ele><time>yesterday</time></wpt>
            </gpx>
            """
        let point = try #require(GPXParser.parse(Data(xml.utf8)).waypoints.first?.point)

        #expect(point.elevation == nil)
        #expect(point.time == nil)
    }

    @Test func readsLeapDaysAndRejectsImpossibleDates() throws {
        #expect(try time("2024-02-29T23:59:59Z") == isoDate("2024-02-29T23:59:59Z"))
        #expect(try time("1969-12-31T23:59:59Z") == Date(timeIntervalSince1970: -1))
        #expect(try time("2025-02-29T00:00:00Z") == nil)
        #expect(try time("2025-13-01T00:00:00Z") == nil)
        #expect(try time("0000-01-01T00:00:00Z") == nil)
        #expect(try time("2025-01-01T08:00:00") == nil)
        #expect(try time("2025-01-01T08:00:00.1234567890123456789012345Z") != nil)
    }

    @Test func readsTimesBeyondThe32BitEpochRange() throws {
        #expect(try time("2040-01-01T00:00:00Z") == Date(timeIntervalSince1970: 2_208_988_800))
        #expect(try time("1850-01-01T00:00:00Z") == isoDate("1850-01-01T00:00:00Z"))
    }

    @Test func readsTheEndOfDayForm() throws {
        #expect(try time("2025-12-31T24:00:00Z") == isoDate("2026-01-01T00:00:00Z"))
        #expect(try time("2024-02-28T24:00:00.000Z") == isoDate("2024-02-29T00:00:00Z"))
        #expect(try time("2025-12-31T24:00:01Z") == nil)
        #expect(try time("2025-12-31T24:01:00Z") == nil)
        #expect(try time("2025-12-31T24:00:00.5Z") == nil)
        #expect(try time("2025-12-31T24:00:00.0000000001Z") == nil)
        #expect(try time("2025-02-29T24:00:00Z") == nil)
        #expect(try time("2025-12-31T25:00:00Z") == nil)
    }

    @Test func readsASecondOf60OnlyAsALeapSecondAtTheEndOfAUTCDay() throws {
        // A leap second is the instant just before the next midnight, so it equals 24:00:00.
        #expect(try time("2016-12-31T23:59:60Z") == isoDate("2017-01-01T00:00:00Z"))
        #expect(try time("2016-12-31T23:59:60.5Z") == isoDate("2017-01-01T00:00:00.5Z"))
        #expect(try time("2017-01-01T01:59:60+02:00") == isoDate("2017-01-01T00:00:00Z"))
        #expect(try time("2016-12-31T18:59:60-05:00") == isoDate("2017-01-01T00:00:00Z"))
        #expect(try time("2025-01-01T08:00:60Z") == nil)
        #expect(try time("2025-01-01T23:58:60Z") == nil)
        #expect(try time("2025-01-01T22:59:60Z") == nil)
        #expect(try time("2025-01-01T08:00:60+02:00") == nil)
        #expect(try time("2025-01-01T23:59:60+02:00") == nil)
        #expect(try time("2025-01-01T08:00:61Z") == nil)
    }

    @Test func validatesEveryFractionalDigit() throws {
        #expect(try time("2025-01-01T08:00:00.123456789xZ") == nil)
        #expect(try time("2025-01-01T08:00:00.123456789012x3Z") == nil)
        #expect(try time("2025-01-01T08:00:00.12x4Z") == nil)
        #expect(try time("2025-01-01T08:00:00.Z") == nil)
        #expect(try time("2025-01-01T08:00:00.123456789012Z") != nil)
    }

    @Test func rejectsImpossibleDatesWithAnOffset() throws {
        #expect(try time("2025-02-29T00:00:00+02:00") == nil)
        #expect(try time("2025-04-31T00:00:00-05:00") == nil)
        #expect(try time("2025-03-01T00:00:00+02:00") == isoDate("2025-02-28T22:00:00Z"))
        #expect(try time("2024-02-29T12:00:00+00:00") == isoDate("2024-02-29T12:00:00Z"))
    }

    // MARK: Helpers

    /// The `time` of a waypoint whose `time` element contains `value`.
    private func time(_ value: String) throws -> Date? {
        let xml = #"<gpx version="1.1" creator="x"><wpt lat="1" lon="2"><time>\#(value)</time></wpt></gpx>"#
        let waypoint = try #require(GPXParser.parse(Data(xml.utf8)).waypoints.first)
        return waypoint.point.time
    }
}

/// The expected value, decoded by Foundation rather than by the parser under test.
func isoDate(_ iso8601: String) -> Date {
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    if let date = formatter.date(from: iso8601) { return date }
    formatter.formatOptions = [.withInternetDateTime]
    return formatter.date(from: iso8601)!
}
