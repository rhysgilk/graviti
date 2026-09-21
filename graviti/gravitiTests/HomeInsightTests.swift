import XCTest
@testable import graviti

final class HomeInsightTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_800_000_000)

    func testRecentIndependentPlacesProduceGainingGravityInsight() throws {
        let artifacts = [
            artifact("tea", city: "Tokyo", country: "Japan", daysAgo: 2),
            artifact("museum", city: "Tokyo", country: "Japan", daysAgo: 8),
            artifact("garden", city: "Tokyo", country: "Japan", daysAgo: 18)
        ]

        let insights = insights(for: artifacts)
        let gaining = try XCTUnwrap(insights.first { $0.kind == .gainingGravity })

        XCTAssertEqual(gaining.destination.name, "Tokyo")
        XCTAssertTrue(gaining.detail.contains("3"))
    }

    func testSeveralStrongCitiesProduceGeographicSplitInsight() throws {
        let artifacts = (0..<3).map {
            artifact("tokyo-\($0)", city: "Tokyo", country: "Japan", daysAgo: $0 + 1)
        } + (0..<3).map {
            artifact("kyoto-\($0)", city: "Kyoto", country: "Japan", daysAgo: $0 + 4)
        }

        let split = try XCTUnwrap(insights(for: artifacts).first { $0.kind == .geographicSplit })

        XCTAssertEqual(split.title, "Japan is coming into focus")
        XCTAssertTrue(split.detail.contains("Tokyo"))
        XCTAssertTrue(split.detail.contains("Kyoto"))
    }

    func testInterestAcrossDestinationsProducesRecurringPatternInsight() throws {
        let artifacts = [
            artifact("acadia-1", city: "Bar Harbor", country: "United States", daysAgo: 70, interest: "Rocky coast"),
            artifact("acadia-2", city: "Bar Harbor", country: "United States", daysAgo: 65, interest: "Rocky coast"),
            artifact("porto-1", city: "Porto", country: "Portugal", daysAgo: 55, interest: "Rocky coast"),
            artifact("porto-2", city: "Porto", country: "Portugal", daysAgo: 50, interest: "Rocky coast")
        ]

        let recurring = try XCTUnwrap(insights(for: artifacts).first { $0.kind == .recurringInterest })

        XCTAssertEqual(recurring.title, "Rocky coast keeps showing up")
        XCTAssertTrue(recurring.detail.contains("2 destinations"))
    }

    func testStrongDestinationWithoutRecentSavesProducesQuietInsight() throws {
        let artifacts = (0..<4).map {
            artifact("maine-\($0)", city: "Portland", country: "United States", daysAgo: 160 + $0)
        }

        let quiet = try XCTUnwrap(insights(for: artifacts).first { $0.kind == .quietDestination })

        XCTAssertEqual(quiet.destination.name, "Portland")
        XCTAssertTrue(quiet.detail.hasPrefix("No new saves in"))
    }

    func testSparseLibraryUsesConservativeLeaderFallback() throws {
        let artifacts = [artifact("kyoto", city: "Kyoto", country: "Japan", daysAgo: 2)]

        let result = try XCTUnwrap(insights(for: artifacts).first)

        XCTAssertEqual(result.kind, .fieldLeader)
        XCTAssertEqual(result.destination.name, "Kyoto")
    }

    private func insights(for artifacts: [Artifact]) -> [HomeInsight] {
        let nodes = DestinationOrbitBuilder.nodes(from: artifacts, mode: .cities, limit: nil)
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return HomeInsightBuilder.build(nodes: nodes, artifacts: artifacts, now: now, calendar: calendar)
    }

    private func artifact(
        _ id: String,
        city: String,
        country: String,
        daysAgo: Int,
        interest: String? = nil
    ) -> Artifact {
        let date = Calendar(identifier: .gregorian).date(byAdding: .day, value: -daysAgo, to: now)!
        let enrichment = interest.map {
            ArtifactEnrichment(
                summary: nil,
                category: .sceneryAndNature,
                interests: [$0],
                source: .savedText,
                confidence: 0.8,
                generatedAt: date
            )
        }
        return Artifact(
            kind: .manual,
            originalText: id,
            place: SavedPlace(
                id: id,
                name: id,
                latitude: 0,
                longitude: 0,
                locality: city,
                region: nil,
                country: country
            ),
            enrichment: enrichment,
            enrichmentState: enrichment == nil ? .pending : .processed,
            processingState: .processed,
            capturedAt: date
        )
    }
}
