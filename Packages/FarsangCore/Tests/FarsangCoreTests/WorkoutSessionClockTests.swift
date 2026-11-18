import Foundation
import Testing

@testable import FarsangCore

struct WorkoutSessionClockTests {
    // MARK: Wall-clock rollback

    @Test func timesStayFixedAfterEndWhenTheWallClockRollsBack() throws {
        var fixture = try Fixture.running()
        fixture.clock.advance(by: 100)
        try fixture.session.handle(.pause)
        fixture.clock.advance(by: 20)
        try fixture.session.handle(.end)
        fixture.clock.advance(by: 5, wallClockRolledBackBy: 35)
        #expect(fixture.session.movingTime == 100)
        #expect(fixture.session.elapsedTime == 120)
    }

    @Test func movingTimeStaysFixedWhilePausedWhenTheWallClockRollsBack() throws {
        var fixture = try Fixture.running()
        fixture.clock.advance(by: 100)
        try fixture.session.handle(.pause)
        fixture.clock.advance(by: 5, wallClockRolledBackBy: 15)
        #expect(fixture.session.movingTime == 100)
    }

    @Test func resumeAfterARollbackKeepsThePauseInOrderAndItsDuration() throws {
        var fixture = try Fixture.running()
        fixture.clock.advance(by: 100)
        try fixture.session.handle(.pause)
        fixture.clock.advance(by: 40, wallClockRolledBackBy: 50)
        let notification = try fixture.session.handle(.resume)
        #expect(fixture.session.pauses == [PauseInterval(start: at(100), duration: 40)])
        #expect(fixture.session.pauses.first?.end == at(140))
        #expect(notification == .resumed(timestamp: at(90)))
        #expect(fixture.session.movingTime(at: at(200)) == 160)
        #expect(fixture.session.elapsedTime(at: at(200)) == 200)
    }

    @Test func endWhilePausedAfterARollbackKeepsThePauseInOrderAndItsDuration() throws {
        var fixture = try Fixture.running()
        fixture.clock.advance(by: 100)
        try fixture.session.handle(.pause)
        fixture.clock.advance(by: 20, wallClockRolledBackBy: 30)
        let notification = try fixture.session.handle(.end)
        #expect(fixture.session.pauses == [PauseInterval(start: at(100), duration: 20)])
        #expect(fixture.session.endedAt == at(90))
        #expect(notification == .ended(timestamp: at(90)))
        #expect(fixture.session.movingTime == 100)
        #expect(fixture.session.elapsedTime == 120)
    }

    @Test func zeroLengthPauseSurvivesARollback() throws {
        var fixture = try Fixture.running()
        fixture.clock.advance(by: 100)
        try fixture.session.handle(.pause)
        fixture.clock.advance(by: 0, wallClockRolledBackBy: 10)
        try fixture.session.handle(.resume)
        #expect(fixture.session.pauses == [PauseInterval(start: at(100), duration: 0)])
    }

    @Test func movingTimeAdvancesRightAfterResumeWhenTheWallClockWasRolledBack() throws {
        var fixture = try Fixture.running()
        fixture.clock.advance(by: 100)
        try fixture.session.handle(.pause)
        fixture.clock.advance(by: 40, wallClockRolledBackBy: 35)
        try fixture.session.handle(.resume)
        #expect(fixture.session.movingTime == 100)
        fixture.clock.advance(by: 10)
        #expect(fixture.session.movingTime == 110)
        #expect(fixture.session.elapsedTime == 150)
        fixture.clock.advance(by: 5)
        #expect(fixture.session.movingTime == 115)
    }

    @Test func aSecondPauseAfterARollbackIsMeasuredOnItsOwn() throws {
        var fixture = try Fixture.running()
        fixture.clock.advance(by: 100)
        try fixture.session.handle(.pause)
        fixture.clock.advance(by: 40, wallClockRolledBackBy: 50)
        try fixture.session.handle(.resume)
        fixture.clock.advance(by: 25)
        try fixture.session.handle(.pause)
        fixture.clock.advance(by: 10)
        try fixture.session.handle(.resume)
        fixture.clock.advance(by: 5)
        // 100 + 25 + 5 moving; the two pauses lasted 40 s and 10 s.
        #expect(fixture.session.movingTime == 130)
        #expect(fixture.session.elapsedTime == 180)
    }

    // MARK: Wall-clock jump forward

