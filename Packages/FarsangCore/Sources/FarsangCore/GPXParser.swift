import Foundation

/// Reads GPX 1.0 and 1.1 files into a ``GPXDocument``.
///
/// The parser streams through the XML with `XMLParser`, so memory use grows with the parsed points rather
/// than with the XML text. Prefer ``parse(contentsOf:)`` for files, which reads from disk in chunks.
///
/// - Elements in the GPX 1.0 or 1.1 namespace, or in no namespace, are read; any namespace prefix works.
///   Everything inside `extensions` and elements from other namespaces is ignored.
/// - A `time` needs a zone (`Z` or an offset). One without a zone, like any unreadable `time`, is read as absent.
/// - A point needs a numeric `lat` and `lon` within range, or parsing fails. An unreadable `ele` or `time`
///   is treated as absent instead, because a route is still usable without it.
/// - A file with no points at all (tracks, routes and waypoints together) fails with ``GPXParseError/noPoints``.
public enum GPXParser {
    public static func parse(_ data: Data) throws(GPXParseError) -> GPXDocument {
        try run(XMLParser(data: data), stream: nil)
    }

    public static func parse(contentsOf url: URL) throws(GPXParseError) -> GPXDocument {
        guard let stream = InputStream(url: url) else { throw .unreadable }
        return try run(XMLParser(stream: stream), stream: stream)
    }

    private static func run(_ parser: XMLParser, stream: InputStream?) throws(GPXParseError) -> GPXDocument {
        let reader = GPXReader()
        parser.shouldProcessNamespaces = true
        parser.shouldResolveExternalEntities = false
        parser.delegate = reader
        let finished = parser.parse()

        if stream?.streamError != nil { throw .unreadable }
        if let failure = reader.failure { throw failure }
        guard finished else {
            throw .invalidXML(line: parser.lineNumber)
        }
        guard reader.sawRoot else { throw .notGPX }
        guard reader.pointCount > 0 else { throw .noPoints }
        return reader.document
    }
}

/// The `XMLParserDelegate` behind ``GPXParser``. One instance reads one document.
private final class GPXReader: NSObject, XMLParserDelegate {
    private static let namespaces: Set<String> = [
        "http://www.topografix.com/GPX/1/0",
        "http://www.topografix.com/GPX/1/1"
    ]

    /// The kind of GPX element a point belongs to.
    private enum PointKind {
        case trackPoint, routePoint, waypoint
    }

    private(set) var document = GPXDocument()
    private(set) var pointCount = 0
    private(set) var sawRoot = false
    private(set) var failure: GPXParseError?

    /// Open elements, innermost last. Foreign-namespace elements are recorded as `nil`.
    private var path: [String?] = []
    /// How many open elements are inside an ignored subtree (`extensions` or a foreign-namespace element),
    /// counting the subtree's root. While it is above zero nothing is dispatched and no text is collected.
    private var ignoredDepth = 0
    private var text = ""
    private var collectingText = false

    private var track: GPXTrack?
    private var segment: GPXTrackSegment?
    private var route: GPXRoute?
    private var waypoint: GPXWaypoint?
    private var point: GPXPoint?
    private var pointKind: PointKind?

    private let timeParser = GPXTimeParser()

    // MARK: XMLParserDelegate

    func parser(
        _ parser: XMLParser,
        didStartElement elementName: String,
        namespaceURI: String?,
        qualifiedName qName: String?,
        attributes attributeDict: [String: String]
    ) {
        let isGPX = namespaceURI.map { $0.isEmpty || Self.namespaces.contains($0) } ?? true
        let name = isGPX ? elementName : nil
        defer { path.append(name) }

        if path.isEmpty {
            guard name == "gpx" else {
                fail(.notGPX, parser)
                return
            }
            sawRoot = true
            document.version = attributeDict["version"]
            return
        }
        guard ignoredDepth == 0, let name, name != "extensions" else {
            ignoredDepth += 1
            return
        }
        startGPXElement(name, parent: path.last ?? nil, attributes: attributeDict, parser: parser)
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        if collectingText, ignoredDepth == 0 { text += string }
    }

    func parser(_ parser: XMLParser, foundCDATA block: Data) {
        if collectingText, ignoredDepth == 0, let string = String(bytes: block, encoding: .utf8) { text += string }
    }

    func parser(
        _ parser: XMLParser,
        didEndElement elementName: String,
        namespaceURI: String?,
        qualifiedName qName: String?
    ) {
        let name = path.removeLast()
        if ignoredDepth > 0 {
            ignoredDepth -= 1
            return
        }
        guard let name else { return }
        endGPXElement(name, parent: path.last ?? nil)
    }

    func parser(_ parser: XMLParser, parseErrorOccurred parseError: any Error) {
        if failure == nil { failure = .invalidXML(line: parser.lineNumber) }
    }

    // MARK: Elements

