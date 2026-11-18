import Foundation
import Synchronization
import Testing

@testable import FarsangCore

struct WorkoutSessionTests {
    private let allEvents: [WorkoutSessionEvent] = [.start, .pause, .resume, .markSegment, .end]

    // MARK: Valid transitions

    @Test func newSessionIsIdleWithNothingRecorded() {
        let fixture = Fixture()
        #expect(fixture.session.state == .idle)
        #expect(fixture.session.startedAt == nil)
        #expect(fixture.session.endedAt == nil)
        #expect(fixture.session.segments.isEmpty)
        #expect(fixture.session.segmentCount == 0)
        #expect(fixture.session.pauses.isEmpty)
        #expect(fixture.session.movingTime == 0)
        #expect(fixture.session.elapsedTime == 0)
    }

    @Test func startMovesIdleToRunningAndRecordsStartTime() throws {
        var fixture = Fixture()
        fixture.clock.advance(by: 5)
        let notification = try fixture.session.handle(.start)
        #expect(fixture.session.state == .running)
        #expect(fixture.session.startedAt == at(5))
        #expect(notification == .started(timestamp: at(5)))
    }

    @Test func pauseMovesRunningToPausedAndOpensAPause() throws {
        var fixture = try Fixture.running()
        fixture.clock.advance(by: 30)
        let notification = try fixture.session.handle(.pause)
        #expect(fixture.session.state == .paused)
        #expect(fixture.session.pauses == [PauseInterval(start: at(30))])
        #expect(notification == .paused(timestamp: at(30)))
    }

    @Test func resumeMovesPausedToRunningAndClosesThePause() throws {
        var fixture = try Fixture.paused()
        fixture.clock.advance(by: 20)
        let notification = try fixture.session.handle(.resume)
        #expect(fixture.session.state == .running)
        #expect(fixture.session.pauses == [PauseInterval(start: at(10), duration: 20)])
        #expect(notification == .resumed(timestamp: at(30)))
    }

