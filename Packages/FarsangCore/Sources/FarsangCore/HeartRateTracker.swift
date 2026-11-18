import Foundation

struct HeartRateTracker: Sendable {
    let zones: HeartRateZones
    /// A reading is assumed to hold for at most this long, so a dropped sensor does not credit endless zone time.
    let staleAfter: TimeInterval

    private var latest: HeartRateSample?
    private var anchor: HeartRateSample?
    /// Time already credited, as intervals so a snapshot of an earlier date can leave out later credit.
    /// Contiguous intervals in the same zone merge, so this grows with zone changes and gaps, not with samples.
    private var credited: [CreditedInterval] = []
    private var sum = 0.0
    private var count = 0

    private struct CreditedInterval {
        let zone: HeartRateZone
        let start: Date
        var end: Date
    }

    init(zones: HeartRateZones, staleAfter: TimeInterval) {
        self.zones = zones
        // A negative (or NaN) limit would credit negative zone time.
        self.staleAfter = staleAfter > 0 ? staleAfter : 0
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
        guard let latest, (0...staleAfter).contains(date.timeIntervalSince(latest.timestamp)) else { return nil }
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

    /// Zone time accrued up to `date`; credit committed after `date` is left out.
    func timeInZone(at date: Date) -> [HeartRateZone: TimeInterval] {
        var result: [HeartRateZone: TimeInterval] = [:]
        for interval in credited {
            let seconds = min(interval.end, date).timeIntervalSince(interval.start)
            if seconds > 0 { result[interval.zone, default: 0] += seconds }
        }
        if let anchor, let zone = zones.zone(for: anchor.beatsPerMinute) {
            result[zone, default: 0] += heldDuration(of: anchor, until: date)
        }
        return result
    }

    private mutating func credit(_ sample: HeartRateSample, until date: Date) {
        guard let zone = zones.zone(for: sample.beatsPerMinute) else { return }
        let end = sample.timestamp.addingTimeInterval(heldDuration(of: sample, until: date))
        if let last = credited.last, last.zone == zone, last.end == sample.timestamp {
            credited[credited.count - 1].end = end
        } else {
            credited.append(CreditedInterval(zone: zone, start: sample.timestamp, end: end))
        }
    }

    private func heldDuration(of sample: HeartRateSample, until date: Date) -> TimeInterval {
        min(max(date.timeIntervalSince(sample.timestamp), 0), staleAfter)
    }

    /// Sensors report 0 when they lose contact.
    private static func isValid(_ sample: HeartRateSample) -> Bool {
        sample.beatsPerMinute.isFinite && sample.beatsPerMinute > 0
    }
}
