import Foundation

enum InterestDisplayName {
    static func localized(_ value: String) -> String {
        switch value {
        case "Matcha": String(localized: "Matcha")
        case "Tea": String(localized: "Tea")
        case "Coffee": String(localized: "Coffee")
        case "Desserts": String(localized: "Desserts")
        case "Ramen": String(localized: "Ramen")
        case "Seafood": String(localized: "Seafood")
        case "Scenic views": String(localized: "Scenic views")
        case "National parks": String(localized: "National parks")
        case "Mountains": String(localized: "Mountains")
        case "Coast & water": String(localized: "Coast & water")
        case "Forests": String(localized: "Forests")
        case "Wildlife": String(localized: "Wildlife")
        case "Hiking": String(localized: "Hiking")
        case "Beaches": String(localized: "Beaches")
        case "Architecture": String(localized: "Architecture")
        case "History": String(localized: "History")
        case "Museums": String(localized: "Museums")
        case "Gardens": String(localized: "Gardens")
        case "Shopping": String(localized: "Shopping")
        case "Nature": String(localized: "Nature")
        default: value
        }
    }

    static func joined(_ values: some Sequence<String>, separator: String = " · ") -> String {
        var localizedValues: [String] = []
        for value in values {
            localizedValues.append(localized(value))
        }
        return localizedValues.joined(separator: separator)
    }
}
