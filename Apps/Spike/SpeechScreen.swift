import SwiftUI

/// Screen 2: speak a navigation prompt and show which audio route is active. Run it with no headphones paired.
struct SpeechScreen: View {
    @State private var speech = SpeechModel()

    var body: some View {
        VStack(spacing: 8) {
            Button("Speak", systemImage: "speaker.wave.2.fill") {
                speech.speak()
            }
            Text(speech.route)
                .font(.caption2)
                .multilineTextAlignment(.center)
            if let error = speech.error {
                Text(error)
                    .font(.caption2)
                    .foregroundStyle(.red)
            }
        }
    }
}
