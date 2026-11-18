public enum SpokenFormatter {
    private static let underTwenty = [
        "zero", "one", "two", "three", "four", "five", "six", "seven", "eight", "nine",
        "ten", "eleven", "twelve", "thirteen", "fourteen", "fifteen", "sixteen", "seventeen",
        "eighteen", "nineteen"
    ]

    private static let tens = ["", "", "twenty", "thirty", "forty", "fifty"]

    public static func pace(fromSecondsPerUnit seconds: Double, unitSystem: UnitSystem) -> String {
        guard let totalSeconds = PaceSeconds.rounded(seconds) else { return "" }
        let minutes = totalSeconds / 60
        let secs = totalSeconds % 60
        return "\(numberWord(minutes)) \(numberWord(secs)) per \(unitSystem.unitName)"
    }

    public static func distanceMarker(fromMeters meters: Double, unitSystem: UnitSystem) -> String {
        guard meters.isFinite, meters >= 0 else { return "\(unitSystem.unitName) 0" }
        guard let count = Int(exactly: unitSystem.value(fromMeters: meters).rounded()) else {
            return "\(unitSystem.unitName) 0"
        }
        return "\(unitSystem.unitName) \(count)"
    }

    /// A distance said aloud: "150 meters", "1.2 kilometers", "250 feet", "0.3 miles".
    ///
    /// Returns nil when there is no sensible distance to say (negative, not finite or too large to represent),
    /// so callers can leave the distance out instead of speaking a wrong one.
    public static func distance(fromMeters meters: Double, unitSystem: UnitSystem) -> String? {
        guard meters.isFinite, meters >= 0 else { return nil }
        let text: String?
        switch unitSystem {
        case .metric:
            if meters < 950 {
                text = distanceText(roundedUp(meters, toNearest: 10), unit: "meter")
            } else {
                text = distanceText(roundedTenths(meters / 1_000), unit: "kilometer")
            }
        case .imperial:
            let feet = meters / 0.3048
            if feet < 500 {
                text = distanceText(roundedUp(feet, toNearest: 50), unit: "foot", plural: "feet")
            } else {
                text = distanceText(roundedTenths(unitSystem.value(fromMeters: meters)), unit: "mile")
            }
        }
        return text
    }

    private static func roundedUp(_ value: Double, toNearest step: Double) -> Double {
        max(step, (value / step).rounded() * step)
    }

    private static func roundedTenths(_ value: Double) -> Double {
        (value * 10).rounded() / 10
    }

    private static func distanceText(_ value: Double, unit: String, plural: String? = nil) -> String? {
        guard let tenths = Int(exactly: (value * 10).rounded()) else { return nil }
        let number = tenths % 10 == 0 ? "\(tenths / 10)" : "\(tenths / 10).\(tenths % 10)"
        return value == 1 ? "\(number) \(unit)" : "\(number) \(plural ?? unit + "s")"
    }

    private static func numberWord(_ value: Int) -> String {
        if value < 20 {
            return underTwenty[value]
        }
        let tensWord = tens[value / 10]
        let ones = value % 10
        if ones == 0 {
            return tensWord
        }
        return "\(tensWord)-\(underTwenty[ones])"
    }
}
