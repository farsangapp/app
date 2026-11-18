import AVFoundation
import Observation

/// Speaks the test prompt through a workout-style audio session and reports the active output route.
@MainActor
@Observable
final class SpeechModel: NSObject {
    static let prompt = "In 150 meters, turn right"

    private let synthesizer = AVSpeechSynthesizer()
    /// Utterances handed to the synthesizer that have not yet finished or been cancelled, tracked by identity.
    @ObservationIgnored private var pendingUtterances: Set<AVSpeechUtterance> = []
    @ObservationIgnored private var observers: [Task<Void, Never>] = []
    private(set) var route = "Route: not checked"
    private(set) var error: String?

    override init() {
        super.init()
        synthesizer.delegate = self
        observers = [
            // An interruption (call, Siri) ends the session's ducking, so drop queued prompts and release the session.
            // Only `.began` matters: `.ended` must not cut off a prompt queued after the interruption.
            observe(AVAudioSession.interruptionNotification) { model, notification in
                let rawType = notification.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt
                guard rawType.flatMap(AVAudioSession.InterruptionType.init(rawValue:)) == .began else { return }
                model.synthesizer.stopSpeaking(at: .immediate)
                // Dropped prompts get no didCancel, so clear them here. A late callback then removes nothing.
                model.pendingUtterances.removeAll()
                model.releaseSessionIfIdle()
            },
            // The output can change mid-playback (headphones connect or drop), so keep the label current.
            observe(AVAudioSession.routeChangeNotification) { model, _ in
                if !model.pendingUtterances.isEmpty { model.refreshRoute() }
            }
        ]
    }

    deinit {
        // Dropping a Task handle does not cancel it. Cancelling ends each suspended notification loop at once.
        for observer in observers { observer.cancel() }
    }

    func speak() {
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.playback, mode: .voicePrompt, options: [.duckOthers])
            try session.setActive(true)
            error = nil
        } catch {
            // Never queue speech without an active session: it could be counted as a pass. A later tap retries.
            self.error = "Audio session: \(error.localizedDescription)"
            route = "Route: not checked"
            return
        }
        let utterance = AVSpeechUtterance(string: Self.prompt)
        pendingUtterances.insert(utterance)
        synthesizer.speak(utterance)
    }

    private func observe(
        _ name: Notification.Name,
        _ handle: @escaping @MainActor (SpeechModel, Notification) -> Void
    ) -> Task<Void, Never> {
        Task { [weak self] in
            for await notification in NotificationCenter.default.notifications(named: name) {
                guard let self else { return }
                handle(self, notification)
            }
        }
    }

    private func refreshRoute() {
        route = Self.describeRoute(AVAudioSession.sharedInstance().currentRoute)
    }

    private func utteranceEnded(_ utterance: AVSpeechUtterance) {
        // A callback for an utterance already cleared by an interruption removes nothing.
        guard pendingUtterances.remove(utterance) != nil else { return }
        releaseSessionIfIdle()
    }

    private func releaseSessionIfIdle() {
        // Releasing the session ends ducking of other audio; keep it while another prompt is queued.
        if pendingUtterances.isEmpty {
            try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        }
    }

    private static func describeRoute(_ route: AVAudioSessionRouteDescription) -> String {
        let outputs = route.outputs.map { "\($0.portName) (\($0.portType.rawValue))" }
        return outputs.isEmpty ? "Route: none" : "Route: " + outputs.joined(separator: ", ")
    }
}

extension SpeechModel: @preconcurrency AVSpeechSynthesizerDelegate {
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didStart utterance: AVSpeechUtterance) {
        refreshRoute()
    }

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        utteranceEnded(utterance)
    }

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        utteranceEnded(utterance)
    }
}
