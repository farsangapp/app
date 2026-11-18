import SwiftUI

/// Throwaway spike (FAR-8). Answers two questions on a real watch: does MapKit show Apple Maps' offline
/// regions with no phone nearby, and can the watch speak through its own speaker without headphones.
/// See docs/spikes/map-and-speech.md. Not shipped.
@main
struct FarsangSpikeApp: App {
    var body: some Scene {
        WindowGroup {
            TabView {
                MapScreen()
                SpeechScreen()
            }
            .tabViewStyle(.verticalPage)
        }
    }
}
