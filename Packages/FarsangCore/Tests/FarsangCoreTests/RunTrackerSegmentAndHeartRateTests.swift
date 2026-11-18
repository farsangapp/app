import Foundation
import Testing

@testable import FarsangCore

struct RunTrackerSegmentTests {
    @Test func segmentsReportPaceDistanceAndHeartRate() throws {
        var tracker = makeTracker()
        tracker.start(at: at(0))
        feed(recordedFixes(from: 0, to: 100, startMeters: 0, speed: 4), into: &tracker)
        tracker.add(heartRate(at: 10, 140))
        tracker.add(heartRate(at: 60, 160))
        tracker.markSegment(at: at(100))
        feed(recordedFixes(from: 101, to: 250, startMeters: 404, speed: 4), into: &tracker)
        tracker.add(heartRate(at: 150, 180))
        tracker.markSegment(at: at(250))

        let snapshot = tracker.snapshot(at: at(250))
        let first = try #require(snapshot.completedSegments.first)
        #expect(first.index == 1)
        #expect(first.duration == 100)
        #expect(abs(first.distance.meters - 400) < 1)
        #expect(abs(try #require(first.averagePace).secondsPerKilometer - 250) < 1)
        #expect(first.averageHeartRate == 150)

        let second = try #require(snapshot.completedSegments.last)
        #expect(snapshot.completedSegments.count == 2)
        #expect(second.index == 2)
        #expect(second.duration == 150)
        #expect(abs(second.distance.meters - 600) < 1)
        #expect(second.averageHeartRate == 180)

        let current = try #require(snapshot.currentSegment)
        #expect(current.index == 3)
        #expect(current.duration == 0)
        #expect(current.averagePace == nil)
        #expect(current.averageHeartRate == nil)
    }

    @Test func currentSegmentCoversTheRunUntilFirstMark() throws {
        var tracker = makeTracker()
        tracker.start(at: at(0))
        feed(recordedFixes(from: 0, to: 100, startMeters: 0, speed: 4), into: &tracker)

        let current = try #require(tracker.snapshot(at: at(100)).currentSegment)
        #expect(current.index == 1)
        #expect(current.duration == 100)
        #expect(abs(current.distance.meters - 400) < 1)
    }

    @Test func segmentDurationExcludesPausedTime() throws {
        var tracker = makeTracker()
        tracker.start(at: at(0))
        feed(recordedFixes(from: 0, to: 50, startMeters: 0, speed: 4), into: &tracker)
        tracker.pause(at: at(50))
        tracker.resume(at: at(150))
        feed(recordedFixes(from: 150, to: 200, startMeters: 200, speed: 4), into: &tracker)
        tracker.markSegment(at: at(200))

        let segment = try #require(tracker.snapshot(at: at(200)).completedSegments.first)
        #expect(segment.duration == 100)
        #expect(abs(segment.distance.meters - 400) < 1)
    }

    @Test func markingTwiceAtTheSameInstantMakesOneSegment() {
        var tracker = makeTracker()
        tracker.start(at: at(0))
        tracker.markSegment(at: at(0))
        tracker.add(location(at: 10, meters: 0))
        tracker.markSegment(at: at(30))
        tracker.markSegment(at: at(30))
        #expect(tracker.snapshot(at: at(30)).completedSegments.count == 1)
    }
}

struct RunTrackerHeartRateTests {
    @Test func staleReadingStopsShowingAsCurrent() {
        var tracker = makeTracker()
        tracker.start(at: at(0))
        tracker.add(heartRate(at: 0, 150))
        #expect(tracker.snapshot(at: at(10)).currentHeartRate == 150)
        #expect(tracker.snapshot(at: at(11)).currentHeartRate == nil)
        #expect(tracker.snapshot(at: at(11)).currentZone == nil)
    }

    @Test func readingIsNotCurrentBeforeItsOwnTimestamp() {
        var tracker = makeTracker()
        tracker.start(at: at(0))
        tracker.add(heartRate(at: 20, 150))
        #expect(tracker.snapshot(at: at(19)).currentHeartRate == nil)
        #expect(tracker.snapshot(at: at(19)).currentZone == nil)
        #expect(tracker.snapshot(at: at(20)).currentHeartRate == 150)
    }

    @Test func negativeStaleLimitNeverCreditsNegativeZoneTime() {
        var tracker = RunTracker(
            configuration: .init(heartRateZones: HeartRateZones(maxHeartRate: 200), heartRateStaleAfter: -1)
        )
        tracker.start(at: at(0))
        tracker.add(heartRate(at: 0, 150))
        tracker.add(heartRate(at: 5, 130))
        let snapshot = tracker.snapshot(at: at(8))
        #expect(snapshot.timeInZone.values.allSatisfy { $0 >= 0 })
        #expect(snapshot.timeInZone.values.reduce(0, +) == 0)
    }

    @Test func historicalSnapshotOnlyReportsZoneTimeUpToItsDate() {
        var tracker = makeTracker(maxHeartRate: 200)
        tracker.start(at: at(0))
        tracker.add(heartRate(at: 0, 130))
        tracker.add(heartRate(at: 8, 170))

        #expect(tracker.snapshot(at: at(4)).timeInZone[.two] == 4)
        #expect(tracker.snapshot(at: at(4)).timeInZone[.four] == nil)
        #expect(tracker.snapshot(at: at(8)).timeInZone[.two] == 8)
        #expect(tracker.snapshot(at: at(10)).timeInZone[.four] == 2)
        #expect(tracker.snapshot(at: at(-3)).timeInZone[.two] == nil)
    }

