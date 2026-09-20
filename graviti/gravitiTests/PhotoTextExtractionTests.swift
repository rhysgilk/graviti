import XCTest
import UIKit
@testable import graviti

@MainActor
final class PhotoTextExtractionTests: XCTestCase {
    func testExtractedTextResetsGeneratedEnrichmentAndKeepsUserDetails() {
        let details = ArtifactUserDetails(
            summary: "A place I want to visit",
            category: .foodAndDrink,
            interests: ["Tea"]
        )
        let artifact = Artifact(
            kind: .photo,
            mediaKey: "photo.png",
            enrichment: ArtifactEnrichment(
                summary: "Old suggestion",
                category: .other,
                interests: [],
                source: .savedText,
                confidence: 0.5,
                generatedAt: .now
            ),
            enrichmentState: .processed,
            userDetails: details
        )

        let updated = artifact.withExtractedText(
            "Ceremonial matcha in Kyoto",
            source: .appleVision,
            state: .processed
        )

        XCTAssertNil(updated.enrichment)
        XCTAssertEqual(updated.enrichmentState, .pending)
        XCTAssertEqual(updated.userDetails, details)
        XCTAssertEqual(updated.extractedTextSource, .appleVision)
    }

    func testEnrichmentUsesDetectedImageText() async throws {
        let artifact = Artifact(
            kind: .photo,
            mediaKey: "photo.png",
            extractedText: "Scenic mountain waterfall and forest hiking trail",
            extractedTextSource: .appleVision,
            textExtractionState: .processed
        )

        let enrichment = try await ArtifactEnricher().enrich(artifact)

        XCTAssertEqual(enrichment?.category, .sceneryAndNature)
        XCTAssertTrue(enrichment?.interests.contains("Mountains") == true)
        XCTAssertTrue(enrichment?.interests.contains("Forests") == true)
        XCTAssertTrue(enrichment?.interests.contains("Hiking") == true)
        XCTAssertEqual(enrichment?.source, .detectedText)
    }

    func testVisionRecognizerReadsClearImageText() async throws {
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 1200, height: 320))
        let image = renderer.image { context in
            UIColor.white.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 1200, height: 320))
            let attributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.boldSystemFont(ofSize: 100),
                .foregroundColor: UIColor.black
            ]
            "MATCHA IN KYOTO".draw(at: CGPoint(x: 55, y: 90), withAttributes: attributes)
        }
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("png")
        try XCTUnwrap(image.pngData()).write(to: url)
        defer { try? FileManager.default.removeItem(at: url) }

        let result = try await VisionTextRecognizer().recognizeText(at: url)

        XCTAssertTrue(result?.uppercased().contains("MATCHA") == true)
        XCTAssertTrue(result?.uppercased().contains("KYOTO") == true)
    }
}
