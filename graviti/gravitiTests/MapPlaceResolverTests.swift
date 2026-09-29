import XCTest
@testable import graviti

@MainActor
final class MapPlaceResolverTests: XCTestCase {
    func testInstagramCaptionExtractsPinnedBusinessHandleAndAddress() {
        let artifact = instagramArtifact(summary: "Hottest new sandwich spot in Boston 👀 The Roman Gold has a crispy chicken cutlet. What we ordered: The South End, The Calabria, Roman Gold 📍South End — @calistosdeli 682 Tremont St Boston, MA 02118")

        let hint = SocialPlaceHintExtractor.hint(for: artifact)

        XCTAssertEqual(hint?.expectedName, "calistosdeli")
        XCTAssertEqual(hint?.queries, [
            "calistosdeli, 682 Tremont St Boston, MA 02118",
            "calistosdeli"
        ])
    }

    func testInstagramCaptionDoesNotTreatOrdinaryMentionAsAPlace() {
        let artifact = instagramArtifact(summary: "A great sandwich from @calistosdeli in Boston.")

        XCTAssertNil(SocialPlaceHintExtractor.hint(for: artifact))
    }

    func testInstagramCaptionUsesLeadingBusinessHandleWithoutPin() {
        let artifact = instagramArtifact(summary: "@stewleonards apple cider donut sundae is a must try. 🍎")

        let hint = SocialPlaceHintExtractor.hint(for: artifact)

        XCTAssertEqual(hint?.expectedName, "stewleonards")
        XCTAssertEqual(hint?.queries, ["stewleonards"])
    }

    func testInstagramLeadingHandleMatchesPunctuatedBusinessName() async throws {
        let stewLeonards = savedPlace(
            id: "stew-leonards",
            name: "Stew Leonard's",
            latitude: 41.36,
            longitude: -73.42
        )
        let provider = RecordingPlaceSearchProvider(results: [
            PlaceCandidate(place: stewLeonards, sourceURL: "https://maps.apple.com")
        ])
        let resolver = MapPlaceResolver(
            searchProvider: provider,
            linkExpander: IdentityMapLinkExpander()
        )
        let artifact = instagramArtifact(
            summary: "@stewleonards apple cider donut sundae is a must try. 🍎"
        )

        let resolution = try await resolver.resolve(artifact)

        guard case .matched(let matched) = resolution else {
            return XCTFail("Expected the leading business handle to resolve Stew Leonard's")
        }
        XCTAssertEqual(matched.id, "stew-leonards")
        XCTAssertEqual(provider.queries, ["stewleonards"])
    }

    func testInstagramPinnedPlaceWinsOverLaterFollowHandle() {
        let artifact = instagramArtifact(summary: "All I could say is it’s so good. The prime rib melts in your mouth. 📍Josephine, Somerville, ma follow @bostoneatin for more Boston recs")

        let hint = SocialPlaceHintExtractor.hint(for: artifact)

        XCTAssertEqual(hint?.expectedName, "Josephine")
        XCTAssertEqual(hint?.queries, [
            "Josephine Somerville ma restaurant",
            "Josephine, Somerville, ma",
            "Josephine"
        ])
    }

    func testInstagramCaptionFindsNamedVenueOnStreetWithoutPin() {
        let artifact = instagramArtifact(summary: "we found the cutest lil hot pot spot in boston~ Growl Growl on Winter Street lets you build your own dreamy malatang bowl 🍜✨ @growlgrowl.usa")

        let hint = SocialPlaceHintExtractor.hint(for: artifact)

        XCTAssertEqual(hint?.expectedName, "Growl Growl")
        XCTAssertEqual(hint?.queries, ["Growl Growl, Winter Street", "Growl Growl"])
    }

    func testInstagramHandleMatchesPunctuatedMapKitName() async throws {
        let place = savedPlace(id: "calistos", name: "Calisto's Deli", latitude: 42.3429, longitude: -71.0712)
        let provider = RecordingPlaceSearchProvider { query in
            query.contains("682 Tremont St")
                ? [PlaceCandidate(place: place, sourceURL: "https://maps.apple.com")]
                : []
        }
        let resolver = MapPlaceResolver(searchProvider: provider, linkExpander: IdentityMapLinkExpander())
        let artifact = instagramArtifact(summary: "Best sandwiches in Boston 📍South End — @calistosdeli 682 Tremont St Boston, MA 02118")

        let resolution = try await resolver.resolve(artifact)

        guard case .matched(let matched) = resolution else {
            return XCTFail("Expected the pinned Instagram business to match")
        }
        XCTAssertEqual(matched.id, "calistos")
        XCTAssertEqual(provider.queries, ["calistosdeli, 682 Tremont St Boston, MA 02118"])
    }

