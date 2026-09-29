import CoreLocation
import Foundation
import Combine

@MainActor
final class SearchLocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    @Published private(set) var authorizationStatus: CLAuthorizationStatus
    @Published private(set) var location: CLLocation?
    @Published private(set) var errorMessage: String?

    private let manager: CLLocationManager

    override init() {
        let manager = CLLocationManager()
        self.manager = manager
        authorizationStatus = manager.authorizationStatus
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
    }

    func requestLocation() {
        errorMessage = nil
        switch manager.authorizationStatus {
        case .notDetermined:
            manager.requestWhenInUseAuthorization()
        case .authorizedAlways, .authorizedWhenInUse:
            manager.requestLocation()
        case .denied, .restricted:
            errorMessage = String(localized: "Location access is off. Enable it in Settings to sort places near you.")
        @unknown default:
            errorMessage = String(localized: "Your location is unavailable right now.")
        }
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        authorizationStatus = manager.authorizationStatus
        if manager.authorizationStatus == .authorizedAlways || manager.authorizationStatus == .authorizedWhenInUse {
            manager.requestLocation()
        } else if manager.authorizationStatus == .denied || manager.authorizationStatus == .restricted {
            errorMessage = String(localized: "Location access is off. Enable it in Settings to sort places near you.")
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        location = locations.last
        errorMessage = nil
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        if (error as? CLError)?.code != .locationUnknown {
            errorMessage = String(localized: "Your location could not be updated. Try again in a moment.")
        }
    }
}

enum NearbyPlaceSorter {
    static func distance(from location: CLLocation, to place: SavedPlace) -> CLLocationDistance {
        location.distance(from: CLLocation(latitude: place.latitude, longitude: place.longitude))
    }

    static func sort(_ places: [SavedPlace], from location: CLLocation) -> [SavedPlace] {
        places.sorted {
            let left = distance(from: location, to: $0)
            let right = distance(from: location, to: $1)
            return left == right ? $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending : left < right
        }
    }

    static func sort(_ candidates: [PlaceCandidate], from location: CLLocation) -> [PlaceCandidate] {
        candidates.sorted {
            distance(from: location, to: $0.place) < distance(from: location, to: $1.place)
        }
    }
}
