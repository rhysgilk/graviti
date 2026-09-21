import Foundation

struct DestinationKnowledgeCatalog: Codable {
    let schemaVersion: Int
    let catalogVersion: String
    let reviewedAt: String
    let destinations: [DestinationKnowledge]
}

struct DestinationKnowledge: Codable, Identifiable {
    let name: String
    let country: String
    let region: RecommendationRegion
    let searchSpan: Double
    let dataConfidence: Double
    let strengths: [String: Double]
    let sources: [DestinationKnowledgeSource]

    var id: String { "\(name), \(country)" }
}

struct DestinationKnowledgeSource: Codable, Hashable, Identifiable {
    let title: String
    let url: URL
    let reviewedAt: String

    var id: URL { url }
}

enum DestinationKnowledgeCatalogError: Error, Equatable {
    case unsupportedSchemaVersion(Int)
    case emptyCatalog
    case duplicateDestination(String)
    case invalidSearchSpan(String)
    case invalidDataConfidence(String)
    case missingStrengths(String)
    case invalidStrength(String)
    case missingSources(String)
    case insecureSource(String)
}

enum DestinationKnowledgeCatalogLoader {
    static let supportedSchemaVersion = 1

    static let bundled: DestinationKnowledgeCatalog = {
        guard let url = Bundle.main.url(forResource: "destination-catalog-v1", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let catalog = try? decode(data) else {
            assertionFailure("The reviewed destination knowledge catalog is missing or invalid.")
            return DestinationKnowledgeCatalog(
                schemaVersion: supportedSchemaVersion,
                catalogVersion: "unavailable",
                reviewedAt: "",
                destinations: []
            )
        }
        return catalog
    }()

    static func decode(_ data: Data) throws -> DestinationKnowledgeCatalog {
        let catalog = try JSONDecoder().decode(DestinationKnowledgeCatalog.self, from: data)
        try validate(catalog)
        return catalog
    }

    static func validate(_ catalog: DestinationKnowledgeCatalog) throws {
        guard catalog.schemaVersion == supportedSchemaVersion else {
            throw DestinationKnowledgeCatalogError.unsupportedSchemaVersion(catalog.schemaVersion)
        }
        guard !catalog.destinations.isEmpty else {
            throw DestinationKnowledgeCatalogError.emptyCatalog
        }

        var ids = Set<String>()
        for destination in catalog.destinations {
            guard ids.insert(destination.id.foldedDestinationKey).inserted else {
                throw DestinationKnowledgeCatalogError.duplicateDestination(destination.id)
            }
            guard destination.searchSpan > 0 else {
                throw DestinationKnowledgeCatalogError.invalidSearchSpan(destination.id)
            }
            guard (0...0.95).contains(destination.dataConfidence) else {
                throw DestinationKnowledgeCatalogError.invalidDataConfidence(destination.id)
            }
            guard !destination.strengths.isEmpty else {
                throw DestinationKnowledgeCatalogError.missingStrengths(destination.id)
            }
            guard destination.strengths.values.allSatisfy({ (0...1).contains($0) }) else {
                throw DestinationKnowledgeCatalogError.invalidStrength(destination.id)
            }
            guard !destination.sources.isEmpty else {
                throw DestinationKnowledgeCatalogError.missingSources(destination.id)
            }
            guard destination.sources.allSatisfy({ $0.url.scheme == "https" }) else {
                throw DestinationKnowledgeCatalogError.insecureSource(destination.id)
            }
        }
    }
}

private extension String {
    var foldedDestinationKey: String {
        folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
    }
}
