import Foundation

/// Routes alerts to a sink, applying the per-type voice toggles, Mute and rate limiting.
public struct AlertEngine {
    public enum Outcome: Sendable, Hashable {
        case delivered
        case rateLimited
    }

    /// Smallest gap before the same alert (same type and same subject) may be delivered again.
    public static func minimumInterval(for kind: AlertKind) -> TimeInterval {
        switch kind {
        case .turnAhead: 15
        case .offRoute: 30
        case .distanceMarker: 60
        case .backOnRoute, .paused, .resumed, .ended: 2
        case .segmentMarked: 0
        }
    }

    public var settings: AlertSettings
    public var unitSystem: UnitSystem

    private let sink: any AlertSink
    private var lastDelivered: [RateLimitKey: Date] = [:]

    public init(sink: any AlertSink, settings: AlertSettings = AlertSettings(), unitSystem: UnitSystem = .metric) {
        self.sink = sink
        self.settings = settings
        self.unitSystem = unitSystem
    }

    /// Delivers the alert unless the same one was delivered too recently.
    ///
    /// Callers can post on every GPS update. A rate-limited alert reaches no output at all,
    /// and a muted one still shows its banner.
    @discardableResult
    public mutating func post(_ alert: Alert, at now: Date = Date()) -> Outcome {
        let key = RateLimitKey(alert, unitSystem: unitSystem)
        // A negative gap means the wall clock moved backward; that must not extend the cooldown.
        if let last = lastDelivered[key] {
            let elapsed = now.timeIntervalSince(last)
            if elapsed >= 0, elapsed < Self.minimumInterval(for: alert.kind) {
                return .rateLimited
            }
        }
        // Announcing a new state ends the opposite one, so its next announcement is never suppressed.
        if let opposite = Self.opposite(of: alert.kind) {
            lastDelivered[RateLimitKey(kind: opposite, subject: "")] = nil
        }
        lastDelivered[key] = now

        sink.showBanner(AlertPhrasing.banner(for: alert, unitSystem: unitSystem))
        if !settings.isMuted {
            sink.playHaptic(AlertPhrasing.haptic(for: alert))
            if settings.isVoiceEnabled(for: alert.kind) {
                sink.speak(AlertPhrasing.spoken(for: alert, unitSystem: unitSystem))
            }
        }
        return .delivered
    }

    /// Pause and resume, and off route and back on route, each end the other's episode.
    private static func opposite(of kind: AlertKind) -> AlertKind? {
        switch kind {
        case .paused: .resumed
        case .resumed: .paused
        case .offRoute: .backOnRoute
        case .backOnRoute: .offRoute
        case .turnAhead, .distanceMarker, .segmentMarked, .ended: nil
        }
    }

    /// Forgets the turn cooldowns, for when the route is replaced.
    ///
    /// Turn cooldowns are keyed by maneuver ID, and a new route may reuse IDs. Call this when the route
    /// changes so the new route's first turn alert is never suppressed by the old route's.
    public mutating func resetTurnCooldowns() {
        lastDelivered = lastDelivered.filter { $0.key.kind != .turnAhead }
    }

    /// Forgets what was delivered, for the start of a new workout.
    public mutating func reset() {
        lastDelivered.removeAll()
    }
}

/// Identifies "the same alert" for rate limiting: a maneuver is the same turn however far away it is.
private struct RateLimitKey: Hashable {
    let kind: AlertKind
    let subject: String

    init(kind: AlertKind, subject: String) {
        self.kind = kind
        self.subject = subject
    }

    init(_ alert: Alert, unitSystem: UnitSystem) {
        kind = alert.kind
        switch alert {
        case .turnAhead(let maneuverID, _, _, _):
            subject = maneuverID
        case .distanceMarker(let meters, _):
            subject = SpokenFormatter.distanceMarker(fromMeters: meters, unitSystem: unitSystem)
        case .segmentMarked(let number):
            subject = "\(number)"
        case .offRoute, .backOnRoute, .paused, .resumed, .ended:
            subject = ""
        }
    }
}