    @Test func pauseLengthIsTheMeasuredDurationWhenTheWallClockJumpsForward() throws {
        var fixture = try Fixture.running()
        fixture.clock.advance(by: 100)
        try fixture.session.handle(.pause)
        fixture.clock.advance(by: 20, wallClockJumpedForwardBy: 60)
        let notification = try fixture.session.handle(.resume)
        #expect(fixture.session.pauses == [PauseInterval(start: at(100), duration: 20)])
        #expect(notification == .resumed(timestamp: at(180)))
        fixture.clock.advance(by: 10)
        #expect(fixture.session.movingTime == 110)
        #expect(fixture.session.elapsedTime == 130)
        #expect(fixture.session.movingTime(at: at(200)) == 180)
    }

    @Test func movingTimeStaysFixedWhilePausedWhenTheWallClockJumpsForward() throws {
        var fixture = try Fixture.running()
        fixture.clock.advance(by: 100)
        try fixture.session.handle(.pause)
        fixture.clock.advance(by: 5, wallClockJumpedForwardBy: 500)
        #expect(fixture.session.movingTime == 100)
    }

    @Test func endWhilePausedAfterAForwardJumpKeepsTheMeasuredPause() throws {
        var fixture = try Fixture.running()
        fixture.clock.advance(by: 100)
        try fixture.session.handle(.pause)
        fixture.clock.advance(by: 20, wallClockJumpedForwardBy: 60)
        let notification = try fixture.session.handle(.end)
        #expect(fixture.session.pauses == [PauseInterval(start: at(100), duration: 20)])
        #expect(notification == .ended(timestamp: at(180)))
        #expect(fixture.session.movingTime == 100)
        #expect(fixture.session.elapsedTime == 120)
    }

    // MARK: Overlapping pauses on the wall timeline

    @Test func overlappingPausesAreDeductedOnce() throws {
        var fixture = try Fixture.running()
        fixture.clock.advance(by: 100)
        try fixture.session.handle(.pause)
        fixture.clock.advance(by: 40, wallClockRolledBackBy: 50)  // wall 90; first pause covers 100...140
        try fixture.session.handle(.resume)
        fixture.clock.advance(by: 25)  // wall 115, inside the first pause's span
        try fixture.session.handle(.pause)
        fixture.clock.advance(by: 10)  // wall 125
        try fixture.session.handle(.resume)
        #expect(fixture.session.movingTime(at: at(115)) == 100)
        #expect(fixture.session.movingTime(at: at(125)) == 100)
        #expect(fixture.session.movingTime(at: at(140)) == 100)
        #expect(fixture.session.movingTime(at: at(150)) == 110)
    }

    // MARK: Pause precision

    @Test func movingTimeWhilePausedDoesNotDependOnLaterClockReads() throws {
        let clock = ManualClock(uptime: 0.15)
        var session = WorkoutSession(clock: clock)
        try session.handle(.start)
        clock.advance(by: 2)
        try session.handle(.pause)
        let atPause = session.movingTime
        #expect(atPause == 2)
        clock.advance(by: 2.35)
        #expect(session.movingTime == atPause)
    }

    @Test func movingTimeWhilePausedAfterAnEarlierPauseDoesNotDependOnLaterClockReads() throws {
        let clock = ManualClock(uptime: 0.15)
        var session = WorkoutSession(clock: clock)
        try session.handle(.start)
        clock.advance(by: 1)
        try session.handle(.pause)
        clock.advance(by: 0.7)
        try session.handle(.resume)
        clock.advance(by: 2)
        try session.handle(.pause)
        let atPause = session.movingTime
        clock.advance(by: 2.35)
        #expect(session.movingTime == atPause)
        clock.advance(by: 1_000.1)
        #expect(session.movingTime == atPause)
    }

    // MARK: Pause interval invariant

    @Test func pauseIntervalNormalizesANegativeDurationToZero() {
        let pause = PauseInterval(start: at(10), duration: -5)
        #expect(pause.duration == 0)
        #expect(pause.end == at(10))
    }

    @Test func pauseIntervalKeepsOpenZeroAndPositiveDurations() {
        #expect(PauseInterval(start: at(10)).duration == nil)
        #expect(PauseInterval(start: at(10)).end == nil)
        #expect(PauseInterval(start: at(10), duration: 0).duration == 0)
        #expect(PauseInterval(start: at(10), duration: 7.5).end == at(17.5))
    }

    // MARK: Equality

    @Test func sessionsWithDifferentOpenPauseBaselinesAreNotEqual() throws {
        let first = try Fixture.running()
        let second = try Fixture.running()
        var firstSession = first.session
        var secondSession = second.session
        #expect(firstSession == secondSession)
        try firstSession.handle(.pause)
        // The same wall date, but ten seconds more uptime.
        second.clock.advance(by: 10, wallClockRolledBackBy: 10)
        try secondSession.handle(.pause)
        #expect(firstSession.pauses == secondSession.pauses)
        #expect(firstSession != secondSession)
        #expect(firstSession == firstSession)
    }
}
