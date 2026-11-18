import Foundation

/// A parsed GPX file: the tracks, routes and waypoints it contains, in file order.
///
/// This is a plain description of what the file says. It does not simplify, merge or measure anything;
/// the route model converts it into something the app can follow.
public struct GPXDocument: Sendable, Hashable {
    /// The `version` attribute of the `gpx` element (`"1.0"` or `"1.1"`), when present.
    public var version: String?
    /// The file's own name: `metadata/name` in GPX 1.1, or the top-level `name` in GPX 1.0.
    public var name: String?
    public var tracks: [GPXTrack]
    public var routes: [GPXRoute]
    public var waypoints: [GPXWaypoint]

    public init(
        version: String? = nil,
        name: String? = nil,
        tracks: [GPXTrack] = [],
        routes: [GPXRoute] = [],
        waypoints: [GPXWaypoint] = []
    ) {
        self.version = version
        self.name = name
        self.tracks = tracks
        self.routes = routes
        self.waypoints = waypoints
    }
}

/// One position from a GPX file. ``GPXParser`` only produces points with a latitude and longitude in range, and
/// sets elevation and time only when the file gives a readable value. The initializer and the properties do not
/// check anything, so code that creates or changes a point must keep the coordinates within bounds itself.
public struct GPXPoint: Sendable, Hashable {
    /// Degrees, in -90...90.
    public var latitude: Double
    /// Degrees, in -180...180.
    public var longitude: Double
    /// Meters above sea level, when the file gives one.
    public var elevation: Double?
    /// When the point was recorded, when the file gives a time.
    public var time: Date?

    public init(latitude: Double, longitude: Double, elevation: Double? = nil, time: Date? = nil) {
        self.latitude = latitude
        self.longitude = longitude
        self.elevation = elevation
        self.time = time
    }
}

/// A `trk` element: a recorded path made of one or more segments.
public struct GPXTrack: Sendable, Hashable {
    public var name: String?
    /// Segments in file order. A new segment starts where the recording had a gap.
    public var segments: [GPXTrackSegment]

    public init(name: String? = nil, segments: [GPXTrackSegment] = []) {
        self.name = name
        self.segments = segments
    }

    /// Every point of every segment, in file order.
    public var points: [GPXPoint] { segments.flatMap(\.points) }
}

/// A `trkseg` element: an unbroken run of track points.
public struct GPXTrackSegment: Sendable, Hashable {
    public var points: [GPXPoint]

    public init(points: [GPXPoint] = []) {
        self.points = points
    }
}

/// An `rte` element: a planned path, in order.
public struct GPXRoute: Sendable, Hashable {
    public var name: String?
    public var points: [GPXPoint]

    public init(name: String? = nil, points: [GPXPoint] = []) {
        self.name = name
        self.points = points
    }
}

/// A `wpt` element: a named place that is not part of a path.
public struct GPXWaypoint: Sendable, Hashable {
    public var name: String?
    /// The `desc` element.
    public var description: String?
    public var point: GPXPoint

    public init(name: String? = nil, description: String? = nil, point: GPXPoint) {
        self.name = name
        self.description = description
        self.point = point
    }
}

/// Why a GPX file could not be parsed.
public enum GPXParseError: Error, Sendable, Equatable {
    /// The file or stream could not be read.
    case unreadable
    /// The data is not well-formed XML. `line` is where the parser gave up.
    case invalidXML(line: Int)
    /// The XML is fine, but its root element is not `gpx`.
    case notGPX
    /// A point has a missing, non-numeric or non-finite `lat` or `lon`.
    case invalidCoordinate(line: Int)
    /// A point has a latitude outside -90...90 or a longitude outside -180...180.
    case coordinateOutOfRange(latitude: Double, longitude: Double, line: Int)
    /// The file has no track, route or waypoint points at all.
    case noPoints
}
