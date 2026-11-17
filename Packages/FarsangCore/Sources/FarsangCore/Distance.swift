public struct Distance: Sendable, Hashable {
    public static let zero = Distance(meters: 0)

    private static let metersPerMile = 1_609.344

    public let meters: Double

    public init(meters: Double) {
        self.meters = meters
    }

    public var kilometers: Double { meters / 1_000 }
    public var miles: Double { meters / Self.metersPerMile }
}
