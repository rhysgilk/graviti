import Foundation

struct PlaceCandidate: Identifiable, Hashable {
    let place: SavedPlace
    let sourceURL: String

    var id: String { place.id }
}

@MainActor
protocol PlaceSearchProviding {
    func search(_ query: String) async throws -> [PlaceCandidate]
    func search(_ query: String, near destination: SavedDestination) async throws -> [PlaceCandidate]
}

extension PlaceSearchProviding {
    func search(_ query: String, near destination: SavedDestination) async throws -> [PlaceCandidate] {
        try await search("\(query) in \(destination.name), \(destination.country)")
    }
}
