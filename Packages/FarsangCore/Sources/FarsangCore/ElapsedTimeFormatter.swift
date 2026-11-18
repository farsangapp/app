public enum ElapsedTimeFormatter {
    public static func string(fromSeconds seconds: Double) -> String {
        guard seconds.isFinite, seconds >= 0 else { return "0:00" }
        guard let totalSeconds = Int(exactly: seconds.rounded()) else { return "0:00" }
        let hours = totalSeconds / 3_600
        let minutes = (totalSeconds % 3_600) / 60
        let secs = totalSeconds % 60
        if hours > 0 {
            return "\(hours):\(Self.padded(minutes)):\(Self.padded(secs))"
        }
        return "\(minutes):\(Self.padded(secs))"
    }

    private static func padded(_ value: Int) -> String {
        value < 10 ? "0\(value)" : "\(value)"
    }
}
