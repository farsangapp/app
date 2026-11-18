public enum AlertHaptic: Sendable, Hashable {
    case turnLeft
    case turnRight
    case longDoubleTap
    case singleTap
    case lightTap
}

public struct AlertBanner: Sendable, Hashable {
    public let kind: AlertKind
    public let title: String
    public let detail: String?

    public init(kind: AlertKind, title: String, detail: String? = nil) {
        self.kind = kind
        self.title = title
        self.detail = detail
    }
}

/// Where alerts end up. The watch app supplies the real outputs; tests supply fakes.
public protocol AlertSink {
    func showBanner(_ banner: AlertBanner)
    func playHaptic(_ haptic: AlertHaptic)
    func speak(_ text: String)
}
