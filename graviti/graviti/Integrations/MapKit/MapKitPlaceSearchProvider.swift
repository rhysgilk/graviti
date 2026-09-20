import Foundation
import MapKit

struct MapKitPlaceSearchProvider: PlaceSearchProviding {
    func search(_ query: String) async throws -> [PlaceCandidate] {
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = query
        request.resultTypes = [.pointOfInterest, .address]
        let response: MKLocalSearch.Response
        do {
            response = try await MKLocalSearch(request: request).start()
        } catch let error as MKError where error.code == .placemarkNotFound {
            return []
        }

        return response.mapItems.compactMap { item in
            guard let place = MapItemPlaceAdapter.savedPlace(from: item) else { return nil }
            guard let sourceURL = Self.sourceURL(for: place) else { return nil }
            return PlaceCandidate(place: place, sourceURL: sourceURL)
        }
    }

    static func sourceURL(for place: SavedPlace) -> String? {
        var components = URLComponents()
        components.scheme = "https"
        components.host = "maps.apple.com"
        components.path = "/"
        components.queryItems = [
            URLQueryItem(name: "ll", value: "\(place.latitude),\(place.longitude)"),
            URLQueryItem(name: "q", value: place.name)
        ]
        return components.url?.absoluteString
    }
}
