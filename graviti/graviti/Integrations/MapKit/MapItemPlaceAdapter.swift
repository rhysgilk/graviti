import Foundation
import MapKit

enum MapItemPlaceAdapter {
    static func savedPlace(from item: MKMapItem, fallbackID: String? = nil) -> SavedPlace? {
        guard let name = item.name?.trimmingCharacters(in: .whitespacesAndNewlines), !name.isEmpty else {
            return nil
        }

        let coordinate: CLLocationCoordinate2D
        let locality: String?
        let region: String?
        let country: String?
        if #available(iOS 26.0, *) {
            coordinate = item.location.coordinate
            locality = item.addressRepresentations?.cityName
            region = nil
            country = item.addressRepresentations?.regionName
        } else {
            coordinate = item.placemark.coordinate
            locality = item.placemark.locality
            region = item.placemark.administrativeArea
            country = item.placemark.country
        }

        return SavedPlace(
            id: item.identifier?.rawValue ?? fallbackID ?? String(
                format: "%.5f,%.5f:%@",
                coordinate.latitude,
                coordinate.longitude,
                name
            ),
            name: name,
            latitude: coordinate.latitude,
            longitude: coordinate.longitude,
            locality: locality,
            region: region,
            country: country
        )
    }
}
