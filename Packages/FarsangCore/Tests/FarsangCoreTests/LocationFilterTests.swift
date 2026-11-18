import Testing

@testable import FarsangCore

struct LocationFilterTests {
    @Test func firstGoodFixAnchorsWithoutDistance() {
        var filter = LocationFilter()
        #expect(filter.process(location(at: 0, meters: 0)) == .anchored)
    }

    @Test func acceptedFixReportsDistanceFromTheLastAcceptedFix() throws {
        var filter = LocationFilter()
        _ = filter.process(location(at: 0, meters: 0))
        guard case .accepted(let moved) = filter.process(location(at: 1, meters: 3)) else {
            Issue.record("expected an accepted fix")
            return
        }
        #expect(abs(moved.meters - 3) < 0.01)
    }

    @Test(arguments: [31.0, 100.0, -1.0])
    func rejectsPoorOrInvalidAccuracy(accuracy: Double) {
        var filter = LocationFilter()
        #expect(filter.process(location(at: 0, meters: 0, accuracy: accuracy)) == .rejected(.poorAccuracy))
    }

    @Test func acceptsAccuracyAtTheLimit() {
        var filter = LocationFilter()
        #expect(filter.process(location(at: 0, meters: 0, accuracy: 30)) == .anchored)
    }

    @Test func poorFixDoesNotMoveTheAnchor() throws {
        var filter = LocationFilter()
        _ = filter.process(location(at: 0, meters: 0))
        #expect(filter.process(location(at: 1, meters: 500, accuracy: 80)) == .rejected(.poorAccuracy))
        guard case .accepted(let moved) = filter.process(location(at: 2, meters: 6)) else {
            Issue.record("expected an accepted fix")
            return
        }
        #expect(abs(moved.meters - 6) < 0.01)
    }

    @Test func rejectsSuddenJump() {
        var filter = LocationFilter()
        _ = filter.process(location(at: 0, meters: 0))
        #expect(filter.process(location(at: 1, meters: 200)) == .rejected(.jump))
    }

    @Test func acceptsFastButPlausibleSpeed() {
        var filter = LocationFilter()
        _ = filter.process(location(at: 0, meters: 0))
        guard case .accepted = filter.process(location(at: 1, meters: 8)) else {
            Issue.record("expected an accepted fix")
            return
        }
    }

    @Test func largeMoveOverLongGapIsNotAJump() {
        var filter = LocationFilter()
        _ = filter.process(location(at: 0, meters: 0))
        guard case .accepted = filter.process(location(at: 60, meters: 200)) else {
            Issue.record("expected an accepted fix")
            return
        }
    }

    @Test func rejectsFixesThatAreNotNewer() {
        var filter = LocationFilter()
        _ = filter.process(location(at: 5, meters: 0))
        #expect(filter.process(location(at: 5, meters: 1)) == .rejected(.outOfOrder))
        #expect(filter.process(location(at: 4, meters: 1)) == .rejected(.outOfOrder))
    }

    @Test func resyncsAfterRepeatedJumps() {
        var filter = LocationFilter()
        _ = filter.process(location(at: 0, meters: 0))
        for second in 1...4 {
            #expect(filter.process(location(at: Double(second), meters: 5_000)) == .rejected(.jump))
        }
        #expect(filter.process(location(at: 5, meters: 5_000)) == .anchored)
        guard case .accepted = filter.process(location(at: 6, meters: 5_003)) else {
            Issue.record("expected an accepted fix")
            return
        }
    }

    @Test func goodFixBreaksTheJumpStreak() {
        var filter = LocationFilter()
        _ = filter.process(location(at: 0, meters: 0))
        for second in 1...4 {
            _ = filter.process(location(at: Double(second), meters: 5_000))
        }
        _ = filter.process(location(at: 5, meters: 4))
        for second in 6...9 {
            #expect(filter.process(location(at: Double(second), meters: 5_000)) == .rejected(.jump))
        }
    }

    @Test func resetForgetsTheAnchor() {
        var filter = LocationFilter()
        _ = filter.process(location(at: 0, meters: 0))
        filter.reset()
        #expect(filter.process(location(at: 100, meters: 9_000)) == .anchored)
    }

