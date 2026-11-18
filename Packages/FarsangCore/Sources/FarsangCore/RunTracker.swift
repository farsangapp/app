import Foundation

public struct SegmentStats: Sendable, Hashable {
    /// 1-based, in the order segments were marked.
    public let index: Int
    public let duration: TimeInterval
    public let distance: Distance
    public let averagePace: Pace?
    public let averageHeartRate: Double?
}

public struct RunSnapshot: Sendable, Hashable {
    public let state: RunTracker.State
    /// Time spent running, excluding paused time.
    public let elapsedTime: TimeInterval
    public let distance: Distance
    public let averagePace: Pace?
    /// Pace over the last rolling distance (1 km by default). Nil until that much distance is covered.
    public let rollingPace: Pace?
    public let currentHeartRate: Double?
    public let currentZone: HeartRateZone?
    public let timeInZone: [HeartRateZone: TimeInterval]
    public let averageHeartRate: Double?
    /// Segments closed by `markSegment`.
    public let completedSegments: [SegmentStats]
    /// The segment in progress, which started at the last mark or at the start of the run.
    public let currentSegment: SegmentStats?
}

/// Turns a stream of location and heart-rate samples into the numbers the watch screens show.
///
/// Time is always passed in, never read from a clock, so behavior is deterministic. Dates passed to `start`,
/// `pause`, `resume`, `markSegment` and `end` form a monotonic clock: a date earlier than one already seen counts
/// as that later date, so time never runs backward. Only calls that take effect move that clock: ignored calls do
/// not, and a mark while paused never does, since a paused run takes no time from the date. Samples are only
/// counted while the run is running; the first fix after a resume re-anchors and adds no distance.
public struct RunTracker: Sendable {
    public struct Configuration: Sendable, Hashable {
        public var heartRateZones: HeartRateZones
        public var locationFilter: LocationFilter.Configuration
        public var rollingDistance: Distance
        public var heartRateStaleAfter: TimeInterval

        public init(
            heartRateZones: HeartRateZones,
            locationFilter: LocationFilter.Configuration = LocationFilter.Configuration(),
            rollingDistance: Distance = Distance(meters: 1_000),
            heartRateStaleAfter: TimeInterval = 10
        ) {
            self.heartRateZones = heartRateZones
            self.locationFilter = locationFilter
            self.rollingDistance = rollingDistance
            self.heartRateStaleAfter = heartRateStaleAfter
        }
    }

    public enum State: Sendable, Hashable {
        case notStarted
        case running
        case paused
        case ended
    }

    private struct TrailPoint {
        let meters: Double
        let elapsed: TimeInterval
    }

    private struct SegmentAccumulator {
        let startElapsed: TimeInterval
        let startMeters: Double
        var heartRateSum = 0.0
        var heartRateCount = 0

        func stats(index: Int, elapsed: TimeInterval, meters: Double) -> SegmentStats {
            let duration = max(elapsed - startElapsed, 0)
            let distance = Distance(meters: max(meters - startMeters, 0))
            return SegmentStats(
                index: index,
                duration: duration,
                distance: distance,
                averagePace: Pace(duration: duration, distance: distance),
                averageHeartRate: heartRateCount > 0 ? heartRateSum / Double(heartRateCount) : nil
            )
        }
    }

    public let configuration: Configuration
    public private(set) var state: State = .notStarted

    private var filter: LocationFilter
    private var heart: HeartRateTracker
    private var accumulatedElapsed: TimeInterval = 0
    private var periodStart: Date?
    /// The latest date any lifecycle call has used.
    private var clock = Date.distantPast
    private var totalMeters = 0.0
    private var trail: [TrailPoint] = []
    private var completedSegments: [SegmentStats] = []
    private var segment = SegmentAccumulator(startElapsed: 0, startMeters: 0)

    public init(configuration: Configuration) {
        self.configuration = configuration
        filter = LocationFilter(configuration: configuration.locationFilter)
        heart = HeartRateTracker(zones: configuration.heartRateZones, staleAfter: configuration.heartRateStaleAfter)
    }

    // MARK: Lifecycle

    public mutating func start(at date: Date) {
        guard state == .notStarted else { return }
        state = .running
        periodStart = tick(date)
    }

    public mutating func pause(at date: Date) {
        guard state == .running else { return }
        closePeriod(at: tick(date))
        state = .paused
    }

    public mutating func resume(at date: Date) {
        guard state == .paused else { return }
        state = .running
        periodStart = tick(date)
        filter.reset()
    }

    public mutating func end(at date: Date) {
        guard state == .running || state == .paused else { return }
        let now = tick(date)
        if state == .running { closePeriod(at: now) }
        closeSegment(elapsed: accumulatedElapsed, keepingZeroDurationData: true)
        state = .ended
    }

    /// Closes the current segment and starts a new one. Ignored when no time has passed since the last mark.
    /// Only a mark that closes a segment while running moves the lifecycle clock; while paused the date is unused.
    /// Ending the run closes the last segment too, so `completedSegments` holds every segment of a finished run.
    public mutating func markSegment(at date: Date) {
        guard state == .running || state == .paused else { return }
        guard closeSegment(elapsed: elapsed(at: date)) else { return }
        if state == .running { _ = tick(date) }
    }

