public enum PaceFormatter {
    public static func string(fromSpeed metersPerSecond: Double, unitSystem: UnitSystem) -> String {
        guard metersPerSecond.isFinite, metersPerSecond > 0 else { return "--:--" }
        return string(fromSecondsPerUnit: unitSystem.metersPerUnit / metersPerSecond)
    }

    public static func string(fromSecondsPerUnit seconds: Double) -> String {
        guard seconds.isFinite, seconds > 0, seconds < 3_600 else { return "--:--" }
        let totalSeconds = Int(seconds.rounded())
        guard totalSeconds > 0, totalSeconds < 3_600 else { return "--:--" }
        return "\(totalSeconds / 60):\(Self.padded(totalSeconds % 60))"
    }

    private static func padded(_ value: Int) -> String {
        value < 10 ? "0\(value)" : "\(value)"
    }
}
