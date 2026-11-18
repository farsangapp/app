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
    private var consecutiveJumps = 0

    public init(configuration: Configuration = Configuration()) {
        self.configuration = configuration
    }

    public mutating func process(_ sample: LocationSample) -> Outcome {
        guard sample.horizontalAccuracy >= 0, sample.horizontalAccuracy <= configuration.maxHorizontalAccuracy else {
            return .rejected(.poorAccuracy)
        }
        guard let anchor else {
            self.anchor = sample
            return .anchored
        }
        let elapsed = sample.timestamp.timeIntervalSince(anchor.timestamp)
        guard elapsed > 0 else { return .rejected(.outOfOrder) }

        let moved = anchor.coordinate.distance(to: sample.coordinate)
        if moved.meters / elapsed > configuration.maxSpeed {
            consecutiveJumps += 1
            guard consecutiveJumps >= configuration.resyncAfterConsecutiveJumps else { return .rejected(.jump) }
            self.anchor = sample
            consecutiveJumps = 0
            return .anchored
        }
        consecutiveJumps = 0
        self.anchor = sample
        return .accepted(moved)
    }

    /// Forgets the reference point, so the next good fix adds no distance. Used across pauses.
    public mutating func reset() {
        anchor = nil
        consecutiveJumps = 0
    }
}
