import MapKit
import SwiftUI

/// Screen 1: full-screen map on the user. Run it offline to see whether Apple Maps' downloaded regions render.
struct MapScreen: View {
    @State private var location = LocationModel()
    @State private var position: MapCameraPosition = .userLocation(fallback: .automatic)

    var body: some View {
        Map(position: $position) {
            UserAnnotation()
        }
        .ignoresSafeArea()
        .overlay(alignment: .top) {
            Text(location.statusText)
                .font(.caption2)
                .padding(.horizontal, 6)
                .background(.black.opacity(0.6), in: Capsule())
        }
        .overlay(alignment: .bottomTrailing) {
            Button("Center", systemImage: "location.fill") {
                position = .userLocation(fallback: .automatic)
            }
            .labelStyle(.iconOnly)
            .buttonBorderShape(.circle)
        }
        .task { location.start() }
    }
}
