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
            var url = URLComponents(string: "https://maps.apple.com/")!
            url.queryItems = [
                URLQueryItem(name: "ll", value: "\(place.latitude),\(place.longitude)"),
                URLQueryItem(name: "q", value: place.name)
            ]
            return PlaceCandidate(place: place, sourceURL: url.url!.absoluteString)
        }
    }
}
