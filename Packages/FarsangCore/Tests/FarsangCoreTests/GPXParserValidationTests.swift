import Foundation
import Testing

@testable import FarsangCore

struct GPXParserValidationTests {
    // MARK: Decimal syntax

    @Test(arguments: [
        "0x10", "0X1p3", "inf", "-inf", "infinity", "nan", "NaN", "1_0", "1,5", "1e", "e5", ".", "+", "--1", "1 2", "",
        "1e1", "5E-1", "1e+2"
    ])
    func rejectsCoordinatesThatAreNotPlainDecimals(_ value: String) {
        let xml = #"<gpx version="1.1" creator="x"><wpt lat="\#(value)" lon="2"/></gpx>"#
        #expect(throws: GPXParseError.invalidCoordinate(line: 1)) { try GPXParser.parse(Data(xml.utf8)) }
    }

    @Test(arguments: [
        ("1", 1.0), ("+1.5", 1.5), ("-0.25", -0.25), (".5", 0.5), ("2.", 2.0)
    ])
    func readsPlainDecimalCoordinates(_ value: String, _ expected: Double) throws {
        let xml = #"<gpx version="1.1" creator="x"><wpt lat="\#(value)" lon="2"/></gpx>"#
        let point = try #require(GPXParser.parse(Data(xml.utf8)).waypoints.first?.point)

        #expect(point.latitude == expected)
    }

    @Test(arguments: ["0x10", "inf", "nan", "1_0", "1e999", "1e2", "-12.5e0"])
    func ignoresElevationsThatAreNotPlainDecimals(_ value: String) throws {
        let xml = #"<gpx version="1.1" creator="x"><wpt lat="1" lon="2"><ele>\#(value)</ele></wpt></gpx>"#
        let point = try #require(GPXParser.parse(Data(xml.utf8)).waypoints.first?.point)

        #expect(point.elevation == nil)
    }

    @Test func readsAnElevationWithSurroundingWhitespace() throws {
        let xml = #"<gpx version="1.1" creator="x"><wpt lat="1" lon="2"><ele> -12.5 </ele></wpt></gpx>"#
        let point = try #require(GPXParser.parse(Data(xml.utf8)).waypoints.first?.point)

        #expect(point.elevation == -12.5)
    }

    // MARK: Ownership

    @Test func ignoresRoutePointsWhoseRouteIsNotADirectChildOfTheRoot() {
        let xml = #"<gpx version="1.1" creator="x"><wrapper><rte><rtept lat="1" lon="2"/></rte></wrapper></gpx>"#
        #expect(throws: GPXParseError.noPoints) { try GPXParser.parse(Data(xml.utf8)) }
    }

    @Test func ignoresTrackPointsWhoseTrackIsNotADirectChildOfTheRoot() {
        let xml = """
            <gpx version="1.1" creator="x">
              <wrapper><trk><trkseg><trkpt lat="1" lon="2"/></trkseg></trk></wrapper>
            </gpx>
            """
        #expect(throws: GPXParseError.noPoints) { try GPXParser.parse(Data(xml.utf8)) }
    }

    @Test func doesNotTakeFieldsFromAnOrphanPointInsideAWaypoint() throws {
        let xml = """
            <gpx version="1.1" creator="x">
              <wpt lat="1" lon="2">
                <ele>12.5</ele>
                <rte><rtept><ele>99</ele><time>2025-01-01T08:00:00Z</time></rtept></rte>
                <name>Water</name>
              </wpt>
            </gpx>
            """
        let waypoint = try #require(GPXParser.parse(Data(xml.utf8)).waypoints.first)

        #expect(waypoint.point.elevation == 12.5)
        #expect(waypoint.point.time == nil)
        #expect(waypoint.name == "Water")
    }

    @Test func doesNotFinishTheWaypointWhenAnOrphanPointCloses() throws {
        let xml = """
            <gpx version="1.1" creator="x">
              <wpt lat="1" lon="2">
                <rte><rtept lat="3" lon="4"/></rte>
                <name>Water</name>
              </wpt>
            </gpx>
            """
        let document = try GPXParser.parse(Data(xml.utf8))

        #expect(document.waypoints.count == 1)
        #expect(document.waypoints.first?.name == "Water")
        #expect(document.waypoints.first?.point.latitude == 1)
    }

    @Test func keepsTheOuterSegmentWhenAWrapperHidesAnotherTrack() throws {
        let xml = """
            <gpx version="1.1" creator="x">
              <trk><trkseg>
                <trkpt lat="1" lon="1"/>
                <wrapper><trk><trkseg><trkpt lat="9" lon="9"/></trkseg></trk></wrapper>
                <trkpt lat="2" lon="2"/>
              </trkseg></trk>
            </gpx>
            """
        let document = try GPXParser.parse(Data(xml.utf8))

        #expect(document.tracks.count == 1)
        #expect(document.tracks.first?.segments.count == 1)
        #expect(document.tracks.first?.points.map(\.latitude) == [1, 2])
    }

    @Test func doesNotValidateOrCountOrphanPoints() throws {
        let xml = """
            <gpx version="1.1" creator="x">
              <wrapper><rte><rtept lat="not a number" lon="2"/></rte></wrapper>
              <trk><trkseg><trkpt lat="3" lon="4"/></trkseg></trk>
            </gpx>
            """
        let document = try GPXParser.parse(Data(xml.utf8))

        #expect(document.routes.isEmpty)
        #expect(document.tracks.first?.points.count == 1)
    }
}
