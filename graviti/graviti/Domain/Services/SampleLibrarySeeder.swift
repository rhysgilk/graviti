import Foundation

enum SampleLibrarySeeder {
    static let collectionTitle = "Graviti Sample Library"

    static func isSample(_ artifact: Artifact) -> Bool {
        artifact.sourceCollectionTitles.contains(collectionTitle)
    }

    static var artifacts: [Artifact] {
        let samples: [(String, String, SavedPlace, ExperienceCategory, [String], String)] = [
            (
                "6bf64096-4424-47b6-bd52-c3b48cfc6201",
                "Rocky coastline and sunrise trails",
                SavedPlace(id: "sample-acadia", name: "Acadia National Park", latitude: 44.3386, longitude: -68.2733, locality: "Bar Harbor", region: "Maine", country: "United States"),
                .sceneryAndNature,
                ["National parks", "Coast & water", "Hiking", "Sunrise"],
                "Granite peaks, ocean views, and quiet early morning trails."
            ),
            (
                "ea74d2f4-8d37-413d-ae12-466002b35502",
                "Torii gates, history, and hillside walks",
                SavedPlace(id: "sample-fushimi-inari", name: "Fushimi Inari Taisha", latitude: 34.9671, longitude: 135.7727, locality: "Kyoto", region: "Kyoto", country: "Japan"),
                .landmarks,
                ["Temples", "Architecture", "History", "Walking"],
                "A historic shrine with thousands of vermilion gates climbing the mountain."
            ),
            (
                "27aad5d1-922e-42b2-bbc7-e52323411603",
                "Modern art and bold design",
                SavedPlace(id: "sample-moma", name: "The Museum of Modern Art", latitude: 40.7614, longitude: -73.9776, locality: "New York", region: "New York", country: "United States"),
                .artsAndCulture,
                ["Museums", "Modern art", "Design", "Architecture"],
                "A dense collection of modern art, film, photography, and design."
            ),
            (
                "86515270-7f75-4d59-864e-a6637e551604",
                "Seafood stalls and lively food markets",
                SavedPlace(id: "sample-tsukiji", name: "Tsukiji Outer Market", latitude: 35.6655, longitude: 139.7707, locality: "Tokyo", region: "Tokyo", country: "Japan"),
                .foodAndDrink,
                ["Seafood", "Food markets", "Street food", "Local specialties"],
                "A walkable market known for fresh seafood, small counters, and Japanese pantry shops."
            ),
            (
                "237420c4-2d72-4188-9df5-f4c95c651605",
                "Mountain lakes and alpine hikes",
                SavedPlace(id: "sample-banff", name: "Banff National Park", latitude: 51.1784, longitude: -115.5708, locality: "Banff", region: "Alberta", country: "Canada"),
                .sceneryAndNature,
                ["Mountains", "Lakes", "National parks", "Hiking"],
                "Turquoise lakes, mountain viewpoints, wildlife, and trails across the Canadian Rockies."
            ),
            (
                "04525363-fae0-4c93-ab8d-c593f72d1606",
                "Traditional matcha and Japanese sweets",
                SavedPlace(id: "sample-tsujiri", name: "Gion Tsujiri", latitude: 35.0038, longitude: 135.7753, locality: "Kyoto", region: "Kyoto", country: "Japan"),
                .foodAndDrink,
                ["Matcha", "Tea", "Desserts", "Traditional food"],
                "A long running tea shop for matcha drinks, parfaits, and Japanese sweets."
            )
        ]

        return samples.enumerated().compactMap { index, sample in
            guard let id = UUID(uuidString: sample.0) else { return nil }
            return Artifact(
                id: id,
                kind: .manual,
                sourceCollectionTitle: collectionTitle,
                originalText: sample.2.name,
                userNote: sample.1,
                textExtractionState: .unavailable,
                linkMetadataState: .unavailable,
                place: sample.2,
                enrichment: ArtifactEnrichment(
                    summary: sample.5,
                    category: sample.3,
                    interests: sample.4,
                    source: .savedText,
                    confidence: 0.92,
                    generatedAt: Date(timeIntervalSince1970: 1_780_000_000 + Double(index))
                ),
                enrichmentState: .processed,
                processingState: .processed,
                capturedAt: Date(timeIntervalSince1970: 1_780_000_000 + Double(index))
            )
        }
    }
}
