import Foundation
import Testing

@testable import FarsangCore

final class FakeAlertSink: AlertSink {
    var banners: [AlertBanner] = []
    var haptics: [AlertHaptic] = []
    var spoken: [String] = []

    func showBanner(_ banner: AlertBanner) { banners.append(banner) }
    func playHaptic(_ haptic: AlertHaptic) { haptics.append(haptic) }
    func speak(_ text: String) { spoken.append(text) }
}

struct AlertEngineTests {
    private let start = Date(timeIntervalSince1970: 1_000)
    private let sink = FakeAlertSink()

    private func makeEngine(
        settings: AlertSettings = AlertSettings(), unitSystem: UnitSystem = .metric
    ) -> AlertEngine {
        AlertEngine(sink: sink, settings: settings, unitSystem: unitSystem)
    }

    // MARK: Spoken text, haptics and banners

    @Test func turnAheadSpeaksDistanceDirectionAndStreet() {
        var engine = makeEngine()
        engine.post(
            .turnAhead(maneuverID: "m1", direction: .right, distanceMeters: 150, streetName: "Elm Street"), at: start)
        #expect(sink.spoken == ["In 150 meters, turn right onto Elm Street"])
        #expect(sink.haptics == [.turnRight])
        #expect(sink.banners == [AlertBanner(kind: .turnAhead, title: "Turn right", detail: "In 0.15 km, Elm Street")])
    }

    @Test func turnAheadWithoutStreetOmitsIt() {
        var engine = makeEngine()
        engine.post(.turnAhead(maneuverID: "m1", direction: .left, distanceMeters: 150, streetName: nil), at: start)
        #expect(sink.spoken == ["In 150 meters, turn left"])
        #expect(sink.haptics == [.turnLeft])
        #expect(sink.banners.first?.detail == "In 0.15 km")
    }

    @Test func turnAheadUsesImperialUnits() {
        var engine = makeEngine(unitSystem: .imperial)
        engine.post(.turnAhead(maneuverID: "m1", direction: .left, distanceMeters: 150, streetName: nil), at: start)
        #expect(sink.spoken == ["In 500 feet, turn left"])
        #expect(sink.banners.first?.detail == "In 0.09 mi")
    }

    @Test func offRouteSpeaksHeading() {
        var engine = makeEngine()
        engine.post(.offRoute(heading: .north), at: start)
        #expect(sink.spoken == ["You're off route. Head north"])
        #expect(sink.haptics == [.longDoubleTap])
        #expect(sink.banners == [AlertBanner(kind: .offRoute, title: "Off route", detail: "Head north")])
    }

    @Test func offRouteWithoutHeading() {
        var engine = makeEngine()
        engine.post(.offRoute(heading: nil), at: start)
        #expect(sink.spoken == ["You're off route"])
        #expect(sink.banners.first?.detail == nil)
    }

    @Test func backOnRoute() {
        var engine = makeEngine()
        engine.post(.backOnRoute, at: start)
        #expect(sink.spoken == ["Back on route"])
        #expect(sink.haptics == [.singleTap])
        #expect(sink.banners == [AlertBanner(kind: .backOnRoute, title: "Back on route")])
    }

    @Test func kilometerMarkerSpeaksPace() {
        var engine = makeEngine()
        engine.post(.distanceMarker(distanceMeters: 6_000, paceSecondsPerUnit: 310), at: start)
        #expect(sink.spoken == ["Kilometer 6. Five ten per kilometer"])
        #expect(sink.haptics == [.lightTap])
        #expect(sink.banners == [AlertBanner(kind: .distanceMarker, title: "Kilometer 6", detail: "5:10 /km")])
    }

    @Test func mileMarkerSpeaksPace() {
        var engine = makeEngine(unitSystem: .imperial)
        engine.post(.distanceMarker(distanceMeters: 3_218.688, paceSecondsPerUnit: 500), at: start)
        #expect(sink.spoken == ["Mile 2. Eight twenty per mile"])
    }

