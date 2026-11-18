import Foundation

/// A source of the current time, injected so tests never sleep.
public protocol WorkoutClock: Sendable {
    /// The wall-clock time. It can jump backwards when the time is changed.
    func now() -> Date

    /// Seconds on a monotonic clock that keeps counting through sleep and never goes backwards. Only
    /// differences between two readings mean anything; the session uses them to measure pauses.
    func uptime() -> TimeInterval
}

/// The wall clock and a monotonic clock, used outside tests.
public struct SystemWorkoutClock: WorkoutClock {
    private let origin = ContinuousClock.now

    public init() {}

    public func now() -> Date { Date() }

    public func uptime() -> TimeInterval {
        let elapsed = ContinuousClock.now - origin
        return TimeInterval(elapsed.components.seconds) + TimeInterval(elapsed.components.attoseconds) / 1e18
    }
}

public enum WorkoutSessionState: Sendable, Hashable {
    case idle
    case running
    case paused
    case ended
}

/// What the watch UI or the HealthKit layer asks the session to do.
public enum WorkoutSessionEvent: Sendable, Hashable {
    case start
    case pause
    case resume
    case markSegment
    case end
}

/// What the session reports after accepting an event, for the alert engine.
public enum WorkoutSessionNotice: Sendable, Hashable {
    case started(timestamp: Date)
    case paused(timestamp: Date)
    case resumed(timestamp: Date)
    case segmentMarked(number: Int, timestamp: Date)
    case ended(timestamp: Date)
}

public enum WorkoutSessionError: Error, Sendable, Hashable {
    case invalidTransition(from: WorkoutSessionState, event: WorkoutSessionEvent)
}

public struct Segment: Sendable, Hashable {
    /// 1-based, in the order the segments were marked.
    public let number: Int
    public let markedAt: Date

    public init(number: Int, markedAt: Date) {
        self.number = number
        self.markedAt = markedAt
    }
}

/// A stretch of time the workout was paused. `duration` is nil while the pause is still open.
///
/// The duration is measured on the monotonic clock, so it is right even when the wall clock was
/// changed during the pause; `start` is the wall date the pause was observed at.
public struct PauseInterval: Sendable, Hashable {
    public let start: Date
    public internal(set) var duration: TimeInterval?

    /// Where the pause ends on the wall timeline, `start` plus the measured duration. It is never
    /// before `start`, and it can differ from the wall date the resume was observed at.
    public var end: Date? { duration.map { start.addingTimeInterval($0) } }

    /// A negative `duration` is stored as zero, so `end` is never before `start`.
    public init(start: Date, duration: TimeInterval? = nil) {
        self.start = start
        self.duration = duration.map { max(0, $0) }
    }
}

/// The run, pause, resume, segment and end lifecycle of one workout.
///
/// Transitions: idle -start-> running; running -pause-> paused; paused -resume-> running;
/// running -markSegment-> running; running or paused -end-> ended. Anything else throws
/// `WorkoutSessionError.invalidTransition` and leaves the session unchanged. Segments can only be
/// marked while running, and `ended` is terminal.
///
/// Two timelines. The wall clock can be set mid-workout, so the live values (`elapsedTime` and
/// `movingTime`) and the length of every pause come from the monotonic uptime alone: a clock change
/// in either direction cannot stall, shift or rescale them. The wall dates (`startedAt`, `endedAt`,
/// segment and pause starts, and the timestamps in notices) are what the wall clock showed when the
/// event was accepted, kept for display and for matching other data. The `at:` queries read those
/// wall dates, so after a clock change they are only as good as the wall clock; each pause covers
/// its start plus its measured duration there, and pauses that overlap on the wall timeline count
/// once.
public struct WorkoutSession: Sendable {
    public private(set) var state: WorkoutSessionState = .idle
    public private(set) var startedAt: Date?
    public private(set) var endedAt: Date?
    public private(set) var segments: [Segment] = []
    public private(set) var pauses: [PauseInterval] = []

    private let clock: any WorkoutClock
    private var startUptime: TimeInterval?
    private var endUptime: TimeInterval?
    /// The uptime at which the open pause began, if one is open.
    private var openPauseUptime: TimeInterval?

    public init(clock: any WorkoutClock = SystemWorkoutClock()) {
        self.clock = clock
    }

    public var segmentCount: Int { segments.count }

