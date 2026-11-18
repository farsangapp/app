import Foundation
import Testing

@testable import FarsangCore

struct GPXParserTests {
    // MARK: Tracks

    @Test func readsTracksSegmentsAndPoints() throws {
        let document = try parseFixture("track-1.1")

        #expect(document.name == "Fixture file name")
        #expect(document.routes.isEmpty)
        #expect(document.waypoints.isEmpty)

        try #require(document.tracks.count == 2)
        let track = document.tracks[0]
        #expect(track.name == "Test Loop")
        try #require(track.segments.count == 2)
        #expect(track.segments[0].points.count == 3)
        #expect(track.segments[1].points.count == 1)
        #expect(document.tracks[1].name == nil)
    }

    @Test func readsPositionElevationAndTimeOfTrackPoints() throws {
        let points = try #require(parseFixture("track-1.1").tracks.first?.segments.first?.points)

        try #require(points.count >= 2)
        #expect(points[0].latitude == 0.0010)
        #expect(points[0].longitude == 0.0020)
        #expect(points[0].elevation == 12.5)
        #expect(points[0].time == isoDate("2025-01-01T08:00:00Z"))
        #expect(points[1].time == isoDate("2025-01-01T08:00:05.5Z"))
    }

    @Test func leavesElevationAndTimeNilWhenAbsent() throws {
        let points = try #require(parseFixture("track-1.1").tracks.first?.segments.first?.points)

        try #require(points.count == 3)
        let point = points[2]
        #expect(point.elevation == nil)
        #expect(point.time == nil)
    }

    @Test func readsTimesWithAnOffset() throws {
        let segments = try #require(parseFixture("track-1.1").tracks.first?.segments)

        try #require(segments.count == 2)
        let point = try #require(segments[1].points.first)
        #expect(point.latitude == -0.0030)
        #expect(point.longitude == -0.0040)
        #expect(point.time == isoDate("2025-01-01T06:10:00Z"))
    }

    @Test func ignoresExtensionContent() throws {
        let points = try #require(parseFixture("track-1.1").tracks.first?.segments.first?.points)

        try #require(points.count == 3)
        #expect(points[0].elevation == 12.5)
    }

    @Test func ignoresGPXNamedElementsInsideAnExtensionsSubtree() throws {
        let xml = """
            <gpx version="1.1" creator="x" xmlns="http://www.topografix.com/GPX/1/1" xmlns:f="urn:other">
              <wpt lat="1" lon="2">
                <ele>12.5</ele>
                <extensions>
                  <f:wrapper><wpt><ele>99</ele><name>wrong</name></wpt></f:wrapper>
                  <wpt><ele>98</ele></wpt>
                </extensions>
              </wpt>
            </gpx>
            """
        let waypoint = try #require(GPXParser.parse(Data(xml.utf8)).waypoints.first)

        #expect(waypoint.point.elevation == 12.5)
        #expect(waypoint.name == nil)
    }

    @Test func keepsTextOfExtensionsAndForeignElementsOutOfFields() throws {
        let xml = """
            <gpx version="1.1" creator="x" xmlns="http://www.topografix.com/GPX/1/1" xmlns:f="urn:other">
              <wpt lat="1" lon="2"><name>North<f:label>wrong</f:label> Ridge</name>
              <desc>A<extensions>junk</extensions>B</desc></wpt>
            </gpx>
            """
        let waypoint = try #require(GPXParser.parse(Data(xml.utf8)).waypoints.first)

        #expect(waypoint.name == "North Ridge")
        #expect(waypoint.description == "AB")
    }

    @Test func skipsForeignNamespaceSubtreesCompletely() throws {
        let wrapped = """
            <gpx version="1.1" creator="x" xmlns:f="urn:other">
              <f:wrapper><rte><rtept lat="1" lon="2"/></rte></f:wrapper>
            </gpx>
            """
        #expect(throws: GPXParseError.noPoints) { try GPXParser.parse(Data(wrapped.utf8)) }

        let mixed = """
            <gpx version="1.1" creator="x" xmlns:f="urn:other">
              <f:wrapper><wpt lat="not a number" lon="2"><name>wrong</name></wpt></f:wrapper>
              <wpt lat="3" lon="4"/>
            </gpx>
            """
        let document = try GPXParser.parse(Data(mixed.utf8))
        #expect(document.waypoints.count == 1)
        #expect(document.waypoints.first?.point.latitude == 3)
    }

    @Test func preservesCDATAInTextFields() throws {
        let xml = """
            <gpx version="1.1" creator="x">
              <wpt lat="1" lon="2"><name><![CDATA[River & Lake]]></name><desc>Plain <![CDATA[<b>]]> mixed</desc></wpt>
            </gpx>
            """
        let waypoint = try #require(GPXParser.parse(Data(xml.utf8)).waypoints.first)

        #expect(waypoint.name == "River & Lake")
        #expect(waypoint.description == "Plain <b> mixed")
    }

    @Test func trimsXMLWhitespaceFromCoordinates() throws {
        let xml = """
            <gpx version="1.1" creator="x">
              <wpt lat="&#10;1&#10;" lon=" &#9;2&#13;&#10;"/>
            </gpx>
            """
        let point = try #require(GPXParser.parse(Data(xml.utf8)).waypoints.first?.point)

        #expect(point.latitude == 1)
        #expect(point.longitude == 2)
    }

    @Test func pointsFlattenEverySegmentInOrder() throws {
        let track = try parseFixture("track-1.1").tracks[0]

        #expect(track.points.map(\.latitude) == [0.0010, 0.0011, 0.0012, -0.0030])
    }

    // MARK: Routes

    @Test func readsRoutePoints() throws {
        let document = try parseFixture("route-1.0")

        try #require(document.routes.count == 1)
        let route = document.routes[0]
        #expect(route.name == "Test Route")
        try #require(route.points.count == 3)
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
        try #require(document.waypoints.count == 3)

        let water = document.waypoints[0]
        #expect(water.name == "Water")
        #expect(water.description == "Fountain & bench")
        #expect(water.point.latitude == 0.0200)
        #expect(water.point.longitude == 0.0300)
        #expect(water.point.elevation == 20.5)
        #expect(water.point.time == isoDate("2025-01-02T10:00:00Z"))
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
        let track = try #require(document.tracks.first)
        #expect(document.tracks.count == 1)
        #expect(track.name == "Old style track")
        #expect(track.points.first?.time == isoDate("2025-01-01T09:00:00Z"))
    }

    @Test func readsGPX11() throws {
        #expect(try parseFixture("track-1.1").version == "1.1")
    }

    @Test func readsFilesWithoutANamespace() throws {
        let document = try parseFixture("no-namespace")

        #expect(document.routes.first?.points.count == 2)
    }

    @Test func readsFilesWithAPrefixedNamespace() throws {
        let document = try parseFixture("prefixed-namespace")

        let track = try #require(document.tracks.first)
        #expect(track.name == "Prefixed")
        #expect(track.points.first?.elevation == 3)
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

    // MARK: Helpers

    private func parseFixture(_ name: String, extension fileExtension: String = "gpx") throws -> GPXDocument {
        let url = try #require(
            Bundle.module.url(forResource: name, withExtension: fileExtension, subdirectory: "Fixtures"))
        return try GPXParser.parse(contentsOf: url)
    }
}