    @Test func markerWithoutPaceSpeaksOnlyTheMarker() {
        var engine = makeEngine()
        engine.post(.distanceMarker(distanceMeters: 1_000, paceSecondsPerUnit: nil), at: start)
        #expect(sink.spoken == ["Kilometer 1"])
        #expect(sink.banners.first?.detail == nil)
    }

    @Test func segmentMarked() {
        var engine = makeEngine()
        engine.post(.segmentMarked(number: 2), at: start)
        #expect(sink.spoken == ["Segment 2"])
        #expect(sink.haptics == [.singleTap])
        #expect(sink.banners == [AlertBanner(kind: .segmentMarked, title: "Segment 2")])
    }

    @Test func pausedResumedAndEnded() {
        var engine = makeEngine()
        engine.post(.paused, at: start)
        engine.post(.resumed, at: start.addingTimeInterval(10))
        engine.post(.ended, at: start.addingTimeInterval(20))
        #expect(sink.spoken == ["Workout paused", "Workout resumed", "Workout ended"])
        #expect(sink.haptics == [.singleTap, .singleTap, .singleTap])
        #expect(sink.banners.map(\.kind) == [.paused, .resumed, .ended])
    }

    // MARK: Toggles and Mute

    @Test func everyAlertTypeSpeaksByDefault() {
        let settings = AlertSettings()
        #expect(AlertKind.allCases.allSatisfy { settings.isVoiceEnabled(for: $0) })
        #expect(!settings.isMuted)
    }

    @Test func switchedOffTypeKeepsBannerAndHapticButNotVoice() {
        var settings = AlertSettings()
        settings.setVoice(false, for: .distanceMarker)
        var engine = makeEngine(settings: settings)
        engine.post(.distanceMarker(distanceMeters: 1_000, paceSecondsPerUnit: 300), at: start)
        #expect(sink.spoken.isEmpty)
        #expect(sink.haptics == [.lightTap])
        #expect(sink.banners.count == 1)
    }

    @Test func switchingOneTypeOffLeavesOthersSpeaking() {
        var settings = AlertSettings()
        settings.setVoice(false, for: .paused)
        var engine = makeEngine(settings: settings)
        engine.post(.paused, at: start)
        engine.post(.ended, at: start.addingTimeInterval(10))
        #expect(sink.spoken == ["Workout ended"])
    }

    @Test func switchingTypeBackOnSpeaksAgain() {
        var settings = AlertSettings()
        settings.setVoice(false, for: .paused)
        settings.setVoice(true, for: .paused)
        #expect(settings.isVoiceEnabled(for: .paused))
    }

    @Test func muteSilencesVoiceAndHapticsButShowsBanner() {
        var engine = makeEngine(settings: AlertSettings(isMuted: true))
        engine.post(.offRoute(heading: .east), at: start)
        #expect(sink.spoken.isEmpty)
        #expect(sink.haptics.isEmpty)
        #expect(sink.banners.count == 1)
    }

    @Test func settingsChangeTakesEffectOnNextAlert() {
        var engine = makeEngine()
        engine.post(.paused, at: start)
        engine.settings.isMuted = true
        engine.post(.resumed, at: start.addingTimeInterval(10))
        engine.settings.isMuted = false
        engine.post(.ended, at: start.addingTimeInterval(20))
        #expect(sink.spoken == ["Workout paused", "Workout ended"])
        #expect(sink.banners.count == 3)
    }
}

extension AlertEngineTests {
    // MARK: Rate limiting

    @Test func sameTurnIsNotRepeatedOnEveryGPSUpdate() {
        var engine = makeEngine()
        let first = engine.post(
            .turnAhead(maneuverID: "m1", direction: .left, distanceMeters: 150, streetName: "Elm"), at: start)
        let second = engine.post(
            .turnAhead(maneuverID: "m1", direction: .left, distanceMeters: 140, streetName: "Elm"),
            at: start.addingTimeInterval(1))
        #expect(first == .delivered)
        #expect(second == .rateLimited)
        #expect(sink.banners.count == 1)
        #expect(sink.haptics.count == 1)
        #expect(sink.spoken.count == 1)
    }