    @Test func markSegmentWhileRunningKeepsRunningAndNumbersFromOne() throws {
        var fixture = try Fixture.running()
        fixture.clock.advance(by: 60)
        let first = try fixture.session.handle(.markSegment)
        fixture.clock.advance(by: 60)
        let second = try fixture.session.handle(.markSegment)
        #expect(fixture.session.state == .running)
        #expect(first == .segmentMarked(number: 1, timestamp: at(60)))
        #expect(second == .segmentMarked(number: 2, timestamp: at(120)))
        #expect(fixture.session.segmentCount == 2)
        #expect(
            fixture.session.segments == [Segment(number: 1, markedAt: at(60)), Segment(number: 2, markedAt: at(120))])
    }

    @Test func endWhileRunningMovesToEndedAndRecordsEndTime() throws {
        var fixture = try Fixture.running()
        fixture.clock.advance(by: 90)
        let notification = try fixture.session.handle(.end)
        #expect(fixture.session.state == .ended)
        #expect(fixture.session.endedAt == at(90))
        #expect(notification == .ended(timestamp: at(90)))
    }

    @Test func endWhilePausedClosesTheOpenPauseAtTheEndTime() throws {
        var fixture = try Fixture.paused()
        fixture.clock.advance(by: 15)
        let notification = try fixture.session.handle(.end)
        #expect(fixture.session.state == .ended)
        #expect(fixture.session.endedAt == at(25))
        #expect(fixture.session.pauses == [PauseInterval(start: at(10), duration: 15)])
        #expect(notification == .ended(timestamp: at(25)))
    }

    @Test func canPauseAndResumeRepeatedly() throws {
        var fixture = try Fixture.running()
        for _ in 0..<3 {
            fixture.clock.advance(by: 10)
            try fixture.session.handle(.pause)
            fixture.clock.advance(by: 5)
            try fixture.session.handle(.resume)
        }
        #expect(fixture.session.state == .running)
        #expect(fixture.session.pauses.count == 3)
        #expect(fixture.session.pauses.allSatisfy { $0.duration != nil })
    }

    @Test func segmentsKeepTheirNumbersAcrossPauses() throws {
        var fixture = try Fixture.running()
        try fixture.session.handle(.markSegment)
        fixture.clock.advance(by: 10)
        try fixture.session.handle(.pause)
        fixture.clock.advance(by: 10)
        try fixture.session.handle(.resume)
        let notification = try fixture.session.handle(.markSegment)
        #expect(notification == .segmentMarked(number: 2, timestamp: at(20)))
    }

    // MARK: Invalid transitions

    private func expectRejected(
        _ events: [WorkoutSessionEvent],
        from makeFixture: () throws -> Fixture,
        in state: WorkoutSessionState
    ) throws {
        for event in events {
            var fixture = try makeFixture()
            fixture.clock.advance(by: 1)
            let before = fixture.session
            #expect(throws: WorkoutSessionError.invalidTransition(from: state, event: event)) {
                try fixture.session.handle(event)
            }
            #expect(fixture.session == before, "a rejected \(event) must leave the \(state) session untouched")
        }
    }

    @Test func idleRejectsEverythingButStart() throws {
        try expectRejected([.pause, .resume, .markSegment, .end], from: { Fixture() }, in: .idle)
    }

    @Test func runningRejectsStartAndResume() throws {
        try expectRejected([.start, .resume], from: Fixture.running, in: .running)
    }

    @Test func pausedRejectsStartPauseAndMarkSegment() throws {
        try expectRejected([.start, .pause, .markSegment], from: Fixture.paused, in: .paused)
    }

    @Test func endedRejectsEveryEvent() throws {
        try expectRejected(allEvents, from: Fixture.ended, in: .ended)
    }

    // MARK: Timestamps for the metrics calculator

    @Test func movingTimeExcludesPausedTime() throws {
        var fixture = try Fixture.running()
        fixture.clock.advance(by: 100)
        try fixture.session.handle(.pause)
        fixture.clock.advance(by: 40)
        try fixture.session.handle(.resume)
        fixture.clock.advance(by: 50)
        #expect(fixture.session.movingTime == 150)
        #expect(fixture.session.elapsedTime == 190)
    }

    @Test func movingTimeHoldsStillWhilePaused() throws {
        var fixture = try Fixture.running()
        fixture.clock.advance(by: 100)
        try fixture.session.handle(.pause)
        fixture.clock.advance(by: 500)
        #expect(fixture.session.movingTime == 100)
        #expect(fixture.session.elapsedTime == 600)
    }

    @Test func timesFreezeOnceEnded() throws {
        var fixture = try Fixture.running()
        fixture.clock.advance(by: 100)
        try fixture.session.handle(.pause)
        fixture.clock.advance(by: 20)
        try fixture.session.handle(.end)
        fixture.clock.advance(by: 1_000)
        #expect(fixture.session.movingTime == 100)
        #expect(fixture.session.elapsedTime == 120)
    }

    @Test func timesAtAnExplicitInstant() throws {
        var fixture = try Fixture.running()
        fixture.clock.advance(by: 100)
        try fixture.session.handle(.pause)
        fixture.clock.advance(by: 50)
        try fixture.session.handle(.resume)
        fixture.clock.advance(by: 100)
        #expect(fixture.session.movingTime(at: at(120)) == 100)
        #expect(fixture.session.movingTime(at: at(125)) == 100)
        #expect(fixture.session.movingTime(at: at(160)) == 110)
        #expect(fixture.session.elapsedTime(at: at(160)) == 160)
    }

    @Test func timesAreZeroBeforeStartAndNeverNegative() throws {
        var fixture = Fixture()
        #expect(fixture.session.movingTime(at: at(100)) == 0)
        fixture.clock.advance(by: 50)
        try fixture.session.handle(.start)
        #expect(fixture.session.movingTime(at: at(0)) == 0)
        #expect(fixture.session.elapsedTime(at: at(0)) == 0)
    }

    @Test func timesAtAnInstantBeforeTheEndIgnoreWhatHappenedAfter() throws {
        var fixture = try Fixture.running()
        fixture.clock.advance(by: 100)
        try fixture.session.handle(.pause)
        fixture.clock.advance(by: 50)
        try fixture.session.handle(.end)
        #expect(fixture.session.movingTime(at: at(60)) == 60)
        #expect(fixture.session.elapsedTime(at: at(60)) == 60)
        #expect(fixture.session.movingTime(at: at(500)) == 100)
    }

    @Test func pauseAndResumeAtTheSameInstantRecordAnEmptyPause() throws {
        var fixture = try Fixture.running()
        try fixture.session.handle(.pause)
        try fixture.session.handle(.resume)
        #expect(fixture.session.pauses == [PauseInterval(start: at(0), duration: 0)])
        #expect(fixture.session.movingTime(at: at(10)) == 10)
    }

    @Test func canHandleAgreesWithHandle() throws {
        let makers: [() throws -> Fixture] = [{ Fixture() }, Fixture.running, Fixture.paused, Fixture.ended]
        for make in makers {
            for event in allEvents {
                var fixture = try make()
                let predicted = fixture.session.canHandle(event)
                let accepted = (try? fixture.session.handle(event)) != nil
                #expect(predicted == accepted, "canHandle(\(event)) in \(fixture.session.state)")
            }
        }
    }

    @Test func clockIsOnlyReadWhenAnEventIsAccepted() {
        let clock = CountingClock()
        var session = WorkoutSession(clock: clock)
        _ = try? session.handle(.pause)
        #expect(clock.reads == 0)
        _ = try? session.handle(.resume)
        #expect(clock.reads == 0)
        _ = try? session.handle(.start)
        #expect(clock.reads > 0)
    }
}

private final class CountingClock: WorkoutClock {
    private let count = Mutex(0)
    var reads: Int { count.withLock { $0 } }

    func now() -> Date {
        count.withLock { $0 += 1 }
        return Date(timeIntervalSince1970: 0)
    }

    func uptime() -> TimeInterval {
        count.withLock { $0 += 1 }
        return 0
    }
}
