import FarsangCore
import SwiftUI

struct ContentView: View {
    var body: some View {
        VStack(spacing: 4) {
            Text("Farsang")
                .font(.headline)
            Text(Distance.zero.kilometers.formatted(.number.precision(.fractionLength(2))) + " km")
                .foregroundStyle(.secondary)
        }
    }
}

#Preview {
    ContentView()
}
