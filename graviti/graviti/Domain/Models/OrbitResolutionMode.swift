import Foundation

enum OrbitResolutionMode: String, Codable, CaseIterable, Identifiable {
    case automatic
    case countries
    case statesProvinces
    case cities

    var id: Self { self }

    var displayName: String {
        switch self {
        case .automatic: String(localized: "Automatic")
        case .countries: String(localized: "Countries")
        case .statesProvinces: String(localized: "States & Provinces")
        case .cities: String(localized: "Cities")
        }
    }
}