    @Test func rejectsInvalidCoordinatesWithoutMovingTheAnchor() {
        var filter = LocationFilter()
        let invalid = [
            Coordinate(latitude: .nan, longitude: 8), Coordinate(latitude: 47, longitude: .infinity),
            Coordinate(latitude: 91, longitude: 8), Coordinate(latitude: 47, longitude: -181)
        ]
        for (offset, coordinate) in invalid.enumerated() {
            let sample = LocationSample(timestamp: at(Double(offset)), coordinate: coordinate, horizontalAccuracy: 5)
            #expect(filter.process(sample) == .rejected(.invalidCoordinate))
        }
        #expect(filter.process(location(at: 10, meters: 0)) == .anchored)
        guard case .accepted(let moved) = filter.process(location(at: 11, meters: 3)) else {
            Issue.record("expected an accepted fix")
            return
        }
        #expect(abs(moved.meters - 3) < 0.01)
    }

    @Test func invalidCoordinateAfterAnchorAddsNoDistance() {
        var filter = LocationFilter()
        _ = filter.process(location(at: 0, meters: 0))
        let invalid = LocationSample(
            timestamp: at(1), coordinate: Coordinate(latitude: .nan, longitude: 8), horizontalAccuracy: 5
        )
        #expect(filter.process(invalid) == .rejected(.invalidCoordinate))
        guard case .accepted(let moved) = filter.process(location(at: 2, meters: 6)) else {
            Issue.record("expected an accepted fix")
            return
        }
        #expect(abs(moved.meters - 6) < 0.01)
    }

    @Test func repeatedCopiesOfAJumpCountOnce() {
        var filter = LocationFilter()
        _ = filter.process(location(at: 0, meters: 0))
        #expect(filter.process(location(at: 1, meters: 5_000)) == .rejected(.jump))
        for _ in 1...6 {
            #expect(filter.process(location(at: 1, meters: 5_000)) == .rejected(.outOfOrder))
        }
        #expect(filter.process(location(at: 0.5, meters: 5_000)) == .rejected(.jump))
        guard case .accepted(let moved) = filter.process(location(at: 2, meters: 4)) else {
            Issue.record("expected an accepted fix")
            return
        }
        #expect(abs(moved.meters - 4) < 0.01)
    }

    @Test func duplicateJumpsDoNotAdvanceTheResyncCount() {
        var filter = LocationFilter()
        _ = filter.process(location(at: 0, meters: 0))
        for second in 1...4 {
            #expect(filter.process(location(at: Double(second), meters: 5_000)) == .rejected(.jump))
            #expect(filter.process(location(at: Double(second), meters: 5_000)) == .rejected(.outOfOrder))
        }
        // Four distinct jumps so far: the duplicates must not have counted, so the fifth distinct one re-anchors.
        #expect(filter.process(location(at: 5, meters: 5_000)) == .anchored)
    }

    @Test func resyncsOnExactlyTheFifthDistinctJump() {
        var filter = LocationFilter()
        _ = filter.process(location(at: 0, meters: 0))
        #expect(filter.process(location(at: 1, meters: 5_000)) == .rejected(.jump))
        for _ in 1...2 {
            #expect(filter.process(location(at: 1, meters: 5_000)) == .rejected(.outOfOrder))
        }
        for second in 2...4 {
            #expect(filter.process(location(at: Double(second), meters: 5_000)) == .rejected(.jump))
        }
        #expect(filter.process(location(at: 5, meters: 5_000)) == .anchored)
    }

    @Test func rejectedFutureJumpDoesNotBlockLaterValidFixes() {
        var filter = LocationFilter()
        _ = filter.process(location(at: 0, meters: 0))
        #expect(filter.process(location(at: 1_000, meters: 50_000)) == .rejected(.jump))
        guard case .accepted(let moved) = filter.process(location(at: 2, meters: 4)) else {
            Issue.record("expected an accepted fix")
            return
        }
        #expect(abs(moved.meters - 4) < 0.01)
        guard case .accepted = filter.process(location(at: 3, meters: 8)) else {
            Issue.record("expected an accepted fix")
            return
        }
    }