    private func startGPXElement(_ name: String, parent: String?, attributes: [String: String], parser: XMLParser) {
        switch (name, parent) {
        case ("trk", "gpx"):
            track = GPXTrack()
        case ("trkseg", "trk"):
            segment = GPXTrackSegment()
        case ("rte", "gpx"):
            route = GPXRoute()
        case ("wpt", "gpx"):
            startPoint(.waypoint, attributes: attributes, parser: parser)
            waypoint = GPXWaypoint(point: GPXPoint(latitude: 0, longitude: 0))
        case ("trkpt", "trkseg"):
            startPoint(.trackPoint, attributes: attributes, parser: parser)
        case ("rtept", "rte"):
            startPoint(.routePoint, attributes: attributes, parser: parser)
        case _ where Self.readsText(name, parent: parent):
            beginText()
        default:
            break
        }
    }

    private func endGPXElement(_ name: String, parent: String?) {
        switch (name, parent) {
        case ("trk", "gpx"):
            if let finished = track { document.tracks.append(finished) }
            track = nil
        case ("trkseg", "trk"):
            if let finished = segment { track?.segments.append(finished) }
            segment = nil
        case ("rte", "gpx"):
            if let finished = route { document.routes.append(finished) }
            route = nil
        case ("trkpt", "trkseg"), ("rtept", "rte"), ("wpt", "gpx"):
            finishPoint()
        case _ where Self.readsText(name, parent: parent):
            finishText(name, parent: parent)
        default:
            break
        }
    }

    private func startPoint(_ kind: PointKind, attributes: [String: String], parser: XMLParser) {
        let line = parser.lineNumber
        guard
            let latitude = attributes["lat"].flatMap(Self.parseNumber),
            let longitude = attributes["lon"].flatMap(Self.parseNumber)
        else {
            fail(.invalidCoordinate(line: line), parser)
            return
        }
        guard (-90...90).contains(latitude), (-180...180).contains(longitude) else {
            fail(.coordinateOutOfRange(latitude: latitude, longitude: longitude, line: line), parser)
            return
        }
        point = GPXPoint(latitude: latitude, longitude: longitude)
        pointKind = kind
    }

    private func finishPoint() {
        guard let finished = point, let kind = pointKind else { return }
        pointCount += 1
        switch kind {
        case .trackPoint:
            segment?.points.append(finished)
        case .routePoint:
            route?.points.append(finished)
        case .waypoint:
            if var finishedWaypoint = waypoint {
                finishedWaypoint.point = finished
                document.waypoints.append(finishedWaypoint)
            }
            waypoint = nil
        }
        point = nil
        pointKind = nil
    }

    // MARK: Text

    private func beginText() {
        text = ""
        collectingText = true
    }

    private func finishText(_ name: String, parent: String?) {
        guard collectingText else { return }
        collectingText = false
        let value = text.trimmingCharacters(in: .whitespacesAndNewlines)
        text = ""

        switch (name, parent) {
        case ("ele", "trkpt"), ("ele", "rtept"), ("ele", "wpt"):
            point?.elevation = Self.parseNumber(value)
        case ("time", "trkpt"), ("time", "rtept"), ("time", "wpt"):
            point?.time = timeParser.parse(value)
        case ("name", "wpt"):
            waypoint?.name = value.nonEmpty
        case ("desc", "wpt"):
            waypoint?.description = value.nonEmpty
        case ("name", "trk"):
            track?.name = value.nonEmpty
        case ("name", "rte"):
            route?.name = value.nonEmpty
        case ("name", "metadata"), ("name", "gpx"):
            document.name = value.nonEmpty
        default:
            break
        }
    }

    // MARK: Helpers

    /// The text-only elements the parser keeps, by name and parent.
    private static func readsText(_ name: String, parent: String?) -> Bool {
        switch (name, parent) {
        case ("name", "gpx"), ("name", "metadata"), ("name", "trk"), ("name", "rte"), ("name", "wpt"), ("desc", "wpt"),
            ("ele", "trkpt"), ("ele", "rtept"), ("ele", "wpt"), ("time", "trkpt"), ("time", "rtept"), ("time", "wpt"):
            true
        default:
            false
        }
    }

    private func fail(_ error: GPXParseError, _ parser: XMLParser) {
        if failure == nil { failure = error }
        parser.abortParsing()
    }

    /// The whitespace XML allows around a decimal value: space, tab, carriage return and line feed.
    private static let xmlWhitespace = CharacterSet(charactersIn: " \t\r\n")

    /// A finite decimal number, or `nil`.
    private static func parseNumber(_ string: String) -> Double? {
        guard let value = Double(string.trimmingCharacters(in: xmlWhitespace)), value.isFinite else { return nil }
        return value
    }
}

extension String {
    fileprivate var nonEmpty: String? { isEmpty ? nil : self }
}

/// Parses the ISO 8601 timestamps GPX uses, with or without fractional seconds and with a `Z` or numeric offset.
///
/// `ISO8601DateFormatter` costs tens of microseconds per call, which adds up over a 50,000-point file.
/// Timestamps in the common UTC form (`2025-01-01T08:00:00Z`, optionally with fractional seconds) are decoded by
/// hand; timestamps with a numeric offset go through the formatter.
private struct GPXTimeParser {
    private let plain = ISO8601DateFormatter()
    private let fractional = ISO8601DateFormatter()

