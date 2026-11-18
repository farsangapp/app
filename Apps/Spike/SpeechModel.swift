import AVFoundation
import Observation

/// Speaks the test prompt through a workout-style audio session and reports the active output route.
@MainActor
@Observable
final class SpeechModel: NSObject {
    static let prompt = "In 150 meters, turn right"

    private let synthesizer = AVSpeechSynthesizer()
    /// Utterances handed to the synthesizer that have not yet finished or been cancelled.
    @ObservationIgnored private var pendingUtterances = 0
    @ObservationIgnored private var observers: [Task<Void, Never>] = []
    private(set) var route = "Route: not checked"
    private(set) var error: String?

    override init() {
        super.init()
        synthesizer.delegate = self
        observers = [
            // An interruption (call, Siri) ends the session's ducking, so drop queued prompts and release the session.
            observe(AVAudioSession.interruptionNotification) { model in
                model.synthesizer.stopSpeaking(at: .immediate)
            },
            // The output can change mid-playback (headphones connect or drop), so keep the label current.
            observe(AVAudioSession.routeChangeNotification) { model in
                if model.pendingUtterances > 0 { model.refreshRoute() }
            }
        ]
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
        pendingUtterances += 1
        synthesizer.speak(AVSpeechUtterance(string: Self.prompt))
    }

    private func observe(
        _ name: Notification.Name,
        _ handle: @escaping @MainActor (SpeechModel) -> Void
    ) -> Task<Void, Never> {
        Task { [weak self] in
            for await _ in NotificationCenter.default.notifications(named: name) {
                guard let self else { return }
                handle(self)
            }
        }
    }

    private func refreshRoute() {
        route = Self.describeRoute(AVAudioSession.sharedInstance().currentRoute)
    }

    private func utteranceEnded() {
        pendingUtterances = max(0, pendingUtterances - 1)
        // Releasing the session ends ducking of other audio; keep it while another prompt is queued.
        if pendingUtterances == 0 {
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
        utteranceEnded()
    }

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        utteranceEnded()
    }
}
