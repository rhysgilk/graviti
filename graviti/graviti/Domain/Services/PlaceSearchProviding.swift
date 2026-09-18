import Foundation

struct PlaceCandidate: Identifiable, Hashable {
    let place: SavedPlace
    let sourceURL: String

    var id: String { place.id }
}

@MainActor
protocol PlaceSearchProviding {
    func search(_ query: String) async throws -> [PlaceCandidate]
}
