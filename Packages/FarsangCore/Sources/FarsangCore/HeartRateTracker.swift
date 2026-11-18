import Foundation

struct HeartRateTracker: Sendable {
    let zones: HeartRateZones
    /// A reading is assumed to hold for at most this long, so a dropped sensor does not credit endless zone time.
    let staleAfter: TimeInterval

    private var latest: HeartRateSample?
    private var anchor: HeartRateSample?
    private var credited: [HeartRateZone: TimeInterval] = [:]
    private var sum = 0.0
    private var count = 0

    init(zones: HeartRateZones, staleAfter: TimeInterval) {
        self.zones = zones
        self.staleAfter = staleAfter
    }

    var average: Double? { count > 0 ? sum / Double(count) : nil }

    /// Returns false when the sample was ignored.
    @discardableResult
    mutating func record(_ sample: HeartRateSample) -> Bool {
        guard Self.isValid(sample), !isOlderThanLatest(sample) else { return false }
        if let anchor {
            guard sample.timestamp >= anchor.timestamp else { return false }
            credit(anchor, until: sample.timestamp)
        }
        anchor = sample
        latest = sample
        sum += sample.beatsPerMinute
        count += 1
        return true
    }

    /// Shows a reading without counting it, for samples that arrive while paused.
    mutating func observe(_ sample: HeartRateSample) {
        guard Self.isValid(sample), !isOlderThanLatest(sample) else { return }
        latest = sample
    }

    /// The latest reading, or nil once it is older than `staleAfter`, so the screen stops showing a dead sensor.
    func current(at date: Date) -> HeartRateSample? {
        guard let latest, date.timeIntervalSince(latest.timestamp) <= staleAfter else { return nil }
        return latest
    }

    private func isOlderThanLatest(_ sample: HeartRateSample) -> Bool {
        guard let latest else { return false }
        return sample.timestamp < latest.timestamp
    }

    mutating func suspend(at date: Date) {
        guard let anchor else { return }
        credit(anchor, until: date)
        self.anchor = nil
    }

    func timeInZone(at date: Date) -> [HeartRateZone: TimeInterval] {
        var result = credited
        if let anchor, let zone = zones.zone(for: anchor.beatsPerMinute) {
            result[zone, default: 0] += heldDuration(of: anchor, until: date)
        }
        return result
    }

    private mutating func credit(_ sample: HeartRateSample, until date: Date) {
        guard let zone = zones.zone(for: sample.beatsPerMinute) else { return }
        credited[zone, default: 0] += heldDuration(of: sample, until: date)
    }

    private func heldDuration(of sample: HeartRateSample, until date: Date) -> TimeInterval {
        min(max(date.timeIntervalSince(sample.timestamp), 0), staleAfter)
    }

    /// Sensors report 0 when they lose contact.
    private static func isValid(_ sample: HeartRateSample) -> Bool {
        sample.beatsPerMinute.isFinite && sample.beatsPerMinute > 0
    }
}
