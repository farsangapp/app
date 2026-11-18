import Foundation
import Testing

@testable import FarsangCore

struct RunTrackerPaceTests {
    @Test func rollingPaceSlowsWhileStandingStill() throws {
        var tracker = makeTracker()
        tracker.start(at: at(0))
        feed(recordedFixes(from: 0, to: 252, startMeters: 0, speed: 4), into: &tracker)
        for second in 253...300 {
            tracker.add(location(at: Double(second), meters: 1_008))
        }

        // The last 1000 m began at 8 m, reached at 2 s, so 298 s ago.
        let pace = try #require(tracker.snapshot(at: at(300)).rollingPace)
        #expect(abs(pace.secondsPerKilometer - 298) < 0.5)
    }

    @Test func standingStillDoesNotGrowTheTrail() {
        var tracker = makeTracker()
        tracker.start(at: at(0))
        tracker.add(location(at: 0, meters: 0))
        for second in 1...3_600 {
            tracker.add(location(at: Double(second), meters: 0))
        }
        #expect(tracker.trailPointCount <= 2)
    }

    @Test func steadyRunReportsDistanceAveragePaceAndRollingPace() throws {
        var tracker = makeTracker()
        tracker.start(at: at(0))
        feed(recordedFixes(from: 0, to: 600, startMeters: 0, speed: 1_000.0 / 300), into: &tracker)

        let snapshot = tracker.snapshot(at: at(600))
        #expect(snapshot.state == .running)
        #expect(snapshot.elapsedTime == 600)
        #expect(abs(snapshot.distance.meters - 2_000) < 1)
        #expect(abs(try #require(snapshot.averagePace).secondsPerKilometer - 300) < 0.5)
        #expect(abs(try #require(snapshot.rollingPace).secondsPerKilometer - 300) < 0.5)
    }

    @Test func rollingPaceReflectsOnlyTheLastKilometer() throws {
        var tracker = makeTracker()
        tracker.start(at: at(0))
        let slow = 1_000.0 / 300
        let fast = 1_000.0 / 240
        feed(recordedFixes(from: 0, to: 300, startMeters: 0, speed: slow), into: &tracker)
        feed(recordedFixes(from: 301, to: 540, startMeters: 1_000 + fast, speed: fast), into: &tracker)

        let snapshot = tracker.snapshot(at: at(540))
        #expect(abs(snapshot.distance.meters - 2_000) < 1)
        #expect(abs(try #require(snapshot.averagePace).secondsPerKilometer - 270) < 0.5)
        #expect(abs(try #require(snapshot.rollingPace).secondsPerKilometer - 240) < 0.5)
    }

    @Test func rollingPaceInterpolatesBetweenFixes() throws {
        var configuration = RunTracker.Configuration(heartRateZones: HeartRateZones(maxHeartRate: 200))
        configuration.rollingDistance = Distance(meters: 100)
        var tracker = RunTracker(configuration: configuration)
        tracker.start(at: at(0))
        tracker.add(location(at: 0, meters: 0))
        tracker.add(location(at: 10, meters: 40))
        tracker.add(location(at: 20, meters: 120))
        tracker.add(location(at: 30, meters: 150))

        // The last 100 m start at 50 m, an eighth of the way from the 40 m fix to the 120 m fix (11.25 s).
        let pace = try #require(tracker.snapshot(at: at(30)).rollingPace)
        #expect(abs(pace.secondsPerKilometer - 187.5) < 0.01)
    }

    @Test func rollingPaceIsNilBeforeAFullKilometer() {
        var tracker = makeTracker()
        tracker.start(at: at(0))
        feed(recordedFixes(from: 0, to: 100, startMeters: 0, speed: 3), into: &tracker)

        let snapshot = tracker.snapshot(at: at(100))
        #expect(snapshot.rollingPace == nil)
        #expect(snapshot.averagePace != nil)
    }

    @Test func rollingDistanceIsConfigurable() throws {
        var configuration = RunTracker.Configuration(heartRateZones: HeartRateZones(maxHeartRate: 200))
        configuration.rollingDistance = Distance(meters: 400)
        var tracker = RunTracker(configuration: configuration)
        tracker.start(at: at(0))
        feed(recordedFixes(from: 0, to: 200, startMeters: 0, speed: 4), into: &tracker)

        let pace = try #require(tracker.snapshot(at: at(200)).rollingPace)
        #expect(abs(pace.secondsPerKilometer - 250) < 0.5)
    }

    @Test func elapsedTimeAdvancesWithoutSamples() {
        var tracker = makeTracker()
        tracker.start(at: at(0))
        #expect(tracker.snapshot(at: at(42)).elapsedTime == 42)
    }

    @Test func averagePaceIsNilBeforeAnyDistance() {
        var tracker = makeTracker()
        tracker.start(at: at(0))
        tracker.add(location(at: 1, meters: 0))

        let snapshot = tracker.snapshot(at: at(30))
        #expect(snapshot.distance == .zero)
        #expect(snapshot.averagePace == nil)
    }
}

struct RunTrackerPauseTests {
    @Test func pausedTimeIsExcludedFromElapsedTime() {
        var tracker = makeTracker()
        tracker.start(at: at(0))
        feed(recordedFixes(from: 0, to: 100, startMeters: 0, speed: 3), into: &tracker)
        tracker.pause(at: at(100))

        #expect(tracker.snapshot(at: at(100)).elapsedTime == 100)
        #expect(tracker.snapshot(at: at(150)).elapsedTime == 100)
        #expect(tracker.snapshot(at: at(150)).state == .paused)

        tracker.resume(at: at(200))
        feed(recordedFixes(from: 200, to: 300, startMeters: 300, speed: 3), into: &tracker)
        #expect(tracker.snapshot(at: at(300)).elapsedTime == 200)
    }

