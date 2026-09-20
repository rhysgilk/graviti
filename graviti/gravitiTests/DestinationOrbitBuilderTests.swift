import XCTest
@testable import graviti

final class DestinationOrbitBuilderTests: XCTestCase {
    func testAutomaticModeCollapsesSmallMultiCityCountry() throws {
        let artifacts = [
            artifact("a", city: "Kyoto", region: "Kyoto", country: "Japan"),
            artifact("b", city: "Tokyo", region: "Tokyo", country: "Japan"),
            artifact("c", city: "Osaka", region: "Osaka", country: "Japan")
        ]

        let nodes = DestinationOrbitBuilder.nodes(from: artifacts, limit: nil)
        let japan = try XCTUnwrap(nodes.first { $0.name == "Japan" })

        XCTAssertEqual(japan.level, .country)
        XCTAssertEqual(japan.saveCount, 3)
        XCTAssertFalse(nodes.contains { ["Kyoto", "Tokyo", "Osaka"].contains($0.name) })
        XCTAssertEqual(DestinationOrbitBuilder.children(of: japan, from: artifacts).count, 3)
    }

    func testAutomaticModeExpandsMultipleEvidenceBackedCityClusters() {
        let artifacts = [
            artifact("k1", city: "Kyoto", region: "Kyoto", country: "Japan"),
            artifact("k2", city: "Kyoto", region: "Kyoto", country: "Japan"),
            artifact("k3", city: "Kyoto", region: "Kyoto", country: "Japan"),
            artifact("t1", city: "Tokyo", region: "Tokyo", country: "Japan"),
            artifact("t2", city: "Tokyo", region: "Tokyo", country: "Japan"),
            artifact("o1", city: "Osaka", region: "Osaka", country: "Japan")
        ]

        let nodes = DestinationOrbitBuilder.nodes(from: artifacts, limit: 10)

        XCTAssertFalse(nodes.contains { $0.name == "Japan" })
        XCTAssertEqual(Set(nodes.map(\.name)), ["Kyoto", "Tokyo", "Osaka"])
    }

    func testAutomaticModeUsesStateForSeveralCitiesInOneRegion() {
        let artifacts = [
            artifact("sf1", city: "San Francisco", region: "California", country: "United States"),
            artifact("sf2", city: "San Francisco", region: "California", country: "United States"),
            artifact("la1", city: "Los Angeles", region: "California", country: "United States"),
            artifact("la2", city: "Los Angeles", region: "California", country: "United States"),
            artifact("c1", city: "Chicago", region: "Illinois", country: "United States"),
            artifact("c2", city: "Chicago", region: "Illinois", country: "United States")
        ]

        let nodes = DestinationOrbitBuilder.nodes(from: artifacts, limit: 10)

        XCTAssertTrue(nodes.contains { $0.name == "California" && $0.level == .stateProvince && $0.saveCount == 4 })
        XCTAssertTrue(nodes.contains { $0.name == "Chicago" && $0.level == .city && $0.saveCount == 2 })
        XCTAssertFalse(nodes.contains { $0.name == "United States" })
    }

    func testAutomaticModeKeepsCountryGroupedWhenExpansionExceedsLabelBudget() {
        let japan = [
            artifact("k1", city: "Kyoto", region: "Kyoto", country: "Japan"),
            artifact("k2", city: "Kyoto", region: "Kyoto", country: "Japan"),
            artifact("t1", city: "Tokyo", region: "Tokyo", country: "Japan"),
            artifact("t2", city: "Tokyo", region: "Tokyo", country: "Japan"),
            artifact("o1", city: "Osaka", region: "Osaka", country: "Japan"),
            artifact("o2", city: "Osaka", region: "Osaka", country: "Japan")
        ]
        let artifacts = japan + [
            artifact("p", city: "Lisbon", region: "Lisbon", country: "Portugal"),
            artifact("m", city: "Montreal", region: "Quebec", country: "Canada")
        ]

        let nodes = DestinationOrbitBuilder.nodes(from: artifacts, limit: 3)

        XCTAssertEqual(nodes.count, 3)
        XCTAssertTrue(nodes.contains { $0.name == "Japan" && $0.level == .country })
        XCTAssertFalse(nodes.contains { ["Kyoto", "Tokyo", "Osaka"].contains($0.name) })
    }

    func testExplicitStateModeFallsBackWhenRegionIsMissing() {
        let artifacts = [
            artifact("a", city: "Portland", region: "Oregon", country: "United States"),
            artifact("b", city: "Singapore", region: nil, country: "Singapore")
        ]

        let nodes = DestinationOrbitBuilder.nodes(from: artifacts, mode: .statesProvinces, limit: nil)

        XCTAssertTrue(nodes.contains { $0.name == "Oregon" && $0.level == .stateProvince })
        XCTAssertTrue(nodes.contains { $0.name == "Singapore" && $0.level == .country })
    }

    func testArtifactsForNodeUsesStableGeographicIdentity() throws {
        let kyoto = artifact("a", city: "Kyoto", region: "Kyoto", country: "Japan")
        let boston = artifact("b", city: "Boston", region: "Massachusetts", country: "United States")
        let nodes = DestinationOrbitBuilder.nodes(from: [kyoto, boston], mode: .cities, limit: nil)
        let kyotoNode = try XCTUnwrap(nodes.first { $0.name == "Kyoto" })

        XCTAssertEqual(DestinationOrbitBuilder.artifacts(for: kyotoNode, from: [kyoto, boston]).map(\.id), [kyoto.id])
    }

    func testDefaultLabelBudgetKeepsTheTenStrongestDestinations() {
        let artifacts = (0..<12).flatMap { destination in
            (0...destination).map { save in
                artifact(
                    "destination-\(destination)-save-\(save)",
                    city: "City \(destination)",
                    region: "Region \(destination)",
                    country: "Country \(destination)"
                )
            }
        }

        let nodes = DestinationOrbitBuilder.nodes(from: artifacts, mode: .cities)

        XCTAssertEqual(nodes.count, 10)
        XCTAssertEqual(nodes.first?.name, "City 11")
        XCTAssertFalse(nodes.contains { $0.name == "City 0" || $0.name == "City 1" })
        XCTAssertEqual(HomeInsight(nodes: nodes)?.leadingDestination.name, "City 11")
    }

    private func artifact(_ id: String, city: String, region: String?, country: String) -> Artifact {
        Artifact(
            id: UUID(),
            kind: .manual,
            originalText: id,
            place: SavedPlace(id: id, name: id, latitude: 0, longitude: 0, locality: city, region: region, country: country),
            processingState: .processed
        )
    }
}
