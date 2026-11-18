import Foundation

@testable import FarsangCore

let epoch = Date(timeIntervalSinceReferenceDate: 800_000_000)

func at(_ seconds: TimeInterval) -> Date {
    epoch.addingTimeInterval(seconds)
}

/// Meters per degree of latitude on the sphere the haversine formula uses.
private let metersPerDegree = 6_371_000.0 * .pi / 180

/// A point `meters` due north of the origin.
func northOf(meters: Double, offsetLongitude: Double = 0) -> Coordinate {
    Coordinate(latitude: 47 + meters / metersPerDegree, longitude: 8 + offsetLongitude)
}

func location(at seconds: TimeInterval, meters: Double, accuracy: Double = 5) -> LocationSample {
    LocationSample(timestamp: at(seconds), coordinate: northOf(meters: meters), horizontalAccuracy: accuracy)
}

func heartRate(at seconds: TimeInterval, _ bpm: Double) -> HeartRateSample {
    HeartRateSample(timestamp: at(seconds), beatsPerMinute: bpm)
}

func makeTracker(maxHeartRate: Double = 200) -> RunTracker {
    RunTracker(configuration: .init(heartRateZones: HeartRateZones(maxHeartRate: maxHeartRate)))
}

/// A recorded run: one fix per second, moving at a constant speed in meters per second.
func recordedFixes(from startSecond: Int, to endSecond: Int, startMeters: Double, speed: Double) -> [LocationSample] {
    (startSecond...endSecond).map { second in
        location(at: Double(second), meters: startMeters + Double(second - startSecond) * speed)
    }
}

func feed(_ samples: [LocationSample], into tracker: inout RunTracker) {
    for sample in samples { tracker.add(sample) }
}
