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
        if let last = lastDelivered[key], now.timeIntervalSince(last) < Self.minimumInterval(for: alert.kind) {
            return .rateLimited
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

    /// Forgets what was delivered, for the start of a new workout.
    public mutating func reset() {
        lastDelivered.removeAll()
    }
}

/// Identifies "the same alert" for rate limiting: a turn is the same turn however far away it is.
private struct RateLimitKey: Hashable {
    let kind: AlertKind
    let subject: String

    init(_ alert: Alert, unitSystem: UnitSystem) {
        kind = alert.kind
        switch alert {
        case .turnAhead(let direction, _, let street):
            subject = "\(direction.rawValue)|\(street ?? "")"
        case .distanceMarker(let meters, _):
            subject = SpokenFormatter.distanceMarker(fromMeters: meters, unitSystem: unitSystem)
        case .segmentMarked(let number):
            subject = "\(number)"
        case .offRoute, .backOnRoute, .paused, .resumed, .ended:
            subject = ""
        }
    }
}