    @Test func olderReadingDoesNotReplaceANewerOne() {
        var tracker = makeTracker()
        tracker.start(at: at(0))
        tracker.add(heartRate(at: 5, 150))
        tracker.pause(at: at(6))
        tracker.add(heartRate(at: 4, 120))
        #expect(tracker.snapshot(at: at(6)).currentHeartRate == 150)
    }

    @Test func tracksCurrentZoneTimeInZoneAndAverage() throws {
        var tracker = makeTracker(maxHeartRate: 200)
        tracker.start(at: at(0))
        tracker.add(heartRate(at: 0, 130))
        tracker.add(heartRate(at: 8, 170))
        tracker.add(heartRate(at: 16, 190))

        let snapshot = tracker.snapshot(at: at(20))
        #expect(snapshot.currentHeartRate == 190)
        #expect(snapshot.currentZone == .five)
        #expect(snapshot.timeInZone[.two] == 8)
        #expect(snapshot.timeInZone[.four] == 8)
        #expect(snapshot.timeInZone[.five] == 4)
        #expect(snapshot.timeInZone[.one] == nil)
        #expect(abs(try #require(snapshot.averageHeartRate) - 490.0 / 3) < 1e-9)
    }

    @Test func maxHeartRateComesFromConfiguration() {
        var lowMax = makeTracker(maxHeartRate: 160)
        lowMax.start(at: at(0))
        lowMax.add(heartRate(at: 0, 150))
        #expect(lowMax.snapshot(at: at(1)).currentZone == .five)

        var highMax = makeTracker(maxHeartRate: 200)
        highMax.start(at: at(0))
        highMax.add(heartRate(at: 0, 150))
        #expect(highMax.snapshot(at: at(1)).currentZone == .three)
    }

    @Test func belowZoneOneCountsTowardAverageButNotZones() {
        var tracker = makeTracker(maxHeartRate: 200)
        tracker.start(at: at(0))
        tracker.add(heartRate(at: 0, 90))
        tracker.add(heartRate(at: 10, 110))

        let snapshot = tracker.snapshot(at: at(15))
        #expect(snapshot.timeInZone.count == 1)
        #expect(snapshot.timeInZone[.one] == 5)
        #expect(snapshot.averageHeartRate == 100)
    }

    @Test func staleReadingStopsEarningZoneTime() {
        var tracker = makeTracker(maxHeartRate: 200)
        tracker.start(at: at(0))
        tracker.add(heartRate(at: 0, 150))
        #expect(tracker.snapshot(at: at(100)).timeInZone[.three] == 10)
    }

    @Test func zoneTimeStopsWhilePausedAndReadingsAreNotCounted() {
        var tracker = makeTracker(maxHeartRate: 200)
        tracker.start(at: at(0))
        tracker.add(heartRate(at: 0, 130))
        tracker.pause(at: at(5))
        tracker.add(heartRate(at: 30, 190))

        let paused = tracker.snapshot(at: at(40))
        #expect(paused.currentHeartRate == 190)
        #expect(paused.timeInZone[.two] == 5)
        #expect(paused.timeInZone[.five] == nil)
        #expect(paused.averageHeartRate == 130)

        tracker.resume(at: at(50))
        #expect(tracker.snapshot(at: at(55)).timeInZone[.two] == 5)
        tracker.add(heartRate(at: 56, 150))
        let resumed = tracker.snapshot(at: at(60))
        #expect(resumed.timeInZone[.three] == 4)
        #expect(resumed.timeInZone[.two] == 5)
    }

    @Test func resumeBeforeThePauseDateDoesNotOverlapZoneCredit() {
        var tracker = makeTracker(maxHeartRate: 200)
        tracker.start(at: at(0))
        tracker.add(heartRate(at: 0, 130))
        tracker.pause(at: at(20))
        tracker.resume(at: at(5))
        tracker.add(heartRate(at: 5, 130))
        tracker.add(heartRate(at: 8, 130))
        #expect(tracker.snapshot(at: at(8)).timeInZone[.two] == 8)
    }

    @Test func ignoresDroppedSensorReadings() {
        var tracker = makeTracker()
        tracker.start(at: at(0))
        tracker.add(heartRate(at: 0, 150))
        tracker.add(heartRate(at: 5, 0))
        tracker.add(heartRate(at: 6, .nan))

        let snapshot = tracker.snapshot(at: at(7))
        #expect(snapshot.currentHeartRate == 150)
        #expect(snapshot.averageHeartRate == 150)
    }

    @Test func ignoresHeartRateCapturedBeforeTheRunningPeriod() {
        var tracker = makeTracker()
        tracker.start(at: at(10))
        tracker.add(heartRate(at: 5, 150))
        #expect(tracker.snapshot(at: at(12)).currentHeartRate == nil)
    }

    @Test func noHeartRateMeansNoHeartRateStats() {
        var tracker = makeTracker()
        tracker.start(at: at(0))
        let snapshot = tracker.snapshot(at: at(10))
        #expect(snapshot.currentHeartRate == nil)
        #expect(snapshot.currentZone == nil)
        #expect(snapshot.averageHeartRate == nil)
        #expect(snapshot.timeInZone.isEmpty)
    }
}
