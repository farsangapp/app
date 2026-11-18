import Foundation
import Testing

@testable import FarsangCore

/// Moving time is a sum of per-running-interval durations, so it never jumps at a transition.
struct WorkoutSessionMovingTimeTests {
    /// A start uptime and gaps whose float sums are not exact, so subtracting a growing total from
    /// the elapsed uptime would round differently from adding the intervals up.
    private static func startedFixture() throws -> Fixture {
        var fixture = Fixture(clock: ManualClock(uptime: 0.15))
        try fixture.session.handle(.start)
        return fixture
    }

    @Test func movingTimeIsIdenticalJustBeforeAndAfterPause() throws {
        var fixture = try Self.startedFixture()
        fixture.clock.advance(by: 2)
        let before = fixture.session.movingTime
        try fixture.session.handle(.pause)
        #expect(fixture.session.movingTime == before)
    }

    @Test func movingTimeIsIdenticalJustBeforeAndAfterResume() throws {
        var fixture = try Self.startedFixture()
        fixture.clock.advance(by: 2)
        try fixture.session.handle(.pause)
        fixture.clock.advance(by: 2.35)
        let before = fixture.session.movingTime
        try fixture.session.handle(.resume)
        #expect(fixture.session.movingTime == before)
        #expect(Int(fixture.session.movingTime) == 2)
    }

    @Test func movingTimeIsIdenticalJustBeforeAndAfterEndWhileRunning() throws {
        var fixture = try Self.startedFixture()
        fixture.clock.advance(by: 2)
        try fixture.session.handle(.pause)
        fixture.clock.advance(by: 2.35)
        try fixture.session.handle(.resume)
        fixture.clock.advance(by: 1.1)
        let before = fixture.session.movingTime
        try fixture.session.handle(.end)
        #expect(fixture.session.movingTime == before)
    }

    @Test func movingTimeIsIdenticalJustBeforeAndAfterEndWhilePaused() throws {
        var fixture = try Self.startedFixture()
        fixture.clock.advance(by: 2)
        try fixture.session.handle(.pause)
        fixture.clock.advance(by: 2.35)
        let before = fixture.session.movingTime
        try fixture.session.handle(.end)
        #expect(fixture.session.movingTime == before)
        #expect(Int(fixture.session.movingTime) == 2)
    }

    @Test func movingTimeNeverDecreasesAcrossManyPauseAndResumeCycles() throws {
        var fixture = try Self.startedFixture()
        var previous = fixture.session.movingTime
        for step in 1...200 {
            fixture.clock.advance(by: 0.1 * Double(step % 7) + 0.07)
            #expect(fixture.session.movingTime >= previous)
            previous = fixture.session.movingTime
            try fixture.session.handle(.pause)
            #expect(fixture.session.movingTime == previous)
            fixture.clock.advance(by: 0.3 * Double(step % 5) + 0.11)
            #expect(fixture.session.movingTime == previous)
            try fixture.session.handle(.resume)
            #expect(fixture.session.movingTime == previous)
        }
    }

    @Test func movingTimeIsTheSumOfTheRunningIntervals() throws {
        var fixture = try Self.startedFixture()
        fixture.clock.advance(by: 2)
        try fixture.session.handle(.pause)
        fixture.clock.advance(by: 2.35)
        try fixture.session.handle(.resume)
        fixture.clock.advance(by: 3)
        #expect(abs(fixture.session.movingTime - 5) < 1e-9)
        #expect(abs(fixture.session.elapsedTime - 7.35) < 1e-9)
    }
}
