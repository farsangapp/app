public struct AlertSettings: Sendable, Hashable {
    public var voiceEnabledKinds: Set<AlertKind>
    /// Silences voice and haptics. Banners still show.
    public var isMuted: Bool

    public init(voiceEnabledKinds: Set<AlertKind> = Set(AlertKind.allCases), isMuted: Bool = false) {
        self.voiceEnabledKinds = voiceEnabledKinds
        self.isMuted = isMuted
    }

    public func isVoiceEnabled(for kind: AlertKind) -> Bool {
        voiceEnabledKinds.contains(kind)
    }

    public mutating func setVoice(_ enabled: Bool, for kind: AlertKind) {
        if enabled {
            voiceEnabledKinds.insert(kind)
        } else {
            voiceEnabledKinds.remove(kind)
        }
    }
}