    // MARK: Samples

    public mutating func add(_ sample: LocationSample) {
        guard isCountable(sample.timestamp) else { return }
        let outcome = filter.process(sample)
        let moved: Double
        switch outcome {
        case .rejected: return
        case .anchored: moved = 0
        case .accepted(let distance): moved = distance.meters
        }
        totalMeters += moved
        record(TrailPoint(meters: totalMeters, elapsed: elapsed(at: sample.timestamp)))
    }

    public mutating func add(_ sample: HeartRateSample) {
        switch state {
        case .running:
            guard isCountable(sample.timestamp), heart.record(sample) else { return }
            segment.heartRateSum += sample.beatsPerMinute
            segment.heartRateCount += 1
        case .paused:
            heart.observe(sample)
        case .notStarted, .ended:
            break
        }
    }

    // MARK: Output

    public func snapshot(at date: Date) -> RunSnapshot {
        // One effective date for every metric, so a snapshot dated before the clock reads as the clock throughout.
        let date = max(date, clock)
        let now = elapsed(at: date)
        let distance = Distance(meters: totalMeters)
        let current = heart.current(at: date).map(\.beatsPerMinute)
        let inProgress =
            state == .notStarted || state == .ended
            ? nil
            : segment.stats(index: completedSegments.count + 1, elapsed: now, meters: totalMeters)
        return RunSnapshot(
            state: state,
            elapsedTime: now,
            distance: distance,
            averagePace: Pace(duration: now, distance: distance),
            rollingPace: rollingPace(elapsed: now),
            currentHeartRate: current,
            currentZone: current.flatMap(configuration.heartRateZones.zone(for:)),
            timeInZone: heart.timeInZone(at: date),
            averageHeartRate: heart.average,
            completedSegments: completedSegments,
            currentSegment: inProgress
        )
    }

    // MARK: Internals

    var trailPointCount: Int { trail.count }

    /// A segment without elapsed time is dropped, unless the run ends and it already holds counted data.
    /// Returns whether a segment was closed.
    @discardableResult
    private mutating func closeSegment(elapsed now: TimeInterval, keepingZeroDurationData: Bool = false) -> Bool {
        let hasData = segment.heartRateCount > 0 || totalMeters > segment.startMeters
        guard now > segment.startElapsed || (keepingZeroDurationData && hasData) else { return false }
        completedSegments.append(segment.stats(index: completedSegments.count + 1, elapsed: now, meters: totalMeters))
        segment = SegmentAccumulator(startElapsed: now, startMeters: totalMeters)
        return true
    }

    /// Advances the clock to `date`, or leaves it where it is when `date` is earlier, and returns the result.
    private mutating func tick(_ date: Date) -> Date {
        clock = max(clock, date)
        return clock
    }

    /// Time running at `date`, which is never read as earlier than the clock, so `clock >= periodStart` keeps it
    /// from going below what a completed segment or a closed period already holds.
    private func elapsed(at date: Date) -> TimeInterval {
        guard state == .running, let periodStart else { return accumulatedElapsed }
        return accumulatedElapsed + max(date, clock).timeIntervalSince(periodStart)
    }

    private mutating func closePeriod(at date: Date) {
        accumulatedElapsed = elapsed(at: date)
        periodStart = nil
        heart.suspend(at: date)
    }

    /// Rejects samples that are not running or that were captured before the current running period began.
    private func isCountable(_ timestamp: Date) -> Bool {
        guard state == .running, let periodStart else { return false }
        return timestamp >= periodStart
    }

    /// Fixes that did not move the runner collapse into the first and last of the stop, so the trail stays bounded.
    private mutating func record(_ point: TrailPoint) {
        let lastTwo = trail.suffix(2)
        if lastTwo.count == 2, lastTwo.allSatisfy({ $0.meters == point.meters }) {
            trail[trail.count - 1] = point
        } else {
            trail.append(point)
        }
        trimTrail()
    }

    /// Keeps only the points the rolling window needs: the newest one at or before its start, and all after.
    private mutating func trimTrail() {
        let windowStart = totalMeters - configuration.rollingDistance.meters
        while trail.count > 1 && trail[1].meters <= windowStart {
            trail.removeFirst()
        }
    }

    /// Time since the window started, measured to `elapsed` so the pace slows while standing still or without a fix.
    private func rollingPace(elapsed now: TimeInterval) -> Pace? {
        let window = configuration.rollingDistance
        guard window.meters > 0, totalMeters >= window.meters else { return nil }
        let target = totalMeters - window.meters
        guard let index = trail.lastIndex(where: { $0.meters <= target }) else { return nil }
        let before = trail[index]
        var startElapsed = before.elapsed
        if index + 1 < trail.count {
            let after = trail[index + 1]
            let fraction = (target - before.meters) / (after.meters - before.meters)
            startElapsed += fraction * (after.elapsed - before.elapsed)
        }
        return Pace(duration: now - startElapsed, distance: window)
    }
}