    /// Time since the start, paused time included, on the monotonic clock. Fixed once ended.
    public var elapsedTime: TimeInterval {
        guard let startUptime else { return 0 }
        return max(0, (endUptime ?? clock.uptime()) - startUptime)
    }

    /// Time since the start without paused time, on the monotonic clock. Fixed while paused and once
    /// ended, and it resumes counting the moment the session resumes.
    public var movingTime: TimeInterval {
        guard let startUptime else { return 0 }
        // While paused, the moving time is frozen at the uptime the pause began, so it does not
        // depend on later clock reads and has no rounding drift.
        let reference = openPauseUptime ?? endUptime ?? clock.uptime()
        let closed = pauses.reduce(0) { $0 + ($1.duration ?? 0) }
        return max(0, reference - startUptime - closed)
    }

    /// Time since the start, paused time included, as of a wall date. Stops growing once ended.
    public func elapsedTime(at date: Date) -> TimeInterval {
        guard let startedAt else { return 0 }
        let reference = endedAt.map { min($0, date) } ?? date
        return max(0, reference.timeIntervalSince(startedAt))
    }

    /// Time since the start without paused time, as of a wall date. Stops growing while paused and
    /// once ended. Overlapping pauses are deducted once.
    public func movingTime(at date: Date) -> TimeInterval {
        guard let startedAt else { return 0 }
        let reference = endedAt.map { min($0, date) } ?? date
        let spans = pauses.map { (start: max($0.start, startedAt), end: min($0.end ?? reference, reference)) }
            .filter { $0.start < $0.end }
            .sorted { $0.start < $1.start }
        var paused: TimeInterval = 0
        var covered: Date?
        for span in spans {
            let from = covered.map { max($0, span.start) } ?? span.start
            if span.end > from { paused += span.end.timeIntervalSince(from) }
            covered = max(covered ?? span.end, span.end)
        }
        return max(0, reference.timeIntervalSince(startedAt) - paused)
    }

    /// Whether `handle` would accept the event in the current state.
    public func canHandle(_ event: WorkoutSessionEvent) -> Bool {
        switch (state, event) {
        case (.idle, .start), (.running, .pause), (.paused, .resume), (.running, .markSegment),
            (.running, .end), (.paused, .end):
            true
        default:
            false
        }
    }

    /// Applies an event and returns the notification for the alert engine.
    @discardableResult
    public mutating func handle(_ event: WorkoutSessionEvent) throws(WorkoutSessionError) -> WorkoutSessionNotice {
        switch (state, event) {
        case (.idle, .start):
            let now = clock.now()
            state = .running
            startedAt = now
            startUptime = clock.uptime()
            return .started(timestamp: now)
        case (.running, .pause):
            let now = clock.now()
            state = .paused
            pauses.append(PauseInterval(start: now))
            openPauseUptime = clock.uptime()
            return .paused(timestamp: now)
        case (.paused, .resume):
            let now = clock.now()
            closeOpenPause(atUptime: clock.uptime())
            state = .running
            return .resumed(timestamp: now)
        case (.running, .markSegment):
            let now = clock.now()
            segments.append(Segment(number: segments.count + 1, markedAt: now))
            return .segmentMarked(number: segments.count, timestamp: now)
        case (.running, .end), (.paused, .end):
            let now = clock.now()
            let uptime = clock.uptime()
            closeOpenPause(atUptime: uptime)
            state = .ended
            endedAt = now
            endUptime = uptime
            return .ended(timestamp: now)
        default:
            throw .invalidTransition(from: state, event: event)
        }
    }

    /// Closes the open pause, if any, recording its measured length.
    private mutating func closeOpenPause(atUptime uptime: TimeInterval) {
        guard let last = pauses.indices.last, pauses[last].duration == nil, let startUptime = openPauseUptime else {
            return
        }
        pauses[last].duration = max(0, uptime - startUptime)
        openPauseUptime = nil
    }
}

extension WorkoutSession: Equatable {
    /// Compares the recorded state, uptime baselines included; the injected clock is not part of a
    /// session's identity.
    public static func == (lhs: WorkoutSession, rhs: WorkoutSession) -> Bool {
        lhs.state == rhs.state && lhs.startedAt == rhs.startedAt && lhs.endedAt == rhs.endedAt
            && lhs.segments == rhs.segments && lhs.pauses == rhs.pauses
            && lhs.startUptime == rhs.startUptime && lhs.endUptime == rhs.endUptime
            && lhs.openPauseUptime == rhs.openPauseUptime
    }
}
