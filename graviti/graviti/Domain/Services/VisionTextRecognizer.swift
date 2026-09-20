import Foundation
import Vision

struct VisionTextRecognizer {
    func recognizeText(at imageURL: URL) async throws -> String? {
        try await Task.detached(priority: .utility) {
            let request = VNRecognizeTextRequest()
            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = true
            let handler = VNImageRequestHandler(url: imageURL, options: [:])
            try handler.perform([request])

            let lines = (request.results ?? [])
                .sorted { lhs, rhs in
                    let verticalDifference = lhs.boundingBox.midY - rhs.boundingBox.midY
                    if abs(verticalDifference) > 0.02 { return verticalDifference > 0 }
                    return lhs.boundingBox.minX < rhs.boundingBox.minX
                }
                .compactMap { $0.topCandidates(1).first?.string.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
            let text = lines.joined(separator: "\n")
            return text.isEmpty ? nil : text
        }.value
    }
}
