import Foundation

public struct Coordinate: Sendable, Hashable {
    private static let earthRadiusMeters = 6_371_000.0

    public let latitude: Double
    public let longitude: Double

    public init(latitude: Double, longitude: Double) {
        self.latitude = latitude
        self.longitude = longitude
    }

    /// Great-circle distance using the haversine formula.
    public func distance(to other: Coordinate) -> Distance {
        let lat1 = latitude * .pi / 180
        let lat2 = other.latitude * .pi / 180
        let deltaLat = lat2 - lat1
        let deltaLon = (other.longitude - longitude) * .pi / 180
        let halfChordSquared =
            sin(deltaLat / 2) * sin(deltaLat / 2)
            + cos(lat1) * cos(lat2) * sin(deltaLon / 2) * sin(deltaLon / 2)
        // Rounding can push the term just outside [0, 1] for near-antipodal points, which would make a root NaN.
        let clamped = min(max(halfChordSquared, 0), 1)
        let angle = 2 * atan2(clamped.squareRoot(), (1 - clamped).squareRoot())
        return Distance(meters: Self.earthRadiusMeters * angle)
    }
}

public struct LocationSample: Sendable, Hashable {
    public let timestamp: Date
    public let coordinate: Coordinate
    /// Radius of uncertainty in meters. A negative value means the fix is invalid, as in Core Location.
    public let horizontalAccuracy: Double

    public init(timestamp: Date, coordinate: Coordinate, horizontalAccuracy: Double) {
        self.timestamp = timestamp
        self.coordinate = coordinate
        self.horizontalAccuracy = horizontalAccuracy
    }
}

public struct HeartRateSample: Sendable, Hashable {
    public let timestamp: Date
    public let beatsPerMinute: Double

    public init(timestamp: Date, beatsPerMinute: Double) {
        self.timestamp = timestamp
        self.beatsPerMinute = beatsPerMinute
    }
}
