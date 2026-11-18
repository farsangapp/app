public enum PaceFormatter {
    public static func string(fromSpeed metersPerSecond: Double, unitSystem: UnitSystem) -> String {
        guard metersPerSecond.isFinite, metersPerSecond > 0 else { return "--:--" }
        return string(fromSecondsPerUnit: unitSystem.metersPerUnit / metersPerSecond)
    }

    public static func string(fromSecondsPerUnit seconds: Double) -> String {
        guard let totalSeconds = PaceSeconds.rounded(seconds) else { return "--:--" }
        return "\(totalSeconds / 60):\(Self.padded(totalSeconds % 60))"
    }

    private static func padded(_ value: Int) -> String {
        value < 10 ? "0\(value)" : "\(value)"
    }
}
