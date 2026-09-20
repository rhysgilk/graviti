import Foundation
import MapKit

@MainActor
final class MapKitPlaceSearchProvider: PlaceSearchProviding {
    private var destinationRegions = [String: MKCoordinateRegion]()

    func search(_ query: String) async throws -> [PlaceCandidate] {
        try await search(query, region: nil, resultTypes: [.pointOfInterest, .address])
    }

    func search(_ query: String, near destination: SavedDestination) async throws -> [PlaceCandidate] {
        guard let region = await region(for: destination) else {
            return try await search("\(query) in \(destination.name), \(destination.country)")
        }
        return try await search(query, region: region, resultTypes: [.pointOfInterest, .physicalFeature])
    }

    private func search(
        _ query: String,
        region: MKCoordinateRegion?,
        resultTypes: MKLocalSearch.ResultType
    ) async throws -> [PlaceCandidate] {
        let response: MKLocalSearch.Response
        do {
            response = try await searchResponse(query, region: region, resultTypes: resultTypes)
        } catch let error as MKError where error.code == .placemarkNotFound {
            return []
        }
        return response.mapItems.compactMap { item in
            guard let place = MapItemPlaceAdapter.savedPlace(from: item) else { return nil }
            guard let sourceURL = Self.sourceURL(for: place) else { return nil }
            return PlaceCandidate(place: place, sourceURL: sourceURL)
        }
    }

    private func searchResponse(
        _ query: String,
        region: MKCoordinateRegion?,
        resultTypes: MKLocalSearch.ResultType
    ) async throws -> MKLocalSearch.Response {
        var attempt = 0
        while true {
            do {
                let request = MKLocalSearch.Request()
                request.naturalLanguageQuery = query
                request.resultTypes = resultTypes
                if let region {
                    request.region = region
                    request.regionPriority = .required
                }
                return try await MKLocalSearch(request: request).start()
            } catch let error as MKError where
                [.serverFailure, .loadingThrottled].contains(error.code) && attempt < 2 {
                attempt += 1
                try await Task.sleep(for: .milliseconds(350 * attempt))
            }
        }
    }

    private func region(for destination: SavedDestination) async -> MKCoordinateRegion? {
        if let cached = destinationRegions[destination.id] { return cached }
        do {
            let response = try await searchResponse(
                "\(destination.name), \(destination.country)",
                region: nil,
                resultTypes: .address
            )
            guard let center = response.mapItems.first?.placemark.coordinate else { return nil }
            let region = MKCoordinateRegion(
                center: center,
                span: MKCoordinateSpan(
                    latitudeDelta: destination.searchSpan,
                    longitudeDelta: destination.searchSpan
                )
            )
            destinationRegions[destination.id] = region
            return region
        } catch {
            return nil
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
