import Foundation
import Testing

@testable import FarsangCore

struct GPXParserTests {
    // MARK: Tracks

    @Test func readsTracksSegmentsAndPoints() throws {
        let document = try parseFixture("track-1.1")

        #expect(document.name == "Fixture file name")
        #expect(document.tracks.count == 2)
        #expect(document.routes.isEmpty)
        #expect(document.waypoints.isEmpty)

        let track = document.tracks[0]
        #expect(track.name == "Test Loop")
        #expect(track.segments.count == 2)
        #expect(track.segments[0].points.count == 3)
        #expect(track.segments[1].points.count == 1)
        #expect(document.tracks[1].name == nil)
    }

    @Test func readsPositionElevationAndTimeOfTrackPoints() throws {
        let points = try parseFixture("track-1.1").tracks[0].segments[0].points

        #expect(points[0].latitude == 0.0010)
        #expect(points[0].longitude == 0.0020)
        #expect(points[0].elevation == 12.5)
        #expect(points[0].time == date("2025-01-01T08:00:00Z"))
        #expect(points[1].time == date("2025-01-01T08:00:05.5Z"))
    }

    @Test func leavesElevationAndTimeNilWhenAbsent() throws {
        let point = try parseFixture("track-1.1").tracks[0].segments[0].points[2]

        #expect(point.elevation == nil)
        #expect(point.time == nil)
    }

    @Test func readsTimesWithAnOffset() throws {
        let point = try parseFixture("track-1.1").tracks[0].segments[1].points[0]

        #expect(point.latitude == -0.0030)
        #expect(point.longitude == -0.0040)
        #expect(point.time == date("2025-01-01T06:10:00Z"))
    }

    @Test func ignoresExtensionContent() throws {
        let points = try parseFixture("track-1.1").tracks[0].segments[0].points

        #expect(points.count == 3)
        #expect(points[0].elevation == 12.5)
    }

    @Test func pointsFlattenEverySegmentInOrder() throws {
        let track = try parseFixture("track-1.1").tracks[0]

        #expect(track.points.map(\.latitude) == [0.0010, 0.0011, 0.0012, -0.0030])
    }

    // MARK: Routes

    @Test func readsRoutePoints() throws {
        let document = try parseFixture("route-1.0")

        #expect(document.routes.count == 1)
        let route = document.routes[0]
        #expect(route.name == "Test Route")
        #expect(route.points.count == 3)
        #expect(route.points[0].latitude == 0.0500)
        #expect(route.points[0].longitude == 0.0600)
        #expect(route.points[0].elevation == 5)
        #expect(route.points[0].time == nil)
        #expect(route.points[1].elevation == nil)
        #expect(route.points[2].elevation == 7.25)
    }

    // MARK: Waypoints

    @Test func readsWaypoints() throws {
        let document = try parseFixture("waypoints")

        #expect(document.tracks.isEmpty)
        #expect(document.waypoints.count == 3)

        let water = document.waypoints[0]
        #expect(water.name == "Water")
        #expect(water.description == "Fountain & bench")
        #expect(water.point.latitude == 0.0200)
        #expect(water.point.longitude == 0.0300)
        #expect(water.point.elevation == 20.5)
        #expect(water.point.time == date("2025-01-02T10:00:00Z"))
    }

    @Test func leavesWaypointNameAndDescriptionNilWhenAbsent() throws {
        let waypoints = try parseFixture("waypoints").waypoints

        #expect(waypoints[1].name == "Bare waypoint")
        #expect(waypoints[1].description == nil)
        #expect(waypoints[2].name == nil)
        #expect(waypoints[2].point.longitude == -0.0320)
    }

    // MARK: Versions and namespaces

    @Test func readsGPX10() throws {
        let document = try parseFixture("route-1.0")

        #expect(document.version == "1.0")
        #expect(document.name == "GPX 1.0 file name")
        #expect(document.tracks.count == 1)
        #expect(document.tracks[0].name == "Old style track")
        #expect(document.tracks[0].points[0].time == date("2025-01-01T09:00:00Z"))
    }

    @Test func readsGPX11() throws {
        #expect(try parseFixture("track-1.1").version == "1.1")
    }

    @Test func readsFilesWithoutANamespace() throws {
        let document = try parseFixture("no-namespace")

        #expect(document.routes[0].points.count == 2)
    }

    @Test func readsFilesWithAPrefixedNamespace() throws {
        let document = try parseFixture("prefixed-namespace")

        #expect(document.tracks[0].name == "Prefixed")
        #expect(document.tracks[0].points[0].elevation == 3)
    }

    @Test func readsAllThreeKindsFromOneFile() throws {
        let xml = """
            <gpx version="1.1" creator="x" xmlns="http://www.topografix.com/GPX/1/1">
              <wpt lat="1" lon="2"/>
              <rte><rtept lat="3" lon="4"/></rte>
              <trk><trkseg><trkpt lat="5" lon="6"/></trkseg></trk>
            </gpx>
            """
        let document = try GPXParser.parse(Data(xml.utf8))

        #expect(document.waypoints.count == 1)
        #expect(document.routes.count == 1)
        #expect(document.tracks.count == 1)
    }

    // MARK: Errors

    @Test func throwsOnInvalidXML() throws {
        let error = try #require(throws: GPXParseError.self) { try parseFixture("invalid-xml") }
        guard case .invalidXML = error else {
            Issue.record("expected invalidXML, got \(error)")
            return
        }
    }

    @Test func throwsOnEmptyData() {
        #expect(throws: GPXParseError.self) { try GPXParser.parse(Data()) }
    }

