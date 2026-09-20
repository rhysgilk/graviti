import XCTest
@testable import graviti

final class LibraryBackupServiceTests: XCTestCase {
    func testRoundTripPreservesArtifactAndEmbeddedMedia() throws {
        let timestamp = Date(timeIntervalSince1970: 1_700_000_000)
        let artifact = Artifact(
            id: UUID(),
            kind: .photo,
            userNote: "Rocky coast at sunrise",
            mediaKey: "photo.jpg",
            extractedText: "Acadia",
            extractedTextSource: .appleVision,
            textExtractionState: .processed,
            place: SavedPlace(
                id: "acadia", name: "Acadia National Park", latitude: 44.35, longitude: -68.21,
                locality: "Bar Harbor", region: "Maine", country: "United States"
            ),
            enrichment: ArtifactEnrichment(
                summary: "A rocky coastal national park.", category: .sceneryAndNature,
                interests: ["Coast & water", "National parks"], source: .detectedText,
                confidence: 0.8, generatedAt: timestamp
            ),
            enrichmentState: .processed,
            processingState: .processed,
            capturedAt: timestamp
        )
        let media = Data([0xFF, 0xD8, 0xFF])

        let encoded = try LibraryBackupService.encode([artifact]) { key in
            XCTAssertEqual(key, "photo.jpg")
            return media
        }
        let decoded = try LibraryBackupService.decode(encoded)

        XCTAssertEqual(decoded.schemaVersion, 1)
        XCTAssertEqual(decoded.artifacts.first?.artifact, artifact)
        XCTAssertEqual(decoded.artifacts.first?.mediaData, media)
        XCTAssertEqual(decoded.artifacts.first?.mediaFileExtension, "jpg")
    }

    func testDecodeRejectsUnsupportedSchema() throws {
        let archive = LibraryBackupArchive(schemaVersion: 999, exportedAt: .now, artifacts: [])
        let data = try JSONEncoder().encode(archive)

        XCTAssertThrowsError(try LibraryBackupService.decode(data))
    }

    func testDecodeRejectsDuplicateArtifactIDs() throws {
        let artifact = Artifact(id: UUID(), kind: .manual, originalText: "One")
        let entry = LibraryBackupEntry(artifact: artifact, mediaData: nil, mediaFileExtension: nil)
        let archive = LibraryBackupArchive(schemaVersion: 1, exportedAt: .now, artifacts: [entry, entry])
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .secondsSince1970

        XCTAssertThrowsError(try LibraryBackupService.decode(encoder.encode(archive)))
    }
}
