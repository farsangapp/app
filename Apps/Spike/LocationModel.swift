import CoreLocation
import Observation

/// Tracks location authorization and whether a fix has arrived, for the spike's status label.
@MainActor
@Observable
final class LocationModel: NSObject {
    private let manager = CLLocationManager()
    private(set) var authorization: CLAuthorizationStatus
    private(set) var hasFix = false
    @ObservationIgnored private var staleTask: Task<Void, Never>?

    /// A sample only counts as a fix if it is recent and its horizontal accuracy is usable.
    private static let maxSampleAge: TimeInterval = 30
    private static let maxHorizontalAccuracy: CLLocationAccuracy = 100

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
        guard let latest = locations.last else { return }
        let age = -latest.timestamp.timeIntervalSinceNow
        let usable =
            latest.horizontalAccuracy >= 0
            && latest.horizontalAccuracy <= Self.maxHorizontalAccuracy
            && age <= Self.maxSampleAge
        staleTask?.cancel()
        hasFix = usable
        guard usable else { return }
        // Expire the label if no further usable sample arrives before this one goes stale.
        let deadline = ContinuousClock.now.advanced(by: .seconds(Self.maxSampleAge - age))
        staleTask = Task { [weak self] in
            try? await Task.sleep(until: deadline, clock: .continuous)
            guard !Task.isCancelled else { return }
            self?.hasFix = false
        }
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: any Error) {
        staleTask?.cancel()
        hasFix = false
    }
}
