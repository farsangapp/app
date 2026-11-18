import Foundation

/// Drops location fixes that would corrupt distance: inaccurate fixes and sudden jumps.
public struct LocationFilter: Sendable {
    public struct Configuration: Sendable, Hashable {
        /// Fixes with a larger horizontal accuracy radius (meters) are ignored.
        public var maxHorizontalAccuracy: Double
        /// Implied speed (meters per second) above which a move is treated as a GPS jump.
        public var maxSpeed: Double
        /// After this many jumps in a row the fix is trusted as a genuine relocation and becomes the new anchor.
        public var resyncAfterConsecutiveJumps: Int

        public init(maxHorizontalAccuracy: Double = 30, maxSpeed: Double = 12, resyncAfterConsecutiveJumps: Int = 5) {
            self.maxHorizontalAccuracy = maxHorizontalAccuracy
            self.maxSpeed = maxSpeed
            self.resyncAfterConsecutiveJumps = resyncAfterConsecutiveJumps
        }
    }

    public enum RejectionReason: Sendable, Hashable {
        case poorAccuracy
        case invalidCoordinate
        case outOfOrder
        case jump
    }

    public enum Outcome: Sendable, Hashable {
        /// First usable fix (or a resync): becomes the reference point and adds no distance.
        case anchored
        case accepted(Distance)
        case rejected(RejectionReason)
    }

    public let configuration: Configuration
    private var anchor: LocationSample?
    /// Timestamp of the newest fix that became the anchor or was accepted. Rejected jumps never move it, so a jump
    /// candidate with a far-future timestamp cannot make every later valid fix look out of order.
    private var latestTimestamp: Date?
    /// Timestamps of the jump candidates rejected since the last good fix, so copies of one count once.
    /// Cleared on every anchor change, so it never holds more than `resyncAfterConsecutiveJumps` entries.
    private var rejectedJumpTimestamps: Set<Date> = []

    public init(configuration: Configuration = Configuration()) {
        self.configuration = configuration
    }

    public mutating func process(_ sample: LocationSample) -> Outcome {
        guard sample.horizontalAccuracy >= 0, sample.horizontalAccuracy <= configuration.maxHorizontalAccuracy else {
            return .rejected(.poorAccuracy)
        }
        guard Self.isValid(sample.coordinate) else { return .rejected(.invalidCoordinate) }
        if let latestTimestamp, sample.timestamp <= latestTimestamp { return .rejected(.outOfOrder) }
        if rejectedJumpTimestamps.contains(sample.timestamp) { return .rejected(.outOfOrder) }
        guard let anchor else {
            adopt(sample)
            return .anchored
        }
        let elapsed = sample.timestamp.timeIntervalSince(anchor.timestamp)

        let moved = anchor.coordinate.distance(to: sample.coordinate)
        if moved.meters / elapsed > configuration.maxSpeed {
            rejectedJumpTimestamps.insert(sample.timestamp)
            guard rejectedJumpTimestamps.count >= configuration.resyncAfterConsecutiveJumps else {
                return .rejected(.jump)
            }
            adopt(sample)
            return .anchored
        }
        adopt(sample)
        return .accepted(moved)
    }

    /// Forgets the reference point, so the next good fix adds no distance. Used across pauses.
    public mutating func reset() {
        anchor = nil
        latestTimestamp = nil
        rejectedJumpTimestamps = []
    }

    private mutating func adopt(_ sample: LocationSample) {
        anchor = sample
        latestTimestamp = sample.timestamp
        rejectedJumpTimestamps = []
    }

    private static func isValid(_ coordinate: Coordinate) -> Bool {
        (-90...90).contains(coordinate.latitude) && (-180...180).contains(coordinate.longitude)
    }
}
