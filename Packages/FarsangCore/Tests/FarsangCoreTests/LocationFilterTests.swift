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
        #expect(filter.process(location(at: 1, meters: 8)) != .rejected(.jump))
    }

    @Test func largeMoveOverLongGapIsNotAJump() {
        var filter = LocationFilter()
        _ = filter.process(location(at: 0, meters: 0))
        #expect(filter.process(location(at: 60, meters: 200)) != .rejected(.jump))
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
        #expect(filter.process(location(at: 6, meters: 5_003)) != .rejected(.jump))
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
}
