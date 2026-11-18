import Foundation
import Synchronization
import Testing

@testable import FarsangCore

final class ManualClock: WorkoutClock {
    private struct Readings {
        var wall: Date
        var uptime: TimeInterval
    }

    private let readings: Mutex<Readings>

    init(_ start: Date = Date(timeIntervalSince1970: 1_000), uptime: TimeInterval = 5_000) {
        readings = Mutex(Readings(wall: start, uptime: uptime))
    }

    func now() -> Date { readings.withLock { $0.wall } }

    func uptime() -> TimeInterval { readings.withLock { $0.uptime } }

    /// Moves the wall clock and the monotonic uptime forward together, as time normally passes.
    func advance(by seconds: TimeInterval) {
        readings.withLock {
            $0.wall = $0.wall.addingTimeInterval(seconds)
            $0.uptime += seconds
        }
    }

    /// Lets `seconds` of real time pass while the wall clock is set back by `rollback` seconds, as when
    /// the user or the network changes the time.
    func advance(by seconds: TimeInterval, wallClockRolledBackBy rollback: TimeInterval) {
        advance(by: seconds, wallClockJumpedForwardBy: -rollback)
    }

    /// Lets `seconds` of real time pass while the wall clock is moved ahead by `jump` seconds.
    func advance(by seconds: TimeInterval, wallClockJumpedForwardBy jump: TimeInterval) {
        readings.withLock {
            $0.wall = $0.wall.addingTimeInterval(seconds + jump)
            $0.uptime += seconds
        }
    }
}

func at(_ seconds: TimeInterval) -> Date {
    Date(timeIntervalSince1970: 1_000 + seconds)
}

struct Fixture {
    var session: WorkoutSession
    let clock: ManualClock

    init(clock: ManualClock = ManualClock()) {
        self.clock = clock
        session = WorkoutSession(clock: clock)
    }

    static func running() throws -> Fixture {
        var fixture = Fixture()
        try fixture.session.handle(.start)
        return fixture
    }

    static func paused() throws -> Fixture {
        var fixture = try running()
        fixture.clock.advance(by: 10)
        try fixture.session.handle(.pause)
        return fixture
    }

    static func ended() throws -> Fixture {
        var fixture = try running()
        fixture.clock.advance(by: 10)
        try fixture.session.handle(.end)
        return fixture
    }
}
