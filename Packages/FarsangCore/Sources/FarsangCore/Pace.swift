import Foundation

public struct Pace: Sendable, Hashable, Comparable {
    private static let metersPerMile = 1_609.344

    public let secondsPerKilometer: Double

    public init(secondsPerKilometer: Double) {
        self.secondsPerKilometer = secondsPerKilometer
    }

    /// Returns nil without distance or time, so callers show a placeholder instead of 0 or infinity.
    public init?(duration: TimeInterval, distance: Distance) {
        guard distance.meters > 0, duration > 0 else { return nil }
        let seconds = duration / distance.kilometers
        guard seconds.isFinite, seconds > 0 else { return nil }
        self.init(secondsPerKilometer: seconds)
    }

    public var secondsPerMile: Double { secondsPerKilometer * Self.metersPerMile / 1_000 }

    public static func < (lhs: Pace, rhs: Pace) -> Bool {
        lhs.secondsPerKilometer < rhs.secondsPerKilometer
    }
}