    @Test func throwsWhenTheRootIsNotGPX() {
        #expect(throws: GPXParseError.notGPX) { try parseFixture("not-gpx", extension: "xml") }
    }

    @Test func throwsWhenThereAreNoPoints() {
        #expect(throws: GPXParseError.noPoints) { try parseFixture("no-points") }
    }

    @Test func throwsWhenLatitudeIsOutOfRange() {
        #expect(throws: GPXParseError.coordinateOutOfRange(latitude: 90.5, longitude: 0.002, line: 5)) {
            try parseFixture("latitude-out-of-range")
        }
    }

    @Test func throwsWhenLongitudeIsOutOfRange() {
        #expect(throws: GPXParseError.coordinateOutOfRange(latitude: 0.001, longitude: -180.5, line: 3)) {
            try parseFixture("longitude-out-of-range")
        }
    }

    @Test func throwsWhenACoordinateIsMissing() {
        #expect(throws: GPXParseError.invalidCoordinate(line: 5)) { try parseFixture("missing-coordinate") }
    }

    @Test func throwsWhenACoordinateIsNotANumber() {
        #expect(throws: GPXParseError.invalidCoordinate(line: 4)) { try parseFixture("non-numeric-coordinate") }
    }

    @Test func acceptsCoordinatesOnTheBoundaries() throws {
        let xml = """
            <gpx version="1.1" creator="x">
              <wpt lat="90" lon="180"/><wpt lat="-90" lon="-180"/>
            </gpx>
            """
        #expect(try GPXParser.parse(Data(xml.utf8)).waypoints.count == 2)
    }

    @Test func rejectsNonFiniteCoordinates() {
        let xml = #"<gpx version="1.1" creator="x"><wpt lat="nan" lon="0"/></gpx>"#
        #expect(throws: GPXParseError.invalidCoordinate(line: 1)) { try GPXParser.parse(Data(xml.utf8)) }
    }

    @Test func throwsWhenTheFileCannotBeRead() {
        let url = URL(fileURLWithPath: "/nonexistent/farsang-fixture.gpx")
        #expect(throws: GPXParseError.unreadable) { try GPXParser.parse(contentsOf: url) }
    }

    @Test func ignoresAnUnparseableElevationOrTime() throws {
        let xml = """
            <gpx version="1.1" creator="x">
              <wpt lat="1" lon="2"><ele>high</ele><time>yesterday</time></wpt>
            </gpx>
            """
        let point = try GPXParser.parse(Data(xml.utf8)).waypoints[0].point

        #expect(point.elevation == nil)
        #expect(point.time == nil)
    }

    @Test func readsLeapDaysAndRejectsImpossibleDates() throws {
        func time(_ value: String) throws -> Date? {
            let xml = #"<gpx version="1.1" creator="x"><wpt lat="1" lon="2"><time>\#(value)</time></wpt></gpx>"#
            return try GPXParser.parse(Data(xml.utf8)).waypoints[0].point.time
        }

        #expect(try time("2024-02-29T23:59:59Z") == date("2024-02-29T23:59:59Z"))
        #expect(try time("1969-12-31T23:59:59Z") == Date(timeIntervalSince1970: -1))
        #expect(try time("2025-02-29T00:00:00Z") == nil)
        #expect(try time("2025-13-01T00:00:00Z") == nil)
        #expect(try time("0000-01-01T00:00:00Z") == nil)
        #expect(try time("2025-01-01T08:00:00") == nil)
        #expect(try time("2025-01-01T08:00:00.1234567890123456789012345Z") != nil)
    }

    // MARK: Large files

    @Test func parsesMoreThanFiftyThousandPointsFromData() throws {
        let count = 60_000
        let document = try GPXParser.parse(Data(Self.largeGPX(pointCount: count).utf8))

        #expect(document.tracks[0].points.count == count)
        #expect(document.tracks[0].points[count - 1].elevation == Double((count - 1) % 100))
    }

    @Test func parsesMoreThanFiftyThousandPointsFromAFile() throws {
        let count = 60_000
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("farsang-\(UUID().uuidString).gpx")
        try Data(Self.largeGPX(pointCount: count).utf8).write(to: url)
        defer { try? FileManager.default.removeItem(at: url) }

        let document = try GPXParser.parse(contentsOf: url)

        #expect(document.tracks[0].points.count == count)
    }

    // MARK: Helpers

    private func parseFixture(_ name: String, extension fileExtension: String = "gpx") throws -> GPXDocument {
        let url = try #require(
            Bundle.module.url(forResource: name, withExtension: fileExtension, subdirectory: "Fixtures"))
        return try GPXParser.parse(contentsOf: url)
    }

    /// The expected value, decoded by Foundation rather than by the parser under test.
    private func date(_ iso8601: String) -> Date {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = formatter.date(from: iso8601) { return date }
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.date(from: iso8601)!
    }

    private static func largeGPX(pointCount: Int) -> String {
        var xml = #"<gpx version="1.1" creator="x" xmlns="http://www.topografix.com/GPX/1/1"><trk><trkseg>"#
        xml.reserveCapacity(pointCount * 110)
        for index in 0..<pointCount {
            let latitude = 0.0001 * Double(index % 1_000)
            let longitude = 0.0001 * Double(index / 1_000)
            xml += #"<trkpt lat="\#(latitude)" lon="\#(longitude)"><ele>\#(index % 100)</ele>"#
            xml += #"<time>2025-01-01T08:00:00Z</time></trkpt>"#
        }
        xml += "</trkseg></trk></gpx>"
        return xml
    }
}