    func testInstagramCaptionKeepsAmbiguousBusinessUnmatched() async throws {
        let candidates = [
            savedPlace(id: "one", name: "Calisto's Deli", latitude: 42.34, longitude: -71.07),
            savedPlace(id: "two", name: "Calistos Deli", latitude: 42.37, longitude: -71.11)
        ].map { PlaceCandidate(place: $0, sourceURL: "https://maps.apple.com") }
        let provider = RecordingPlaceSearchProvider(results: candidates)
        let resolver = MapPlaceResolver(searchProvider: provider, linkExpander: IdentityMapLinkExpander())
        let artifact = instagramArtifact(summary: "Sandwich stop 📍South End — @calistosdeli")

        let resolution = try await resolver.resolve(artifact)

        guard case .unmatched = resolution else {
            return XCTFail("Expected ambiguous social results to remain unmatched")
        }
    }

    func testInstagramCreatorHandleCannotResolveToBoston() async throws {
        let boston = savedPlace(id: "boston", name: "Boston", latitude: 42.36, longitude: -71.06)
        let josephine = savedPlace(id: "josephine", name: "Josephine", latitude: 42.39, longitude: -71.10)
        let provider = RecordingPlaceSearchProvider { query in
            query.hasPrefix("Josephine")
                ? [PlaceCandidate(place: josephine, sourceURL: "https://maps.apple.com")]
                : [PlaceCandidate(place: boston, sourceURL: "https://maps.apple.com")]
        }
        let resolver = MapPlaceResolver(searchProvider: provider, linkExpander: IdentityMapLinkExpander())
        let artifact = instagramArtifact(summary: "The prime rib melts in your mouth. 📍Josephine, Somerville, ma follow @bostoneatin for more Boston recs")

        let resolution = try await resolver.resolve(artifact)

        guard case .matched(let matched) = resolution else {
            return XCTFail("Expected Josephine rather than the creator's Boston handle")
        }
        XCTAssertEqual(matched.id, "josephine")
        XCTAssertEqual(provider.queries, ["Josephine Somerville ma restaurant"])
    }

    func testGoogleImportUsesAddressHintForSearch() async throws {
        let place = savedPlace(id: "tea", name: "Tea House", latitude: 40.7, longitude: -73.9)
        let provider = RecordingPlaceSearchProvider(results: [PlaceCandidate(place: place, sourceURL: "https://maps.apple.com")])
        let resolver = MapPlaceResolver(searchProvider: provider, linkExpander: IdentityMapLinkExpander())
        let artifact = Artifact(
            kind: .url,
            sourceURL: "https://www.google.com/maps/place/Tea%20House/data=!4m2?q=Tea%20House,%201%20Main%20St&ll=40.7,-73.9",
            originalText: "Tea House"
        )

        let resolution = try await resolver.resolve(artifact)

        guard case .matched(let matched) = resolution else {
            return XCTFail("Expected the exact place to match")
        }
        XCTAssertEqual(matched.id, "tea")
        XCTAssertEqual(provider.queries, ["Tea House, 1 Main St"])
    }

    func testCoordinateHintResolvesCompatibleRenamedPlace() async throws {
        let nearby = savedPlace(
            id: "nearby",
            name: "Aoko Matcha West Village",
            latitude: 40.7317,
            longitude: -74.0031
        )
        let unrelated = savedPlace(
            id: "other",
            name: "Aoko Matcha East Village",
            latitude: 40.7280,
            longitude: -73.9850
        )
        let provider = RecordingPlaceSearchProvider(results: [nearby, unrelated].map {
            PlaceCandidate(place: $0, sourceURL: "https://maps.apple.com")
        })
        let resolver = MapPlaceResolver(searchProvider: provider, linkExpander: IdentityMapLinkExpander())
        let artifact = Artifact(
            kind: .url,
            sourceURL: "https://www.google.com/maps/place/Aoko%20Matcha/data=!4m2?q=Aoko%20Matcha,%20275%20Bleecker%20St&ll=40.7316255,-74.0030701",
            originalText: "Aoko Matcha"
        )

        let resolution = try await resolver.resolve(artifact)

        guard case .matched(let matched) = resolution else {
            return XCTFail("Expected the nearby compatible place to match")
        }
        XCTAssertEqual(matched.id, "nearby")
    }

    func testCoordinateHintDoesNotSelectNearbyUnrelatedPlace() async throws {
        let place = savedPlace(id: "other", name: "Completely Different Cafe", latitude: 40.7001, longitude: -73.9001)
        let provider = RecordingPlaceSearchProvider(results: [PlaceCandidate(place: place, sourceURL: "https://maps.apple.com")])
        let resolver = MapPlaceResolver(searchProvider: provider, linkExpander: IdentityMapLinkExpander())
        let artifact = Artifact(
            kind: .url,
            sourceURL: "https://www.google.com/maps/place/Tea%20House/data=!4m2?q=Tea%20House,%201%20Main%20St&ll=40.7,-73.9",
            originalText: "Tea House"
        )

        let resolution = try await resolver.resolve(artifact)

        guard case .needsReview = resolution else {
            return XCTFail("Expected an unrelated candidate to need review")
        }
    }

