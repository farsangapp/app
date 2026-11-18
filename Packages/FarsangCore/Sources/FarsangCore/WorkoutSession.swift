import Foundation

/// A source of the current time, injected so tests never sleep.
public protocol WorkoutClock: Sendable {
    func now() -> Date
}

/// The wall clock used outside tests.
public struct SystemWorkoutClock: WorkoutClock {
    public init() {}

    public func now() -> Date { Date() }
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

/// A stretch of time the workout was paused. `end` is nil while the pause is still open.
public struct PauseInterval: Sendable, Hashable {
    public let start: Date
    public internal(set) var end: Date?

    public init(start: Date, end: Date? = nil) {
        self.start = start
        self.end = end
    }
}

/// The run, pause, resume, segment and end lifecycle of one workout.
///
/// Transitions: idle -start-> running; running -pause-> paused; paused -resume-> running;
/// running -markSegment-> running; running or paused -end-> ended. Anything else throws
/// `WorkoutSessionError.invalidTransition` and leaves the session unchanged. Segments can only be
/// marked while running, and `ended` is terminal.
public struct WorkoutSession: Sendable {
    public private(set) var state: WorkoutSessionState = .idle
    public private(set) var startedAt: Date?
    public private(set) var endedAt: Date?
    public private(set) var segments: [Segment] = []
    public private(set) var pauses: [PauseInterval] = []

    private let clock: any WorkoutClock

    public init(clock: any WorkoutClock = SystemWorkoutClock()) {
        self.clock = clock
    }

    public var segmentCount: Int { segments.count }

    /// Time since the start, paused time included, as of the clock's current time.
    public var elapsedTime: TimeInterval { elapsedTime(at: clock.now()) }

    /// Time since the start without paused time, as of the clock's current time.
    public var movingTime: TimeInterval { movingTime(at: clock.now()) }

    /// Time since the start, paused time included. Stops growing once ended.
    public func elapsedTime(at date: Date) -> TimeInterval {
        guard let startedAt else { return 0 }
        let reference = endedAt.map { min($0, date) } ?? date
        return max(0, reference.timeIntervalSince(startedAt))
    }

    /// Time since the start without paused time. Stops growing while paused and once ended.
    public func movingTime(at date: Date) -> TimeInterval {
        guard let startedAt else { return 0 }
        let reference = endedAt.map { min($0, date) } ?? date
        let paused = pauses.reduce(0) { total, pause in
            let pauseStart = max(pause.start, startedAt)
            let pauseEnd = min(pause.end ?? reference, reference)
            return total + max(0, pauseEnd.timeIntervalSince(pauseStart))
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
            return .started(timestamp: now)
        case (.running, .pause):
            let now = clock.now()
            state = .paused
            pauses.append(PauseInterval(start: now))
            return .paused(timestamp: now)
        case (.paused, .resume):
            let now = clock.now()
            state = .running
            closeOpenPause(at: now)
            return .resumed(timestamp: now)
        case (.running, .markSegment):
            let now = clock.now()
            segments.append(Segment(number: segments.count + 1, markedAt: now))
            return .segmentMarked(number: segments.count, timestamp: now)
        case (.running, .end), (.paused, .end):
            let now = clock.now()
            closeOpenPause(at: now)
            state = .ended
            endedAt = now
            return .ended(timestamp: now)
        default:
            throw .invalidTransition(from: state, event: event)
        }
    }

    private mutating func closeOpenPause(at date: Date) {
        guard let last = pauses.indices.last, pauses[last].end == nil else { return }
        pauses[last].end = date
    }
}

extension WorkoutSession: Equatable {
    /// Compares the recorded state; the injected clock is not part of a session's identity.
    public static func == (lhs: WorkoutSession, rhs: WorkoutSession) -> Bool {
        lhs.state == rhs.state && lhs.startedAt == rhs.startedAt && lhs.endedAt == rhs.endedAt
            && lhs.segments == rhs.segments && lhs.pauses == rhs.pauses
    }
}
