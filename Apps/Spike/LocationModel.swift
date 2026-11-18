import CoreLocation
import Observation

/// Tracks location authorization and whether a fix has arrived, for the spike's status label.
@MainActor
@Observable
final class LocationModel: NSObject {
    private let manager = CLLocationManager()
    private(set) var authorization: CLAuthorizationStatus
    private(set) var hasFix = false

    override init() {
        authorization = manager.authorizationStatus
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBest
    }

    var isAuthorized: Bool {
        authorization == .authorizedWhenInUse || authorization == .authorizedAlways
    }

    /// Short text for the on-screen label.
    var statusText: String {
        switch authorization {
        case .notDetermined: "Location: not asked"
        case .denied: "Location: denied"
        case .restricted: "Location: restricted"
        case .authorizedAlways, .authorizedWhenInUse: hasFix ? "Location: available" : "Location: no fix yet"
        @unknown default: "Location: unknown"
        }
    }

    func start() {
        if authorization == .notDetermined {
            manager.requestWhenInUseAuthorization()
        }
        manager.startUpdatingLocation()
    }
}

extension LocationModel: @preconcurrency CLLocationManagerDelegate {
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        authorization = manager.authorizationStatus
        if isAuthorized {
            manager.startUpdatingLocation()
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        hasFix = !locations.isEmpty
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: any Error) {
        hasFix = false
    }
}