    func testRetriesANameWithoutAlternateScriptCharacters() async throws {
        let place = savedPlace(
            id: "calistos",
            name: "Calistos Deli",
            latitude: 42.3429,
            longitude: -71.0712
        )
        let provider = RecordingPlaceSearchProvider { query in
            query == "Calistos Deli"
                ? [PlaceCandidate(place: place, sourceURL: "https://maps.apple.com")]
                : []
        }
        let resolver = MapPlaceResolver(searchProvider: provider, linkExpander: IdentityMapLinkExpander())
        let artifact = Artifact(
            kind: .url,
            sourceURL: "https://www.google.com/maps/place/Calistos%20Deli%20%E5%8D%A1%E5%88%A9%E6%96%AF%E6%89%98?q=Calistos%20Deli%20%E5%8D%A1%E5%88%A9%E6%96%AF%E6%89%98,%20682%20Tremont%20St%20Boston%20MA",
            originalText: "Calistos Deli 卡利斯托"
        )

        let resolution = try await resolver.resolve(artifact)

        guard case .matched(let matched) = resolution else {
            return XCTFail("Expected a cleaned query to match the place")
        }
        XCTAssertEqual(matched.id, "calistos")
        XCTAssertEqual(provider.queries, [
            "Calistos Deli 卡利斯托, 682 Tremont St Boston MA",
            "Calistos Deli 卡利斯托",
            "Calistos Deli"
        ])
    }

    func testAppleAddressIsIncludedInAutomaticSearch() async throws {
        let place = savedPlace(id: "tea", name: "Tea House", latitude: 41.82, longitude: -71.41)
        let provider = RecordingPlaceSearchProvider(results: [
            PlaceCandidate(place: place, sourceURL: "https://maps.apple.com")
        ])
        let resolver = MapPlaceResolver(searchProvider: provider, linkExpander: IdentityMapLinkExpander())
        let artifact = Artifact(
            kind: .url,
            sourceURL: "https://maps.apple.com/?q=Tea%20House&address=1%20Main%20St,%20Providence,%20RI"
        )

        let resolution = try await resolver.resolve(artifact)

        guard case .matched = resolution else {
            return XCTFail("Expected the Apple Maps place to match")
        }
        XCTAssertEqual(provider.queries, ["Tea House, 1 Main St, Providence, RI"])
    }

    func testCleanedNameKeepsMultipleLocationsForReview() async throws {
        let southEnd = savedPlace(id: "south", name: "Calistos Deli", latitude: 42.34, longitude: -71.07)
        let cambridge = savedPlace(id: "north", name: "Calistos Deli", latitude: 42.37, longitude: -71.11)
        let candidates = [southEnd, cambridge].map {
            PlaceCandidate(place: $0, sourceURL: "https://maps.apple.com")
        }
        let provider = RecordingPlaceSearchProvider { query in
            query == "Calistos Deli" ? candidates : []
        }
        let resolver = MapPlaceResolver(searchProvider: provider, linkExpander: IdentityMapLinkExpander())
        let artifact = Artifact(
            kind: .url,
            sourceURL: "https://www.google.com/maps/place/Calistos%20Deli%20%E5%8D%A1%E5%88%A9%E6%96%AF%E6%89%98",
            originalText: "Calistos Deli 卡利斯托"
        )

        let resolution = try await resolver.resolve(artifact)

        guard case .needsReview = resolution else {
            return XCTFail("Expected genuinely ambiguous locations to remain for review")
        }
    }

    private func savedPlace(
        id: String,
        name: String,
        latitude: Double,
        longitude: Double
    ) -> SavedPlace {
        SavedPlace(
            id: id,
            name: name,
            latitude: latitude,
            longitude: longitude,
            locality: "New York",
            region: "New York",
            country: "United States"
        )
    }

    private func instagramArtifact(summary: String) -> Artifact {
        let url = "https://www.instagram.com/reel/example/"
        return Artifact(
            kind: .url,
            sourceURL: url,
            originalText: "Instagram reel",
            linkMetadata: ArtifactLinkMetadata(
                title: "Boston sandwich shop",
                summary: summary,
                siteName: "Instagram",
                imageData: nil,
                resolvedURL: url,
                fetchedAt: .now
            ),
            linkMetadataState: .processed
        )
    }
}

@MainActor
private final class RecordingPlaceSearchProvider: PlaceSearchProviding {
    private let resultsForQuery: (String) -> [PlaceCandidate]
    private(set) var queries = [String]()

    init(results: [PlaceCandidate]) {
        self.resultsForQuery = { _ in results }
    }

    init(resultsForQuery: @escaping (String) -> [PlaceCandidate]) {
        self.resultsForQuery = resultsForQuery
    }

    func search(_ query: String) async throws -> [PlaceCandidate] {
        queries.append(query)
        return resultsForQuery(query)
    }
}

@MainActor
private struct IdentityMapLinkExpander: MapLinkExpanding {
    func expandedURL(for rawURL: String) async -> String { rawURL }
}
