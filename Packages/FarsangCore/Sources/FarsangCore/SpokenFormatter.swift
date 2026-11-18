public enum SpokenFormatter {
    private static let underTwenty = [
        "zero", "one", "two", "three", "four", "five", "six", "seven", "eight", "nine",
        "ten", "eleven", "twelve", "thirteen", "fourteen", "fifteen", "sixteen", "seventeen",
        "eighteen", "nineteen"
    ]

    private static let tens = ["", "", "twenty", "thirty", "forty", "fifty"]

    public static func pace(fromSecondsPerUnit seconds: Double, unitSystem: UnitSystem) -> String {
        guard seconds.isFinite, seconds > 0, seconds < 3_600 else { return "" }
        let totalSeconds = Int(seconds.rounded())
        guard totalSeconds > 0, totalSeconds < 3_600 else { return "" }
        let minutes = totalSeconds / 60
        let secs = totalSeconds % 60
        return "\(numberWord(minutes)) \(numberWord(secs)) per \(unitSystem.unitName)"
    }

    public static func distanceMarker(fromMeters meters: Double, unitSystem: UnitSystem) -> String {
        guard meters.isFinite, meters >= 0 else { return "\(unitSystem.unitName) 0" }
        let count = Int(unitSystem.value(fromMeters: meters).rounded())
        return "\(unitSystem.unitName) \(count)"
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
