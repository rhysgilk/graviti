import Foundation

struct SavedPlace: Codable, Hashable, Identifiable {
    let id: String
    let name: String
    let latitude: Double
    let longitude: Double
    let locality: String?
    let region: String?
    let country: String?

    var subtitle: String {
        [locality, region, country]
            .compactMap { $0 }
            .reduce(into: [String]()) { result, part in
                if !result.contains(part) { result.append(part) }
            }
            .joined(separator: ", ")
    }
}
