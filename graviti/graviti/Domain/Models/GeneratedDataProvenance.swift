import Foundation

struct GeneratedDataProvenance: Codable, Hashable {
    let producer: String
    let version: Int
    let generatedAt: Date
    let inputFingerprint: String?

    init(
        producer: String,
        version: Int,
        generatedAt: Date = .now,
        inputFingerprint: String? = nil
    ) {
        self.producer = producer
        self.version = version
        self.generatedAt = generatedAt
        self.inputFingerprint = inputFingerprint
    }
}
