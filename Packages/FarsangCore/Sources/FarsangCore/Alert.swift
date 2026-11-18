public enum TurnDirection: String, Sendable, Hashable, CaseIterable {
    case left
    case right
}

public enum CompassDirection: String, Sendable, Hashable, CaseIterable {
    case north
    case northEast = "northeast"
    case east
    case southEast = "southeast"
    case south
    case southWest = "southwest"
    case west
    case northWest = "northwest"
}

/// Something the watch tells the runner about: each one gets a banner, a haptic and a spoken line.
public enum Alert: Sendable, Hashable {
    case turnAhead(direction: TurnDirection, distanceMeters: Double, streetName: String?)
    case offRoute(heading: CompassDirection?)
    case backOnRoute
    /// A completed kilometer or mile, depending on the unit system the engine uses.
    case distanceMarker(distanceMeters: Double, paceSecondsPerUnit: Double?)
    case segmentMarked(number: Int)
    case paused
    case resumed
    case ended

    public var kind: AlertKind {
        switch self {
        case .turnAhead: .turnAhead
        case .offRoute: .offRoute
        case .backOnRoute: .backOnRoute
        case .distanceMarker: .distanceMarker
        case .segmentMarked: .segmentMarked
        case .paused: .paused
        case .resumed: .resumed
        case .ended: .ended
        }
    }
}

/// The alert types a runner can switch voice on or off for.
public enum AlertKind: String, Sendable, Hashable, CaseIterable {
    case turnAhead
    case offRoute
    case backOnRoute
    case distanceMarker
    case segmentMarked
    case paused
    case resumed
    case ended
}
