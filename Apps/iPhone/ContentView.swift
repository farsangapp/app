import FarsangCore
import SwiftUI

struct ContentView: View {
    var body: some View {
        VStack(spacing: 8) {
            Text("Farsang")
                .font(.largeTitle.bold())
            Text(Distance.zero.kilometers.formatted(.number.precision(.fractionLength(2))) + " km")
                .foregroundStyle(.secondary)
        }
        .padding()
    }
}

#Preview {
    ContentView()
}
