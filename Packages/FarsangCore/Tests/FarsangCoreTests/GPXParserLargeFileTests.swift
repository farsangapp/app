import Foundation
import Testing

@testable import FarsangCore

struct GPXParserLargeFileTests {
    @Test func parsesMoreThanFiftyThousandPointsFromData() throws {
        let count = 60_000
        let document = try GPXParser.parse(Data(Self.largeGPX(pointCount: count).utf8))

        let points = try #require(document.tracks.first?.points)
        try #require(points.count == count)
        #expect(points[count - 1].elevation == Double((count - 1) % 100))
    }

    @Test func parsesMoreThanFiftyThousandPointsFromAFile() throws {
        let count = 60_000
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("farsang-\(UUID().uuidString).gpx")
        try Data(Self.largeGPX(pointCount: count).utf8).write(to: url)
        defer { try? FileManager.default.removeItem(at: url) }

        let document = try GPXParser.parse(contentsOf: url)

        #expect(document.tracks.first?.points.count == count)
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
