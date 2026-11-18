import Foundation
import Testing

@testable import FarsangCore

/// Rolling pace reads trail points stamped with when each fix was captured, not with the lifecycle clock.
struct RunTrackerTrailTests {
    @Test func rollingPaceUsesFixCaptureTimeNotTheLifecycleClock() throws {
        var configuration = RunTracker.Configuration(heartRateZones: HeartRateZones(maxHeartRate: 200))
        configuration.rollingDistance = Distance(meters: 100)
        var tracker = RunTracker(configuration: configuration)
        tracker.start(at: at(0))
        tracker.markSegment(at: at(30))
        // Fixes delivered late: captured before the mark, so they keep their own times.
        tracker.add(location(at: 5, meters: 0))
        tracker.add(location(at: 15, meters: 80))
        tracker.add(location(at: 25, meters: 160))

        // The last 100 m start at 60 m, three quarters of the way from the 0 m fix to the 80 m fix (12.5 s).
        let pace = try #require(tracker.snapshot(at: at(30)).rollingPace)
        #expect(abs(pace.secondsPerKilometer - 175) < 0.01)
    }

    @Test func fixCapturedAfterTheClockIsBoundedToTheSnapshotTime() throws {
        var configuration = RunTracker.Configuration(heartRateZones: HeartRateZones(maxHeartRate: 200))
        configuration.rollingDistance = Distance(meters: 100)
        var tracker = RunTracker(configuration: configuration)
        tracker.start(at: at(0))
        tracker.add(location(at: 10, meters: 0))
        tracker.add(location(at: 50, meters: 200))

        // The window starts at 100 m, reached at 30 s, which is after the snapshot's 20 s. The span is bounded to
        // zero, which has no pace, rather than going negative.
        let early = tracker.snapshot(at: at(20))
        #expect(early.elapsedTime == 20)
        #expect(early.rollingPace == nil)
        let later = try #require(tracker.snapshot(at: at(60)).rollingPace)
        #expect(abs(later.secondsPerKilometer - 300) < 0.01)
    }

    @Test func trailTimesStayNonDecreasingAcrossAPauseAfterAFutureCapture() throws {
        var configuration = RunTracker.Configuration(heartRateZones: HeartRateZones(maxHeartRate: 200))
        configuration.rollingDistance = Distance(meters: 100)
        var tracker = RunTracker(configuration: configuration)
        tracker.start(at: at(0))
        tracker.add(location(at: 0, meters: 0))
        tracker.add(location(at: 50, meters: 80))
        tracker.pause(at: at(40))
        tracker.resume(at: at(41))
        tracker.add(location(at: 45, meters: 80))
        tracker.add(location(at: 55, meters: 160))

        let pace = try #require(tracker.snapshot(at: at(70)).rollingPace)
        #expect(pace.secondsPerKilometer > 0)
    }
}