    @Test func copiesOfAFutureJumpStillCountOnce() {
        var filter = LocationFilter()
        _ = filter.process(location(at: 0, meters: 0))
        #expect(filter.process(location(at: 1_000, meters: 50_000)) == .rejected(.jump))
        for _ in 1...6 {
            #expect(filter.process(location(at: 1_000, meters: 50_000)) == .rejected(.outOfOrder))
        }
        guard case .accepted = filter.process(location(at: 2, meters: 4)) else {
            Issue.record("expected an accepted fix")
            return
        }
    }

    @Test func staleCandidateDoesNotBecomeTheResyncAnchor() {
        var filter = LocationFilter()
        _ = filter.process(location(at: 0, meters: 0))
        for second in 10...13 {
            #expect(filter.process(location(at: Double(second), meters: 5_000)) == .rejected(.jump))
        }
        // Older than the rejected jumps, so it must not be adopted as the new reference point.
        #expect(filter.process(location(at: 1, meters: 1_000)) == .rejected(.jump))
        // A newer candidate still completes the resync.
        #expect(filter.process(location(at: 14, meters: 5_000)) == .anchored)
    }

    @Test func rejectedFutureJumpStaysBlockedAfterLaterFixesAreAdopted() {
        var filter = LocationFilter()
        _ = filter.process(location(at: 0, meters: 0))
        #expect(filter.process(location(at: 1_000, meters: 50_000)) == .rejected(.jump))
        guard case .accepted = filter.process(location(at: 2, meters: 4)) else {
            Issue.record("expected an accepted fix")
            return
        }
        for second in 3...6 {
            #expect(filter.process(location(at: Double(second), meters: 50_000)) == .rejected(.jump))
        }
        #expect(filter.process(location(at: 7, meters: 50_000)) == .anchored)
        // The rejected fix must not be accepted when it is delivered again.
        #expect(filter.process(location(at: 1_000, meters: 50_000)) == .rejected(.outOfOrder))
        guard case .accepted = filter.process(location(at: 8, meters: 50_003)) else {
            Issue.record("expected an accepted fix")
            return
        }
    }

    @Test func genuineRelocationReanchorsAfterAnIsolatedFutureJump() {
        var filter = LocationFilter()
        _ = filter.process(location(at: 0, meters: 0))
        #expect(filter.process(location(at: 1_000, meters: 50_000)) == .rejected(.jump))
        for second in 1...3 {
            #expect(filter.process(location(at: Double(second), meters: 5_000)) == .rejected(.jump))
        }
        // The future-dated jump is the first distinct jump, so the fourth increasing fix after it is the fifth.
        // The relocation re-anchors there instead of counting 5 km as distance.
        #expect(filter.process(location(at: 4, meters: 5_000)) == .anchored)
        guard case .accepted(let moved) = filter.process(location(at: 5, meters: 5_003)) else {
            Issue.record("expected an accepted fix")
            return
        }
        #expect(abs(moved.meters - 3) < 0.01)
    }

    @Test func staleJumpIsRememberedSoItsReplayCannotPassLater() {
        var filter = LocationFilter()
        _ = filter.process(location(at: 0, meters: 0))
        for second in 10...13 {
            #expect(filter.process(location(at: Double(second), meters: 5_000)) == .rejected(.jump))
        }
        // Older than the rejected jumps: rejected, and its copy is an out-of-order replay.
        #expect(filter.process(location(at: 9, meters: 5_000)) == .rejected(.jump))
        #expect(filter.process(location(at: 9, meters: 5_000)) == .rejected(.outOfOrder))
        guard case .accepted = filter.process(location(at: 2, meters: 4)) else {
            Issue.record("expected an accepted fix")
            return
        }
        for second in 3...6 {
            #expect(filter.process(location(at: Double(second), meters: 1_000)) == .rejected(.jump))
        }
        #expect(filter.process(location(at: 7, meters: 1_000)) == .anchored)
        #expect(filter.process(location(at: 9, meters: 1_010)) == .rejected(.outOfOrder))
    }

    @Test func resetForgetsTheLatestTimestamp() {
        var filter = LocationFilter()
        _ = filter.process(location(at: 50, meters: 0))
        filter.reset()
        #expect(filter.process(location(at: 10, meters: 0)) == .anchored)
    }
}
