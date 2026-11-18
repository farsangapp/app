public enum HeartRateZone: Int, Sendable, Hashable, CaseIterable, Comparable {
    case one = 1
    case two
    case three
    case four
    case five

    /// Lower bound of the zone as a whole percentage of the maximum heart rate.
    fileprivate var lowerBoundPercent: Double {
        switch self {
        case .one: 50
        case .two: 60
        case .three: 70
        case .four: 80
        case .five: 90
        }
    }

    public static func < (lhs: HeartRateZone, rhs: HeartRateZone) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

/// Five zones at 50-60, 60-70, 70-80, 80-90 and 90-100 percent of the maximum heart rate.
public struct HeartRateZones: Sendable, Hashable {
    public let maxHeartRate: Double

    public init(maxHeartRate: Double) {
        self.maxHeartRate = maxHeartRate
    }

    /// Builds zones from the common `220 - age` estimate of maximum heart rate.
    public init(age: Int) {
        self.init(maxHeartRate: Self.estimatedMaxHeartRate(forAge: age))
    }

    public static func estimatedMaxHeartRate(forAge age: Int) -> Double {
        220 - Double(age)
    }

    public func lowerBound(of zone: HeartRateZone) -> Double {
        maxHeartRate * zone.lowerBoundPercent / 100
    }

    /// Returns nil below zone 1; anything above the maximum counts as zone 5.
    public func zone(for beatsPerMinute: Double) -> HeartRateZone? {
        guard maxHeartRate.isFinite, maxHeartRate > 0 else { return nil }
        return HeartRateZone.allCases.last { beatsPerMinute >= lowerBound(of: $0) }
    }
}
