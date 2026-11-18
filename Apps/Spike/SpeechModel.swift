import AVFoundation
import Observation

/// Speaks the test prompt through a workout-style audio session and reports the active output route.
@MainActor
@Observable
final class SpeechModel {
    static let prompt = "In 150 meters, turn right"

    private let synthesizer = AVSpeechSynthesizer()
    private(set) var route = "Route: not checked"
    private(set) var error: String?

    func speak() {
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.playback, mode: .voicePrompt, options: [.duckOthers])
            try session.setActive(true)
            error = nil
        } catch {
            self.error = "Audio session: \(error.localizedDescription)"
        }
        route = Self.describeRoute(session.currentRoute)
        synthesizer.speak(AVSpeechUtterance(string: Self.prompt))
    }

    private static func describeRoute(_ route: AVAudioSessionRouteDescription) -> String {
        let outputs = route.outputs.map { "\($0.portName) (\($0.portType.rawValue))" }
        return outputs.isEmpty ? "Route: none" : "Route: " + outputs.joined(separator: ", ")
    }
}
