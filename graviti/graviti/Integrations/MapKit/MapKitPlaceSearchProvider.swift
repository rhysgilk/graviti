import Foundation
import MapKit

struct MapKitPlaceSearchProvider: PlaceSearchProviding {
    func search(_ query: String) async throws -> [PlaceCandidate] {
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = query
        request.resultTypes = [.pointOfInterest, .address]
        let response = try await MKLocalSearch(request: request).start()

        return response.mapItems.compactMap { item in
            guard let name = item.name, !name.isEmpty else { return nil }
            let coordinate = item.location.coordinate
            let place = SavedPlace(
                id: item.identifier?.rawValue ?? String(format: "%.5f,%.5f:%@", coordinate.latitude, coordinate.longitude, name),
                name: name,
                latitude: coordinate.latitude,
                longitude: coordinate.longitude,
                locality: item.addressRepresentations?.cityName,
                region: nil,
                country: item.addressRepresentations?.regionName
            )
            var url = URLComponents(string: "https://maps.apple.com/")!
            url.queryItems = [
                URLQueryItem(name: "ll", value: "\(coordinate.latitude),\(coordinate.longitude)"),
                URLQueryItem(name: "q", value: name)
            ]
            return PlaceCandidate(place: place, sourceURL: url.url!.absoluteString)
        }
    }
}
