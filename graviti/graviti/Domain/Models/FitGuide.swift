import Foundation

struct FitGuide: Identifiable, Hashable {
    let destination: SavedDestination
    let interests: [String]

    var id: String { destination.id }

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