    @Test func sameTurnIsDeliveredAgainAfterTheInterval() {
        var engine = makeEngine()
        let interval = AlertEngine.minimumInterval(for: .turnAhead)
        engine.post(.turnAhead(maneuverID: "m1", direction: .left, distanceMeters: 150, streetName: "Elm"), at: start)
        let later = engine.post(
            .turnAhead(maneuverID: "m1", direction: .left, distanceMeters: 50, streetName: "Elm"),
            at: start.addingTimeInterval(interval))
        #expect(later == .delivered)
        #expect(sink.spoken.count == 2)
    }

    @Test func differentTurnsAreNotRateLimitedAgainstEachOther() {
        var engine = makeEngine()
        engine.post(.turnAhead(maneuverID: "m1", direction: .left, distanceMeters: 150, streetName: "Elm"), at: start)
        let next = engine.post(
            .turnAhead(maneuverID: "m2", direction: .right, distanceMeters: 100, streetName: "Oak"),
            at: start.addingTimeInterval(1))
        #expect(next == .delivered)
    }

    @Test func consecutiveUnnamedTurnsInTheSameDirectionAreBothDelivered() {
        var engine = makeEngine()
        engine.post(.turnAhead(maneuverID: "m1", direction: .left, distanceMeters: 50, streetName: nil), at: start)
        let next = engine.post(
            .turnAhead(maneuverID: "m2", direction: .left, distanceMeters: 50, streetName: nil),
            at: start.addingTimeInterval(5))
        #expect(next == .delivered)
        #expect(sink.spoken.count == 2)
    }

    @Test func turnsOntoTheSameStreetAreBothDelivered() {
        var engine = makeEngine()
        engine.post(.turnAhead(maneuverID: "m1", direction: .left, distanceMeters: 50, streetName: "Elm"), at: start)
        let next = engine.post(
            .turnAhead(maneuverID: "m2", direction: .left, distanceMeters: 50, streetName: "Elm"),
            at: start.addingTimeInterval(5))
        #expect(next == .delivered)
    }

    @Test func blankStreetNameIsTreatedAsAbsent() {
        var engine = makeEngine()
        engine.post(.turnAhead(maneuverID: "m1", direction: .left, distanceMeters: 150, streetName: "  \n"), at: start)
        engine.post(.turnAhead(maneuverID: "m2", direction: .left, distanceMeters: 150, streetName: ""), at: start)
        #expect(sink.spoken == ["In 150 meters, turn left", "In 150 meters, turn left"])
        #expect(sink.banners.map(\.detail) == ["In 0.15 km", "In 0.15 km"])
    }

    @Test func streetNameIsTrimmed() {
        var engine = makeEngine()
        engine.post(.turnAhead(maneuverID: "m1", direction: .left, distanceMeters: 150, streetName: " Elm "), at: start)
        #expect(sink.spoken == ["In 150 meters, turn left onto Elm"])
        #expect(sink.banners.first?.detail == "In 0.15 km, Elm")
    }

    @Test func offRouteRepeatsOnlyAsAnOccasionalReminder() {
        var engine = makeEngine()
        let interval = AlertEngine.minimumInterval(for: .offRoute)
        engine.post(.offRoute(heading: .north), at: start)
        let soon = engine.post(.offRoute(heading: .north), at: start.addingTimeInterval(1))
        let later = engine.post(.offRoute(heading: .north), at: start.addingTimeInterval(interval))
        #expect(soon == .rateLimited)
        #expect(later == .delivered)
    }

    @Test func sameKilometerMarkerIsSpokenOnce() {
        var engine = makeEngine()
        engine.post(.distanceMarker(distanceMeters: 6_000, paceSecondsPerUnit: 310), at: start)
        let repeated = engine.post(
            .distanceMarker(distanceMeters: 6_002, paceSecondsPerUnit: 311), at: start.addingTimeInterval(1))
        #expect(repeated == .rateLimited)
        #expect(sink.spoken.count == 1)
    }

