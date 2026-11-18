/// Shared validation and rounding for per-unit pace values, used by both the
/// display formatter and the speech formatter so they always agree on the boundary.
enum PaceSeconds {
    /// Returns the pace rounded to a whole second, or `nil` when the value is not a
    /// valid pace: it must be finite, positive, and round to a value strictly under
    /// one hour (`1..<3600`).
    static func rounded(_ seconds: Double) -> Int? {
        guard seconds.isFinite, seconds > 0, seconds < 3_600 else { return nil }
        guard let totalSeconds = Int(exactly: seconds.rounded()), totalSeconds > 0, totalSeconds < 3_600 else {
            return nil
        }
        return totalSeconds
    }
}