    @Test func distanceMovedWhilePausedIsNotCounted() throws {
        var tracker = makeTracker()
        tracker.start(at: at(0))
        feed(recordedFixes(from: 0, to: 100, startMeters: 0, speed: 3), into: &tracker)
        tracker.pause(at: at(100))
        tracker.add(location(at: 110, meters: 400))
        tracker.add(location(at: 120, meters: 800))
        tracker.resume(at: at(200))
        // Resumed 5 km away, and one stale fix from before the resume arrives late.
        tracker.add(location(at: 199, meters: 5_000))
        feed(recordedFixes(from: 200, to: 300, startMeters: 5_000, speed: 3), into: &tracker)

        let snapshot = tracker.snapshot(at: at(300))
        #expect(abs(snapshot.distance.meters - 600) < 1)
        #expect(snapshot.elapsedTime == 200)
        #expect(abs(try #require(snapshot.averagePace).secondsPerKilometer - 200 / 0.6) < 1)
    }

    @Test func rollingPaceSkipsPausedTime() throws {
        var tracker = makeTracker()
        tracker.start(at: at(0))
        feed(recordedFixes(from: 0, to: 100, startMeters: 0, speed: 5), into: &tracker)
        tracker.pause(at: at(100))
        tracker.resume(at: at(160))
        feed(recordedFixes(from: 160, to: 262, startMeters: 500, speed: 5), into: &tracker)

        let snapshot = tracker.snapshot(at: at(262))
        #expect(abs(snapshot.distance.meters - 1_010) < 1)
        #expect(snapshot.elapsedTime == 202)
        #expect(abs(try #require(snapshot.rollingPace).secondsPerKilometer - 200) < 0.5)
    }

    @Test func pauseAndResumeAreIgnoredInTheWrongState() {
        var tracker = makeTracker()
        tracker.pause(at: at(5))
        tracker.resume(at: at(6))
        #expect(tracker.state == .notStarted)

        tracker.start(at: at(10))
        tracker.resume(at: at(20))
        tracker.pause(at: at(30))
        tracker.pause(at: at(40))
        #expect(tracker.snapshot(at: at(50)).elapsedTime == 20)
    }
}

struct RunTrackerNoiseTests {
    @Test func poorAccuracyAndJumpsDoNotAddDistance() {
        var tracker = makeTracker()
        tracker.start(at: at(0))
        tracker.add(location(at: 0, meters: 0))
        tracker.add(location(at: 1, meters: 3))
        tracker.add(location(at: 2, meters: 40, accuracy: 65))
        tracker.add(location(at: 3, meters: 9))
        tracker.add(location(at: 4, meters: 400))
        tracker.add(location(at: 5, meters: 15))

        #expect(abs(tracker.snapshot(at: at(5)).distance.meters - 15) < 0.1)
    }

    @Test func staysUsableAfterGenuineRelocation() {
        var tracker = makeTracker()
        tracker.start(at: at(0))
        tracker.add(location(at: 0, meters: 0))
        for second in 1...10 {
            tracker.add(location(at: Double(second), meters: 1_000 + Double(second)))
        }
        // The first four far fixes are rejected, the fifth resyncs, the rest count from there.
        #expect(abs(tracker.snapshot(at: at(10)).distance.meters - 5) < 0.1)
    }
}

struct RunTrackerLifecycleTests {
    @Test func endingTheRunClosesTheLastSegment() throws {
        var tracker = makeTracker()
        tracker.start(at: at(0))
        feed(recordedFixes(from: 0, to: 100, startMeters: 0, speed: 4), into: &tracker)
        tracker.markSegment(at: at(40))
        tracker.end(at: at(100))

        let snapshot = tracker.snapshot(at: at(100))
        #expect(snapshot.completedSegments.map(\.index) == [1, 2])
        #expect(snapshot.completedSegments.last?.duration == 60)
        #expect(snapshot.currentSegment == nil)
    }

    @Test func ignoresSamplesBeforeStartAndAfterEnd() {
        var tracker = makeTracker()
        tracker.add(location(at: 0, meters: 0))
        tracker.add(heartRate(at: 0, 150))
        tracker.start(at: at(1))
        tracker.add(location(at: 1, meters: 0))
        tracker.add(location(at: 2, meters: 3))
        tracker.end(at: at(3))
        tracker.add(location(at: 4, meters: 6))
        tracker.add(heartRate(at: 4, 150))

        let snapshot = tracker.snapshot(at: at(100))
        #expect(snapshot.state == .ended)
        #expect(snapshot.elapsedTime == 2)
        #expect(abs(snapshot.distance.meters - 3) < 0.1)
        #expect(snapshot.currentHeartRate == nil)
    }

    @Test func startingTwiceKeepsTheFirstStart() {
        var tracker = makeTracker()
        tracker.start(at: at(0))
        tracker.start(at: at(50))
        #expect(tracker.snapshot(at: at(60)).elapsedTime == 60)
    }

    @Test func notStartedSnapshotIsEmpty() {
        let snapshot = makeTracker().snapshot(at: at(10))
        #expect(snapshot.state == .notStarted)
        #expect(snapshot.elapsedTime == 0)
        #expect(snapshot.distance == .zero)
        #expect(snapshot.currentSegment == nil)
        #expect(snapshot.completedSegments.isEmpty)
    }

    @Test func endingWhilePausedKeepsPausedTimeOut() {
        var tracker = makeTracker()
        tracker.start(at: at(0))
        tracker.pause(at: at(30))
        tracker.end(at: at(90))
        #expect(tracker.snapshot(at: at(200)).elapsedTime == 30)
    }
}
