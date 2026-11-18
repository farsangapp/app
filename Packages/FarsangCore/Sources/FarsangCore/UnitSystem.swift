public enum UnitSystem: String, Sendable, Hashable, CaseIterable {
    case metric
    case imperial

    public var metersPerUnit: Double {
        switch self {
        case .metric: 1_000
        case .imperial: 1_609.344
        }
    }

    public var unitSymbol: String {
        switch self {
        case .metric: "km"
        case .imperial: "mi"
        }
    }

    public var unitName: String {
        switch self {
        case .metric: "kilometer"
        case .imperial: "mile"
        }
    }

    public func value(fromMeters meters: Double) -> Double {
        meters / metersPerUnit
    }
}
