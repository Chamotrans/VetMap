import CoreLocation
import Foundation

enum LocationButtonRequestOutcome: Equatable {
    case requestedPermission
    case requestedLocation
    case requiresSettings
}

enum LocationAuthorizationState: Equatable {
    case notDetermined
    case authorized
    case denied
    case restricted
}

enum LocationButtonPolicy {
    static func outcome(
        for state: LocationAuthorizationState
    ) -> LocationButtonRequestOutcome {
        switch state {
        case .notDetermined:
            .requestedPermission
        case .authorized:
            .requestedLocation
        case .denied, .restricted:
            .requiresSettings
        }
    }
}

@MainActor
@Observable
final class LocationService: NSObject {
    private(set) var authorizationStatus: CLAuthorizationStatus
    private(set) var currentLocation: CLLocation?
    private(set) var locationRequestFailed = false

    @ObservationIgnored private let manager: CLLocationManager
    @ObservationIgnored private var shouldRequestLocationAfterAuthorization = false

    override init() {
        let manager = CLLocationManager()
        self.manager = manager
        self.authorizationStatus = manager.authorizationStatus
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
    }

    var canUseLocation: Bool {
        authorizationState == .authorized
    }

    var requiresSettingsRecovery: Bool {
        authorizationState == .denied || authorizationState == .restricted
    }

    /// The only entry point that may show the system location permission prompt.
    /// Call this directly from the map's location button action.
    @discardableResult
    func requestLocationFromButton() -> LocationButtonRequestOutcome {
        authorizationStatus = manager.authorizationStatus
        locationRequestFailed = false

        let outcome = LocationButtonPolicy.outcome(for: authorizationState)
        switch outcome {
        case .requestedPermission:
            shouldRequestLocationAfterAuthorization = true
            #if os(macOS)
            manager.requestAlwaysAuthorization()
            #else
            manager.requestWhenInUseAuthorization()
            #endif
        case .requestedLocation:
            shouldRequestLocationAfterAuthorization = false
            manager.requestLocation()
        case .requiresSettings:
            shouldRequestLocationAfterAuthorization = false
        }
        return outcome
    }

    /// Refreshes the displayed status after returning from Settings without
    /// requesting permission or starting a location request.
    func refreshAuthorizationStatus() {
        authorizationStatus = manager.authorizationStatus

        if !canUseLocation {
            currentLocation = nil
            locationRequestFailed = false
        }
        if requiresSettingsRecovery {
            shouldRequestLocationAfterAuthorization = false
        }
    }

    private var authorizationState: LocationAuthorizationState {
        switch authorizationStatus {
        case .notDetermined:
            .notDetermined
        case .authorizedAlways:
            .authorized
        #if !os(macOS)
        case .authorizedWhenInUse:
            .authorized
        #endif
        case .denied:
            .denied
        case .restricted:
            .restricted
        @unknown default:
            .restricted
        }
    }
}

extension LocationService: CLLocationManagerDelegate {
    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        Task { @MainActor in
            authorizationStatus = manager.authorizationStatus

            if canUseLocation, shouldRequestLocationAfterAuthorization {
                shouldRequestLocationAfterAuthorization = false
                locationRequestFailed = false
                manager.requestLocation()
            } else if !canUseLocation {
                currentLocation = nil
                locationRequestFailed = false
                if requiresSettingsRecovery {
                    shouldRequestLocationAfterAuthorization = false
                }
            }
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }

        Task { @MainActor in
            currentLocation = location
            locationRequestFailed = false
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        Task { @MainActor in
            locationRequestFailed = true
        }
    }
}