    @Test func nextKilometerMarkerIsDelivered() {
        var engine = makeEngine()
        engine.post(.distanceMarker(distanceMeters: 6_000, paceSecondsPerUnit: 310), at: start)
        let next = engine.post(
            .distanceMarker(distanceMeters: 7_000, paceSecondsPerUnit: 305), at: start.addingTimeInterval(1))
        #expect(next == .delivered)
        #expect(sink.spoken.count == 2)
    }

    @Test func pauseTappedTwiceQuicklySpeaksOnce() {
        var engine = makeEngine()
        engine.post(.paused, at: start)
        let again = engine.post(.paused, at: start.addingTimeInterval(0.5))
        #expect(again == .rateLimited)
    }

    @Test func pauseResumePauseWithinTheCooldownDeliversEachOne() {
        var engine = makeEngine()
        let first = engine.post(.paused, at: start)
        let resumed = engine.post(.resumed, at: start.addingTimeInterval(0.5))
        let second = engine.post(.paused, at: start.addingTimeInterval(1))
        #expect([first, resumed, second] == [.delivered, .delivered, .delivered])
        #expect(sink.spoken == ["Workout paused", "Workout resumed", "Workout paused"])
    }

    @Test func duplicateResumeIsStillSuppressedAfterAPause() {
        var engine = makeEngine()
        engine.post(.paused, at: start)
        engine.post(.resumed, at: start.addingTimeInterval(0.5))
        let again = engine.post(.resumed, at: start.addingTimeInterval(1))
        #expect(again == .rateLimited)
    }

    @Test func backOnRouteEndsTheOffRouteEpisode() {
        var engine = makeEngine()
        engine.post(.offRoute(heading: .north), at: start)
        engine.post(.backOnRoute, at: start.addingTimeInterval(5))
        let again = engine.post(.offRoute(heading: .south), at: start.addingTimeInterval(10))
        #expect(again == .delivered)
        #expect(sink.spoken.last == "You're off route. Head south")
    }

    @Test func offRouteRepeatsAreSuppressedWithinOneEpisode() {
        var engine = makeEngine()
        engine.post(.offRoute(heading: .north), at: start)
        let repeated = engine.post(.offRoute(heading: .north), at: start.addingTimeInterval(10))
        #expect(repeated == .rateLimited)
    }

    @Test func wallClockMovingBackwardDoesNotExtendTheCooldown() {
        var engine = makeEngine()
        engine.post(.offRoute(heading: nil), at: start)
        let afterJump = engine.post(.offRoute(heading: nil), at: start.addingTimeInterval(-3_600))
        #expect(afterJump == .delivered)
    }

    @Test func quickPauseAndResumeAreBothDelivered() {
        var engine = makeEngine()
        engine.post(.paused, at: start)
        let resumed = engine.post(.resumed, at: start.addingTimeInterval(0.5))
        #expect(resumed == .delivered)
    }

    @Test func successiveSegmentsAreNeverRateLimited() {
        var engine = makeEngine()
        engine.post(.segmentMarked(number: 1), at: start)
        let second = engine.post(.segmentMarked(number: 2), at: start)
        #expect(second == .delivered)
    }

    @Test func rateLimitedAlertWhileMutedStillCountsAsDelivered() {
        var engine = makeEngine(settings: AlertSettings(isMuted: true))
        engine.post(.offRoute(heading: nil), at: start)
        engine.settings.isMuted = false
        let again = engine.post(.offRoute(heading: nil), at: start.addingTimeInterval(1))
        #expect(again == .rateLimited)
        #expect(sink.spoken.isEmpty)
    }

    @Test func resetForgetsHistory() {
        var engine = makeEngine()
        engine.post(.offRoute(heading: nil), at: start)
        engine.reset()
        let again = engine.post(.offRoute(heading: nil), at: start.addingTimeInterval(1))
        #expect(again == .delivered)
    }
}
