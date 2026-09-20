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
