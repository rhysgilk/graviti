import Foundation

struct FitGuide: Identifiable, Hashable {
    let id: String
    let destination: SavedDestination
    let interests: [String]

    init(id: String? = nil, destination: SavedDestination, interests: [String]) {
        self.id = id ?? destination.id
        self.destination = destination
        self.interests = interests
    }

    var collectionTitle: String {
        String(localized: "\(destination.name) Fit Guide")
    }

    func collectionTitle(for interest: String) -> String {
        "\(collectionTitle) · \(InterestDisplayName.localized(interest))"
    }

    func contains(_ artifact: Artifact) -> Bool {
        artifact.sourceCollectionTitles.contains { title in
            title == collectionTitle || title.hasPrefix("\(collectionTitle) · ")
        }
    }
}