    init() {
        plain.formatOptions = [.withInternetDateTime]
        fractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    }

    func parse(_ string: String) -> Date? {
        if string.hasSuffix("Z") { return parseUTC(string) }
        // The formatter normalizes impossible dates such as February 29 in a common year, so check the date first.
        guard hasValidCalendarDate(string) else { return nil }
        return plain.date(from: string) ?? fractional.date(from: string)
    }

    private static let digits = UInt8(ascii: "0")...UInt8(ascii: "9")

    /// Whether the `YYYY-MM-DD` start of `string` names a real day. Strings too short or oddly shaped pass
    /// through to the formatter, which rejects them.
    private func hasValidCalendarDate(_ string: String) -> Bool {
        let bytes = Array(string.utf8.prefix(10))
        guard bytes.count == 10, bytes[4] == UInt8(ascii: "-"), bytes[7] == UInt8(ascii: "-") else { return true }
        let digitBytes = bytes[0..<4] + bytes[5..<7] + bytes[8..<10]
        guard digitBytes.allSatisfy(Self.digits.contains) else { return true }
        let value = { (range: Range<Int>) in bytes[range].reduce(0) { $0 * 10 + Int($1 - UInt8(ascii: "0")) } }
        return Self.isValidDay(year: value(0..<4), month: value(5..<7), day: value(8..<10))
    }

    private static func isValidDay(year: Int, month: Int, day: Int) -> Bool {
        guard year >= 1, (1...12).contains(month) else { return false }
        let isLeapYear = year % 4 == 0 && (year % 100 != 0 || year % 400 == 0)
        let daysInMonth = [31, isLeapYear ? 29 : 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31][month - 1]
        return (1...daysInMonth).contains(day)
    }

    /// Decodes `YYYY-MM-DDTHH:MM:SS[.fraction]Z`, or returns `nil` for any other shape or an invalid date.
    private func parseUTC(_ string: String) -> Date? {
        var bytes = Array(string.utf8)
        guard bytes.count >= 20, bytes.removeLast() == UInt8(ascii: "Z") else { return nil }

        /// The decimal value of the digits in `range`, or `nil` if any is not an ASCII digit.
        /// With `accumulate` false only the digits are checked, and the result is 0.
        func number(_ range: Range<Int>, accumulate: Bool = true) -> Int? {
            var value = 0
            for byte in bytes[range] {
                guard Self.digits.contains(byte) else { return nil }
                if accumulate { value = value * 10 + Int(byte - UInt8(ascii: "0")) }
            }
            return value
        }

        guard
            bytes[4] == UInt8(ascii: "-"), bytes[7] == UInt8(ascii: "-"), bytes[10] == UInt8(ascii: "T"),
            bytes[13] == UInt8(ascii: ":"), bytes[16] == UInt8(ascii: ":"),
            let year = number(0..<4), let month = number(5..<7), let day = number(8..<10),
            let hour = number(11..<13), let minute = number(14..<16), let second = number(17..<19),
            hour <= 24, minute < 60, second < 61, Self.isValidDay(year: year, month: month, day: day)
        else { return nil }

        var fraction = 0.0
        var fractionIsZero = true
        if bytes.count > 19 {
            guard bytes[19] == UInt8(ascii: "."), bytes.count > 20 else { return nil }
            // Every digit must be valid, but nanosecond precision is plenty: extra digits are not used,
            // so the value cannot overflow.
            guard number(20..<bytes.count, accumulate: false) != nil else { return nil }
            let end = min(bytes.count, 29)
            fraction = Double(number(20..<end) ?? 0) / pow(10, Double(end - 20))
            fractionIsZero = bytes[20...].allSatisfy { $0 == UInt8(ascii: "0") }
        }

        // `24:00:00` is the xsd:dateTime end-of-day form of midnight on the next day; nothing later is valid.
        let isEndOfDay = hour == 24
        if isEndOfDay, minute != 0 || second != 0 || !fractionIsZero { return nil }

        // Days since 1970-01-01 in the proleptic Gregorian calendar (Howard Hinnant's algorithm).
        let shiftedYear = month <= 2 ? year - 1 : year
        let era = shiftedYear / 400
        let yearOfEra = shiftedYear - era * 400
        let monthIndex = (month + 9) % 12
        let dayOfYear = (153 * monthIndex + 2) / 5 + day - 1
        let dayOfEra = yearOfEra * 365 + yearOfEra / 4 - yearOfEra / 100 + dayOfYear
        // Widen before scaling: `Int` is 32 bits on arm64_32, where days * 86,400 overflows after 2038.
        let days = Int64(era * 146_097 + dayOfEra - 719_468) + (isEndOfDay ? 1 : 0)
        let wholeSeconds = days * 86_400 + Int64((isEndOfDay ? 0 : hour) * 3_600 + minute * 60 + second)
        return Date(timeIntervalSince1970: Double(wholeSeconds) + fraction)
    }
}
