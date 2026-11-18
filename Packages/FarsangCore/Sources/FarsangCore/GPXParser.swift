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

    /// Open elements, innermost last. An element is recorded by name only if the parser accepted it at its position
    /// (a `trkseg` directly inside a `trk` it accepted, and so on). Foreign-namespace elements and elements found
    /// anywhere else are recorded as `nil`, so nothing inside them is ever read as GPX content.
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
        var accepted = false
        defer { path.append(accepted ? name : nil) }

        if path.isEmpty {
            guard name == "gpx" else {
                fail(.notGPX, parser)
                return
            }
            sawRoot = true
            accepted = true
            document.version = attributeDict["version"]
            return
        }
        guard ignoredDepth == 0, let name, name != "extensions" else {
            ignoredDepth += 1
            return
        }
        accepted = startGPXElement(name, parent: path.last ?? nil, attributes: attributeDict, parser: parser)
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

    /// Starts the element if GPX allows it inside `parent`, and returns whether it did. `parent` is the name of
    /// the enclosing element only if that element was itself accepted, so a point, segment or field can only
    /// ever attach to the element that really contains it.
    private func startGPXElement(
        _ name: String, parent: String?, attributes: [String: String], parser: XMLParser
    ) -> Bool {
        if let kind = Self.pointKind(name, parent: parent) {
            return startPoint(kind, attributes: attributes, parser: parser)
        }
        switch (name, parent) {
        case ("trk", "gpx"):
            track = GPXTrack()
        case ("trkseg", "trk"):
            segment = GPXTrackSegment()
        case ("rte", "gpx"):
            route = GPXRoute()
        case ("metadata", "gpx"):
            break
        case _ where Self.readsText(name, parent: parent):
            beginText()
        default:
            return false
        }
        return true
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

    /// Begins a point from its `lat` and `lon`, or fails the parse and returns `false`.
    private func startPoint(_ kind: PointKind, attributes: [String: String], parser: XMLParser) -> Bool {
        let line = parser.lineNumber
        guard
            let latitude = attributes["lat"].flatMap(Self.parseNumber),
            let longitude = attributes["lon"].flatMap(Self.parseNumber)
        else {
            fail(.invalidCoordinate(line: line), parser)
            return false
        }
        guard (-90...90).contains(latitude), (-180...180).contains(longitude) else {
            fail(.coordinateOutOfRange(latitude: latitude, longitude: longitude, line: line), parser)
            return false
        }
        point = GPXPoint(latitude: latitude, longitude: longitude)
        pointKind = kind
        if kind == .waypoint { waypoint = GPXWaypoint(point: GPXPoint(latitude: 0, longitude: 0)) }
        return true
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

    private static func pointKind(_ name: String, parent: String?) -> PointKind? {
        switch (name, parent) {
        case ("wpt", "gpx"): .waypoint
        case ("trkpt", "trkseg"): .trackPoint
        case ("rtept", "rte"): .routePoint
        default: nil
        }
    }

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
    ///
    /// Only `xsd:decimal` syntax is accepted: an optional sign, then digits with an optional fraction. `Double(_:)`
    /// alone would also read exponents (`1e2`), hexadecimal forms, `inf` and `nan`, which GPX does not allow.
    private static func parseNumber(_ string: String) -> Double? {
        let trimmed = string.trimmingCharacters(in: xmlWhitespace)
        guard isPlainDecimal(trimmed), let value = Double(trimmed), value.isFinite else { return nil }
        return value
    }

    /// Whether `string` matches `[+-]? (digits [. digits?] | . digits)`.
    private static func isPlainDecimal(_ string: String) -> Bool {
        var rest = string.utf8[...]
        let isDigit = { (byte: UInt8) in (UInt8(ascii: "0")...UInt8(ascii: "9")).contains(byte) }
        let skipDigits = { () -> Int in
            let digits = rest.prefix(while: isDigit)
            rest = rest.dropFirst(digits.count)
            return digits.count
        }
        let skipOne = { (accepts: (UInt8) -> Bool) -> Bool in
            guard let byte = rest.first, accepts(byte) else { return false }
            rest = rest.dropFirst()
            return true
        }
        let isSign = { (byte: UInt8) in byte == UInt8(ascii: "+") || byte == UInt8(ascii: "-") }

        _ = skipOne(isSign)
        let integerDigits = skipDigits()
        var fractionDigits = 0
        if skipOne({ $0 == UInt8(ascii: ".") }) { fractionDigits = skipDigits() }
        return integerDigits + fractionDigits > 0 && rest.isEmpty
    }
}

extension String {
    fileprivate var nonEmpty: String? { isEmpty ? nil : self }
}
